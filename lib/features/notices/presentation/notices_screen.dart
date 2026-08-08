import 'package:flutter/material.dart';
import '../data/notice.dart';
import '../data/notice_service.dart';
import '../data/notice_types.dart';
import 'package:cottage/models/profile.dart';
import 'package:cottage/helpers/supabase_service.dart';
import '../../dashboard/data/dashboard_service.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/common_widgets/responsive_utils.dart';
import 'package:cottage/common_widgets/cottage_bottom_sheet.dart';
import 'package:cottage/common_widgets/empty_state.dart';
import 'package:cottage/helpers/ui_helpers.dart';
import 'notice_sticky_note.dart';

/// Full notice-board screen -- mirrors src/app/(house)/notice-board/page.tsx:
/// feed (published, visibility-filtered, pinned-first) / scheduled / history
/// tabs, backed by the real notices schema (type/priority/visibility/status).
///
/// Presentation follows the Figma "Notice Board" spec (orange band + white
/// rounded sheet, pill tab switcher, sticky-note cards), page-shelled the
/// same way as the Meal tab's "Monthly Details" screen: a collapsing
/// [SliverPersistentHeader] (title fades/shrinks into the white sheet as
/// you scroll, with the "Create Notice" button and tab switcher pinned at
/// its bottom) around a [TabBarView] of independently-scrollable lists,
/// instead of a static fixed header + single ListView.
class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _Member {
  final String id;
  final String name;
  const _Member(this.id, this.name);
}

class _NoticesData {
  final Profile profile;
  final List<Notice> notices;
  final Map<String, _Member> membersById;
  const _NoticesData({
    required this.profile,
    required this.notices,
    required this.membersById,
  });
}

class _NoticesScreenState extends State<NoticesScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _noticeService = NoticeService();
  final _dashService = DashboardService();
  late Future<_NoticesData> _future;
  late TabController _tabController;
  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _activeTabIndex = _tabController.index);
      }
    });
    _future = _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A request in flight when the OS suspends the app (e.g. phone sleeps
    // overnight) has its socket killed without ever completing or erroring
    // -- the awaiting Future just hangs forever, leaving the screen stuck
    // on its loading spinner. Reloading on resume recovers from that;
    // combined with _load()'s timeout below, the screen can't get stuck
    // for longer than one foreground/background cycle.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<_NoticesData> _load() async {
    final profile = await _dashService.getCurrentProfile().timeout(
      const Duration(seconds: 15),
    );
    final notices = await _noticeService
        .getNotices(profile.cottageId)
        .timeout(const Duration(seconds: 15));
    final memberRows = await SupabaseService.client
        .from('profiles')
        .select('id, first_name, last_name')
        .eq('cottage_id', profile.cottageId)
        .eq('is_active', true)
        .timeout(const Duration(seconds: 15));
    final membersById = <String, _Member>{
      for (final r in memberRows as List)
        (r as Map<String, dynamic>)['id'] as String: _Member(
          r['id'] as String,
          ((r['last_name'] as String?)?.isNotEmpty ?? false)
              ? r['last_name'] as String
              : ((r['first_name'] as String?)?.isNotEmpty ?? false)
              ? r['first_name'] as String
              : 'Member',
        ),
    };
    return _NoticesData(
      profile: profile,
      notices: notices,
      membersById: membersById,
    );
  }

  void _refresh() => setState(() => _future = _load());

  List<Notice> _visibleTo(List<Notice> notices, Profile profile) {
    return notices
        .where(
          (n) => n.visibleTo(
            profileId: profile.id,
            isSuperAdmin: profile.isSuperAdmin,
          ),
        )
        .toList();
  }

  static const _typeGridOrder = [
    NoticeType.general,
    NoticeType.utility,
    NoticeType.meal,
    NoticeType.emergency,
    NoticeType.personal,
    NoticeType.maintenance,
  ];

  static String _formatScheduleMoment(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h24 = d.hour;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final period = h24 < 12 ? 'AM' : 'PM';
    final minute = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]}, $h12:$minute $period';
  }

  /// Figma node 97:1705 ("Create Notice" drawer): Notice Type grid,
  /// Details, Priority, Audience (with a member checklist), Schedule
  /// (Publish now/later, Expire in-7-days/custom), and Options (Pin to
  /// dashboard / Post as "Cottage"), all wired to the real
  /// [NoticeService.createNotice] -- every field here already has a
  /// matching parameter there.
  void _showAddNotice(Profile profile, Map<String, _Member> membersById) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final dueAmountCtrl = TextEditingController();
    NoticeType type = NoticeType.general;
    NoticePriority priority = NoticePriority.normal;
    NoticeVisibility visibility = NoticeVisibility.selected;
    final targetMemberIds = <String>{};
    bool publishNow = true;
    DateTime? scheduledPublishAt;
    bool expireIn7Days = true;
    DateTime? customExpiresAt;
    DateTime? dueDate;
    bool pinToDashboard = false;
    bool postAsCottage = false;

    final members = membersById.values.toList();

    showCottageSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          DateTime resolvedPublishAt() => publishNow ? DateTime.now() : (scheduledPublishAt ?? DateTime.now());
          DateTime resolvedExpiresAt() =>
              expireIn7Days ? resolvedPublishAt().add(const Duration(days: 7)) : (customExpiresAt ?? resolvedPublishAt().add(const Duration(days: 7)));

          Future<void> pickPublishDate() async {
            final now = DateTime.now();
            final date = await showDatePicker(context: sheetContext, initialDate: now, firstDate: now, lastDate: DateTime(now.year + 1));
            if (date == null || !sheetContext.mounted) return;
            final time = await showTimePicker(context: sheetContext, initialTime: TimeOfDay.fromDateTime(now));
            if (time == null) return;
            setSheetState(() => scheduledPublishAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
          }

          Future<void> pickExpireDate() async {
            final now = DateTime.now();
            final date = await showDatePicker(context: sheetContext, initialDate: now.add(const Duration(days: 7)), firstDate: now, lastDate: DateTime(now.year + 2));
            if (date == null) return;
            setSheetState(() => customExpiresAt = DateTime(date.year, date.month, date.day, 23, 59));
          }

          Future<void> pickDueDate() async {
            final now = DateTime.now();
            final date = await showDatePicker(context: sheetContext, initialDate: now, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 1));
            if (date != null) setSheetState(() => dueDate = date);
          }

          void toggleMember(String id) {
            setSheetState(() {
              if (visibility == NoticeVisibility.specific) {
                targetMemberIds
                  ..clear()
                  ..add(id);
              } else if (!targetMemberIds.remove(id)) {
                targetMemberIds.add(id);
              }
            });
          }

          return _NoticeFormDrawer(
            children: [
              const _NoticeSectionLabel('NOTICE TYPE'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in _typeGridOrder)
                    SizedBox(
                      width: (335 - 16) / 3,
                      child: _NoticeTypeOption(
                        type: t,
                        selected: type == t,
                        onTap: () => setSheetState(() => type = t),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const _NoticeSectionLabel('DETAILS'),
              const SizedBox(height: 12),
              _NoticeFieldLabel('Title'),
              const SizedBox(height: 6),
              _NoticeTextField(controller: titleCtrl, hint: 'e.g. Water supply interruption, 2-4 PM'),
              const SizedBox(height: 12),
              _NoticeFieldLabel('Description'),
              const SizedBox(height: 6),
              _NoticeTextField(controller: descCtrl, hint: 'Keep it scannable - one idea, plainly stated.', minLines: 3, maxLines: 5),
              if (type == NoticeType.utility) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _NoticeFieldLabel('Due amount (BDT)'),
                          const SizedBox(height: 6),
                          _NoticeTextField(controller: dueAmountCtrl, hint: '1450', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _NoticeFieldLabel('Due date'),
                          const SizedBox(height: 6),
                          _NoticeTapField(
                            value: dueDate == null ? 'Select date' : _formatScheduleMoment(dueDate!).split(',').first,
                            isPlaceholder: dueDate == null,
                            onTap: pickDueDate,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const _NoticeDivider(),
              const _NoticeSectionLabel('PRIORITY'),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final p in NoticePriority.values) ...[
                    if (p != NoticePriority.values.first) const SizedBox(width: 8),
                    Expanded(child: _NoticePriorityPill(priority: p, selected: priority == p, onTap: () => setSheetState(() => priority = p))),
                  ],
                ],
              ),
              const _NoticeDivider(),
              const _NoticeSectionLabel('AUDIENCE'),
              const SizedBox(height: 10),
              Row(
                children: [
                  _NoticeAudienceChip(
                    label: 'Specific member',
                    selected: visibility == NoticeVisibility.specific,
                    onTap: () => setSheetState(() {
                      visibility = NoticeVisibility.specific;
                      if (targetMemberIds.length > 1) {
                        final first = targetMemberIds.first;
                        targetMemberIds
                          ..clear()
                          ..add(first);
                      }
                    }),
                  ),
                  const SizedBox(width: 8),
                  _NoticeAudienceChip(
                    label: 'Selected members',
                    selected: visibility == NoticeVisibility.selected,
                    onTap: () => setSheetState(() => visibility = NoticeVisibility.selected),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _NoticeFormColors.border, width: 0.8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < members.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _NoticeMemberRow(
                        name: members[i].name,
                        checked: targetMemberIds.contains(members[i].id),
                        onTap: () => toggleMember(members[i].id),
                      ),
                    ],
                    if (members.isEmpty)
                      Text('No active members yet.', style: TextStyle(fontSize: 13, color: context.surface.mutedForeground)),
                  ],
                ),
              ),
              const _NoticeDivider(),
              const _NoticeSectionLabel('SCHEDULE'),
              const SizedBox(height: 12),
              Text('Publish', style: TextStyle(fontSize: 11, color: _NoticeFormColors.sectionLabel)),
              const SizedBox(height: 6),
              _NoticeSegmentedToggle(
                leftLabel: 'Now',
                rightLabel: 'Schedule for later',
                selectedLeft: publishNow,
                onChanged: (left) => setSheetState(() => publishNow = left),
              ),
              if (!publishNow) ...[
                const SizedBox(height: 8),
                _NoticeTapField(
                  value: scheduledPublishAt == null ? 'Pick date & time' : _formatScheduleMoment(scheduledPublishAt!),
                  isPlaceholder: scheduledPublishAt == null,
                  onTap: pickPublishDate,
                ),
              ],
              const SizedBox(height: 12),
              Text('Expire', style: TextStyle(fontSize: 11, color: _NoticeFormColors.sectionLabel)),
              const SizedBox(height: 6),
              _NoticeSegmentedToggle(
                leftLabel: 'In 7 days',
                rightLabel: 'Custom date',
                selectedLeft: expireIn7Days,
                onChanged: (left) => setSheetState(() => expireIn7Days = left),
              ),
              if (!expireIn7Days) ...[
                const SizedBox(height: 8),
                _NoticeTapField(
                  value: customExpiresAt == null ? 'Pick a date' : _formatScheduleMoment(customExpiresAt!).split(',').first,
                  isPlaceholder: customExpiresAt == null,
                  onTap: pickExpireDate,
                ),
              ],
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: _NoticeFormColors.fieldBg, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  publishNow
                      ? "Will publish immediately and expire ${_formatScheduleMoment(resolvedExpiresAt())} -- your device's local time."
                      : "Will publish ${_formatScheduleMoment(resolvedPublishAt())} and expire ${_formatScheduleMoment(resolvedExpiresAt())} -- your device's local time.",
                  style: TextStyle(fontSize: 11.5, height: 1.4, color: _NoticeFormColors.sectionLabel),
                ),
              ),
              const _NoticeDivider(),
              const _NoticeSectionLabel('OPTIONS'),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: _NoticeFormColors.border, width: 0.8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _NoticeOptionRow(
                      title: 'Pin to dashboard',
                      subtitle: "Shows this notice in Pinned Notices for everyone it's visible to.",
                      value: pinToDashboard,
                      onChanged: (v) => setSheetState(() => pinToDashboard = v),
                    ),
                    Container(height: 0.8, color: _NoticeFormColors.border),
                    _NoticeOptionRow(
                      title: 'Post as "Cottage"',
                      subtitle: 'Hides your name - members see it as a house announcement.',
                      value: postAsCottage,
                      onChanged: (v) => setSheetState(() => postAsCottage = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _NoticeSaveButton(
                label: 'Create Notice',
                onTap: () async {
                  if (titleCtrl.text.trim().isEmpty) {
                    showToast(sheetContext, 'Give the notice a title.');
                    return;
                  }
                  if (targetMemberIds.isEmpty) {
                    showToast(sheetContext, 'Pick at least one member.');
                    return;
                  }
                  Navigator.pop(sheetContext);
                  await _noticeService.createNotice(
                    createdBy: profile.id,
                    cottageId: profile.cottageId,
                    title: titleCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    type: type,
                    priority: priority,
                    visibility: visibility,
                    targetMemberIds: targetMemberIds.toList(),
                    isPinned: pinToDashboard,
                    pinDuration: pinToDashboard ? PinDuration.untilManual : PinDuration.none,
                    isAnonymous: postAsCottage,
                    publishAt: publishNow ? null : scheduledPublishAt,
                    expiresAt: expireIn7Days ? null : customExpiresAt,
                    dueAmount: type == NoticeType.utility ? double.tryParse(dueAmountCtrl.text) : null,
                    dueDate: type == NoticeType.utility ? dueDate : null,
                  );
                  _refresh();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // Figma node 15:695 ("Self driver requirement"): p-3.217 gap-3.217
  // rounded-10 wrapper; items px-9.651 py-6.434 rounded-8.043, and
  // "Scheduled Notices" wraps to 2 lines -- wrapped in IntrinsicHeight with
  // a stretched Row so all three tabs stay the same height regardless.
  Widget _buildTabSwitcher(CottageSurface surface) {
    return IntrinsicHeight(
      child: Container(
        padding: const EdgeInsets.all(3.217),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFEEEEEE)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildTabItem(0, 'Notice Feed')),
            const SizedBox(width: 3.217),
            Expanded(child: _buildTabItem(1, 'Scheduled Notices')),
            const SizedBox(width: 3.217),
            Expanded(child: _buildTabItem(2, 'Notice History')),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String label) {
    final active = _activeTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() {
        _activeTabIndex = index;
        _tabController.animateTo(index);
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9.651, vertical: 6.434),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? CottageColors.primary : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(8.043),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: active ? Colors.white : const Color(0xFF404040),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return FutureBuilder<_NoticesData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: CottageColors.primary,
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
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
                      'Could not load notices.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: surface.foreground),
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
        final visible = _visibleTo(data.notices, data.profile);
        final feed = sortNoticesForDisplay(
          visible.where((n) => n.status == NoticeStatus.published).toList(),
        );
        final scheduled = sortNoticesForDisplay(
          visible.where((n) => n.status == NoticeStatus.scheduled).toList(),
        );
        final history = sortNoticesForDisplay(visible);
        final pinned = feed.where((n) => n.effectivelyPinned).toList();
        final unpinned = feed.where((n) => !n.effectivelyPinned).toList();

        Widget noticeCard(Notice n, {bool showStatus = false}) {
          final creatorName = n.isAnonymous
              ? 'Cottage'
              : (data.membersById[n.createdBy]?.name ?? 'Member');
          final canManage =
              data.profile.isSuperAdmin || n.createdBy == data.profile.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: NoticeStickyNoteCard(
              notice: n,
              creatorName: creatorName,
              canManage: canManage,
              showStatusBadge: showStatus,
              onManage: (v) async {
                if (v == 'pin')
                  await _noticeService.togglePin(n.id, !n.isPinned);
                if (v == 'archive') await _noticeService.archiveNotice(n.id);
                _refresh();
              },
            ),
          );
        }

        Widget tabList(List<Widget> children) {
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                context.responsivePadding,
                20,
                context.responsivePadding,
                96,
              ),
              children: children,
            ),
          );
        }

        return Scaffold(
          backgroundColor: CottageColors.primary,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _DynamicNoticeHeaderDelegate(
                    surface: surface,
                    tabSwitcher: _buildTabSwitcher(surface),
                    onCreateNotice: () => _showAddNotice(data.profile, data.membersById),
                    safeAreaTop: MediaQuery.of(context).padding.top,
                  ),
                ),
              ];
            },
            body: Container(
              color: surface.card,
              child: TabBarView(
                controller: _tabController,
                children: [
                  tabList(
                    feed.isEmpty
                        ? const [
                            EmptyState(
                              icon: Icons.push_pin_rounded,
                              title: 'No active notices right now.',
                            ),
                          ]
                        : [
                            if (pinned.isNotEmpty) ...[
                              const _SectionLabel('Pinned'),
                              const SizedBox(height: 8),
                              for (final n in pinned) noticeCard(n),
                            ],
                            if (unpinned.isNotEmpty) ...[
                              const _SectionLabel('Recent'),
                              const SizedBox(height: 8),
                              for (final n in unpinned) noticeCard(n),
                            ],
                          ],
                  ),
                  tabList(
                    scheduled.isEmpty
                        ? const [
                            EmptyState(
                              icon: Icons.schedule_rounded,
                              title: 'Nothing scheduled.',
                            ),
                          ]
                        : [for (final n in scheduled) noticeCard(n)],
                  ),
                  tabList(
                    history.isEmpty
                        ? const [
                            EmptyState(
                              icon: Icons.history_rounded,
                              title: 'No notices yet.',
                            ),
                          ]
                        : [
                            for (final n in history)
                              noticeCard(n, showStatus: true),
                          ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.surface.mutedForeground,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// Collapsing header for the Notice Board, matching [MealScreen]'s
/// "Monthly Details" `_DynamicMealHeaderDelegate` exactly: orange band
/// with the page title fades/shrinks into the white sheet as the body
/// scrolls, with the "Create Notice" button and tab switcher pinned at
/// the header's bottom throughout.
class _DynamicNoticeHeaderDelegate extends SliverPersistentHeaderDelegate {
  final CottageSurface surface;
  final Widget tabSwitcher;
  final VoidCallback onCreateNotice;
  final double safeAreaTop;

  _DynamicNoticeHeaderDelegate({
    required this.surface,
    required this.tabSwitcher,
    required this.onCreateNotice,
    required this.safeAreaTop,
  });

  @override
  double get minExtent => safeAreaTop + 150.0;

  @override
  double get maxExtent => safeAreaTop + 234.0;

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
          height:
              safeAreaTop +
              56 -
              (shrinkOffset * 1.5).clamp(0, safeAreaTop + 56),
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
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        'Notice Board',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Colors.white,
                        ),
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
                        "The house's communication hub - independent of Meal, Utilities and Cottage Balance.",
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
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Notice Board',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: surface.foreground,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Common bottom elements (Create Notice button & tab switcher)
        Positioned(
          left: context.responsivePadding,
          right: context.responsivePadding,
          bottom: 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onCreateNotice,
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 20, color: Color(0xFF404040)),
                      const SizedBox(width: 8),
                      const Text(
                        'Create Notice',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF404040),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              tabSwitcher,
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _DynamicNoticeHeaderDelegate oldDelegate) =>
      true;
}

// --- Create Notice drawer widgets (Figma node 97:1705) --- //

class _NoticeFormColors {
  _NoticeFormColors._();
  static const sectionLabel = Color(0xFF707070);
  static const fieldBg = Color(0xFFFAFAFA);
  static const border = Color(0xFFEEEEEE);
  static const inputText = Color(0xFF2A2A2A);
  static const placeholder = Color(0xFFA3A3A3);
  static const saveButton = Color(0xFFD1593B);
}

const Map<NoticeType, Color> _noticeTypeIconBg = {
  NoticeType.general: Color(0xFFD3E9FA),
  NoticeType.utility: Color(0xFFFFEDB8),
  NoticeType.meal: Color(0xFFD8F3D0),
  NoticeType.emergency: Color(0xFFFFE1DE),
  NoticeType.personal: Color(0xFFE9DFFB),
  NoticeType.maintenance: Color(0xFFD6F5EE),
};

const Map<NoticePriority, Color> _noticePriorityBg = {
  NoticePriority.critical: Color(0xFFFFE1DE),
  NoticePriority.high: Color(0xFFFFEDB8),
  NoticePriority.normal: Color(0xFFD3E9FA),
  NoticePriority.low: Color(0xFFE7E9ED),
};

const Map<NoticePriority, Color> _noticePriorityFg = {
  NoticePriority.critical: Color(0xFFB31717),
  NoticePriority.high: Color(0xFF925C04),
  NoticePriority.normal: Color(0xFF0A6B9C),
  NoticePriority.low: Color(0xFF707070),
};

/// The sheet's outer shell: drag handle (from [showCottageSheet]) then an
/// icon+title+close header, then every field with Figma's gap-16 rhythm.
class _NoticeFormDrawer extends StatelessWidget {
  final List<Widget> children;
  const _NoticeFormDrawer({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.sticky_note_2_outlined, size: 24, color: Color(0xFF17191E)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Create Notice',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF17191E)),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: _NoticeFormColors.fieldBg, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.close, size: 16, color: Color(0xFF17191E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _NoticeSectionLabel extends StatelessWidget {
  final String text;
  const _NoticeSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _NoticeFormColors.sectionLabel, letterSpacing: 0.55),
    );
  }
}

class _NoticeFieldLabel extends StatelessWidget {
  final String text;
  const _NoticeFieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _NoticeFormColors.inputText));
  }
}

class _NoticeDivider extends StatelessWidget {
  const _NoticeDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Container(height: 0.8, color: _NoticeFormColors.border),
    );
  }
}

class _NoticeTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;

  const _NoticeTextField({
    required this.controller,
    required this.hint,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _NoticeFormColors.fieldBg,
        border: Border.all(color: _NoticeFormColors.border, width: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(fontSize: 13, color: _NoticeFormColors.inputText),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13, color: _NoticeFormColors.placeholder),
          filled: false,
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _NoticeTapField extends StatelessWidget {
  final String value;
  final bool isPlaceholder;
  final VoidCallback onTap;

  const _NoticeTapField({required this.value, this.isPlaceholder = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _NoticeFormColors.fieldBg,
          border: Border.all(color: _NoticeFormColors.border, width: 0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          value,
          style: TextStyle(fontSize: 13, color: isPlaceholder ? _NoticeFormColors.placeholder : _NoticeFormColors.inputText),
        ),
      ),
    );
  }
}

class _NoticeTypeOption extends StatelessWidget {
  final NoticeType type;
  final bool selected;
  final VoidCallback onTap;

  const _NoticeTypeOption({required this.type, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final meta = kNoticeTypeMeta[type]!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFBE9E2) : Colors.white,
          border: Border.all(color: selected ? CottageColors.primary : _NoticeFormColors.border, width: selected ? 1.5 : 0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: _noticeTypeIconBg[type], shape: BoxShape.circle),
              child: Icon(meta.icon, size: 16, color: selected ? CottageColors.primary : _NoticeFormColors.sectionLabel),
            ),
            const SizedBox(height: 6),
            Text(
              meta.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: selected ? CottageColors.primary : _NoticeFormColors.sectionLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticePriorityPill extends StatelessWidget {
  final NoticePriority priority;
  final bool selected;
  final VoidCallback onTap;

  const _NoticePriorityPill({required this.priority, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = _noticePriorityFg[priority]!;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: selected ? 1.0 : 0.55,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _noticePriorityBg[priority],
            border: selected ? Border.all(color: fg, width: 1.5) : null,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(kPriorityMeta[priority]!.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
        ),
      ),
    );
  }
}

class _NoticeAudienceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NoticeAudienceChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFBE9E2) : Colors.white,
          border: Border.all(color: selected ? CottageColors.primary : _NoticeFormColors.border, width: selected ? 1.5 : 0.8),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: selected ? CottageColors.primary : _NoticeFormColors.sectionLabel),
        ),
      ),
    );
  }
}

class _NoticeMemberRow extends StatelessWidget {
  final String name;
  final bool checked;
  final VoidCallback onTap;

  const _NoticeMemberRow({required this.name, required this.checked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: checked ? CottageColors.primary : Colors.white,
              border: Border.all(color: checked ? CottageColors.primary : _NoticeFormColors.border, width: 1.2),
              borderRadius: BorderRadius.circular(5),
            ),
            child: checked ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
          ),
          const SizedBox(width: 10),
          Text(name, style: const TextStyle(fontSize: 13, color: _NoticeFormColors.inputText)),
        ],
      ),
    );
  }
}

/// Figma's "Now"/"Schedule for later" and "In 7 days"/"Custom date"
/// switches: a pill wrapper (p-2, gap-2), selected segment is #fafafa
/// (not primary-tinted, unlike most other toggles in this app).
class _NoticeSegmentedToggle extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;
  final bool selectedLeft;
  final ValueChanged<bool> onChanged;

  const _NoticeSegmentedToggle({
    required this.leftLabel,
    required this.rightLabel,
    required this.selectedLeft,
    required this.onChanged,
  });

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _NoticeFormColors.fieldBg : Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: selected ? _NoticeFormColors.inputText : _NoticeFormColors.sectionLabel,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: _NoticeFormColors.border, width: 0.8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(leftLabel, selectedLeft, () => onChanged(true)),
          const SizedBox(width: 2),
          _segment(rightLabel, !selectedLeft, () => onChanged(false)),
        ],
      ),
    );
  }
}

class _NoticeOptionRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NoticeOptionRow({required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _NoticeFormColors.inputText)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: _NoticeFormColors.sectionLabel)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: CottageColors.primary,
            inactiveTrackColor: _NoticeFormColors.border,
            inactiveThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _NoticeSaveButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NoticeSaveButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: _NoticeFormColors.saveButton, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }
}
