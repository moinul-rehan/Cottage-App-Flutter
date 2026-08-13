import 'package:cottage/models/profile.dart';
import 'package:cottage/helpers/format_month.dart';
import 'package:cottage/helpers/utility_categories.dart';
import 'package:cottage/helpers/supabase_service.dart';
import 'utility_statement_models.dart';

/// Data layer for the "Utility Statement" page (Figma node 115:1343) --
/// every active member's carry-in + this-month utility_adjustments lines
/// plus what they've paid, and the admin-only "Add Adjustment" write path
/// (supabase/migrations/0012_utility_adjustments.sql: `is_super_admin()`,
/// `created_by = auth.uid()`, and the month must not be closed).
class UtilityStatementService {
  final _client = SupabaseService.client;

  String _monthLabel(String monthKey) {
    // Same month names as formatMonthKey, but without its ", " -- Figma's
    // carry-in/pill labels read "June 2026", not "June, 2026".
    final parts = monthKey.split('-');
    final withComma = formatMonthKey(monthKey);
    return withComma.replaceFirst(', ${parts[0]}', ' ${parts[0]}');
  }

  Future<List<MemberStatement>> getStatements({
    required String cottageId,
    required String monthKey,
    required List<Profile> members,
  }) async {
    // Both kinds, not just 'utility' -- a closed month's Meal Due/Balance
    // carries into next month's statement exactly like a Utility
    // Due/Advance does (see finance.ts's getCarryInTotalsByUser on the web
    // app, which sums every row regardless of kind). Filtering to 'utility'
    // here silently dropped carried-over meal balances from both the shown
    // lines and the assignedCost/due totals below.
    final carryIns = await _client
        .from('utility_carry_ins')
        .select('user_id, amount, source_month_key, kind')
        .eq('cottage_id', cottageId)
        .eq('month_key', monthKey);

    final adjustments = await _client
        .from('utility_adjustments')
        .select('user_id, category, amount, created_at')
        .eq('cottage_id', cottageId)
        .eq('month_key', monthKey)
        .order('created_at');

    final deposits = await _client
        .from('utility_deposits')
        .select('user_id, amount')
        .eq('cottage_id', cottageId)
        .eq('month_key', monthKey)
        .eq('source_type', 'member');

    final linesByUser = <String, List<UtilityStatementLine>>{};
    for (final row in carryIns as List) {
      final userId = row['user_id'] as String;
      final amount = (row['amount'] as num).toDouble();
      final sourceLabel = _monthLabel(row['source_month_key'] as String);
      final isUtility = row['kind'] == 'utility';
      // Mirrors page.tsx's label exactly: Utility Due/Advanced vs Meal
      // Due/Balance.
      final kindLabel = isUtility ? 'Utility' : 'Meal';
      final stateLabel = amount >= 0
          ? 'Due'
          : (isUtility ? 'Advanced' : 'Balance');
      linesByUser
          .putIfAbsent(userId, () => [])
          .add(
            UtilityStatementLine(
              label: '$sourceLabel $kindLabel $stateLabel',
              amount: amount,
            ),
          );
    }
    for (final row in adjustments as List) {
      final userId = row['user_id'] as String;
      final amount = (row['amount'] as num).toDouble();
      final label = utilityCategoryLabel(row['category'] as String);
      linesByUser
          .putIfAbsent(userId, () => [])
          .add(UtilityStatementLine(label: label, amount: amount));
    }

    final paidByUser = <String, double>{};
    for (final row in deposits as List) {
      final userId = row['user_id'] as String;
      paidByUser[userId] =
          (paidByUser[userId] ?? 0) + (row['amount'] as num).toDouble();
    }

    return members
        .map(
          (m) => MemberStatement(
            profile: m,
            lines: linesByUser[m.id] ?? const [],
            paid: paidByUser[m.id] ?? 0,
          ),
        )
        .toList();
  }

  /// Inserts one `utility_adjustments` row per entry in [amountsByUser] --
  /// a single entry for "Specific Member", one per active member (equal or
  /// custom split) for "All Members". Every row shares the same
  /// category/payment info; only the per-member amount differs.
  Future<void> addAdjustment({
    required String cottageId,
    required String monthKey,
    required Map<String, double> amountsByUser,
    required String category,
    required String paymentSource,
    String? paymentMemberId,
    required String createdBy,
  }) async {
    final rows = amountsByUser.entries
        .map(
          (e) => {
            'cottage_id': cottageId,
            'month_key': monthKey,
            'user_id': e.key,
            'category': category,
            'amount': e.value,
            'payment_source': paymentSource,
            'payment_member_id': paymentMemberId,
            'created_by': createdBy,
          },
        )
        .toList();
    await _client.from('utility_adjustments').insert(rows);
  }
}
