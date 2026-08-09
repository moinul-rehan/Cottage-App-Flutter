import 'package:flutter/material.dart';
import 'package:cottage/constants/theme.dart';

/// Opens a themed modal bottom sheet with the Cottage design language.
///
/// Sizing mirrors the web app's mobile sheets exactly (see
/// UtilityBreakdownDialog's `Sheet` usage and NotificationTray's custom
/// drawer in src/app/(house)/): full width, 24px top corner radius, capped
/// at 85% of the screen height (`max-h-[85dvh]`) so content never runs
/// under the status bar, and a 40x6 drag handle (`h-1.5 w-10`). The
/// [builder] receives the sheet's [BuildContext] so downstream widgets can
/// still use `context.surface`.
Future<T?> showCottageSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = true,
}) {
  final surface = context.surface;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: surface.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 6,
              decoration: BoxDecoration(
                color: surface.muted,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(child: builder(ctx)),
          ],
        ),
      );
    },
  );
}

/// A titled bottom sheet with consistent header styling.
class CottageSheetContent extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const CottageSheetContent({
    super.key,
    required this.title,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 24),
  });

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    // Scrollable so a sheet with more fields than fit the available height
    // (e.g. the keyboard covering half the screen) scrolls instead of
    // overflowing -- [showCottageSheet] only caps the sheet's max height,
    // it doesn't make its content scrollable on its own.
    return SingleChildScrollView(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: surface.foreground,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
