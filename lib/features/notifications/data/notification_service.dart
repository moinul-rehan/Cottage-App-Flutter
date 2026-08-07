import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification.dart';
import 'package:cottage/helpers/supabase_service.dart';
import 'package:cottage/helpers/month_helper.dart';

/// Ports getUnreadCount/getNotifications from src/lib/data/notifications.ts,
/// including the `since` month-scoping (only notifications from the current
/// active month onward -- see getActiveMonthStartedAt).
class NotificationService {
  final SupabaseClient _client = SupabaseService.client;

  /// Resolves the caller's cottage id, then `since` via
  /// getActiveMonthStartedAt -- both the bell badge and the full list need
  /// this pair, so callers fetch it once and pass it to the two calls below.
  Future<String?> resolveSince(String cottageId) => getActiveMonthStartedAt(_client, cottageId);

  Future<int> getUnreadCount(String userId, String? since) async {
    var query = _client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);
    if (since != null) query = query.gte('created_at', since);
    final rows = await query;
    return (rows as List).length;
  }

  Future<List<AppNotification>> getNotifications(String userId, String? since, {int limit = 30}) async {
    var query = _client
        .from('notifications')
        .select('id, type, title, body, link, is_read, created_at')
        .eq('user_id', userId);
    if (since != null) query = query.gte('created_at', since);
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return (rows as List).map((r) => AppNotification.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> markRead(String notificationId, String userId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId)
        .eq('user_id', userId);
  }

  Future<void> markAllRead(String userId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }
}
