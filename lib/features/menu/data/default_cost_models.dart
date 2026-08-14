/// One member's fixed monthly amount for a default-cost category -- mirrors
/// a `default_costs` row (see supabase/migrations/0014_default_costs.sql).
class DefaultCostRow {
  final String id;
  final String userId;
  final double amount;
  final String? notes;

  const DefaultCostRow({
    required this.id,
    required this.userId,
    required this.amount,
    this.notes,
  });

  factory DefaultCostRow.fromMap(Map<String, dynamic> map) {
    return DefaultCostRow(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      notes: map['notes'] as String?,
    );
  }
}

/// One category's full template -- every member's row plus the total,
/// mirrors page.tsx's `categories` derivation from getDefaultCosts.
class DefaultCostCategory {
  final String category;
  final List<DefaultCostRow> rows;

  const DefaultCostCategory({required this.category, required this.rows});

  double get total => rows.fold(0, (sum, r) => sum + r.amount);
}
