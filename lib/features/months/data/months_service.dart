import 'package:cottage/helpers/supabase_service.dart';
import 'month_models.dart';

/// Data layer for the "Months" page (Figma node 126:1504) -- the active
/// month's cottage-wide totals, locked history (`month_closures`), and the
/// super-admin-only month-management RPCs already defined in
/// supabase/migrations/0007_active_month_workflow.sql and
/// 0009_manual_month_management.sql. Every write RPC there already
/// enforces `is_super_admin()` server-side; this layer doesn't duplicate
/// that check, it just surfaces whatever error Postgres raises.
class MonthsService {
  final _client = SupabaseService.client;

  Future<MonthStats> getMonthStats(String cottageId, String monthKey) async {
    // Mirrors web's getMonthlyDues/getMonthHistory: adjustments + carry-ins
    // (both meal and utility kind, per web's own unfiltered sum) minus
    // member deposits -- not just raw utility_adjustments.
    final utilityRows = await _client
        .from('utility_adjustments')
        .select('amount')
        .eq('cottage_id', cottageId)
        .eq('month_key', monthKey);
    double totalUtilityDue = 0;
    for (final row in utilityRows as List) {
      totalUtilityDue += (row['amount'] as num).toDouble();
    }

    final carryInRows = await _client
        .from('utility_carry_ins')
        .select('amount')
        .eq('cottage_id', cottageId)
        .eq('month_key', monthKey);
    for (final row in carryInRows as List) {
      totalUtilityDue += (row['amount'] as num).toDouble();
    }

    final depositRows = await _client
        .from('utility_deposits')
        .select('amount')
        .eq('cottage_id', cottageId)
        .eq('month_key', monthKey)
        .eq('source_type', 'member');
    for (final row in depositRows as List) {
      totalUtilityDue -= (row['amount'] as num).toDouble();
    }

    final bazaarRows = await _client
        .from('bazaar_entries')
        .select('amount')
        .eq('cottage_id', cottageId)
        .eq('month_key', monthKey);
    double totalBazaar = 0;
    for (final row in bazaarRows as List) {
      totalBazaar += (row['amount'] as num).toDouble();
    }

    final mealRows = await _client
        .from('daily_meals')
        .select('count')
        .eq('cottage_id', cottageId)
        .eq('month_key', monthKey);
    double totalMeals = 0;
    for (final row in mealRows as List) {
      totalMeals += (row['count'] as num).toDouble();
    }

    return MonthStats(
      monthKey: monthKey,
      totalUtilityDue: totalUtilityDue,
      totalBazaar: totalBazaar,
      totalMeals: totalMeals,
    );
  }

  /// Every locked month for this cottage, newest-locked first, each with
  /// its own totals -- mirrors the History section.
  Future<List<MonthHistoryEntry>> getHistory(String cottageId) async {
    final rows = await _client
        .from('month_closures')
        .select('month_key, closed_at')
        .eq('cottage_id', cottageId)
        .order('closed_at', ascending: false);

    final entries = <MonthHistoryEntry>[];
    for (final row in rows as List) {
      final monthKey = row['month_key'] as String;
      final stats = await getMonthStats(cottageId, monthKey);
      entries.add(
        MonthHistoryEntry(
          stats: stats,
          closedAt: DateTime.parse(row['closed_at'] as String),
        ),
      );
    }
    return entries;
  }

  /// Locks the currently-active month and opens [monthKey] -- works for
  /// any valid month, not just one already in history (`set_active_month`).
  Future<void> setActiveMonth(String monthKey) async {
    await _client.rpc('set_active_month', params: {'p_month_key': monthKey});
  }

  /// Reopens a month that's already in history, re-locking whatever was
  /// active (`activate_month`) -- the History card's "Activate" button.
  Future<void> activateMonth(String monthKey) async {
    await _client.rpc('activate_month', params: {'p_month_key': monthKey});
  }

  /// Permanently deletes a locked month's data. Irreversible; refuses to
  /// touch the active month server-side.
  Future<void> deleteMonth(String monthKey) async {
    await _client.rpc('delete_month', params: {'p_month_key': monthKey});
  }

  Future<void> resetUtilityMonth() async {
    await _client.rpc('reset_utility_month');
  }

  Future<void> resetMealMonth() async {
    await _client.rpc('reset_meal_month');
  }
}
