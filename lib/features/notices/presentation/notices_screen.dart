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
import 'package:cottage/features/notifications/presentation/notification_bell.dart';
import 'notice_sticky_note.dart';

/// Full notice-board screen -- mirrors src/app/(house)/notice-board/page.tsx:
/// feed (published, visibility-filtered, pinned-first) / scheduled / history
/// tabs, backed by the real notices schema (type/priority/visibility/status).
///
/// Presentation follows the Figma "Notice Board" spec (orange band + white
/// rounded sheet, pill tab switcher, sticky-note cards), page-shelled the
/// same way as the Meal tab's "Monthly Details" header (orange band with
/// title, white content sheet below) instead of the default [AppScaffold]
/// bar, since this tab -- like Dashboard and Meal -- owns its header.
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
  const _NoticesData({required this.profile, required this.notices, required this.membersById});
}

class _NoticesScreenState extends State<NoticesScreen> {
  final _noticeService = NoticeService();
  final _dashService = DashboardService();
  late Future<_NoticesData> _future;
  String _tab = 'feed';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_NoticesData> _load() async {
    final profile = await _dashService.getCurrentProfile();
    final notices = await _noticeService.getNotices(profile.cottageId);
    final memberRows = await SupabaseService.client
        .from('profiles')
        .select('id, first_name, last_name')
        .eq('cottage_id', profile.cottageId)
        .eq('is_active', true);
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
    return _NoticesData(profile: profile, notices: notices, membersById: membersById);
  }

  void _refresh() => setState(() => _future = _load());

  List<Notice> _visibleTo(List<Notice> notices, Profile profile) {
    return notices
        .where((n) => n.visibleTo(profileId: profile.id, isSuperAdmin: profile.isSuperAdmin))
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
                  DropdownMenuItem(value: t, child: Text(kNoticeTypeMeta[t]!.label)),
              ],
              onChanged: (v) => setSheetState(() => type = v ?? type),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<NoticePriority>(
              initialValue: priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: [
                for (final p in NoticePriority.values)
                  DropdownMenuItem(value: p, child: Text(kPriorityMeta[p]!.label)),
              ],
              onChanged: (v) => setSheetState(() => priority = v ?? priority),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<NoticeVisibility>(
              initialValue: visibility,
              decoration: const InputDecoration(labelText: 'Visible to'),
              items: [
                for (final v in [NoticeVisibility.everyone, NoticeVisibility.admins])
                  DropdownMenuItem(value: v, child: Text(kVisibilityLabel[v]!)),
              ],
              onChanged: (v) => setSheetState(() => visibility = v ?? visibility),
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
              padding: EdgeInsets.fromLTRB(context.responsivePadding, 8, context.responsivePadding, 16),
              child: Row(
                children: [
                  const Text(
                    'Notice Board',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white),
                  ),
                  const Spacer(),
                  Theme(
                    data: Theme.of(context).copyWith(iconTheme: const IconThemeData(color: Colors.white)),
                    child: const NotificationBell(bareIcon: true),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: surface.card,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                ),
                child: FutureBuilder<_NoticesData>(
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
                            const Icon(Icons.error_outline, size: 40, color: CottageColors.destructive),
                            const SizedBox(height: 12),
                            Text('Could not load notices.\n${snapshot.error}', textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: _refresh, child: const Text('Retry')),
                          ],
                        ),
                      );
                    }

                    final data = snapshot.data!;
                    final visible = _visibleTo(data.notices, data.profile);
                    final feed = sortNoticesForDisplay(visible.where((n) => n.status == NoticeStatus.published).toList());
                    final scheduled = sortNoticesForDisplay(visible.where((n) => n.status == NoticeStatus.scheduled).toList());
                    final history = sortNoticesForDisplay(visible);

                    final pinned = feed.where((n) => n.effectivelyPinned).toList();
                    final unpinned = feed.where((n) => !n.effectivelyPinned).toList();

                    return RefreshIndicator(
                      onRefresh: () async => _refresh(),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(context.responsivePadding, 20, context.responsivePadding, 96),
                        children: [
                          const Text(
                            "The house's communication hub - independent of Meal, Utilities and Cottage Balance.",
                            style: TextStyle(fontSize: 14, color: Color(0xFF303030)),
                          ),
                          const SizedBox(height: 16),
                          _CreateNoticeButton(onTap: () => _showAddNotice(data.profile)),
                          const SizedBox(height: 16),
                          _NoticeTabSwitcher(tab: _tab, onChanged: (t) => setState(() => _tab = t)),
                          const SizedBox(height: 16),
                          ..._buildTabBody(data, feed, pinned, unpinned, scheduled, history),
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

  List<Widget> _buildTabBody(
    _NoticesData data,
    List<Notice> feed,
    List<Notice> pinned,
    List<Notice> unpinned,
    List<Notice> scheduled,
    List<Notice> history,
  ) {
    Widget noticeCard(Notice n, {bool showStatus = false}) {
      final creatorName = n.isAnonymous ? 'Cottage' : (data.membersById[n.createdBy]?.name ?? 'Member');
      final canManage = data.profile.isSuperAdmin || n.createdBy == data.profile.id;
      final service = NoticeService();
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: NoticeStickyNoteCard(
          notice: n,
          creatorName: creatorName,
          canManage: canManage,
          showStatusBadge: showStatus,
          onManage: (v) async {
            if (v == 'pin') await service.togglePin(n.id, !n.isPinned);
            if (v == 'archive') await service.archiveNotice(n.id);
            _refresh();
          },
        ),
      );
    }

    if (_tab == 'feed') {
      if (feed.isEmpty) {
        return const [EmptyState(icon: Icons.push_pin_rounded, title: 'No active notices right now.')];
      }
      return [
        if (pinned.isNotEmpty) ...[
          _SectionLabel('Pinned'),
          const SizedBox(height: 8),
          for (final n in pinned) noticeCard(n),
        ],
        if (unpinned.isNotEmpty) ...[
          _SectionLabel('Recent'),
          const SizedBox(height: 8),
          for (final n in unpinned) noticeCard(n),
        ],
      ];
    }
    if (_tab == 'scheduled') {
      if (scheduled.isEmpty) {
        return const [EmptyState(icon: Icons.schedule_rounded, title: 'Nothing scheduled.')];
      }
      return [for (final n in scheduled) noticeCard(n)];
    }
    // history
    if (history.isEmpty) {
      return const [EmptyState(icon: Icons.history_rounded, title: 'No notices yet.')];
    }
    return [for (final n in history) noticeCard(n, showStatus: true)];
  }
}

class _CreateNoticeButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateNoticeButton({required this.onTap});

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
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 1, offset: const Offset(0, 1))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 20, color: Color(0xFF404040)),
            const SizedBox(width: 8),
            const Text('Create Notice', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF404040))),
          ],
        ),
      ),
    );
  }
}

class _NoticeTabSwitcher extends StatelessWidget {
  final String tab;
  final ValueChanged<String> onChanged;
  const _NoticeTabSwitcher({required this.tab, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEEEEEE)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _NoticeTab(label: 'Notice Feed', selected: tab == 'feed', onTap: () => onChanged('feed'))),
          const SizedBox(width: 4),
          Expanded(child: _NoticeTab(label: 'Scheduled Notices', selected: tab == 'scheduled', onTap: () => onChanged('scheduled'))),
          const SizedBox(width: 4),
          Expanded(child: _NoticeTab(label: 'Notice History', selected: tab == 'history', onTap: () => onChanged('history'))),
        ],
      ),
    );
  }
}

class _NoticeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NoticeTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? CottageColors.primary : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF404040),
          ),
        ),
      ),
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

