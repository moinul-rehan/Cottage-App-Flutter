import 'bazaar_duty_models.dart';
import 'package:cottage/helpers/supabase_service.dart';

/// Data layer for the `bazaar_duties` table. Mirrors the query functions in
/// src/lib/data/bazaar-duty.ts (getCottageBazaarDuties, getAllBazaarDuties,
/// getUpcomingBazaarDuties).
class BazaarDutyService {
  final _client = SupabaseService.client;

  /// [start, end) date bounds for a "YYYY-MM" month key -- same shape as
  /// monthRange() in src/lib/data/finance.ts.
  (String start, String end) _monthRange(String monthKey) {
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final start = DateTime.utc(year, month, 1);
    final end = DateTime.utc(year, month + 1, 1);
    String iso(DateTime d) => d.toIso8601String().substring(0, 10);
    return (iso(start), iso(end));
  }

  /// Every duty overlapping [monthKey]'s date range -- mirrors
  /// getCottageBazaarDuties(supabase, cottageId, monthKey) in
  /// src/lib/data/bazaar-duty.ts (`start_date < monthEnd AND end_date >=
  /// monthStart`) exactly. Used for the Dashboard's shared roster and the
  /// Member Summary cards, so switching the cottage's active month changes
  /// which duties show there -- this used to fetch the last 100 duties
  /// globally with no month scoping at all, so the roster kept showing
  /// whatever duty was nearest to today's real date regardless of which
  /// month was actually set active.
  Future<List<BazaarDuty>> getCottageBazaarDuties(
    String cottageId,
    String monthKey,
  ) async {
    final (start, end) = _monthRange(monthKey);
    final rows = await _client
        .from('bazaar_duties')
        .select('id, user_id, start_date, end_date, note')
        .eq('cottage_id', cottageId)
        .lt('start_date', end)
        .gte('end_date', start)
        .order('start_date');
    return (rows as List)
        .map((r) => BazaarDuty.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Every duty (past and upcoming) in the cottage, newest-starting first --
  /// used to block assigning a range that overlaps someone else's duty.
  /// Mirrors getAllBazaarDuties.
  Future<List<BazaarDuty>> getAllBazaarDuties(String cottageId) async {
    final rows = await _client
        .from('bazaar_duties')
        .select('id, user_id, start_date, end_date, note')
        .eq('cottage_id', cottageId)
        .order('start_date', ascending: false);
    return (rows as List)
        .map((r) => BazaarDuty.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Assign a new bazaar duty. Callers should check [bazaarDutyOverlaps]
  /// against [getAllBazaarDuties] first, mirroring the web's overlap
  /// prevention (commit 3c5aefa).
  ///
  /// [createdBy] must be the *acting* super admin's own id (not [userId],
  /// the person being assigned) -- `bazaar_duties.created_by` is `not null`
  /// and RLS's `bazaar_duties_admin_insert` policy requires
  /// `created_by = auth.uid()`, so omitting it makes every insert fail
  /// (silently, if the caller doesn't check for an exception).
  Future<void> assignDuty({
    required String cottageId,
    required String userId,
    required String startDate,
    required String endDate,
    required String createdBy,
    String? note,
  }) async {
    await _client.from('bazaar_duties').insert({
      'cottage_id': cottageId,
      'user_id': userId,
      'start_date': startDate,
      'end_date': endDate,
      'created_by': createdBy,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  /// Update an existing duty's date range/note.
  Future<void> updateDuty({
    required String id,
    required String startDate,
    required String endDate,
    String? note,
  }) async {
    await _client
        .from('bazaar_duties')
        .update({
          'start_date': startDate,
          'end_date': endDate,
          'note': note ?? '',
        })
        .eq('id', id);
  }

  /// Remove a duty assignment.
  Future<void> deleteDuty(String id) async {
    await _client.from('bazaar_duties').delete().eq('id', id);
  }
}
