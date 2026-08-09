import 'bazaar_duty_models.dart';
import 'package:cottage/helpers/supabase_service.dart';

/// Data layer for the `bazaar_duties` table. Mirrors the query functions in
/// src/lib/data/bazaar-duty.ts (getCottageBazaarDuties, getAllBazaarDuties,
/// getUpcomingBazaarDuties).
class BazaarDutyService {
  final _client = SupabaseService.client;

  /// Flat, sorted list of every assigned duty in the cottage -- past,
  /// current, and upcoming -- for the Dashboard's shared roster and the
  /// Member Summary cards. Previously filtered to `end_date >= today`,
  /// which made a member's duty vanish from both the roster and their
  /// summary card the moment it ended instead of just no longer being
  /// highlighted as active; every assigned duty should stay visible.
  Future<List<BazaarDuty>> getCottageBazaarDuties(
    String cottageId, {
    int limit = 100,
  }) async {
    final rows = await _client
        .from('bazaar_duties')
        .select('id, user_id, start_date, end_date, note')
        .eq('cottage_id', cottageId)
        .order('start_date', ascending: false)
        .limit(limit);
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
