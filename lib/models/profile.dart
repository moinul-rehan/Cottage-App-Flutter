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

  /// Mirrors profiles.is_active -- defaults true since most queries don't
  /// select this column (they already filter to active-only server-side),
  /// so a missing value should never be misread as inactive.
  final bool isActive;

  /// Per-action grants a super admin can hand to an ordinary member --
  /// mirror `profiles.can_add_*` (see supabase/migrations/0002, 0004, 0010,
  /// 0022), each independently enforced by RLS server-side. There is no
  /// generic `permissions` array column; these are five real booleans.
  final bool canAddExpenses;
  final bool canAddBazaar;
  final bool canAddMeals;
  final bool canAddDeposit;
  final bool canAddNotice;

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
    this.isActive = true,
    this.canAddExpenses = true,
    this.canAddBazaar = true,
    this.canAddMeals = true,
    this.canAddDeposit = false,
    this.canAddNotice = false,
  });

  bool get isSuperAdmin => role == 'super_admin';

  /// True once a super admin has granted this member any of the four
  /// grantable permissions (`can_add_notice` doesn't count -- every member
  /// can already post notices by default, so it isn't a real grant). Drives
  /// the "Manager" role label and the blue verified-tick badge, in place of
  /// the plain "Member" label and black tick.
  bool get hasElevatedAccess => canAddExpenses || canAddBazaar || canAddMeals || canAddDeposit;

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
      isActive: map['is_active'] as bool? ?? true,
      canAddExpenses: map['can_add_expenses'] as bool? ?? true,
      canAddBazaar: map['can_add_bazaar'] as bool? ?? true,
      canAddMeals: map['can_add_meals'] as bool? ?? true,
      canAddDeposit: map['can_add_deposit'] as bool? ?? false,
      canAddNotice: map['can_add_notice'] as bool? ?? false,
    );
  }

  /// Same fallback order as the web app's getDisplayName (src/lib/data/display-name.ts).
  String get displayName => (lastName?.isNotEmpty ?? false)
      ? lastName!
      : (firstName.isNotEmpty ? firstName : 'Member');

  String get fullName =>
      [firstName, lastName].where((s) => s != null && s.isNotEmpty).join(' ');
}
