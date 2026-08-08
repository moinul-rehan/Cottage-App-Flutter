import 'package:flutter/material.dart';
import 'package:cottage/constants/theme.dart';
import '../data/notice.dart';
import '../data/notice_types.dart';

/// Full-board sticky-note notice card -- the Figma "Notice Board" spec
/// renders every notice as a torn-paper sticky note (megaphone + script-font
/// title), one shade per [NoticeType] rather than the single pink used by
/// the Dashboard's [PinNoticeCard] (which stays pink deliberately, to read
/// as "the one pinned/important note" regardless of type). Colors are
/// derived from the existing [kNoticeTypeMeta] chip palette (a slightly
/// darker header over the chip's light body tone) instead of hardcoding
/// Figma's demo colors, so it stays consistent with the chips/pills already
/// used for type elsewhere on this screen. Deterministic per-notice tilt
/// via [noticeTilt] mirrors the web app's sticky-note board.
class NoticeStickyNoteCard extends StatelessWidget {
  final Notice notice;
  final String creatorName;
  final VoidCallback? onTap;
  final bool tilted;
  final bool canManage;
  final bool showStatusBadge;
  final ValueChanged<String>? onManage;

  const NoticeStickyNoteCard({
    super.key,
    required this.notice,
    required this.creatorName,
    this.onTap,
    this.tilted = true,
    this.canManage = false,
    this.showStatusBadge = false,
    this.onManage,
  });

  static String _fmt(DateTime d) {
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
    final h24 = d.hour;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final period = h24 < 12 ? 'am' : 'pm';
    final minute = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year}, $h12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final meta = kNoticeTypeMeta[notice.type]!;
    final priorityMeta = kPriorityMeta[notice.priority]!;
    final bodyColor = meta.chipBg;
    final headerColor = Color.alphaBlend(
      Colors.black.withValues(alpha: 0.06),
      meta.chipBg,
    );
    final angle = tilted ? noticeTilt(notice.id) * 3.14159265 / 180 : 0.0;

    Widget bodyContent() {
      if (notice.type == NoticeType.utility && notice.dueAmount != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${notice.dueAmount!.toStringAsFixed(2)} BDT',
              style: TextStyle(fontFamily: 'Lobster', fontSize: 17, color: meta.chipFg),
            ),
            if (notice.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                notice.description,
                style: const TextStyle(fontSize: 13, color: Color(0xFF1E1E1E)),
              ),
            ],
          ],
        );
      }
      if (notice.type == NoticeType.meal &&
          (notice.mealLunch != null || notice.mealDinner != null)) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notice.mealLunch != null)
              Text(
                'Lunch - ${notice.mealLunch}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF1E1E1E)),
              ),
            if (notice.mealDinner != null)
              Text(
                'Dinner - ${notice.mealDinner}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF1E1E1E)),
              ),
          ],
        );
      }
      return Text(
        notice.description.isNotEmpty ? notice.description : ' ',
        style: const TextStyle(fontSize: 13, color: Color(0xFF1E1E1E)),
      );
    }

    return Transform.rotate(
      angle: angle,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: bodyColor,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: headerColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.campaign_outlined, size: 18, color: meta.chipFg),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        meta.label,
                        style: TextStyle(
                          fontFamily: 'Lobster',
                          fontSize: 15,
                          color: meta.chipFg,
                        ),
                      ),
                    ),
                    if (notice.effectivelyPinned)
                      Icon(
                        Icons.push_pin,
                        size: 15,
                        color: priorityMeta.pinColor,
                      ),
                    if (showStatusBadge ||
                        notice.status != NoticeStatus.published) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          notice.status.name,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: meta.chipFg,
                          ),
                        ),
                      ),
                    ],
                    if (canManage)
                      PopupMenuButton<String>(
                        iconSize: 18,
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.more_vert,
                          size: 18,
                          color: meta.chipFg,
                        ),
                        onSelected: onManage,
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'pin',
                            child: Text(notice.isPinned ? 'Unpin' : 'Pin'),
                          ),
                          const PopupMenuItem(
                            value: 'archive',
                            child: Text(
                              'Archive',
                              style: TextStyle(
                                color: CottageColors.destructive,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notice.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Lobster',
                        fontSize: 17,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 10),
                    bodyContent(),
                    const SizedBox(height: 20),
                    Text(
                      '${priorityMeta.label} · $creatorName · published ${_fmt(notice.publishAt)}\nExpires ${_fmt(notice.expiresAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Color(0xBF1E1E1E),
                      ),
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
