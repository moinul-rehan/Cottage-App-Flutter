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
