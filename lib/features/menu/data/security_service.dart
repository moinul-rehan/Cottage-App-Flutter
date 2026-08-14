import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cottage/helpers/supabase_service.dart';

/// Change-password + self account-deletion, mirroring
/// src/app/(house)/settings/security/actions.ts. Change-password is a plain
/// re-auth via signInWithPassword then auth.updateUser, same as the web.
/// The deletion request is different: the web writes `profiles` directly
/// with a service-role client, but `profiles` has no self-update RLS policy
/// for a plain authenticated client (only `profiles_admin_write`, scoped to
/// super admins), so this goes through the `request_own_account_deletion`/
/// `cancel_own_account_deletion` SECURITY DEFINER RPCs instead (see
/// supabase/migrations/0053).
class SecurityService {
  final _client = SupabaseService.client;

  /// Re-authenticates with [currentPassword], then sets [newPassword] as the
  /// account's password. Throws [AuthException] with 'Incorrect password.'
  /// on a wrong current password (same shape as password_confirm_dialog).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = SupabaseService.currentUser?.email;
    if (email == null) {
      throw Exception('Could not verify your account. Try signing in again.');
    }
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
    } on AuthException {
      throw AuthException('Incorrect password.');
    }
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Schedules the caller's own account for removal in 7 days (mirrors
  /// requestAccountDeletion) -- stamps `account_deletion_requested_at` on
  /// their profile row; a server-side cron does the actual removal after the
  /// grace period. Notifies every other active member of the cottage.
  Future<void> requestAccountDeletion({
    required String userId,
    required String cottageId,
    required String requesterName,
  }) async {
    await _client.rpc('request_own_account_deletion');

    final others = await _client
        .from('profiles')
        .select('id')
        .eq('cottage_id', cottageId)
        .eq('is_active', true)
        .isFilter('removed_at', null)
        .neq('id', userId);
    final ids = (others as List)
        .map((r) => (r as Map<String, dynamic>)['id'] as String)
        .toList();
    if (ids.isNotEmpty) {
      await _client.from('notifications').insert([
        for (final id in ids)
          {
            'user_id': id,
            'type': 'account_deletion_scheduled',
            'title': 'Account deletion scheduled',
            'body':
                '$requesterName requested to delete their account. It will be removed in 7 days.',
          },
      ]);
    }
  }

  /// Cancels a pending self-deletion request.
  Future<void> cancelAccountDeletion(String userId) async {
    await _client.rpc('cancel_own_account_deletion');
  }
}
