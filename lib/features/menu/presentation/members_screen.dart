import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cottage/models/profile.dart';
import '../data/member_service.dart';
import '../../dashboard/data/dashboard_service.dart';
import '../../bazaar_duty/data/bazaar_duty_models.dart';
import '../../bazaar_duty/data/bazaar_duty_service.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/common_widgets/empty_state.dart';
import 'package:cottage/common_widgets/responsive_utils.dart';
import 'package:cottage/common_widgets/cottage_bottom_sheet.dart';
import 'package:cottage/common_widgets/confirm_modal.dart';
import 'package:cottage/helpers/ui_helpers.dart';
import '../../dashboard/presentation/verified_badge.dart';

/// Full Members screen -- Figma node 79:1109 ("Members"): every member of
/// the cottage (active or not), with role, contact info, current/upcoming
/// bazaar duty, and admin actions. Page-shelled like Contacts/Notices
/// (orange band + white rounded sheet), since this tab owns its header
/// rather than using [AppScaffold]'s bar.
///
/// Some of the Figma spec has no backing data or service yet -- there's no
/// `room`/`permissions` column on `profiles`, and no "verified" concept --
/// so those bits are omitted rather than faked. "Assign Duty" and
/// "Deactivate" are real (backed by [BazaarDutyService]/[MemberService]);
/// "Permissions" and "Remove" are stubbed with a toast, matching the same
/// "coming in a future update" pattern already used for other unbuilt
/// actions elsewhere in the app (e.g. [MenuScreen]).
class MembersScreen extends StatefulWidget {
  final String cottageId;
  const MembersScreen({super.key, required this.cottageId});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersData {
  final Profile viewer;
  final List<Profile> members;
  final List<BazaarDuty> duties;
  final String cottageName;
  const _MembersData({
    required this.viewer,
    required this.members,
    required this.duties,
    required this.cottageName,
  });
}

class _MembersScreenState extends State<MembersScreen>
    with WidgetsBindingObserver {
  final _memberService = MemberService();
  final _dashService = DashboardService();
  final _dutyService = BazaarDutyService();
  late Future<_MembersData> _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // See NoticesScreen/ContactsScreen/DashboardScreen for why: a request
    // in flight when the OS suspends the app never completes or errors,
    // leaving the screen stuck loading -- reloading on resume recovers.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<_MembersData> _load() async {
    final viewer = await _dashService.getCurrentProfile().timeout(
      const Duration(seconds: 15),
    );
    final members = await _memberService
        .getAllMembers(widget.cottageId)
        .timeout(const Duration(seconds: 15));
    final duties = await _dutyService
        .getAllBazaarDuties(widget.cottageId)
        .timeout(const Duration(seconds: 15));
    final cottageName = await _memberService
        .getCottageName(widget.cottageId)
        .timeout(const Duration(seconds: 15));
    return _MembersData(viewer: viewer, members: members, duties: duties, cottageName: cottageName);
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatRange(String startIso, String endIso) {
    final s = DateTime.tryParse(startIso);
    final e = DateTime.tryParse(endIso);
    if (s == null || e == null) return '$startIso – $endIso';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${s.day} ${months[s.month - 1]} – ${e.day} ${months[e.month - 1]}, ${e.year}';
  }

  /// The member's current duty if today falls in its range, else their
  /// nearest upcoming one -- mirrors dutyStatus() ordering used elsewhere.
  BazaarDuty? _currentOrNextDuty(List<BazaarDuty> duties, String userId) {
    final today = _iso(DateTime.now());
    final mine =
        duties
            .where((d) => d.userId == userId && d.endDate.compareTo(today) >= 0)
            .toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));
    return mine.isEmpty ? null : mine.first;
  }

  Future<void> _assignDuty(_MembersData data, Profile member) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, 1),
      lastDate: DateTime(now.year, now.month + 3, 0),
      initialDateRange: DateTimeRange(
        start: now,
        end: now.add(const Duration(days: 5)),
      ),
    );
    if (range == null) return;

    final startIso = _iso(range.start);
    final endIso = _iso(range.end);
    if (bazaarDutyOverlaps(
      existing: data.duties,
      start: startIso,
      end: endIso,
    )) {
      if (mounted)
        showToast(context, "That range overlaps another member's duty.");
      return;
    }

    await _dutyService.assignDuty(
      cottageId: widget.cottageId,
      userId: member.id,
      startDate: startIso,
      endDate: endIso,
    );
    _refresh();
  }

  Future<void> _removeDuty(BazaarDuty duty) async {
    await _dutyService.deleteDuty(duty.id);
    _refresh();
  }

  Future<void> _confirmDeactivate(Profile member) async {
    final confirmed = await showConfirmModal(
      context,
      icon: Icons.person_off_outlined,
      title: 'Deactivate member?',
      message: '${member.displayName} will no longer show as an active member of this cottage.',
      confirmLabel: 'Deactivate',
      destructive: true,
    );
    if (confirmed) {
      await _memberService.setActive(member.id, false);
      _refresh();
    }
  }

  Future<void> _showPermissionsSheet(Profile member) async {
    final permissions = List<String>.from(member.permissions);

    await showCottageSheet(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Widget buildToggle(String title, String key) {
            final hasPerm = permissions.contains(key);
            return CheckboxListTile(
              title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              value: hasPerm,
              onChanged: (val) {
                setSheetState(() {
                  if (val == true) {
                    permissions.add(key);
                  } else {
                    permissions.remove(key);
                  }
                });
              },
              contentPadding: EdgeInsets.zero,
              activeColor: CottageColors.primary,
              controlAffinity: ListTileControlAffinity.leading,
            );
          }

          return CottageSheetContent(
            title: '${member.firstName}\'s Permissions',
            children: [
              const Text(
                'Select which actions this member is allowed to perform.',
                style: TextStyle(fontSize: 13, color: Color(0xFF7A818D)),
              ),
              const SizedBox(height: 8),
              buildToggle('Add Utility Expenses', 'add_utility_expenses'),
              buildToggle('Add meal Cost', 'add_meal_cost'),
              buildToggle('Add Meal', 'add_meal'),
              buildToggle('Add meal deposit', 'add_meal_deposit'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  await _memberService.updatePermissions(member.id, permissions);
                  _refresh();
                },
                child: const Text('Save Permissions'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Figma node 85:1143 ("Invite Member - Drawer"). There's no `invites`
  /// table (or any other join-an-existing-cottage mechanism) in the backend
  /// yet -- `auth.signUp` always creates a brand-new cottage for the signer
  /// -- so this can't create a real pending-member record. Instead it opens
  /// the device's mail app with the invite details pre-filled; the admin
  /// still has to add the person to the cottage themselves once they sign
  /// up and reach out.
  void _showInviteSheet(Profile viewer, String cottageName) {
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final roomCtrl = TextEditingController();
    String role = 'member';

    showCottageSheet(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => CottageSheetContent(
          title: 'Invite Member',
          children: [
            Text(
              "They'll get an email to join this Cottage",
              style: TextStyle(fontSize: 12, color: context.surface.mutedForeground),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: firstNameCtrl,
                    decoration: const InputDecoration(labelText: 'First Name *', hintText: 'John'),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: lastNameCtrl,
                    decoration: const InputDecoration(labelText: 'Last Name', hintText: 'Doe'),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email *', hintText: 'johndoe@gmail.com'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: roomCtrl,
              decoration: const InputDecoration(labelText: 'Room Label (optional)', hintText: 'e.g. Room 2'),
            ),
            const SizedBox(height: 12),
            const Text('Role', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _RoleChoice(
                    label: 'Member',
                    selected: role == 'member',
                    onTap: () => setSheetState(() => role = 'member'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RoleChoice(
                    label: 'Super Admin',
                    selected: role == 'super_admin',
                    onTap: () => setSheetState(() => role = 'super_admin'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final firstName = firstNameCtrl.text.trim();
                final email = emailCtrl.text.trim();
                if (firstName.isEmpty || email.isEmpty) {
                  showToast(sheetContext, 'First name and email are required.');
                  return;
                }
                final lastName = lastNameCtrl.text.trim();
                final room = roomCtrl.text.trim();
                final roleLabel = role == 'super_admin' ? 'Super Admin' : 'Member';

                final subject = "You're invited to join $cottageName on Cottage";
                final body = StringBuffer()
                  ..writeln('Hi $firstName${lastName.isEmpty ? '' : ' $lastName'},')
                  ..writeln()
                  ..writeln('${viewer.displayName} has invited you to join "$cottageName" on Cottage as a $roleLabel${room.isEmpty ? '' : ' ($room)'}.')
                  ..writeln()
                  ..writeln('Download the Cottage app, sign up, and let ${viewer.displayName} know once you have -- they\'ll add you to the cottage.');

                final uri = Uri(
                  scheme: 'mailto',
                  path: email,
                  query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body.toString())}',
                );
                Navigator.pop(sheetContext);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else if (mounted) {
                  showToast(context, 'Could not open a mail app.');
                }
              },
              child: const Text('Send Invite'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Scaffold(
      backgroundColor: CottageColors.primary,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverPersistentHeader(
              pinned: true,
              delegate: _DynamicMembersHeaderDelegate(
                surface: surface,
                safeAreaTop: MediaQuery.of(context).padding.top,
              ),
            ),
          ];
        },
        body: Container(
          color: surface.card,
          child: FutureBuilder<_MembersData>(
            future: _future,
            builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 40,
                              color: CottageColors.destructive,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Could not load members.\n${snapshot.error}',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _refresh,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    final data = snapshot.data!;
                    if (data.members.isEmpty) {
                      return const EmptyState(
                        icon: Icons.people_rounded,
                        title: 'No members found',
                        subtitle: 'There are no members in this cottage yet.',
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async => _refresh(),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          context.responsivePadding,
                          20,
                          context.responsivePadding,
                          96,
                        ),
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Everyone sharing this Cottage and their role.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF303030),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              _InviteButton(
                                onTap: () => _showInviteSheet(data.viewer, data.cottageName),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          for (final member in data.members)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _MemberCard(
                                member: member,
                                isViewer: member.id == data.viewer.id,
                                canManage:
                                    data.viewer.isSuperAdmin &&
                                    member.id != data.viewer.id,
                                duty: _currentOrNextDuty(
                                  data.duties,
                                  member.id,
                                ),
                                formatRange: _formatRange,
                                onAssignDuty: () => _assignDuty(data, member),
                                onRemoveDuty: (duty) => _removeDuty(duty),
                                onDeactivate: () => _confirmDeactivate(member),
                                onRemove: () => showToast(
                                  context,
                                  'Removing members is coming in a future update',
                                ),
                                onPermissions: () => _showPermissionsSheet(member),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _DynamicMembersHeaderDelegate extends SliverPersistentHeaderDelegate {
  final CottageSurface surface;
  final double safeAreaTop;

  _DynamicMembersHeaderDelegate({
    required this.surface,
    required this.safeAreaTop,
  });

  @override
  double get minExtent => safeAreaTop + 56.0;

  @override
  double get maxExtent => safeAreaTop + 104.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: maxExtent - (shrinkOffset * 1.5).clamp(0, maxExtent),
          child: Container(color: CottageColors.primary),
        ),
        Positioned(
          top: maxExtent * (1 - progress),
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: surface.card,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24 * (1 - progress)),
                topRight: Radius.circular(24 * (1 - progress)),
              ),
            ),
          ),
        ),

        if (progress < 1.0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: Opacity(
              opacity: 1.0 - progress,
              child: IgnorePointer(
                ignoring: progress > 0.5,
                child: Container(
                  height: safeAreaTop + 56,
                  padding: EdgeInsets.only(
                    top: safeAreaTop + 8,
                    left: context.responsivePadding,
                    right: context.responsivePadding,
                  ),
                  child: const Text(
                    'Members',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),

        if (progress > 0.0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: Opacity(
              opacity: progress,
              child: IgnorePointer(
                ignoring: progress < 0.5,
                child: Container(
                  padding: EdgeInsets.only(
                    top: safeAreaTop + 8,
                    left: context.responsivePadding,
                    right: context.responsivePadding,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Members',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: surface.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _DynamicMembersHeaderDelegate oldDelegate) {
    return true;
  }
}

class _InviteButton extends StatelessWidget {
  final VoidCallback onTap;
  const _InviteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFEEEEEE)),
          borderRadius: BorderRadius.circular(1000),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 20, color: Color(0xFF404040)),
            SizedBox(width: 8),
            Text(
              'Invite',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF404040),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final Profile member;
  final bool isViewer;
  final bool canManage;
  final BazaarDuty? duty;
  final String Function(String, String) formatRange;
  final VoidCallback onAssignDuty;
  final ValueChanged<BazaarDuty> onRemoveDuty;
  final VoidCallback onDeactivate;
  final VoidCallback onRemove;
  final VoidCallback onPermissions;

  const _MemberCard({
    required this.member,
    required this.isViewer,
    required this.canManage,
    required this.duty,
    required this.formatRange,
    required this.onAssignDuty,
    required this.onRemoveDuty,
    required this.onDeactivate,
    required this.onRemove,
    required this.onPermissions,
  });

  @override
  Widget build(BuildContext context) {
    final initial = member.firstName.isNotEmpty
        ? member.firstName[0].toUpperCase()
        : '?';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEEEEEE)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBEAE5),
                  borderRadius: BorderRadius.circular(22),
                  image:
                      (member.avatarUrl != null && member.avatarUrl!.isNotEmpty)
                      ? DecorationImage(
                          image: NetworkImage(member.avatarUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child:
                    (member.avatarUrl != null && member.avatarUrl!.isNotEmpty)
                    ? null
                    : Text(
                        initial,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: CottageColors.primary,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isViewer
                                ? '${member.displayName} (you)'
                                : member.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF17191E),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        VerifiedBadge(isSuperAdmin: member.isSuperAdmin, defaultColor: const Color(0xFF17191E), size: 14),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      member.isSuperAdmin ? 'Super admin' : 'Member',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7A818D),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: member.isActive
                      ? const Color(0xFFE8F5EC)
                      : const Color(0xFFF4F4F6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  member.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: member.isActive
                        ? const Color(0xFF059669)
                        : const Color(0xFF7A818D),
                  ),
                ),
              ),
            ],
          ),
          if (member.mobileNumber != null ||
              member.email != null ||
              (member.address?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (member.mobileNumber != null) ...[
                  _ContactRow(
                    icon: Icons.call_outlined,
                    text: member.mobileNumber!,
                  ),
                  const SizedBox(height: 6),
                ],
                if (member.email != null) ...[
                  _ContactRow(icon: Icons.mail_outline, text: member.email!),
                  if (member.address?.isNotEmpty ?? false)
                    const SizedBox(height: 6),
                ],
                if (member.address?.isNotEmpty ?? false)
                  _ContactRow(
                    icon: Icons.location_on_outlined,
                    text: member.address!,
                  ),
              ],
            ),
          ],
          if (duty != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFBEAE5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Bazaar duty: ${formatRange(duty!.startDate, duty!.endDate)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: Color(0xFFD1593B),
                      ),
                    ),
                  ),
                  if (canManage)
                    GestureDetector(
                      onTap: () => onRemoveDuty(duty!),
                      child: const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: Color(0xFFD1593B),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (canManage) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _ActionPill(
                  label: 'Permissions',
                  trailingIcon: Icons.keyboard_arrow_down_rounded,
                  onTap: onPermissions,
                ),
                const SizedBox(width: 8),
                _ActionPill(label: 'Assign Duty', onTap: onAssignDuty),
                const Spacer(),
                GestureDetector(
                  onTap: member.isActive ? onDeactivate : onRemove,
                  child: Text(
                    member.isActive ? 'Deactivate' : 'Remove',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: member.isActive
                          ? const Color(0xFF7A818D)
                          : CottageColors.destructive,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ContactRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF7A818D)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Color(0xFF7A818D)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _RoleChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RoleChoice({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? CottageColors.primary : const Color(0xFFFAFAFA),
          border: Border.all(color: selected ? CottageColors.primary : const Color(0xFFEEEEEE)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF404040),
          ),
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final String label;
  final IconData? trailingIcon;
  final VoidCallback onTap;
  const _ActionPill({
    required this.label,
    this.trailingIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFEEEEEE)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Color(0xFF17191E),
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 4),
              Icon(trailingIcon, size: 14, color: const Color(0xFF17191E)),
            ],
          ],
        ),
      ),
    );
  }
}
