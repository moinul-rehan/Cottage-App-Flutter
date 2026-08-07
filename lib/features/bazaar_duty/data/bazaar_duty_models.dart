/// A single bazaar (grocery shopping) duty assignment. Mirrors the
/// `BazaarDuty` type in src/lib/data/bazaar-duty.ts.
class BazaarDuty {
  final String id;
  final String userId;
  final String startDate; // 'YYYY-MM-DD'
  final String endDate; // 'YYYY-MM-DD'
  final String? note;

  const BazaarDuty({
    required this.id,
    required this.userId,
    required this.startDate,
    required this.endDate,
    this.note,
  });

  factory BazaarDuty.fromMap(Map<String, dynamic> map) {
    return BazaarDuty(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      startDate: map['start_date'] as String,
      endDate: map['end_date'] as String,
      note: map['note'] as String?,
    );
  }

  Map<String, dynamic> toInsertMap({required String cottageId}) => {
        'user_id': userId,
        'start_date': startDate,
        'end_date': endDate,
        'cottage_id': cottageId,
        if (note != null && note!.isNotEmpty) 'note': note,
      };
}

/// Status of a duty relative to today, mirrors dutyStatus() in
/// src/app/(house)/dashboard/BazaarDutyRoster.tsx.
enum BazaarDutyStatus { active, today, upcoming }

BazaarDutyStatus bazaarDutyStatus(String startIso, String endIso) {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  if (startIso.compareTo(today) <= 0 && today.compareTo(endIso) <= 0) {
    return BazaarDutyStatus.active;
  }
  if (startIso == today) return BazaarDutyStatus.today;
  return BazaarDutyStatus.upcoming;
}

/// Whether [start, end] overlaps any existing duty for a different user --
/// mirrors the overlap-prevention check added alongside the web's shared
/// roster/calendar (see commit 3c5aefa "Bazaar duty overlap prevention").
bool bazaarDutyOverlaps({
  required List<BazaarDuty> existing,
  required String start,
  required String end,
  String? excludeDutyId,
}) {
  for (final d in existing) {
    if (d.id == excludeDutyId) continue;
    final overlap = start.compareTo(d.endDate) <= 0 && d.startDate.compareTo(end) <= 0;
    if (overlap) return true;
  }
  return false;
}
