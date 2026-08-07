import 'package:flutter/material.dart';
import '../data/notification.dart';
import '../data/notification_service.dart';
import 'package:cottage/helpers/supabase_service.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/common_widgets/cottage_bottom_sheet.dart';
import 'notifications_screen.dart';

/// Bell icon with an unread-count badge, plus a dropdown/bottom sheet of
/// recent notifications -- mirrors src/app/(house)/NotificationTray.tsx
/// (a simplified, non-swipe-driven port for the app's top bar).
class NotificationBell extends StatefulWidget {
  final bool bareIcon;
  const NotificationBell({super.key, this.bareIcon = false});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final _service = NotificationService();
  int _unreadCount = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  String get _userId => SupabaseService.currentUser!.id;

  Future<String> _cottageId() async {
    final row = await SupabaseService.client
        .from('profiles')
        .select('cottage_id')
        .eq('id', _userId)
        .single();
    return row['cottage_id'] as String;
  }

  Future<void> _loadUnreadCount() async {
    try {
      final cottageId = await _cottageId();
      final since = await _service.resolveSince(cottageId);
      final count = await _service.getUnreadCount(_userId, since);
      if (mounted) setState(() { _unreadCount = count; _loaded = true; });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _openTray() async {
    await showCottageSheet(
      context: context,
      builder: (sheetContext) => _NotificationSheet(
        service: _service,
        userId: _userId,
        cottageIdFuture: _cottageId(),
        onChanged: _loadUnreadCount,
      ),
    );
    _loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final iconStack = Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.notifications_outlined, color: surface.foreground, size: widget.bareIcon ? 22 : 24),
        if (_loaded && _unreadCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: CottageColors.destructive, shape: BoxShape.circle),
            ),
          ),
      ],
    );

    if (widget.bareIcon) {
      return GestureDetector(
        onTap: _openTray,
        child: iconStack,
      );
    }

    return IconButton(
      tooltip: 'Notifications',
      onPressed: _openTray,
      icon: iconStack,
    );
  }
}

class _NotificationSheet extends StatefulWidget {
  final NotificationService service;
  final String userId;
  final Future<String> cottageIdFuture;
  final VoidCallback onChanged;

  const _NotificationSheet({
    required this.service,
    required this.userId,
    required this.cottageIdFuture,
    required this.onChanged,
  });

  @override
  State<_NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<_NotificationSheet> {
  late Future<List<AppNotification>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AppNotification>> _load() async {
    final cottageId = await widget.cottageIdFuture;
    final since = await widget.service.resolveSince(cottageId);
    return widget.service.getNotifications(widget.userId, since);
  }

  Future<void> _markRead(AppNotification n) async {
    if (n.isRead) return;
    await widget.service.markRead(n.id, widget.userId);
    widget.onChanged();
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text('Notifications', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: surface.foreground)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                  },
                  child: const Text('See all'),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<AppNotification>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final notifications = snapshot.data ?? const [];
                if (notifications.isEmpty) {
                  return Center(
                    child: Text('No notifications yet.', style: TextStyle(color: surface.mutedForeground)),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                  itemCount: notifications.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final n = notifications[index];
                    final categoryLabel = platformCategoryLabel(n.type);
                    return ListTile(
                      onTap: () => _markRead(n),
                      tileColor: n.isRead ? null : surface.accent.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: surface.accent,
                        child: Icon(notificationIconFor(n.type), size: 14, color: surface.accentForeground),
                      ),
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              n.title,
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: surface.foreground),
                            ),
                          ),
                          if (categoryLabel != null) ...[
                            const SizedBox(width: 6),
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
                        ],
                      ),
                      subtitle: n.body != null && n.body!.isNotEmpty
                          ? Text(n.body!, style: TextStyle(fontSize: 12, color: surface.mutedForeground))
                          : null,
                      trailing: n.isRead ? null : const Icon(Icons.circle, size: 8, color: CottageColors.destructive),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
