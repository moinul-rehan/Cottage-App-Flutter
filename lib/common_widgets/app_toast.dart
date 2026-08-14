import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cottage/constants/theme.dart';

/// The four toast variants from Figma node 192:1668 -- each just a color +
/// icon pair, everything else about the card is identical.
enum ToastType { success, error, warning, info }

class _ToastSpec {
  final Color color;
  final IconData icon;
  const _ToastSpec(this.color, this.icon);
}

const _toastSpecs = {
  ToastType.success: _ToastSpec(Color(0xFF63B64E), LucideIcons.circleCheck),
  ToastType.error: _ToastSpec(Color(0xFFFF4F4F), LucideIcons.circleX),
  ToastType.warning: _ToastSpec(Color(0xFFFA9033), LucideIcons.triangleAlert),
  ToastType.info: _ToastSpec(Color(0xFFDE7356), LucideIcons.info),
};

OverlayEntry? _activeToast;
Timer? _activeToastTimer;

/// Replaces the platform default [SnackBar]/[ScaffoldMessenger] toast with
/// the app's own card design (left accent bar + tinted icon circle + title/
/// subtitle + dismiss button), matching Figma exactly instead of Material's
/// stock bottom bar. Only one toast shows at a time -- a new call replaces
/// whatever's currently showing, same as most toast libraries' default
/// "latest wins" behavior.
void showAppToast(
  BuildContext context, {
  required String title,
  String? subtitle,
  ToastType type = ToastType.info,
  Duration duration = const Duration(seconds: 4),
}) {
  _activeToastTimer?.cancel();
  _activeToast?.remove();
  _activeToast = null;

  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  late OverlayEntry entry;
  final key = GlobalKey<_ToastCardState>();

  entry = OverlayEntry(
    builder: (context) => _ToastOverlay(
      key: key,
      title: title,
      subtitle: subtitle,
      type: type,
      onDismissed: () {
        _activeToastTimer?.cancel();
        if (_activeToast == entry) _activeToast = null;
        entry.remove();
      },
    ),
  );

  _activeToast = entry;
  overlay.insert(entry);

  _activeToastTimer = Timer(duration, () {
    key.currentState?.dismiss();
  });
}

class _ToastOverlay extends StatefulWidget {
  final String title;
  final String? subtitle;
  final ToastType type;
  final VoidCallback onDismissed;

  const _ToastOverlay({
    super.key,
    required this.title,
    this.subtitle,
    required this.type,
    required this.onDismissed,
  });

  @override
  State<_ToastOverlay> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();
  bool _dismissing = false;

  void dismiss() {
    if (_dismissing) return;
    _dismissing = true;
    _controller.reverse().whenComplete(widget.onDismissed);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: SafeArea(
        bottom: false,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.3),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: GestureDetector(
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) < -200) dismiss();
              },
              child: _ToastCard(
                title: widget.title,
                subtitle: widget.subtitle,
                type: widget.type,
                onClose: dismiss,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final ToastType type;
  final VoidCallback onClose;

  const _ToastCard({
    required this.title,
    this.subtitle,
    required this.type,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final spec = _toastSpecs[type]!;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: surface.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: surface.border, width: 0.8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26101828),
              offset: Offset(0, 8),
              blurRadius: 24,
              spreadRadius: -4,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: spec.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14 + 8, 14, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: spec.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(spec.icon, size: 18, color: spec.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: surface.foreground,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 12,
                              color: surface.mutedForeground,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: onClose,
                    behavior: HitTestBehavior.opaque,
                    child: Icon(
                      LucideIcons.x,
                      size: 14,
                      color: surface.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
