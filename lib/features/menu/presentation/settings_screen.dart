import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cottage/models/profile.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/helpers/ui_helpers.dart';
import 'package:cottage/common_widgets/bottom_nav_shell.dart';
import 'package:cottage/common_widgets/confirm_modal.dart';
import 'package:cottage/helpers/supabase_service.dart';
import '../../dashboard/presentation/verified_badge.dart';
import 'profile_screen.dart';
import 'default_cost_screen.dart';
import 'security_screen.dart';
import 'ownership_screen.dart';
import 'cottage_profile_screen.dart';

/// Settings (and anything pushed on top of it, e.g. Profile) is only ever
/// reached via the Menu tab's speed dial, which leaves the underlying
/// [BottomNavShell] sitting on the now-empty Menu tab -- popping back to
/// that placeholder reads as a dead end. Switching to the Dashboard tab
/// before popping means "back" always lands somewhere useful instead.
void _backToDashboard(BuildContext context) {
  BottomNavShell.shellKey.currentState?.openTab(0);
  Navigator.of(context).pop();
}

/// "Settings" -- Figma node 209:1950: profile header band (avatar, name +
/// verified badge, email, cottage-name pill) over a white rounded card of
/// navigation rows (Edit Profile / Cottage Profile / Default Cost /
/// Security / Ownership). Pushed from the Menu tab's "Settings" entry.
class SettingsScreen extends StatelessWidget {
  final Profile profile;
  final String cottageName;

  const SettingsScreen({
    super.key,
    required this.profile,
    required this.cottageName,
  });

  /// No manual navigation to LoginScreen here -- the root _AuthGate
  /// (main.dart) listens to onAuthStateChange and swaps to it on its own,
  /// same as AppScaffold's own logout button.
  Future<void> _logout(BuildContext context) async {
    final confirmed = await showConfirmModal(
      context,
      icon: Icons.logout_rounded,
      title: 'Log out?',
      message: "You'll need to sign in again to access your Cottage.",
      confirmLabel: 'Log Out',
      destructive: true,
    );
    if (!confirmed) return;
    await SupabaseService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _backToDashboard(context);
      },
      child: Scaffold(
      backgroundColor: surface.background,
      // A Column with a naturally-sized header + Expanded body, not a Stack
      // with a hand-computed `top:` offset for the white card -- that
      // offset was a flat guess (`49 + 81 + 10 + 32 + 60`) that never
      // actually accounted for the name/email/cottage-pill rows' real
      // height, so the white card's top edge landed wherever that guess
      // happened to under/overshoot the actual header content instead of
      // exactly where the header ends. A Column can't drift out of sync
      // like that since the second child's position is however tall the
      // first child really rendered, not a number pretending to know that.
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              14,
              MediaQuery.of(context).padding.top + 4,
              14,
              32,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFD1593B),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(60)),
            ),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => _backToDashboard(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
                Container(
                  width: 81,
                  height: 81,
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: (profile.avatarUrl?.isNotEmpty ?? false)
                        ? Image.network(
                            profile.avatarUrl!,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: CottageColors.primary.withValues(
                              alpha: 0.15,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              profile.firstName.isNotEmpty
                                  ? profile.firstName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        profile.fullName,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    VerifiedBadge(
                      isSuperAdmin: profile.isSuperAdmin,
                      hasElevatedAccess: profile.hasElevatedAccess,
                      defaultColor: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
                if (profile.email != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    profile.email!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBEAE5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    cottageName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFDE7356),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // White card of nav rows -- Expanded so it fills whatever space
          // is left below the header, however tall that actually is.
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: surface.background,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: ListView(
                children: [
                  _SettingsRow(
                    icon: LucideIcons.pencil,
                    iconColor: const Color(0xFFDE7356),
                    label: 'Edit Profile',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(profile: profile),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SettingsRow(
                    icon: LucideIcons.house,
                    iconColor: const Color(0xFF5B8DEF),
                    label: 'Cottage Profile',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CottageProfileScreen(viewer: profile),
                      ),
                    ),
                  ),
                  // Default Cost and Ownership & Control are super-admin-only
                  // management screens (both already gate their own body
                  // with an EmptyState if reached some other way) -- a
                  // general member has nothing to do there, so the row
                  // itself is hidden rather than leading to a dead end.
                  if (profile.isSuperAdmin) ...[
                    const SizedBox(height: 12),
                    _SettingsRow(
                      icon: LucideIcons.banknote,
                      iconColor: const Color(0xFF63B64E),
                      label: 'Default Cost',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DefaultCostScreen(viewer: profile),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _SettingsRow(
                    icon: LucideIcons.shieldCheck,
                    iconColor: const Color(0xFFFA9033),
                    label: 'Security',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SecurityScreen(viewer: profile),
                      ),
                    ),
                  ),
                  if (profile.isSuperAdmin) ...[
                    const SizedBox(height: 12),
                    _SettingsRow(
                      icon: LucideIcons.crown,
                      iconColor: CottageColors.destructive,
                      label: 'Ownership & Control',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OwnershipScreen(viewer: profile),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _SettingsRow(
                    icon: LucideIcons.logOut,
                    iconColor: CottageColors.destructive,
                    label: 'Log Out',
                    labelColor: CottageColors.destructive,
                    onTap: () => _logout(context),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SocialLinkButton(
                        icon: Icons.facebook,
                        url: 'https://www.facebook.com/Cottagee.me',
                      ),
                      const SizedBox(width: 16),
                      _SocialLinkButton(
                        icon: LucideIcons.globe,
                        url: 'https://www.cottagee.me',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'Cottage v1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: surface.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Facebook page / website link, Settings footer -- opens externally via
/// url_launcher (same pattern as ContactsScreen's tel:/mailto: links).
class _SocialLinkButton extends StatelessWidget {
  final IconData icon;
  final String url;
  const _SocialLinkButton({required this.icon, required this.url});

  Future<void> _open(BuildContext context) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      showToast(context, 'Could not open $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: surface.card,
          border: Border.all(color: surface.border),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: surface.mutedForeground),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Material(
      color: surface.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 76,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: labelColor ?? surface.foreground,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: surface.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
