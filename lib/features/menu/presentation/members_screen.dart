import 'package:flutter/material.dart';
import 'package:cottage/models/profile.dart';
import '../data/member_service.dart';
import '../../dashboard/data/dashboard_service.dart';
import '../../bazaar_duty/data/bazaar_duty_models.dart';
import '../../bazaar_duty/data/bazaar_duty_service.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/common_widgets/empty_state.dart';
import 'package:cottage/common_widgets/responsive_utils.dart';
import 'package:cottage/helpers/ui_helpers.dart';

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
  const _MembersData({
    required this.viewer,
    required this.members,
    required this.duties,
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
    return _MembersData(viewer: viewer, members: members, duties: duties);
  }

  void _refresh() => setState(() => _future = _load());

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate member?'),
        content: Text(
          '${member.displayName} will no longer show as an active member of this cottage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Deactivate',
              style: TextStyle(color: CottageColors.destructive),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _memberService.setActive(member.id, false);
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Scaffold(
      backgroundColor: CottageColors.primary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.responsivePadding,
                8,
                context.responsivePadding,
                16,
              ),
              child: const Row(
                children: [
                  Text(
                    'Members',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: surface.card,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
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
                                onTap: () => showToast(
                                  context,
                                  'Invite links are coming in a future update',
                                ),
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
                                onPermissions: () => showToast(
                                  context,
                                  'Granular permissions are coming in a future update',
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                    Text(
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
          if (member.mobileNumber != null || member.email != null) ...[
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (member.mobileNumber != null) ...[
                  _ContactRow(
                    icon: Icons.call_outlined,
                    text: member.mobileNumber!,
                  ),
                  if (member.email != null) const SizedBox(height: 6),
                ],
                if (member.email != null)
                  _ContactRow(icon: Icons.mail_outline, text: member.email!),
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
