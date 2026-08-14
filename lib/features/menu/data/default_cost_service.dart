import 'package:cottage/helpers/supabase_service.dart';
import 'default_cost_models.dart';

/// Data layer for "Default Cost" -- mirrors
/// src/app/(house)/settings/rent/actions.ts and getDefaultCosts in
/// src/lib/data/finance.ts. Every write is super-admin-only, enforced by
/// RLS (default_costs_admin_write/update/delete all require
/// is_super_admin()), so this layer doesn't re-check role itself.
class DefaultCostService {
  final _client = SupabaseService.client;

  /// Every default-cost row for the cottage, grouped by category -- mirrors
  /// getDefaultCosts's `Map<category, rows>` shape.
  Future<List<DefaultCostCategory>> getDefaultCosts(String cottageId) async {
    final rows = await _client
        .from('default_costs')
        .select('id, category, user_id, amount, notes')
        .eq('cottage_id', cottageId);

    final byCategory = <String, List<DefaultCostRow>>{};
    for (final r in rows as List) {
      final map = r as Map<String, dynamic>;
      final category = map['category'] as String;
      (byCategory[category] ??= []).add(DefaultCostRow.fromMap(map));
    }
    return byCategory.entries
        .map((e) => DefaultCostCategory(category: e.key, rows: e.value))
        .toList();
  }

  /// Upserts one row per member with a positive amount -- mirrors
  /// saveDefaultCost exactly: members left at 0 (or blank) are just
  /// skipped, not written as a zero row (and any of their previously-saved
  /// amount for this category stays as-is, since this never deletes -- use
  /// [deleteCategory] to clear a category entirely).
  Future<void> saveDefaultCost({
    required String cottageId,
    required String category,
    required String setBy,
    required Map<String, double> amountsByUserId,
  }) async {
    final rows = amountsByUserId.entries
        .where((e) => e.value > 0)
        .map(
          (e) => {
            'cottage_id': cottageId,
            'category': category,
            'user_id': e.key,
            'amount': e.value,
            'set_by': setBy,
            'updated_at': DateTime.now().toIso8601String(),
          },
        )
        .toList();
    if (rows.isEmpty) return;

    await _client
        .from('default_costs')
        .upsert(rows, onConflict: 'cottage_id,category,user_id');
  }

  /// Mirrors deleteDefaultCostCategory -- the caller is responsible for the
  /// password re-confirmation step (showPasswordConfirmDialog) before
  /// calling this; RLS itself is the actual backstop (super-admin only).
  Future<void> deleteCategory({
    required String cottageId,
    required String category,
  }) async {
    await _client
        .from('default_costs')
        .delete()
        .eq('cottage_id', cottageId)
        .eq('category', category);
  }
}
