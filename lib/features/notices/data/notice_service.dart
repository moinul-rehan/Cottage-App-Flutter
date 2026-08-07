import 'notice.dart';
import 'notice_types.dart';
import 'package:cottage/helpers/supabase_service.dart';

const _noticeColumns =
    'id, title, description, type, priority, visibility, target_member_ids, is_pinned, pin_duration, pin_until_date, is_anonymous, publish_at, expires_at, archived_at, due_amount, due_date, meal_lunch, meal_dinner, created_by, created_at, updated_at';

/// CRUD + read operations for the notice board. Mirrors
/// src/lib/data/notice-board.ts (getNotices) and
/// src/app/(house)/notice-board/actions.ts (createNotice, dismissNotice,
/// pin/archive actions from NoticeCardActions.tsx).
class NoticeService {
  final _client = SupabaseService.client;

  /// Every notice in the cottage (RLS scopes by visibility) -- callers
  /// filter by status/pin/visibility themselves, same as the web's
  /// getNotices.
  Future<List<Notice>> getNotices(String cottageId) async {
    final rows = await _client
        .from('notices')
        .select(_noticeColumns)
        .eq('cottage_id', cottageId)
        .order('created_at', ascending: false);

    return (rows as List).map((r) => Notice.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Create a new notice. A pared-down port of createNotice in
  /// notice-board/actions.ts -- publish_at defaults to now, expires_at
  /// defaults to 7 days out, matching the web's fallback.
  Future<void> createNotice({
    required String createdBy,
    required String cottageId,
    required String title,
    required String description,
    required NoticeType type,
    required NoticePriority priority,
    required NoticeVisibility visibility,
    List<String> targetMemberIds = const [],
    bool isPinned = false,
    PinDuration pinDuration = PinDuration.none,
    DateTime? pinUntilDate,
    bool isAnonymous = false,
    DateTime? publishAt,
    DateTime? expiresAt,
    double? dueAmount,
    DateTime? dueDate,
    String? mealLunch,
    String? mealDinner,
  }) async {
    final resolvedPublishAt = publishAt ?? DateTime.now();
    final resolvedExpiresAt = expiresAt ?? resolvedPublishAt.add(const Duration(days: 7));

    await _client.from('notices').insert({
      'cottage_id': cottageId,
      'created_by': createdBy,
      'title': title,
      'description': description,
      'type': type.name,
      'priority': priority.name,
      'visibility': visibility.name,
      'target_member_ids': targetMemberIds,
      'is_pinned': isPinned,
      'pin_duration': isPinned ? _pinDurationToString(pinDuration) : 'none',
      'pin_until_date': pinUntilDate?.toIso8601String().substring(0, 10),
      'is_anonymous': isAnonymous,
      'publish_at': resolvedPublishAt.toIso8601String(),
      'expires_at': resolvedExpiresAt.toIso8601String(),
      'due_amount': dueAmount,
      'due_date': dueDate?.toIso8601String().substring(0, 10),
      'meal_lunch': mealLunch,
      'meal_dinner': mealDinner,
    });
  }

  String _pinDurationToString(PinDuration d) {
    switch (d) {
      case PinDuration.untilManual:
        return 'until_manual';
      case PinDuration.oneDay:
        return '1d';
      case PinDuration.threeDay:
        return '3d';
      case PinDuration.untilDate:
        return 'until_date';
      case PinDuration.untilExpires:
        return 'until_expires';
      case PinDuration.none:
        return 'none';
    }
  }

  /// Archives a notice (soft delete) -- mirrors the archive action in
  /// NoticeCardActions.tsx.
  Future<void> archiveNotice(String noticeId) async {
    await _client.from('notices').update({'archived_at': DateTime.now().toIso8601String()}).eq('id', noticeId);
  }

  Future<void> togglePin(String noticeId, bool pinned) async {
    await _client.from('notices').update({
      'is_pinned': pinned,
      'pin_duration': pinned ? 'until_manual' : 'none',
    }).eq('id', noticeId);
  }

  /// Marks the dashboard popup for this notice as seen by the current
  /// member -- mirrors dismissNotice in notice-board/actions.ts.
  Future<void> dismissNotice(String noticeId, String userId) async {
    await _client.from('notice_dismissals').upsert(
      {'notice_id': noticeId, 'user_id': userId},
      onConflict: 'notice_id,user_id',
    );
  }

  /// Ids of notices already dismissed by this member -- used to filter the
  /// dashboard popup queue.
  Future<Set<String>> getDismissedNoticeIds(String userId) async {
    final rows = await _client.from('notice_dismissals').select('notice_id').eq('user_id', userId);
    return (rows as List).map((r) => (r as Map<String, dynamic>)['notice_id'] as String).toSet();
  }
}
