import 'package:flutter/material.dart';

/// A row from the `notifications` table. Mirrors the shape returned by
/// getNotifications/getUnreadCount in src/lib/data/notifications.ts.
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String? body;
  final String? link;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.link,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      type: map['type'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String?,
      link: map['link'] as String?,
      isRead: map['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      link: link,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}

/// Icon per notification `type` -- mirrors NOTIFICATION_ICONS in
/// src/app/(house)/notification-icons.tsx (falls back to a plain bell).
IconData notificationIconFor(String type) {
  switch (type) {
    case 'notice_posted':
      return Icons.push_pin_outlined;
    case 'meal_request_submitted':
    case 'meal_cost_request_submitted':
      return Icons.inbox_outlined;
    case 'meal_request_approved':
    case 'meal_cost_request_approved':
    case 'cottage_deletion_cancelled':
      return Icons.check_circle_outline;
    case 'meal_request_rejected':
    case 'meal_cost_request_rejected':
      return Icons.cancel_outlined;
    case 'ownership_transferred':
      return Icons.workspace_premium_outlined;
    case 'cottage_deletion_scheduled':
      return Icons.dangerous_outlined;
    case 'utility_adjustment':
    case 'utility_expense_credit':
      return Icons.receipt_long_outlined;
    case 'utility_adjustment_removed':
      return Icons.delete_outline;
    case 'utility_deposit':
    case 'meal_deposit':
      return Icons.account_balance_wallet_outlined;
    case 'bazaar_entry':
      return Icons.shopping_basket_outlined;
    case 'bazaar_duty_assigned':
      return Icons.event_available_outlined;
    case 'bazaar_duty_removed':
      return Icons.event_busy_outlined;
    case 'daily_meal':
      return Icons.restaurant_outlined;
    case 'month_created':
      return Icons.date_range_outlined;
    case 'month_activated':
      return Icons.refresh_outlined;
    case 'utility_month_reset':
    case 'meal_month_reset':
      return Icons.restore_outlined;
    case 'feedback_submitted':
      return Icons.report_gmailerrorred_outlined;
    case 'platform_feature':
      return Icons.auto_awesome_outlined;
    case 'platform_update':
      return Icons.refresh_outlined;
    case 'platform_announcement':
      return Icons.campaign_outlined;
    case 'platform_maintenance':
      return Icons.build_outlined;
    case 'platform_alert':
      return Icons.warning_amber_outlined;
    default:
      return Icons.notifications_outlined;
  }
}

const _platformTypePrefix = 'platform_';

/// Category label for a platform-admin-sent notification's badge (e.g.
/// "platform_feature" -> "Feature"), or null for regular in-app activity
/// notifications. Mirrors getPlatformCategoryLabel in
/// src/app/(house)/notification-icons.tsx.
String? platformCategoryLabel(String type) {
  if (!type.startsWith(_platformTypePrefix)) return null;
  final category = type.substring(_platformTypePrefix.length);
  if (category.isEmpty) return null;
  return category[0].toUpperCase() + category.substring(1);
}
