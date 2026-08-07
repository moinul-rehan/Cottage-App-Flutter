import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cottage/models/profile.dart';
import 'package:cottage/constants/theme.dart';
import '../../notices/data/notice.dart';
import '../../notices/data/notice_service.dart';
import '../../notices/data/notice_types.dart';
import '../../notices/presentation/notices_screen.dart';

/// "Pin Notice" section: a sticky-note-styled card for the single top
/// pinned notice, styled after the Rento Figma kit's mobile home screen.
///
/// Reuses the exact same data flow as
/// lib/features/notices/presentation/pinned_notices_section.dart (same
/// `NoticeService`, same `visibleTo`/`effectivelyPinned`/`sortForDisplay`
/// filtering from lib/features/notices/data/notice_types.dart) rather than
/// re-fetching separately -- this widget only differs in how it renders the
/// single highest-priority result.
class PinNoticeCard extends StatefulWidget {
  final Profile profile;
  const PinNoticeCard({super.key, required this.profile});

  @override
  State<PinNoticeCard> createState() => _PinNoticeCardState();
}

class _PinNoticeCardState extends State<PinNoticeCard> {
  final _service = NoticeService();
  late Future<Notice?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Notice?> _load() async {
    final notices = await _service.getNotices(widget.profile.cottageId);
    final visible = notices.where(
      (n) => n.visibleTo(profileId: widget.profile.id, isSuperAdmin: widget.profile.isSuperAdmin),
    );
    final pinned = visible.where((n) => n.status == NoticeStatus.published && n.effectivelyPinned).toList();
    final sorted = sortNoticesForDisplay(pinned);
    return sorted.isEmpty ? null : sorted.first;
  }

  void _openNotices() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NoticesScreen()));

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('📌', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text('Pin Notice', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: surface.foreground)),
          ],
        ),
        const SizedBox(height: 14),
        FutureBuilder<Notice?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(height: 140, child: Center(child: CircularProgressIndicator()));
            }
            final notice = snapshot.data;
            if (notice == null) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surface.muted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: surface.border),
                ),
                child: Center(
                  child: Text('No pinned notices right now.', style: TextStyle(color: surface.mutedForeground, fontSize: 13)),
                ),
              );
            }
            return _StickyNote(notice: notice, onTap: _openNotices);
          },
        ),
      ],
    );
  }
}

class _StickyNote extends StatelessWidget {
  final Notice notice;
  final VoidCallback onTap;

  const _StickyNote({required this.notice, required this.onTap});

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final meta = kNoticeTypeMeta[notice.type]!;
    final priorityMeta = kPriorityMeta[notice.priority]!;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFFFBDEE),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Darker pink header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF9A8DF),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.campaign_outlined, size: 20, color: Color(0xFF1E1E1E)),
                    const SizedBox(width: 8),
                    Text(
                      meta.label,
                      style: GoogleFonts.lobster(
                        fontSize: 18,
                        color: const Color(0xFF1E1E1E),
                      ),
                    ),
                  ],
                ),
              ),
              // Main card body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notice.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lobster(
                        fontSize: 18,
                        color: const Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      notice.description.isNotEmpty ? notice.description : 'Write your Notice here',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF1E1E1E)),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '${priorityMeta.label} · Cottage · published ${_fmt(notice.publishAt)}\nExpires ${_fmt(notice.expiresAt)}',
                      style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xBF1E1E1E)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
