import 'bazaar_duty_models.dart';
import 'package:cottage/helpers/supabase_service.dart';

/// Data layer for the `bazaar_duties` table. Mirrors the query functions in
/// src/lib/data/bazaar-duty.ts (getCottageBazaarDuties, getAllBazaarDuties,
/// getUpcomingBazaarDuties).
class BazaarDutyService {
  final _client = SupabaseService.client;

  /// Flat, sorted list of every upcoming/current duty in the cottage -- for
  /// the Dashboard's shared roster. Mirrors getCottageBazaarDuties.
  Future<List<BazaarDuty>> getCottageBazaarDuties(String cottageId, {int limit = 8}) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await _client
        .from('bazaar_duties')
        .select('id, user_id, start_date, end_date, note')
        .eq('cottage_id', cottageId)
        .gte('end_date', today)
        .order('start_date')
        .limit(limit);
    return (rows as List).map((r) => BazaarDuty.fromMap(r as Map<String, dynamic>)).toList();
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
    return (rows as List).map((r) => BazaarDuty.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Assign a new bazaar duty. Callers should check [bazaarDutyOverlaps]
  /// against [getAllBazaarDuties] first, mirroring the web's overlap
  /// prevention (commit 3c5aefa).
  Future<void> assignDuty({
    required String cottageId,
    required String userId,
    required String startDate,
    required String endDate,
    String? note,
  }) async {
    await _client.from('bazaar_duties').insert({
      'cottage_id': cottageId,
      'user_id': userId,
      'start_date': startDate,
      'end_date': endDate,
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
    await _client.from('bazaar_duties').update({
      'start_date': startDate,
      'end_date': endDate,
      'note': note ?? '',
    }).eq('id', id);
  }

  /// Remove a duty assignment.
  Future<void> deleteDuty(String id) async {
    await _client.from('bazaar_duties').delete().eq('id', id);
  }
}
