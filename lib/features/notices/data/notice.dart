import 'notice_types.dart';

/// A notice-board entry. Mirrors the `notices` table / NoticeRow in
/// src/lib/data/notice-board.ts (NOTICE_COLUMNS).
class Notice {
  final String id;
  final String title;
  final String description;
  final NoticeType type;
  final NoticePriority priority;
  final NoticeVisibility visibility;
  final List<String> targetMemberIds;
  final bool isPinned;
  final PinDuration pinDuration;
  final DateTime? pinUntilDate;
  final bool isAnonymous;
  final DateTime publishAt;
  final DateTime expiresAt;
  final DateTime? archivedAt;
  final double? dueAmount;
  final DateTime? dueDate;
  final String? mealLunch;
  final String? mealDinner;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Notice({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.priority,
    required this.visibility,
    required this.targetMemberIds,
    required this.isPinned,
    required this.pinDuration,
    this.pinUntilDate,
    required this.isAnonymous,
    required this.publishAt,
    required this.expiresAt,
    this.archivedAt,
    this.dueAmount,
    this.dueDate,
    this.mealLunch,
    this.mealDinner,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Notice.fromMap(Map<String, dynamic> map) {
    DateTime? parseNullable(dynamic v) =>
        v == null ? null : DateTime.parse(v as String);
    return Notice(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      type: noticeTypeFromString(map['type'] as String? ?? 'general'),
      priority: noticePriorityFromString(
        map['priority'] as String? ?? 'normal',
      ),
      visibility: noticeVisibilityFromString(
        map['visibility'] as String? ?? 'everyone',
      ),
      targetMemberIds:
          (map['target_member_ids'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isPinned: map['is_pinned'] as bool? ?? false,
      pinDuration: pinDurationFromString(
        map['pin_duration'] as String? ?? 'none',
      ),
      pinUntilDate: parseNullable(map['pin_until_date']),
      isAnonymous: map['is_anonymous'] as bool? ?? false,
      publishAt: DateTime.parse(map['publish_at'] as String),
      expiresAt: DateTime.parse(map['expires_at'] as String),
      archivedAt: parseNullable(map['archived_at']),
      dueAmount: (map['due_amount'] as num?)?.toDouble(),
      dueDate: parseNullable(map['due_date']),
      mealLunch: map['meal_lunch'] as String?,
      mealDinner: map['meal_dinner'] as String?,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  NoticeStatus get status => computeStatus(
    archivedAt: archivedAt,
    publishAt: publishAt,
    expiresAt: expiresAt,
  );

  bool get effectivelyPinned => isEffectivelyPinned(
    isPinned: isPinned,
    pinDuration: pinDuration,
    pinUntilDate: pinUntilDate,
    publishAt: publishAt,
    expiresAt: expiresAt,
    archivedAt: archivedAt,
  );

  bool visibleTo({required String profileId, required bool isSuperAdmin}) =>
      isNoticeVisibleTo(
        visibility: visibility,
        createdBy: createdBy,
        targetMemberIds: targetMemberIds,
        profileId: profileId,
        isSuperAdmin: isSuperAdmin,
      );
}

/// Mirrors sortForDisplay: emergency first, then priority order, then
/// newest publish_at first.
List<Notice> sortNoticesForDisplay(List<Notice> notices) {
  final list = List<Notice>.of(notices);
  list.sort((a, b) {
    if (a.type == NoticeType.emergency && b.type != NoticeType.emergency)
      return -1;
    if (b.type == NoticeType.emergency && a.type != NoticeType.emergency)
      return 1;
    final p = kPriorityMeta[a.priority]!.order.compareTo(
      kPriorityMeta[b.priority]!.order,
    );
    if (p != 0) return p;
    return b.publishAt.compareTo(a.publishAt);
  });
  return list;
}
