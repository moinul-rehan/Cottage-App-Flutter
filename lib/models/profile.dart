/// Mirrors the subset of `profiles` columns the Dashboard screen needs.
/// See src/lib/data/dal.ts's Profile type / PROFILE_COLUMNS for the full
/// web-side shape -- this is intentionally a smaller slice for Phase 1.
class Profile {
  final String id;
  final String cottageId;
  final String firstName;
  final String? lastName;
  final String? email;
  final String? avatarUrl;
  final String? mobileNumber;
  final String? address;

  /// 'super_admin' | 'member' -- mirrors profiles.role, used by notice-board
  /// visibility/management checks (see src/lib/notice-types.tsx).
  final String role;

  const Profile({
    required this.id,
    required this.cottageId,
    required this.firstName,
    this.lastName,
    this.email,
    this.avatarUrl,
    this.mobileNumber,
    this.address,
    this.role = 'member',
  });

  bool get isSuperAdmin => role == 'super_admin';

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      cottageId: map['cottage_id'] as String,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String?,
      email: map['email'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      mobileNumber: map['mobile_number'] as String?,
      address: map['address'] as String?,
      role: map['role'] as String? ?? 'member',
    );
  }

  /// Same fallback order as the web app's getDisplayName (src/lib/data/display-name.ts).
  String get displayName => (lastName?.isNotEmpty ?? false) ? lastName! : (firstName.isNotEmpty ? firstName : 'Member');

  String get fullName => [firstName, lastName].where((s) => s != null && s.isNotEmpty).join(' ');
}
