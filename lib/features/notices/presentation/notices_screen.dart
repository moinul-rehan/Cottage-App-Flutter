import 'package:flutter/material.dart';
import '../data/notice.dart';
import '../data/notice_service.dart';
import '../data/notice_types.dart';
import 'package:cottage/models/profile.dart';
import 'package:cottage/helpers/supabase_service.dart';
import '../../dashboard/data/dashboard_service.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/common_widgets/app_scaffold.dart';
import 'package:cottage/common_widgets/cottage_bottom_sheet.dart';
import 'package:cottage/common_widgets/empty_state.dart';

/// Full notice-board screen -- mirrors src/app/(house)/notice-board/page.tsx:
/// feed (published, visibility-filtered, pinned-first) / scheduled / history
/// tabs, backed by the real notices schema (type/priority/visibility/status).
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
    return AppScaffold(
      title: 'Notice Board',
      showLogout: false,
      body: FutureBuilder<_NoticesData>(
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

          return Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        _TabChip(label: 'Feed', selected: _tab == 'feed', onTap: () => setState(() => _tab = 'feed')),
                        const SizedBox(width: 8),
                        _TabChip(label: 'Scheduled', selected: _tab == 'scheduled', onTap: () => setState(() => _tab = 'scheduled')),
                        const SizedBox(width: 8),
                        _TabChip(label: 'History', selected: _tab == 'history', onTap: () => setState(() => _tab = 'history')),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async => _refresh(),
                      child: _buildTabBody(data, feed, pinned, unpinned, scheduled, history),
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton(
                  onPressed: () => _showAddNotice(data.profile),
                  backgroundColor: CottageColors.primary,
                  foregroundColor: CottageColors.primaryForeground,
                  child: const Icon(Icons.add),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabBody(
    _NoticesData data,
    List<Notice> feed,
    List<Notice> pinned,
    List<Notice> unpinned,
    List<Notice> scheduled,
    List<Notice> history,
  ) {
    if (_tab == 'feed') {
      if (feed.isEmpty) {
        return ListView(children: const [
          EmptyState(icon: Icons.push_pin_rounded, title: 'No active notices right now.'),
        ]);
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          if (pinned.isNotEmpty) ...[
            _SectionLabel('Pinned'),
            const SizedBox(height: 8),
            for (final n in pinned) _NoticeCard(notice: n, data: data, onChanged: _refresh),
            const SizedBox(height: 16),
          ],
          if (unpinned.isNotEmpty) ...[
            _SectionLabel('Recent'),
            const SizedBox(height: 8),
            for (final n in unpinned) _NoticeCard(notice: n, data: data, onChanged: _refresh),
          ],
        ],
      );
    }
    if (_tab == 'scheduled') {
      if (scheduled.isEmpty) {
        return ListView(children: const [
          EmptyState(icon: Icons.schedule_rounded, title: 'Nothing scheduled.'),
        ]);
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [for (final n in scheduled) _NoticeCard(notice: n, data: data, onChanged: _refresh)],
      );
    }
    // history
    if (history.isEmpty) {
      return ListView(children: const [
        EmptyState(icon: Icons.history_rounded, title: 'No notices yet.'),
      ]);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      children: [for (final n in history) _NoticeCard(notice: n, data: data, onChanged: _refresh, showStatus: true)],
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? surface.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? surface.accentForeground : surface.mutedForeground,
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

class _NoticeCard extends StatelessWidget {
  final Notice notice;
  final _NoticesData data;
  final VoidCallback onChanged;
  final bool showStatus;

  const _NoticeCard({required this.notice, required this.data, required this.onChanged, this.showStatus = false});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  bool get _canManage => data.profile.isSuperAdmin || notice.createdBy == data.profile.id;

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final meta = kNoticeTypeMeta[notice.type]!;
    final priorityMeta = kPriorityMeta[notice.priority]!;
    final creatorName = notice.isAnonymous ? 'Cottage' : (data.membersById[notice.createdBy]?.name ?? 'Member');
    final service = NoticeService();
    const dot = '·';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: surface.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notice.type == NoticeType.emergency ? priorityMeta.pinColor : surface.border,
            width: notice.type == NoticeType.emergency ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(meta.icon, size: 16, color: meta.chipFg),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: meta.chipBg, borderRadius: BorderRadius.circular(20)),
                  child: Text(meta.label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: meta.chipFg)),
                ),
                const Spacer(),
                if (notice.effectivelyPinned) Icon(Icons.push_pin, size: 16, color: priorityMeta.pinColor),
                if (_canManage)
                  PopupMenuButton<String>(
                    iconSize: 18,
                    onSelected: (v) async {
                      if (v == 'pin') await service.togglePin(notice.id, !notice.isPinned);
                      if (v == 'archive') await service.archiveNotice(notice.id);
                      onChanged();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'pin', child: Text(notice.isPinned ? 'Unpin' : 'Pin')),
                      const PopupMenuItem(value: 'archive', child: Text('Archive', style: TextStyle(color: CottageColors.destructive))),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(notice.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: surface.foreground)),
            if (notice.type == NoticeType.utility && notice.dueAmount != null) ...[
              const SizedBox(height: 4),
              Text('${notice.dueAmount!.toStringAsFixed(2)} BDT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: surface.foreground)),
              if (notice.description.isNotEmpty) Text(notice.description, style: TextStyle(fontSize: 13, color: surface.mutedForeground)),
            ] else if (notice.type == NoticeType.meal && (notice.mealLunch != null || notice.mealDinner != null)) ...[
              const SizedBox(height: 4),
              if (notice.mealLunch != null) Text('Lunch - ${notice.mealLunch}', style: TextStyle(fontSize: 13, color: surface.mutedForeground)),
              if (notice.mealDinner != null) Text('Dinner - ${notice.mealDinner}', style: TextStyle(fontSize: 13, color: surface.mutedForeground)),
            ] else if (notice.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(notice.description, style: TextStyle(fontSize: 13, color: surface.mutedForeground)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: priorityMeta.pillBg, borderRadius: BorderRadius.circular(20)),
                  child: Text(priorityMeta.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: priorityMeta.pillFg)),
                ),
                Text('$creatorName $dot ${_timeAgo(notice.publishAt)}', style: TextStyle(fontSize: 11, color: surface.mutedForeground)),
                if (notice.visibility != NoticeVisibility.everyone)
                  Text('$dot ${kVisibilityLabel[notice.visibility]}', style: TextStyle(fontSize: 11, color: surface.mutedForeground)),
                if (showStatus || notice.status != NoticeStatus.published)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: surface.muted, borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      notice.status.name,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: surface.mutedForeground),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
