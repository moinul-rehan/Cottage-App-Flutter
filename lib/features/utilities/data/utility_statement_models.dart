import 'package:cottage/models/profile.dart';

/// One line item on a member's statement card -- either a carried-in
/// due/advance from a closed month, or a single `utility_adjustments` row
/// for the active month. Signed: positive increases the member's due,
/// negative reduces it (mirrors `utility_adjustments.amount`).
class UtilityStatementLine {
  final String label;
  final double amount;
  const UtilityStatementLine({required this.label, required this.amount});
}

/// One member's full utility statement for the active month -- every
/// [UtilityStatementLine] (carry-in first, then this month's adjustments,
/// in the order they were added) plus how much they've paid.
class MemberStatement {
  final Profile profile;
  final List<UtilityStatementLine> lines;
  final double paid;

  const MemberStatement({
    required this.profile,
    required this.lines,
    required this.paid,
  });

  double get assignedCost => lines.fold(0, (s, l) => s + l.amount);
  double get due => assignedCost - paid;

  /// Matches the Figma "Paid" pill: shown once the member has actually been
  /// assigned something and isn't left owing (an exact settle or an
  /// advance both count) -- not for a member with no activity at all,
  /// where "Paid" would be a meaningless label for $0 owed on $0 assigned.
  bool get isSettled => (assignedCost != 0 || paid != 0) && due <= 0;
}
