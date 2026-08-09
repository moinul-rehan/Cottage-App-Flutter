import 'package:flutter/material.dart';
import 'package:cottage/models/profile.dart';
import '../data/member_service.dart';
import '../../dashboard/data/dashboard_service.dart';
import '../../bazaar_duty/data/bazaar_duty_models.dart';
import '../../bazaar_duty/data/bazaar_duty_service.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/common_widgets/cottage_loader.dart';
import 'package:cottage/common_widgets/empty_state.dart';
import 'package:cottage/common_widgets/responsive_utils.dart';
import 'package:cottage/common_widgets/cottage_bottom_sheet.dart';
import 'package:cottage/common_widgets/confirm_modal.dart';
import 'package:cottage/common_widgets/password_confirm_dialog.dart';
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
    return _MembersData(
      viewer: viewer,
      members: members,
      duties: duties,
      cottageName: cottageName,
    );
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
      if (mounted) {
        showToast(context, "That range overlaps another member's duty.");
      }
      return;
    }

    try {
      await _dutyService.assignDuty(
        cottageId: widget.cottageId,
        userId: member.id,
        startDate: startIso,
        endDate: endIso,
        createdBy: data.viewer.id,
      );
    } catch (e) {
      if (mounted) showToast(context, 'Could not assign duty: $e');
      return;
    }
    _refresh();
  }

  Future<void> _removeDuty(BazaarDuty duty) async {
    await _dutyService.deleteDuty(duty.id);
    _refresh();
  }

  /// Toggles between Deactivate and Activate depending on the member's
  /// current state -- deactivating is a "soft pause" (excluded from meal
  /// forms/duty pickers/cost splits, but still shows in the roster and can
  /// still sign in), so only deactivating gets the destructive red styling.
  Future<void> _confirmToggleActive(Profile member) async {
    final activating = !member.isActive;
    final confirmed = await showConfirmModal(
      context,
      icon: activating ? Icons.person_outline : Icons.person_off_outlined,
      title: activating ? 'Activate member?' : 'Deactivate member?',
      message: activating
          ? '${member.displayName} will show as an active member again.'
          : '${member.displayName} will no longer show as an active member of this cottage.',
      confirmLabel: activating ? 'Activate' : 'Deactivate',
      destructive: !activating,
    );
    if (confirmed) {
      await _memberService.setActive(member.id, activating);
      _refresh();
    }
  }

  /// Two-step removal: only reachable once a member is already deactivated
  /// (enforced both by the UI -- see [_MemberCard] -- and by
  /// [MemberService.removeMember]). Requires the acting admin's own
  /// password before proceeding, same as the Months screen's destructive
  /// actions.
  Future<void> _confirmRemove(Profile viewer, Profile member) async {
    final proceed = await showConfirmModal(
      context,
      icon: Icons.person_remove_outlined,
      title: 'Remove ${member.displayName}?',
      message:
          "This hides them from the member list and stops them appearing anywhere new. Their past expenses, meals, and deposits stay fully intact and attributed to them. This can't be undone from here.",
      confirmLabel: 'Continue',
      destructive: true,
    );
    if (!proceed || !mounted) return;

    final verified = await showPasswordConfirmDialog(
      context,
      title: 'Confirm removal',
      message: 'Enter your password to remove ${member.displayName}.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!verified) return;

    try {
      await _memberService.removeMember(viewer: viewer, target: member);
    } catch (e) {
      if (mounted) showToast(context, '$e');
      return;
    }
    if (mounted) showToast(context, '${member.displayName} removed.');
    _refresh();
  }

  Future<void> _showPermissionsSheet(Profile member) async {
    // Mirrors four of the five real `profiles.can_add_*` columns (see
    // supabase/migrations/0002, 0004, 0010, 0022) -- there is no generic
    // permissions array, so each toggle is its own boolean. `can_add_notice`
    // is deliberately not surfaced here: every member can already post a
    // notice by default, so it isn't a real grant to hand out.
    var canAddExpenses = member.canAddExpenses;
    var canAddBazaar = member.canAddBazaar;
    var canAddMeals = member.canAddMeals;
    var canAddDeposit = member.canAddDeposit;

    await showCottageSheet(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Widget buildToggle(
            String title,
            bool value,
            ValueChanged<bool> onChanged,
          ) {
            return CheckboxListTile(
              title: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              value: value,
              onChanged: (val) => setSheetState(() => onChanged(val ?? false)),
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
              buildToggle(
                'Add Utility Expenses',
                canAddExpenses,
                (v) => canAddExpenses = v,
              ),
              buildToggle(
                'Add Bazar / Meal Cost',
                canAddBazaar,
                (v) => canAddBazaar = v,
              ),
              buildToggle('Add Meal', canAddMeals, (v) => canAddMeals = v),
              buildToggle(
                'Add Meal Deposit',
                canAddDeposit,
                (v) => canAddDeposit = v,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  await _memberService.updatePermissions(
                    userId: member.id,
                    canAddExpenses: canAddExpenses,
                    canAddBazaar: canAddBazaar,
                    canAddMeals: canAddMeals,
                    canAddDeposit: canAddDeposit,
                    canAddNotice: member.canAddNotice,
                  );
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
  void _showAddMemberSheet(Profile viewer, String cottageName) {
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final roomCtrl = TextEditingController();
    String role = 'member';

    bool isInviteMode = false;
    bool userNotFound = false;
    bool isChecking = false;

    showCottageSheet(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => CottageSheetContent(
          title: isInviteMode ? 'Invite Member' : 'Add Member',
          children: [
            Text(
              isInviteMode
                  ? "They'll get an invitation email to join this Cottage"
                  : "Enter their email address to add them to this Cottage",
              style: TextStyle(
                fontSize: 12,
                color: context.surface.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),
            if (!isInviteMode) ...[
              _InviteTextField(
                label: 'Email',
                isRequired: true,
                hintText: 'johndoe@gmail.com',
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
              ),
              if (userNotFound) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Color(0xFFB45309),
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'This user is not registered on Cottage yet.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Send an invitation to let them sign up and join.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setSheetState(() {
                              isInviteMode = true;
                            });
                          },
                          icon: const Icon(
                            Icons.mail_outline,
                            size: 15,
                            color: Color(0xFFD1593B),
                          ),
                          label: const Text(
                            'Invite Member',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD1593B),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFD1593B)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _InviteTextField(
                      label: 'First Name',
                      isRequired: true,
                      hintText: 'John',
                      controller: firstNameCtrl,
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _InviteTextField(
                      label: 'Last Name',
                      hintText: 'Doe',
                      controller: lastNameCtrl,
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _InviteTextField(
                label: 'Email',
                isRequired: true,
                hintText: 'johndoe@gmail.com',
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _InviteTextField(
                label: 'Room Label (optional)',
                hintText: 'e.g. Room 2',
                controller: roomCtrl,
              ),
              const SizedBox(height: 12),
              const Text(
                'Role',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF404040),
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 6),
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
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isChecking
                    ? null
                    : () async {
                        final email = emailCtrl.text.trim();
                        if (email.isEmpty) {
                          showToast(sheetContext, 'Email is required.');
                          return;
                        }

                        if (!isInviteMode) {
                          setSheetState(() => isChecking = true);
                          try {
                            final result =
                                await _memberService.inviteOrAddMember(
                              cottageId: viewer.cottageId,
                              email: email,
                              firstName: '',
                              lastName: '',
                              role: 'member',
                            );

                            if (!mounted || !sheetContext.mounted) return;

                            if (result == InviteMemberResult.added) {
                              Navigator.pop(sheetContext);
                              showToast(
                                context,
                                '$email was added to $cottageName!',
                              );
                              _refresh();
                              return;
                            } else if (result ==
                                InviteMemberResult.alreadyInThisCottage) {
                              setSheetState(() => isChecking = false);
                              showToast(
                                sheetContext,
                                '$email is already in this cottage.',
                              );
                              return;
                            } else if (result ==
                                InviteMemberResult.alreadyInAnotherCottage) {
                              setSheetState(() => isChecking = false);
                              showToast(
                                sheetContext,
                                '$email belongs to another cottage.',
                              );
                              return;
                            } else if (result == InviteMemberResult.needsSignup) {
                              setSheetState(() {
                                isChecking = false;
                                userNotFound = true;
                              });
                              return;
                            }
                          } catch (e) {
                            if (sheetContext.mounted) {
                              setSheetState(() => isChecking = false);
                              showToast(
                                sheetContext,
                                'Could not check member: $e',
                              );
                            }
                            return;
                          }
                        } else {
                          final firstName = firstNameCtrl.text.trim();
                          if (firstName.isEmpty) {
                            showToast(
                              sheetContext,
                              'First name is required.',
                            );
                            return;
                          }
                          final lastName = lastNameCtrl.text.trim();
                          final room = roomCtrl.text.trim();

                          setSheetState(() => isChecking = true);
                          await _memberService.sendBackendInvite(
                            cottageId: viewer.cottageId,
                            email: email,
                            firstName: firstName,
                            lastName: lastName,
                            role: role,
                            roomLabel: room,
                          );

                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                          if (mounted) {
                            showToast(
                              context,
                              'Invite sent to $email!',
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD1593B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 0,
                ),
                child: isChecking
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isInviteMode ? 'Invite Member' : 'Add Member',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD1593B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 0,
                ),
                child: const Text(
                  'Send Invite',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return FutureBuilder<_MembersData>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: CottageColors.primary,
            body: Center(child: CottageLoader()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: CottageColors.primary,
            body: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: surface.card,
                  borderRadius: BorderRadius.circular(16),
                ),
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
              ),
            ),
          );
        }

        final data = snapshot.data!;

        final pageContent = Scaffold(
          backgroundColor: CottageColors.primary,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _DynamicMembersHeaderDelegate(
                    surface: surface,
                    safeAreaTop: MediaQuery.of(context).padding.top,
                    onInviteTap: () =>
                        _showAddMemberSheet(data.viewer, data.cottageName),
                  ),
                ),
              ];
            },
            body: Container(
              color: surface.card,
              child: data.members.isEmpty
                  ? const EmptyState(
                      icon: Icons.people_rounded,
                      title: 'No members found',
                      subtitle: 'There are no members in this cottage yet.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async => _refresh(),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          context.responsivePadding,
                          20,
                          context.responsivePadding,
                          24 + MediaQuery.paddingOf(context).bottom,
                        ),
                        children: [
                          for (final member in data.members)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _MemberCard(
                                member: member,
                                isViewer: member.id == data.viewer.id,
                                canManage:
                                    data.viewer.isSuperAdmin &&
                                    member.id != data.viewer.id,
                                // Unlike Permissions/Deactivate/Remove,
                                // assigning bazaar duty to yourself is a
                                // normal thing for a super admin to want
                                // (they're a household member too), so it
                                // isn't gated on "not self" like the rest.
                                canAssignDuty: data.viewer.isSuperAdmin,
                                duty: _currentOrNextDuty(
                                  data.duties,
                                  member.id,
                                ),
                                formatRange: _formatRange,
                                onAssignDuty: () => _assignDuty(data, member),
                                onRemoveDuty: (duty) => _removeDuty(duty),
                                onToggleActive: () =>
                                    _confirmToggleActive(member),
                                onRemove: () =>
                                    _confirmRemove(data.viewer, member),
                                onPermissions: () =>
                                    _showPermissionsSheet(member),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        );

        if (snapshot.connectionState != ConnectionState.done) {
          return Stack(
            children: [
              pageContent,
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.15),
                  child: const Center(child: CottageLoader()),
                ),
              ),
            ],
          );
        }
        return pageContent;
      },
    );
  }
}

class _DynamicMembersHeaderDelegate extends SliverPersistentHeaderDelegate {
  final CottageSurface surface;
  final double safeAreaTop;
  final VoidCallback onInviteTap;

  _DynamicMembersHeaderDelegate({
    required this.surface,
    required this.safeAreaTop,
    required this.onInviteTap,
  });

  @override
  double get minExtent => safeAreaTop + 88.0;

  @override
  double get maxExtent => safeAreaTop + 148.0;

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
        // Background: Orange top, White bottom
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: (safeAreaTop + 56) * (1 - progress),
          child: Container(color: CottageColors.primary),
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

        // Expanded Content (Fades out)
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Orange Header Content
                    Container(
                      height: safeAreaTop + 56,
                      padding: EdgeInsets.only(
                        top: safeAreaTop,
                        left: context.responsivePadding,
                        right: context.responsivePadding,
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
                    // White Card Content (Details)
                    Padding(
                      padding: EdgeInsets.only(
                        left: context.responsivePadding,
                        right: context.responsivePadding,
                        top: 16,
                      ),
                      child: const Text(
                        "Everyone sharing this Cottage and their role.",
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          color: Color(0xFF303030),
                        ),
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Collapsed Content (Fades in)
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Common bottom elements (Invite Button)
        Positioned(
          left: context.responsivePadding,
          right: context.responsivePadding,
          bottom: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [_AddMemberButton(onTap: onInviteTap)]),
            ],
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

class _AddMemberButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddMemberButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(Icons.add, color: surface.foreground, size: 18),
      label: Text(
        'Add Member',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: surface.foreground,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: surface.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(1000),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: Size.zero,
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final Profile member;
  final bool isViewer;
  final bool canManage;
  final bool canAssignDuty;
  final BazaarDuty? duty;
  final String Function(String, String) formatRange;
  final VoidCallback onAssignDuty;
  final ValueChanged<BazaarDuty> onRemoveDuty;
  final VoidCallback onToggleActive;
  final VoidCallback onRemove;
  final VoidCallback onPermissions;

  const _MemberCard({
    required this.member,
    required this.isViewer,
    required this.canManage,
    required this.canAssignDuty,
    required this.duty,
    required this.formatRange,
    required this.onAssignDuty,
    required this.onRemoveDuty,
    required this.onToggleActive,
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
                        VerifiedBadge(
                          isSuperAdmin: member.isSuperAdmin,
                          hasElevatedAccess: member.hasElevatedAccess,
                          defaultColor: const Color(0xFF17191E),
                          size: 14,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      member.isSuperAdmin
                          ? 'Super admin'
                          : (member.hasElevatedAccess ? 'Manager' : 'Member'),
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
                  if (canAssignDuty)
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
          if (canManage || canAssignDuty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (canManage)
                  _ActionPill(
                    label: 'Permissions',
                    trailingIcon: Icons.keyboard_arrow_down_rounded,
                    onTap: onPermissions,
                  ),
                if (canAssignDuty)
                  _ActionPill(label: 'Assign Duty', onTap: onAssignDuty),
                if (canManage && member.isSuperAdmin)
                  _ToggleActiveLabel(
                    isActive: member.isActive,
                    onTap: onToggleActive,
                  )
                else if (canManage && member.isActive)
                  _ToggleActiveLabel(isActive: true, onTap: onToggleActive)
                else if (canManage) ...[
                  _ToggleActiveLabel(isActive: false, onTap: onToggleActive),
                  GestureDetector(
                    onTap: onRemove,
                    child: const Text(
                      'Remove',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: CottageColors.destructive,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ToggleActiveLabel extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  const _ToggleActiveLabel({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        isActive ? 'Deactivate' : 'Activate',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: isActive ? const Color(0xFF7A818D) : CottageColors.primary,
        ),
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

class _InviteTextField extends StatelessWidget {
  final String label;
  final bool isRequired;
  final String hintText;
  final TextEditingController controller;
  final TextCapitalization textCapitalization;
  final TextInputType keyboardType;

  const _InviteTextField({
    required this.label,
    this.isRequired = false,
    required this.hintText,
    required this.controller,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF404040),
                fontWeight: FontWeight.w400,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 2),
              const Text(
                '*',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFFCC4F4F),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          textCapitalization: textCapitalization,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 13, color: Color(0xFF404040)),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
            ),
            isDense: true,
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
  const _RoleChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDE7356) : const Color(0xFFFAFAFA),
          border: Border.all(
            color: selected ? const Color(0xFFDE7356) : const Color(0xFFEEEEEE),
          ),
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
