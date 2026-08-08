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

  void _showAddNotice(Profile profile) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    NoticeType type = NoticeType.general;
    NoticePriority priority = NoticePriority.normal;
    NoticeVisibility visibility = NoticeVisibility.everyone;

    showCottageSheet(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => CottageSheetContent(
          title: 'New Notice',
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<NoticeType>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [
                for (final t in NoticeType.values)
                  DropdownMenuItem(
                    value: t,
                    child: Text(kNoticeTypeMeta[t]!.label),
                  ),
              ],
              onChanged: (v) => setSheetState(() => type = v ?? type),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<NoticePriority>(
              initialValue: priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: [
                for (final p in NoticePriority.values)
                  DropdownMenuItem(
                    value: p,
                    child: Text(kPriorityMeta[p]!.label),
                  ),
              ],
              onChanged: (v) => setSheetState(() => priority = v ?? priority),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<NoticeVisibility>(
              initialValue: visibility,
              decoration: const InputDecoration(labelText: 'Visible to'),
              items: [
                for (final v in [
                  NoticeVisibility.everyone,
                  NoticeVisibility.admins,
                ])
                  DropdownMenuItem(value: v, child: Text(kVisibilityLabel[v]!)),
              ],
              onChanged: (v) =>
                  setSheetState(() => visibility = v ?? visibility),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.pop(sheetContext);
                await _noticeService.createNotice(
                  createdBy: profile.id,
                  cottageId: profile.cottageId,
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  type: type,
                  priority: priority,
                  visibility: visibility,
                );
                _refresh();
              },
              child: const Text('Post Notice'),
            ),
          ],
        ),
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
                    onCreateNotice: () => _showAddNotice(data.profile),
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
