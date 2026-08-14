import 'package:flutter/material.dart';
import '../data/notification.dart';
import '../data/notification_service.dart';
import 'package:cottage/helpers/supabase_service.dart';
import 'package:cottage/helpers/ui_helpers.dart';
import 'package:cottage/constants/theme.dart';
import 'notifications_screen.dart';
import 'notification_navigation.dart';

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
    final surface = context.surface;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        // A generous initial height (short of full page) that the user can
        // drag further up toward maxChildSize (full page) or down toward
        // minChildSize, at which point it dismisses -- see
        // _DismissOnMinExtent below.
        initialChildSize: 0.62,
        minChildSize: 0.3,
        maxChildSize: 1,
        expand: false,
        builder: (context, scrollController) => _DismissOnMinExtent(
          minExtent: 0.3,
          child: Container(
            decoration: BoxDecoration(
              color: surface.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: _NotificationSheet(
              service: _service,
              userId: _userId,
              cottageIdFuture: _cottageId(),
              onChanged: _loadUnreadCount,
              scrollController: scrollController,
            ),
          ),
        ),
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

/// Pops the enclosing modal route once the sheet is dragged down to (or
/// past) [minExtent], so "drag down further than the short-drawer size"
/// reads as a close gesture instead of just stopping at the floor.
class _DismissOnMinExtent extends StatelessWidget {
  final double minExtent;
  final Widget child;
  const _DismissOnMinExtent({required this.minExtent, required this.child});

  @override
  Widget build(BuildContext context) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        if (notification.extent <= minExtent + 0.01) {
          Navigator.of(context).maybePop();
        }
        return false;
      },
      child: child,
    );
  }
}

class _NotificationSheet extends StatefulWidget {
  final NotificationService service;
  final String userId;
  final Future<String> cottageIdFuture;
  final VoidCallback onChanged;
  final ScrollController scrollController;

  const _NotificationSheet({
    required this.service,
    required this.userId,
    required this.cottageIdFuture,
    required this.onChanged,
    required this.scrollController,
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
    // Block body -- see contacts_screen.dart's _refresh for why the arrow
    // form is a real bug (setState() callback implicitly returning a Future).
    setState(() {
      _future = _load();
    });
  }

  Future<void> _open(AppNotification n) async {
    _markRead(n);
    // openNotificationDestination pops back to the shell's root first (see
    // its doc comment), which also closes this modal sheet as part of that
    // -- nothing further to dismiss here on the success path.
    final navigatedInApp = openNotificationDestination(context, n);
    if (navigatedInApp) return;
    final hasLink = n.link != null && n.link!.trim().isNotEmpty;
    if (!hasLink) return;
    final opened = await openNotificationLink(n.link);
    if (!opened && mounted) {
      showToast(context, 'Could not open this notification\'s link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Drag handle -- also the surface the user grabs to expand/collapse
        // the sheet, matching CottageSheetContent's handle look elsewhere.
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 40,
            height: 6,
            decoration: BoxDecoration(color: surface.muted, borderRadius: BorderRadius.circular(3)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
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
                return ListView(
                  controller: widget.scrollController,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text('No notifications yet.', style: TextStyle(color: surface.mutedForeground)),
                      ),
                    ),
                  ],
                );
              }
              return ListView.separated(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                itemCount: notifications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final n = notifications[index];
                  final categoryLabel = platformCategoryLabel(n.type);
                  final hasLink = n.link != null && n.link!.trim().isNotEmpty;
                  return ListTile(
                    onTap: () => _open(n),
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!n.isRead) ...[
                          const Icon(Icons.circle, size: 8, color: CottageColors.destructive),
                          if (hasLink) const SizedBox(width: 6),
                        ],
                        if (hasLink) Icon(Icons.chevron_right, size: 18, color: surface.mutedForeground),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
