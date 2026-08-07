import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_data.dart';
import 'package:cottage/models/profile.dart';
import 'package:cottage/helpers/supabase_service.dart';
import 'package:cottage/helpers/format_month.dart';
import 'package:cottage/helpers/utility_categories.dart';
import '../../bazaar_duty/data/bazaar_duty_service.dart';

/// Ports the aggregation logic in src/lib/data/finance.ts and
/// src/lib/data/meal.ts. These are NOT Postgres RPCs on the web side --
/// they fetch raw rows and aggregate client-side -- so this does the same,
/// on the same tables, to stay in sync with the web app's numbers.
class DashboardService {
  final SupabaseClient _client = SupabaseService.client;
  final BazaarDutyService _bazaarDutyService = BazaarDutyService();

  /// The signed-in member's own profile row -- mirrors getCurrentProfile in
  /// src/lib/data/dal.ts (a smaller column slice for Phase 1).
  Future<Profile> getCurrentProfile() async {
    final userId = SupabaseService.currentUser!.id;
    final row = await _client
        .from('profiles')
        .select('id, cottage_id, first_name, last_name, email, avatar_url, mobile_number, address, role')
        .eq('id', userId)
        .single();
    return Profile.fromMap(row);
  }

  /// cottages.active_month_key, falling back to the current calendar month
  /// if unset -- mirrors getActiveMonthKey in src/lib/data/months.ts.
  Future<String> getActiveMonthKey(String cottageId) async {
    final row = await _client.from('cottages').select('active_month_key').eq('id', cottageId).single();
    final key = row['active_month_key'] as String?;
    if (key != null && key.isNotEmpty) return key;
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
  }

  /// [start, end) date bounds for a "YYYY-MM" month key -- mirrors
  /// monthRange in src/lib/data/finance.ts.
  (String start, String end) _monthRange(String monthKey) {
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final start = DateTime.utc(year, month, 1);
    final end = DateTime.utc(year, month + 1, 1);
    String iso(DateTime d) => d.toIso8601String().substring(0, 10);
    return (iso(start), iso(end));
  }

  Future<double> _getCottageBalance(String cottageId) async {
    final rows = await _client
        .from('cottage_balance_transactions')
        .select('amount, direction')
        .eq('cottage_id', cottageId);
    double sum = 0;
    for (final row in rows as List) {
      final amount = (row['amount'] as num).toDouble();
      sum += row['direction'] == 'in' ? amount : -amount;
    }
    return sum;
  }

  Future<double> _getMonthlyExpenseTotal(String monthKey) async {
    final (start, end) = _monthRange(monthKey);
    final rows = await _client.from('expenses').select('amount').gte('expense_date', start).lt('expense_date', end);
    double sum = 0;
    for (final row in rows as List) {
      sum += (row['amount'] as num).toDouble();
    }
    return sum;
  }

  /// Just this member's due -- mirrors getMonthlyDues in finance.ts, scoped
  /// to one user instead of building the whole-cottage map (the Dashboard
  /// only ever needs "my" row). Also keeps the raw adjustment/deposit/
  /// carry-in rows (not just totals) for the utility breakdown sheet and
  /// invoice export -- mirrors the queries in
  /// src/app/(house)/dashboard/page.tsx (myAdjustmentsQuery, myDepositsQuery,
  /// getCarryIns filtered to this member).
  Future<(MemberDue, List<AdjustmentLine>, List<DepositLine>, List<CarryInLine>)> _getMyDue(
    String cottageId,
    String monthKey,
    String userId,
  ) async {
    final adjustments = await _client
        .from('utility_adjustments')
        .select('id, category, amount, created_at')
        .eq('cottage_id', cottageId)
        .eq('month_key', monthKey)
        .eq('user_id', userId)
        .order('created_at');

    double rent = 0;
    double expenses = 0;
    final adjustmentLines = <AdjustmentLine>[];
    for (final row in adjustments as List) {
      final amount = (row['amount'] as num).toDouble();
      final category = row['category'] as String;
      if (category == 'house_rent') {
        rent += amount;
      } else {
        expenses += amount;
      }
      adjustmentLines.add(AdjustmentLine(
        id: row['id'] as String,
        date: DateTime.parse(row['created_at'] as String),
        label: utilityCategoryLabel(category),
        amount: amount,
      ));
    }

    final deposits = await _client
        .from('utility_deposits')
        .select('id, deposit_date, amount, note')
        .eq('cottage_id', cottageId)
        .eq('month_key', monthKey)
        .eq('user_id', userId)
        .eq('source_type', 'member')
        .order('deposit_date', ascending: false);

    double paid = 0;
    final depositLines = <DepositLine>[];
    for (final row in deposits as List) {
      final amount = (row['amount'] as num).toDouble();
      paid += amount;
      depositLines.add(DepositLine(
        id: row['id'] as String,
        date: DateTime.parse(row['deposit_date'] as String),
        note: row['note'] as String?,
        amount: amount,
      ));
    }

    final carryInRows = await _client
        .from('utility_carry_ins')
        .select('id, amount, source_month_key, kind')
        .eq('cottage_id', cottageId)
        .eq('month_key', monthKey)
        .eq('user_id', userId);

    double carryIn = 0;
    final carryInLines = <CarryInLine>[];
    for (final row in carryInRows as List) {
      final amount = (row['amount'] as num).toDouble();
      final kind = row['kind'] as String;
      carryIn += amount;
      final sourceLabel = formatMonthKey(row['source_month_key'] as String);
      final kindLabel = kind == 'utility' ? 'Utility' : 'Meal';
      final stateLabel = amount >= 0 ? 'Due' : (kind == 'utility' ? 'Advanced' : 'Balance');
      carryInLines.add(CarryInLine(
        id: row['id'] as String,
        label: '$sourceLabel $kindLabel $stateLabel',
        amount: amount,
      ));
    }

    final due = MemberDue(
      rent: rent,
      expenses: expenses,
      carryIn: carryIn,
      paid: paid,
      due: rent + expenses + carryIn - paid,
    );
    return (due, adjustmentLines, depositLines, carryInLines);
  }

  Future<List<Profile>> _getActiveMembers(String cottageId) async {
    final rows = await _client
        .from('profiles')
        .select('id, cottage_id, first_name, last_name, email, avatar_url')
        .eq('cottage_id', cottageId)
        .eq('is_active', true)
        .order('last_name');
    return (rows as List).map((r) => Profile.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Mirrors getMealTotals + getMemberMealSummary in src/lib/data/meal.ts.
  Future<(double mealRate, double totalMeals, double totalBazaar, Map<String, double> mealsByUser, Map<String, double> depositsByUser)>
      _getMealTotals(String monthKey) async {
    final bazaarRows = await _client.from('bazaar_entries').select('amount').eq('month_key', monthKey);
    double totalBazaar = 0;
    for (final row in bazaarRows as List) {
      totalBazaar += (row['amount'] as num).toDouble();
    }

    final mealRows = await _client.from('daily_meals').select('user_id, count').eq('month_key', monthKey);
    double totalMeals = 0;
    final mealsByUser = <String, double>{};
    for (final row in mealRows as List) {
      final count = (row['count'] as num).toDouble();
      totalMeals += count;
      final userId = row['user_id'] as String;
      mealsByUser[userId] = (mealsByUser[userId] ?? 0) + count;
    }

    final depositRows = await _client.from('meal_deposits').select('user_id, amount').eq('month_key', monthKey);
    final depositsByUser = <String, double>{};
    for (final row in depositRows as List) {
      final amount = (row['amount'] as num).toDouble();
      final userId = row['user_id'] as String;
      depositsByUser[userId] = (depositsByUser[userId] ?? 0) + amount;
    }

    final mealRate = totalMeals > 0 ? totalBazaar / totalMeals : 0.0;
    return (mealRate, totalMeals, totalBazaar, mealsByUser, depositsByUser);
  }

  /// cottages.name -- mirrors profile.cottage_name in src/lib/data/dal.ts
  /// (there, joined onto the profile row; here, a small standalone lookup
  /// alongside active_month_key).
  Future<String> _getCottageName(String cottageId) async {
    final row = await _client.from('cottages').select('name').eq('id', cottageId).single();
    return row['name'] as String? ?? '';
  }

  Future<DashboardData> load(Profile me) async {
    final monthKey = await getActiveMonthKey(me.cottageId);
    final cottageName = await _getCottageName(me.cottageId);

    final cottageBalanceFuture = _getCottageBalance(me.cottageId);
    final totalUtilityExpenseFuture = _getMonthlyExpenseTotal(monthKey);
    final myDueFuture = _getMyDue(me.cottageId, monthKey, me.id);
    final membersFuture = _getActiveMembers(me.cottageId);
    // Shared roster of every member's upcoming/current bazaar duty -- mirrors
    // getCottageBazaarDuties in src/lib/data/bazaar-duty.ts, fetched
    // alongside everything else like the web dashboard does.
    final bazaarDutiesFuture = _bazaarDutyService.getCottageBazaarDuties(me.cottageId);

    final cottageBalance = await cottageBalanceFuture;
    final totalUtilityExpense = await totalUtilityExpenseFuture;
    final (myDue, myAdjustmentLines, myDepositLines, myCarryInLines) = await myDueFuture;
    final members = await membersFuture;
    final bazaarDuties = await bazaarDutiesFuture;
    final membersById = {for (final m in members) m.id: m};

    final (mealRate, totalMeals, totalBazaar, mealsByUser, depositsByUser) = await _getMealTotals(monthKey);

    final memberMealRows = members.map((m) {
      final meals = mealsByUser[m.id] ?? 0;
      final deposit = depositsByUser[m.id] ?? 0;
      final cost = meals * mealRate;
      return MemberMealRow(
        id: m.id,
        firstName: m.firstName,
        lastName: m.lastName,
        avatarUrl: m.avatarUrl,
        meals: meals,
        deposit: deposit,
        cost: cost,
      );
    }).toList();

    // "Outstanding from members" / "Collected this month" need every
    // member's due, not just mine -- fetch the whole cottage's adjustments
    // and deposits for the month in two queries rather than looping
    // _getMyDue per member (mirrors getMonthlyDues building its map once).
    final allAdjustments = await _client
        .from('utility_adjustments')
        .select('user_id, category, amount')
        .eq('cottage_id', me.cottageId)
        .eq('month_key', monthKey);
    final allDeposits = await _client
        .from('utility_deposits')
        .select('user_id, amount')
        .eq('cottage_id', me.cottageId)
        .eq('month_key', monthKey)
        .eq('source_type', 'member');

    final dueByUser = <String, double>{};
    for (final row in allAdjustments as List) {
      final userId = row['user_id'] as String;
      final amount = (row['amount'] as num).toDouble();
      dueByUser[userId] = (dueByUser[userId] ?? 0) + amount;
    }
    final paidByUser = <String, double>{};
    for (final row in allDeposits as List) {
      final userId = row['user_id'] as String?;
      if (userId == null) continue;
      final amount = (row['amount'] as num).toDouble();
      paidByUser[userId] = (paidByUser[userId] ?? 0) + amount;
      dueByUser[userId] = (dueByUser[userId] ?? 0) - amount;
    }

    double outstandingFromMembers = 0;
    for (final due in dueByUser.values) {
      if (due > 0) outstandingFromMembers += due;
    }
    double collectedThisMonth = 0;
    for (final paid in paidByUser.values) {
      collectedThisMonth += paid;
    }

    return DashboardData(
      monthKey: monthKey,
      cottageName: cottageName,
      cottageBalance: cottageBalance,
      totalUtilityExpense: totalUtilityExpense,
      outstandingFromMembers: outstandingFromMembers,
      collectedThisMonth: collectedThisMonth,
      myDue: myDue,
      mealRate: mealRate,
      totalMeals: totalMeals,
      totalBazaar: totalBazaar,
      memberMealRows: memberMealRows,
      myCarryInLines: myCarryInLines,
      myAdjustmentLines: myAdjustmentLines,
      myDepositLines: myDepositLines,
      bazaarDuties: bazaarDuties,
      membersById: membersById,
    );
  }
}
