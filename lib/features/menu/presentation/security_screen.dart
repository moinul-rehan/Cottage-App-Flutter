import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cottage/models/profile.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/common_widgets/password_confirm_dialog.dart';
import 'package:cottage/common_widgets/app_toast.dart';
import 'package:cottage/helpers/ui_helpers.dart';
import '../data/security_service.dart';

/// "Security" -- Figma node 220:1774: change password + a self-service
/// "Delete My Account" (schedules removal in 7 days). Page shell copies
/// _DynamicDefaultCostHeaderDelegate's collapsing-title mechanics.
class SecurityScreen extends StatefulWidget {
  final Profile viewer;
  const SecurityScreen({super.key, required this.viewer});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _service = SecurityService();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final current = _currentCtrl.text;
    final next = _newCtrl.text;
    final confirm = _confirmCtrl.text;
    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      showToast(context, 'Fill in every password field.');
      return;
    }
    if (next.length < 8) {
      showToast(context, 'New password must be at least 8 characters.');
      return;
    }
    if (next != confirm) {
      showToast(context, 'New password and confirmation do not match.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.changePassword(
        currentPassword: current,
        newPassword: next,
      );
      if (!mounted) return;
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
      showAppToast(context, title: 'Password changed.', type: ToastType.success);
    } on AuthException {
      if (!mounted) return;
      showAppToast(context, title: 'Current password is incorrect.', type: ToastType.error);
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, title: 'Could not change password. Try again.', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteAccount() async {
    if (widget.viewer.isSuperAdmin) {
      showAppToast(
        context,
        title: 'Transfer ownership before deleting your account.',
        type: ToastType.warning,
      );
      return;
    }
    final confirmed = await showPasswordConfirmDialog(
      context,
      title: 'Delete your account?',
      message:
          'Your account will be scheduled for removal in 7 days. You can cancel any time before then.',
      confirmLabel: 'Delete My Account',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await _service.requestAccountDeletion(
        userId: widget.viewer.id,
        cottageId: widget.viewer.cottageId,
        requesterName: widget.viewer.displayName,
      );
      if (!mounted) return;
      showAppToast(
        context,
        title: 'Account scheduled for deletion in 7 days.',
        type: ToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, title: 'Could not schedule deletion. Try again.', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Scaffold(
      backgroundColor: const Color(0xFFDE7356),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverPersistentHeader(
              pinned: true,
              delegate: _DynamicSecurityHeaderDelegate(
                surface: surface,
                safeAreaTop: MediaQuery.of(context).padding.top,
              ),
            ),
          ];
        },
        body: Container(
          color: surface.card,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              _ChangePasswordCard(
                currentCtrl: _currentCtrl,
                newCtrl: _newCtrl,
                confirmCtrl: _confirmCtrl,
                saving: _saving,
                onSubmit: _changePassword,
              ),
              const SizedBox(height: 16),
              DangerZoneCardShared(
                description:
                    'Schedules your account for removal in 7 days. You can cancel any time before then.',
                buttonLabel: 'Delete My Account',
                buttonIcon: LucideIcons.userX,
                onTap: _deleteAccount,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordCard extends StatelessWidget {
  final TextEditingController currentCtrl;
  final TextEditingController newCtrl;
  final TextEditingController confirmCtrl;
  final bool saving;
  final VoidCallback onSubmit;

  const _ChangePasswordCard({
    required this.currentCtrl,
    required this.newCtrl,
    required this.confirmCtrl,
    required this.saving,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: context.surface.background,
        border: Border.all(color: context.surface.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFDE7356).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.keyRound,
                  size: 16,
                  color: Color(0xFFDE7356),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Change Password',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.surface.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PasswordField(label: 'Current Password', controller: currentCtrl),
          const SizedBox(height: 12),
          _PasswordField(label: 'New Password', controller: newCtrl),
          const SizedBox(height: 12),
          _PasswordField(
            label: 'Confirm New Password',
            controller: confirmCtrl,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: saving ? null : onSubmit,
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFDE7356),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                saving ? 'Changing…' : 'Change Password',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  const _PasswordField({required this.label, required this.controller});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: context.surface.card,
        border: Border.all(color: context.surface.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.surface.mutedForeground,
                  ),
                ),
                TextField(
                  controller: widget.controller,
                  obscureText: _obscure,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.surface.foreground,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              _obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 16,
              color: context.surface.mutedForeground,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ],
      ),
    );
  }
}

/// Pink-bordered "Danger Zone" card, shared shape between Security's
/// "Delete My Account" and Ownership's "Delete Cottage" -- same
/// #FFF2F2/#FF4F4F treatment in both Figma frames.
class DangerZoneCardShared extends StatelessWidget {
  final String description;
  final String buttonLabel;
  final IconData? buttonIcon;
  final VoidCallback onTap;

  const DangerZoneCardShared({
    super.key,
    required this.description,
    required this.buttonLabel,
    this.buttonIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        // A flat #FFF2F2 never adapted to dark mode -- on a dark card it
        // stayed a bright pink box regardless of theme, with the
        // description's #593333 (a warm near-black meant for THAT pink
        // background) unreadable against dark. `toneRedBg` is the same red
        // tint the rest of the app already uses for status boxes, and it's
        // defined per-theme (translucent red over whatever the surface is).
        color: context.surface.toneRedBg,
        border: Border.all(color: const Color(0x4DFF4F4F)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.triangleAlert, size: 16, color: Color(0xFFFF4F4F)),
              SizedBox(width: 8),
              Text(
                'Danger Zone',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFF4F4F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: context.surface.foreground,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4F4F),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (buttonIcon != null) ...[
                    Icon(buttonIcon, size: 15, color: Colors.white),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    buttonLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DynamicSecurityHeaderDelegate extends SliverPersistentHeaderDelegate {
  final CottageSurface surface;
  final double safeAreaTop;

  _DynamicSecurityHeaderDelegate({
    required this.surface,
    required this.safeAreaTop,
  });

  @override
  double get minExtent => safeAreaTop + 56.0;

  @override
  double get maxExtent => safeAreaTop + 88.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height:
              safeAreaTop + 56 - (shrinkOffset * 1.5).clamp(0, safeAreaTop + 56),
          child: const ColoredBox(color: Color(0xFFDE7356)),
        ),
        Positioned(
          top: (safeAreaTop + 56) * (1 - progress),
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: surface.card,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20 * (1 - progress)),
                topRight: Radius.circular(20 * (1 - progress)),
              ),
            ),
          ),
        ),
        Positioned(
          top: safeAreaTop,
          left: 4,
          right: 16,
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.arrow_back,
                  color: Color.lerp(Colors.white, surface.foreground, progress),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Security',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color.lerp(Colors.white, surface.foreground, progress),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _DynamicSecurityHeaderDelegate oldDelegate) {
    return true;
  }
}
