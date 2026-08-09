/// A month's cottage-wide totals -- mirrors what the Months screen's stat
/// rows show for both the active month and every locked history month.
class MonthStats {
  final String monthKey;
  final double totalUtilityDue;
  final double totalBazaar;
  final double totalMeals;
  double get mealRate => totalMeals > 0 ? totalBazaar / totalMeals : 0;

  const MonthStats({
    required this.monthKey,
    required this.totalUtilityDue,
    required this.totalBazaar,
    required this.totalMeals,
  });
}

/// One locked month in `month_closures` -- mirrors the History section's
/// cards ("Locked {date}" pill + the same stat rows + Activate/Delete).
class MonthHistoryEntry {
  final MonthStats stats;
  final DateTime closedAt;

  const MonthHistoryEntry({required this.stats, required this.closedAt});

  String get monthKey => stats.monthKey;
}
