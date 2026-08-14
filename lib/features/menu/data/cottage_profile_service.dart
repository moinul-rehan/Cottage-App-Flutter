import 'package:cottage/helpers/supabase_service.dart';

class CottageProfile {
  final String name;
  final DateTime createdAt;
  final int memberCount;

  const CottageProfile({
    required this.name,
    required this.createdAt,
    required this.memberCount,
  });
}

/// Cottage Profile -- mirrors src/app/(house)/settings/cottage/page.tsx:
/// name/created/member-count, plus a super-admin-only rename. Renaming has
/// no RLS update policy for a plain client (only `cottages_select_own`
/// exists) -- the web app updates via a service-role client instead, which
/// a mobile app can't embed, so this goes through the `update_cottage_name`
/// SECURITY DEFINER RPC (see supabase/migrations/0053).
class CottageProfileService {
  final _client = SupabaseService.client;

  Future<CottageProfile> getCottageProfile(String cottageId) async {
    final cottageRow = await _client
        .from('cottages')
        .select('name, created_at')
        .eq('id', cottageId)
        .single();
    final memberCount = await _client
        .from('profiles')
        .select('id')
        .eq('cottage_id', cottageId)
        .isFilter('removed_at', null)
        .count();

    return CottageProfile(
      name: cottageRow['name'] as String? ?? 'Cottage',
      createdAt: DateTime.parse(cottageRow['created_at'] as String),
      memberCount: memberCount.count,
    );
  }

  Future<void> updateCottageName(String name) async {
    await _client.rpc('update_cottage_name', params: {'p_name': name});
  }
}
