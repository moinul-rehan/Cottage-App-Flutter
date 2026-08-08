import 'package:cottage/models/profile.dart';
import 'package:cottage/helpers/supabase_service.dart';

/// Fetch and manage cottage members.
class MemberService {
  final _client = SupabaseService.client;

  /// Fetch all active members for the given cottage.
  Future<List<Profile>> getActiveMembers(String cottageId) async {
    final rows = await _client
        .from('profiles')
        .select('id, cottage_id, first_name, last_name, email, avatar_url')
        .eq('cottage_id', cottageId)
        .eq('is_active', true)
        .order('first_name');

    return (rows as List)
        .map((r) => Profile.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Fetch every member of the cottage, active or not -- for the Members
  /// list screen, which shows an "Inactive" pill rather than hiding them.
  Future<List<Profile>> getAllMembers(String cottageId) async {
    final rows = await _client
        .from('profiles')
        .select(
          'id, cottage_id, first_name, last_name, email, avatar_url, mobile_number, address, role, is_active',
        )
        .eq('cottage_id', cottageId)
        .order('is_active', ascending: false)
        .order('first_name');

    return (rows as List)
        .map((r) => Profile.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Activate/deactivate a member -- only meaningful for a super admin
  /// acting on someone else, enforced by RLS server-side.
  Future<void> setActive(String userId, bool active) async {
    await _client
        .from('profiles')
        .update({'is_active': active})
        .eq('id', userId);
  }

  /// Get cottage name.
  Future<String> getCottageName(String cottageId) async {
    final row = await _client
        .from('cottages')
        .select('name')
        .eq('id', cottageId)
        .single();
    return row['name'] as String? ?? 'Cottage';
  }
}
