import 'package:flutter/material.dart';

/// Port of src/lib/notice-types.tsx -- notice type/priority/visibility
/// metadata and the status/pin/visibility computation helpers.

enum NoticeType { utility, meal, general, emergency, personal, maintenance }

enum NoticePriority { critical, high, normal, low }

enum NoticeVisibility { everyone, specific, selected, admins }

enum PinDuration { none, untilManual, oneDay, threeDay, untilDate, untilExpires }

enum NoticeStatus { scheduled, published, expired, archived }

NoticeType noticeTypeFromString(String s) => NoticeType.values.firstWhere(
      (t) => t.name == s,
      orElse: () => NoticeType.general,
    );

NoticePriority noticePriorityFromString(String s) => NoticePriority.values.firstWhere(
      (p) => p.name == s,
      orElse: () => NoticePriority.normal,
    );

NoticeVisibility noticeVisibilityFromString(String s) => NoticeVisibility.values.firstWhere(
      (v) => v.name == s,
      orElse: () => NoticeVisibility.everyone,
    );

PinDuration pinDurationFromString(String s) {
  switch (s) {
    case 'until_manual':
      return PinDuration.untilManual;
    case '1d':
      return PinDuration.oneDay;
    case '3d':
      return PinDuration.threeDay;
    case 'until_date':
      return PinDuration.untilDate;
    case 'until_expires':
      return PinDuration.untilExpires;
    default:
      return PinDuration.none;
  }
}

class NoticeTypeMeta {
  final String label;
  final IconData icon;
  final Color chipBg;
  final Color chipFg;
  const NoticeTypeMeta({required this.label, required this.icon, required this.chipBg, required this.chipFg});
}

const Map<NoticeType, NoticeTypeMeta> kNoticeTypeMeta = {
  NoticeType.utility: NoticeTypeMeta(
    label: 'Utility Reminder',
    icon: Icons.account_balance_wallet_outlined,
    chipBg: Color(0xFFFEF3C7),
    chipFg: Color(0xFF92400E),
  ),
  NoticeType.meal: NoticeTypeMeta(
    label: 'Meal Plan',
    icon: Icons.restaurant_outlined,
    chipBg: Color(0xFFD1FAE5),
    chipFg: Color(0xFF065F46),
  ),
  NoticeType.general: NoticeTypeMeta(
    label: 'General Notice',
    icon: Icons.campaign_outlined,
    chipBg: Color(0xFFE0F2FE),
    chipFg: Color(0xFF075985),
  ),
  NoticeType.emergency: NoticeTypeMeta(
    label: 'Emergency',
    icon: Icons.warning_amber_rounded,
    chipBg: Color(0xFFFEE2E2),
    chipFg: Color(0xFF991B1B),
  ),
  NoticeType.personal: NoticeTypeMeta(
    label: 'Personal Reminder',
    icon: Icons.sticky_note_2_outlined,
    chipBg: Color(0xFFEDE9FE),
    chipFg: Color(0xFF5B21B6),
  ),
  NoticeType.maintenance: NoticeTypeMeta(
    label: 'Maintenance',
    icon: Icons.build_outlined,
    chipBg: Color(0xFFCCFBF1),
    chipFg: Color(0xFF115E59),
  ),
};

class NoticePriorityMeta {
  final String label;
  final int order;
  final Color pillBg;
  final Color pillFg;
  final Color pinColor;
  const NoticePriorityMeta({required this.label, required this.order, required this.pillBg, required this.pillFg, required this.pinColor});
}

const Map<NoticePriority, NoticePriorityMeta> kPriorityMeta = {
  NoticePriority.critical: NoticePriorityMeta(label: 'Critical', order: 0, pillBg: Color(0xFFFEE2E2), pillFg: Color(0xFFB91C1C), pinColor: Color(0xFFDC2626)),
  NoticePriority.high: NoticePriorityMeta(label: 'High', order: 1, pillBg: Color(0xFFFEF3C7), pillFg: Color(0xFFB45309), pinColor: Color(0xFFF59E0B)),
  NoticePriority.normal: NoticePriorityMeta(label: 'Normal', order: 2, pillBg: Color(0xFFE0F2FE), pillFg: Color(0xFF0369A1), pinColor: Color(0xFF0EA5E9)),
  NoticePriority.low: NoticePriorityMeta(label: 'Low', order: 3, pillBg: Color(0xFFF1F5F9), pillFg: Color(0xFF64748B), pinColor: Color(0xFF94A3B8)),
};

const Map<NoticeVisibility, String> kVisibilityLabel = {
  NoticeVisibility.everyone: 'Everyone',
  NoticeVisibility.specific: 'Specific member',
  NoticeVisibility.selected: 'Selected members',
  NoticeVisibility.admins: 'Admins only',
};

/// Deterministic -3..3deg tilt per notice id -- mirrors noticeTilt in
/// src/lib/notice-types.tsx.
double noticeTilt(String id) {
  int h = 0;
  for (final code in id.codeUnits) {
    h = (h * 31 + code) & 0x7fffffff;
  }
  return (h % 7) - 3;
}

DateTime? computePinEndAt({
  required PinDuration pinDuration,
  required DateTime? pinUntilDate,
  required DateTime publishAt,
  required DateTime expiresAt,
}) {
  switch (pinDuration) {
    case PinDuration.untilManual:
      return null;
    case PinDuration.oneDay:
      return publishAt.add(const Duration(hours: 24));
    case PinDuration.threeDay:
      return publishAt.add(const Duration(days: 3));
    case PinDuration.untilDate:
      return pinUntilDate;
    case PinDuration.untilExpires:
      return expiresAt;
    case PinDuration.none:
      return null;
  }
}

NoticeStatus computeStatus({
  required DateTime? archivedAt,
  required DateTime publishAt,
  required DateTime expiresAt,
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  if (archivedAt != null) return NoticeStatus.archived;
  if (n.isBefore(publishAt)) return NoticeStatus.scheduled;
  if (n.isAfter(expiresAt)) return NoticeStatus.expired;
  return NoticeStatus.published;
}

/// Effectively pinned right now -- accounts for pin duration lapsing without
/// a write-back. Mirrors isEffectivelyPinned.
bool isEffectivelyPinned({
  required bool isPinned,
  required PinDuration pinDuration,
  required DateTime? pinUntilDate,
  required DateTime publishAt,
  required DateTime expiresAt,
  required DateTime? archivedAt,
  DateTime? now,
}) {
  if (!isPinned || archivedAt != null) return false;
  final end = computePinEndAt(pinDuration: pinDuration, pinUntilDate: pinUntilDate, publishAt: publishAt, expiresAt: expiresAt);
  final n = now ?? DateTime.now();
  return end == null || !n.isAfter(end);
}

/// Mirrors isVisibleTo -- super_admins see everything, creators see their
/// own, "everyone" is visible to all, "admins" only to super_admins, and
/// "specific"/"selected" only to those in target_member_ids.
bool isNoticeVisibleTo({
  required NoticeVisibility visibility,
  required String createdBy,
  required List<String> targetMemberIds,
  required String profileId,
  required bool isSuperAdmin,
}) {
  if (isSuperAdmin) return true;
  if (createdBy == profileId) return true;
  if (visibility == NoticeVisibility.everyone) return true;
  if (visibility == NoticeVisibility.admins) return false;
  return targetMemberIds.contains(profileId);
}
