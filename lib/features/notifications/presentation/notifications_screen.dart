import 'package:flutter/material.dart';
import '../data/notification.dart';
import '../data/notification_service.dart';
import 'package:cottage/helpers/supabase_service.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/common_widgets/app_scaffold.dart';
import 'package:cottage/common_widgets/empty_state.dart';
import 'package:cottage/helpers/ui_helpers.dart';
import 'notification_navigation.dart';

/// Full notifications list -- mirrors src/app/(house)/notifications/page.tsx
/// and NotificationRow.tsx.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationService();
  late Future<List<AppNotification>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  String get _userId => SupabaseService.currentUser!.id;

  Future<List<AppNotification>> _load() async {
    final profileRow = await SupabaseService.client
        .from('profiles')
        .select('cottage_id')
        .eq('id', _userId)
        .single();
    final cottageId = profileRow['cottage_id'] as String;
    final since = await _service.resolveSince(cottageId);
    return _service.getNotifications(_userId, since);
  }

  // Block body -- see contacts_screen.dart's _refresh for why the arrow
  // form is a real bug (setState() callback implicitly returning a Future).
  void _refresh() => setState(() {
    _future = _load();
  });

  Future<void> _markRead(AppNotification n) async {
    if (n.isRead) return;
    await _service.markRead(n.id, _userId);
    _refresh();
  }

  Future<void> _markAllRead() async {
    await _service.markAllRead(_userId);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Notifications',
      showLogout: false,
      body: FutureBuilder<List<AppNotification>>(
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
                  Text('Could not load notifications.\n${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _refresh, child: const Text('Retry')),
                ],
              ),
            );
          }

          final notifications = snapshot.data!;
          final hasUnread = notifications.any((n) => !n.isRead);
          final surface = context.surface;

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: notifications.isEmpty
                ? ListView(
                    children: const [
                      EmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: 'No notifications yet',
                        subtitle: 'Updates from the Meal ledger, Utility ledger, months and members show up here.',
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length + (hasUnread ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (hasUnread && index == 0) {
                        return Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _markAllRead,
                            child: const Text('Mark all read'),
                          ),
                        );
                      }
                      final n = notifications[index - (hasUnread ? 1 : 0)];
                      return _NotificationTile(
                        notification: n,
                        surface: surface,
                        onMarkRead: () => _markRead(n),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final CottageSurface surface;
  final VoidCallback onMarkRead;

  const _NotificationTile({required this.notification, required this.surface, required this.onMarkRead});

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  bool get _hasLink => notification.link != null && notification.link!.trim().isNotEmpty;

  Future<void> _open(BuildContext context) async {
    onMarkRead();
    if (openNotificationDestination(context, notification)) return;
    if (!_hasLink) return;
    final opened = await openNotificationLink(notification.link);
    if (!opened && context.mounted) {
      showToast(context, 'Could not open this notification\'s link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryLabel = platformCategoryLabel(notification.type);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(context),
        child: Container(
          decoration: BoxDecoration(
            color: notification.isRead ? surface.card : surface.accent.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: surface.border),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(color: surface.accent, shape: BoxShape.circle),
                child: Icon(notificationIconFor(notification.type), size: 14, color: surface.accentForeground),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            children: [
                              Text(
                                notification.title,
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: surface.foreground),
                              ),
                              if (categoryLabel != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: CottageColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    categoryLabel.toUpperCase(),
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: CottageColors.primary, letterSpacing: 0.4),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: CottageColors.primary, borderRadius: BorderRadius.circular(10)),
                            child: const Text('New', style: TextStyle(fontSize: 10, color: CottageColors.primaryForeground, fontWeight: FontWeight.w600)),
                          ),
                        if (_hasLink) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right, size: 18, color: surface.mutedForeground),
                        ],
                      ],
                    ),
                    if (notification.body != null && notification.body!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(notification.body!, style: TextStyle(fontSize: 12.5, color: surface.mutedForeground)),
                    ],
                    const SizedBox(height: 4),
                    Text(_relativeTime(notification.createdAt), style: TextStyle(fontSize: 11, color: surface.mutedForeground.withValues(alpha: 0.8))),
                    if (!notification.isRead) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: onMarkRead,
                          child: Text('Mark read', style: TextStyle(fontSize: 12, color: CottageColors.primary, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
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
