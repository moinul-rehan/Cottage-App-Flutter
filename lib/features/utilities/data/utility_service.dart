import 'package:cottage/models/profile.dart';
import 'utility_models.dart';
import 'package:cottage/helpers/supabase_service.dart';

/// Data layer for the Utilities tab — expenses, deposits, and member dues.
class UtilityService {
  final _client = SupabaseService.client;

  /// [start, end) date bounds for a "YYYY-MM" month key.
  (String start, String end) _monthRange(String monthKey) {
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final start = DateTime.utc(year, month, 1);
    final end = DateTime.utc(year, month + 1, 1);
    String iso(DateTime d) => d.toIso8601String().substring(0, 10);
    return (iso(start), iso(end));
  }

  /// Fetch all expenses for the given month.
  Future<List<Expense>> getExpenses(String monthKey) async {
    final (start, end) = _monthRange(monthKey);
    final rows = await _client
        .from('expenses')
        .select('*, payer:profiles!expenses_paid_by_fkey(first_name, last_name)')
        .gte('expense_date', start)
        .lt('expense_date', end)
        .order('expense_date', ascending: false);

    return (rows as List)
        .map((r) => Expense.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Add a new expense.
  Future<void> addExpense({
    required String cottageId,
    required double amount,
    required String expenseDate,
    String? description,
    String? category,
  }) async {
    await _client.from('expenses').insert({
      'cottage_id': cottageId,
      'amount': amount,
      'expense_date': expenseDate,
      if (description != null && description.isNotEmpty) 'description': description,
      if (category != null && category.isNotEmpty) 'category': category,
    });
  }

  /// Fetch all utility deposits for the given month, with member names.
  Future<List<UtilityDeposit>> getDeposits(String cottageId, String monthKey) async {
    final rows = await _client
        .from('utility_deposits')
        .select('*, profiles!utility_deposits_user_id_fkey(first_name, last_name)')
        .eq('cottage_id', cottageId)
        .eq('month_key', monthKey)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => UtilityDeposit.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Add a member utility deposit.
  Future<void> addDeposit({
    required String cottageId,
    required String userId,
    required String monthKey,
    required double amount,
  }) async {
    await _client.from('utility_deposits').insert({
      'cottage_id': cottageId,
      'user_id': userId,
      'month_key': monthKey,
      'amount': amount,
      'source_type': 'member',
    });
  }

  /// Compute every active member's utility due for the month.
  Future<List<MemberUtilityDue>> getMemberDues(
    String cottageId,
    String monthKey,
    List<Profile> members,
  ) async {
    final adjustments = await _client
        .from('utility_adjustments')
        .select('user_id, category, amount')
        .eq('cottage_id', cottageId)
        .eq('month_key', monthKey);

    final deposits = await _client
        .from('utility_deposits')
        .select('user_id, amount')
        .eq('cottage_id', cottageId)
        .eq('month_key', monthKey)
        .eq('source_type', 'member');

    final rentByUser = <String, double>{};
    final expenseByUser = <String, double>{};
    for (final row in adjustments as List) {
      final userId = row['user_id'] as String;
      final amount = (row['amount'] as num).toDouble();
      if (row['category'] == 'house_rent') {
        rentByUser[userId] = (rentByUser[userId] ?? 0) + amount;
      } else {
        expenseByUser[userId] = (expenseByUser[userId] ?? 0) + amount;
      }
    }

    final paidByUser = <String, double>{};
    for (final row in deposits as List) {
      final userId = row['user_id'] as String;
      final amount = (row['amount'] as num).toDouble();
      paidByUser[userId] = (paidByUser[userId] ?? 0) + amount;
    }

    return members.map((m) {
      return MemberUtilityDue(
        userId: m.id,
        memberName: m.displayName,
        avatarUrl: m.avatarUrl,
        rent: rentByUser[m.id] ?? 0,
        expenses: expenseByUser[m.id] ?? 0,
        paid: paidByUser[m.id] ?? 0,
      );
    }).toList();
  }
}
