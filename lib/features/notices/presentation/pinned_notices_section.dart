import 'package:flutter/material.dart';
import '../data/notice.dart';
import '../data/notice_service.dart';
import '../data/notice_types.dart';
import 'package:cottage/models/profile.dart';
import 'package:cottage/constants/theme.dart';
import 'notices_screen.dart';

/// Pinned-notices strip for the Dashboard -- mirrors the placement of
/// pinned notices near the top of src/app/(house)/dashboard/page.tsx
/// (above the Utility/Bazaar overview). Shows nothing if there are no
/// effectively-pinned, visible, published notices.
class PinnedNoticesSection extends StatefulWidget {
  final Profile profile;

  const PinnedNoticesSection({super.key, required this.profile});

  @override
  State<PinnedNoticesSection> createState() => _PinnedNoticesSectionState();
}

class _PinnedNoticesSectionState extends State<PinnedNoticesSection> {
  final _service = NoticeService();
  late Future<List<Notice>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Notice>> _load() async {
    final notices = await _service.getNotices(widget.profile.cottageId);
    final visible = notices.where(
      (n) => n.visibleTo(
        profileId: widget.profile.id,
        isSuperAdmin: widget.profile.isSuperAdmin,
      ),
    );
    final pinned = visible
        .where((n) => n.status == NoticeStatus.published && n.effectivelyPinned)
        .toList();
    return sortNoticesForDisplay(pinned);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Notice>>(
      future: _future,
      builder: (context, snapshot) {
        final notices = snapshot.data ?? const [];
        if (notices.isEmpty) return const SizedBox.shrink();
        final surface = context.surface;

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.push_pin_rounded,
                    size: 15,
                    color: surface.mutedForeground,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Pinned Notices',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: surface.mutedForeground,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NoticesScreen()),
                    ),
                    child: Text(
                      'See all',
                      style: TextStyle(
                        fontSize: 12,
                        color: CottageColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: notices.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) =>
                      _PinnedNoticeChip(notice: notices[index]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PinnedNoticeChip extends StatelessWidget {
  final Notice notice;
  const _PinnedNoticeChip({required this.notice});

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final meta = kNoticeTypeMeta[notice.type]!;
    final priorityMeta = kPriorityMeta[notice.priority]!;

    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const NoticesScreen())),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: meta.chipBg.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: priorityMeta.pinColor.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(meta.icon, size: 14, color: meta.chipFg),
                const SizedBox(width: 5),
                Text(
                  meta.label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: meta.chipFg,
                  ),
                ),
                const Spacer(),
                Icon(Icons.push_pin, size: 12, color: priorityMeta.pinColor),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              notice.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: surface.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
