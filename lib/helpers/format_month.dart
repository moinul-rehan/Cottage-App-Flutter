/// "2026-07" -> "July, 2026". Mirrors formatMonthKey in
/// src/lib/format-month.ts.
String formatMonthKey(String monthKey) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final parts = monthKey.split('-');
  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  return '${months[month - 1]}, $year';
}
