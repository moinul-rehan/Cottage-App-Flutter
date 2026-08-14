import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cottage/models/profile.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/common_widgets/password_confirm_dialog.dart';
import 'package:cottage/common_widgets/app_toast.dart';
import 'package:cottage/common_widgets/empty_state.dart';
import '../data/member_service.dart';
import '../data/ownership_service.dart';
import 'security_screen.dart';

/// "Ownership & Control" -- Figma node 221:1777: transfer super-admin role
/// to another member, and a "Delete Cottage" self-service request (schedules
/// permanent deletion in 7 days). Super-admin only. Page shell copies
/// _DynamicDefaultCostHeaderDelegate's collapsing-title mechanics.
class OwnershipScreen extends StatefulWidget {
  final Profile viewer;
  const OwnershipScreen({super.key, required this.viewer});

  @override
  State<OwnershipScreen> createState() => _OwnershipScreenState();
}

class _OwnershipScreenState extends State<OwnershipScreen> {
  final _memberService = MemberService();
  final _ownershipService = OwnershipService();
  late Future<List<Profile>> _membersFuture;
  Profile? _selectedMember;

  @override
  void initState() {
    super.initState();
    _membersFuture = _loadMembers();
  }

  Future<List<Profile>> _loadMembers() async {
    final members = await _memberService.getActiveMembers(
      widget.viewer.cottageId,
    );
    return members.where((m) => m.id != widget.viewer.id).toList();
  }

  Future<void> _pickMember(List<Profile> members) async {
    final picked = await showModalBottomSheet<Profile>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final m in members)
              ListTile(
                title: Text(m.displayName),
                subtitle: m.email != null ? Text(m.email!) : null,
                onTap: () => Navigator.pop(sheetCtx, m),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() => _selectedMember = picked);
    }
  }

  Future<void> _transferOwnership() async {
    final target = _selectedMember;
    if (target == null) {
      showAppToast(context, title: 'Select a member first.', type: ToastType.warning);
      return;
    }
    final confirmed = await showPasswordConfirmDialog(
      context,
      title: 'Transfer ownership?',
      message:
          "You'll hand super admin access to ${target.displayName} and become a regular member immediately.",
      confirmLabel: 'Transfer Ownership',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await _ownershipService.transferOwnership(
        currentAdminId: widget.viewer.id,
        newAdminId: target.id,
        currentAdminName: widget.viewer.displayName,
        newAdminName: target.displayName,
      );
      if (!mounted) return;
      showAppToast(
        context,
        title: 'Ownership transferred to ${target.displayName}.',
        type: ToastType.success,
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, title: 'Could not transfer ownership. Try again.', type: ToastType.error);
    }
  }

  Future<void> _deleteCottage() async {
    final confirmed = await showPasswordConfirmDialog(
      context,
      title: 'Delete this Cottage?',
      message:
          'This Cottage will be scheduled for permanent deletion in 7 days. Every member is notified.',
      confirmLabel: 'Delete Cottage',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await _ownershipService.requestCottageDeletion(
        cottageId: widget.viewer.cottageId,
        requestedBy: widget.viewer.id,
        requesterName: widget.viewer.displayName,
      );
      if (!mounted) return;
      showAppToast(
        context,
        title: 'Cottage scheduled for deletion in 7 days.',
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

    if (!widget.viewer.isSuperAdmin) {
      return Scaffold(
        backgroundColor: const Color(0xFFDE7356),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 15),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Ownership & Control',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: surface.card,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: const EmptyState(
                    icon: Icons.lock_outline,
                    title: 'Super admins only',
                    subtitle:
                        'Only a super admin can manage ownership and control.',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFDE7356),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverPersistentHeader(
              pinned: true,
              delegate: _DynamicOwnershipHeaderDelegate(
                surface: surface,
                safeAreaTop: MediaQuery.of(context).padding.top,
              ),
            ),
          ];
        },
        body: Container(
          color: surface.card,
          child: FutureBuilder<List<Profile>>(
            future: _membersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final members = snapshot.data ?? const [];
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                children: [
                  _TransferOwnershipCard(
                    selected: _selectedMember,
                    onPick: () => _pickMember(members),
                    onTransfer: _transferOwnership,
                  ),
                  const SizedBox(height: 16),
                  DangerZoneCardShared(
                    description:
                        'Schedules this Cottage for permanent deletion in 7 days. Every member is notified.',
                    buttonLabel: 'Delete Cottage',
                    onTap: _deleteCottage,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TransferOwnershipCard extends StatelessWidget {
  final Profile? selected;
  final VoidCallback onPick;
  final VoidCallback onTransfer;

  const _TransferOwnershipCard({
    required this.selected,
    required this.onPick,
    required this.onTransfer,
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
                  color: const Color(0xFF5B8DEF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.crown,
                  size: 16,
                  color: Color(0xFF5B8DEF),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Transfer Ownership',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.surface.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Hand over super admin access. You'll become a regular member immediately.",
            style: TextStyle(fontSize: 12, color: context.surface.mutedForeground, height: 1.4),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onPick,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.surface.card,
                border: Border.all(color: context.surface.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selected?.displayName ?? 'Select a member…',
                      style: TextStyle(
                        fontSize: 13,
                        color: selected != null
                            ? context.surface.foreground
                            : context.surface.mutedForeground,
                      ),
                    ),
                  ),
                  Icon(LucideIcons.users, size: 15, color: context.surface.mutedForeground),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onTransfer,
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: context.surface.card,
                border: Border.all(color: const Color(0xFF5B8DEF)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Transfer Ownership',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5B8DEF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DynamicOwnershipHeaderDelegate extends SliverPersistentHeaderDelegate {
  final CottageSurface surface;
  final double safeAreaTop;

  _DynamicOwnershipHeaderDelegate({
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
              Expanded(
                child: Text(
                  'Ownership & Control',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color.lerp(Colors.white, surface.foreground, progress),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _DynamicOwnershipHeaderDelegate oldDelegate) {
    return true;
  }
}
