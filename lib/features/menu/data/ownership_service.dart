import 'package:cottage/helpers/supabase_service.dart';

/// Transfer-ownership + cottage-deletion, mirroring
/// src/app/(house)/settings/ownership/actions.ts. The web app does these as
/// plain table updates via a service-role client -- `cottages` only has a
/// select RLS policy and `profiles`' admin-write policy can't atomically
/// swap two rows' roles either, so a mobile client (anon key only) goes
/// through the SECURITY DEFINER RPCs in supabase/migrations/0053 instead.
/// In-app notifications to affected members stay plain table inserts (the
/// `notifications` table has its own insert policy).
class OwnershipService {
  final _client = SupabaseService.client;

  /// Hands super_admin to [newAdminId], demotes [currentAdminId] to a
  /// regular member. Notifies both.
  Future<void> transferOwnership({
    required String currentAdminId,
    required String newAdminId,
    required String currentAdminName,
    required String newAdminName,
  }) async {
    await _client.rpc('transfer_ownership', params: {'p_new_admin_id': newAdminId});

    await _client.from('notifications').insert([
      {
        'user_id': newAdminId,
        'type': 'ownership_transferred',
        'title': 'You are now the super admin',
        'body': '$currentAdminName transferred ownership to you.',
      },
      {
        'user_id': currentAdminId,
        'type': 'ownership_transferred',
        'title': 'Ownership transferred',
        'body': "You handed over super admin access to $newAdminName.",
      },
    ]);
  }

  /// Schedules the whole cottage for permanent deletion in 7 days. Notifies
  /// every active member (mirrors requestCottageDeletion).
  Future<void> requestCottageDeletion({
    required String cottageId,
    required String requestedBy,
    required String requesterName,
  }) async {
    await _client.rpc('request_cottage_deletion');

    final members = await _client
        .from('profiles')
        .select('id')
        .eq('cottage_id', cottageId)
        .eq('is_active', true)
        .isFilter('removed_at', null);
    final ids = (members as List)
        .map((r) => (r as Map<String, dynamic>)['id'] as String)
        .toList();
    if (ids.isNotEmpty) {
      await _client.from('notifications').insert([
        for (final id in ids)
          {
            'user_id': id,
            'type': 'cottage_deletion_scheduled',
            'title': 'Cottage deletion scheduled',
            'body':
                '$requesterName scheduled this Cottage for deletion. It will be permanently removed in 7 days.',
          },
      ]);
    }
  }

  /// Cancels a pending cottage-deletion request.
  Future<void> cancelCottageDeletion(String cottageId) async {
    await _client.rpc('cancel_cottage_deletion');
  }
}
