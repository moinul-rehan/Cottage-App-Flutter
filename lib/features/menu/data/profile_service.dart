import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cottage/helpers/supabase_service.dart';

/// Data layer for the Profile / Edit Profile screens -- mirrors
/// src/app/(house)/settings/profile/actions.ts.
class ProfileService {
  final _client = SupabaseService.client;

  static final _bdMobileRegex = RegExp(r'^(?:\+?88)?01[3-9]\d{8}$');

  /// Same rule as the web's BD_MOBILE_REGEX -- surfaced here so the edit
  /// screen can validate before ever calling [updateOwnProfile].
  static bool isValidBdMobile(String value) => _bdMobileRegex.hasMatch(value);

  /// Mirrors `update_own_profile` (see
  /// supabase/migrations/0018_profile_address.sql) -- a SECURITY DEFINER
  /// RPC scoped to `auth.uid()`, so there's no `user_id` param to pass or
  /// spoof. [avatarUrl], when provided, commits a photo picked via
  /// [uploadAvatar] in the SAME call as the rest of the form -- nothing
  /// about the profile (picture included) is written to the row until this
  /// runs, so backing out of an edit after picking a photo but before
  /// tapping "Update Information" leaves the saved profile untouched.
  Future<void> updateOwnProfile({
    required String firstName,
    String? lastName,
    String? avatarUrl,
    String? gender,
    String? hometown,
    String? mobileNumber,
    String? address,
  }) async {
    await _client.rpc(
      'update_own_profile',
      params: {
        'p_first_name': firstName,
        'p_last_name': lastName,
        'p_avatar_url': avatarUrl,
        'p_gender': gender,
        'p_hometown': hometown,
        'p_mobile_number': mobileNumber,
        'p_address': address,
      },
    );
  }

  /// Uploads to the `avatars` bucket at `{userId}/avatar.{ext}` (upsert, so
  /// re-uploading always replaces the same object rather than accumulating
  /// old photos) and returns the public URL -- deliberately does NOT touch
  /// the profile row itself (that used to happen here via a separate
  /// `update_own_avatar` RPC call, immediately on pick, before the member
  /// ever tapped "Update Information" -- so backing out of an edit still
  /// left the new photo permanently saved). The caller only passes this URL
  /// into [updateOwnProfile] once the member actually submits.
  Future<String> uploadAvatar({
    required String userId,
    required File file,
    required String extension,
  }) async {
    final path = '$userId/avatar.$extension';
    await _client.storage
        .from('avatars')
        .upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );
    final publicUrl = _client.storage.from('avatars').getPublicUrl(path);
    // Cache-bust: same URL as before (upsert overwrote the same object
    // path), so a NetworkImage already cached by the old bytes needs a
    // distinguishing query param to actually re-fetch.
    return '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
  }
}
