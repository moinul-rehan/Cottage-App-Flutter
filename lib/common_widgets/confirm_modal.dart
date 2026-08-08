import 'package:flutter/material.dart';
import 'package:cottage/constants/theme.dart';

/// Cottage's standard confirmation popup -- Figma node 87:1646 ("Confirm
/// Dialog - Delete" / "Confirm Dialog - Generic"): a centered white
/// rounded-24 card over a dark scrim, with an icon circle, title, message,
/// and a Cancel + confirm button pair. [destructive] switches both the
/// icon-circle tint and the confirm button between the red "delete" style
/// and the primary-orange "neutral confirmation" style (e.g. log out).
///
/// Use this instead of a raw [AlertDialog] for any "are you sure?" prompt
/// so confirmations look consistent across the app.
Future<bool> showConfirmModal(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x8C0F0F0F), // rgba(15,15,15,0.55)
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        width: 311,
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 32, offset: const Offset(0, 12), spreadRadius: -4),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: destructive ? const Color(0xFFFFE9E9) : const Color(0xFFFBE9E2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: destructive ? const Color(0xFFCC4F4F) : CottageColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF2A2A2A)),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF707070)),
            ),
            const SizedBox(height: 20), // Figma: gap-16 + the button row's own pt-4
            Row(
              children: [
                Expanded(
                  child: _ConfirmModalButton(
                    label: cancelLabel,
                    onTap: () => Navigator.pop(ctx, false),
                    background: Colors.white,
                    textColor: const Color(0xFF404040),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                    shadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 2, offset: const Offset(0, 1))],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ConfirmModalButton(
                    label: confirmLabel,
                    onTap: () => Navigator.pop(ctx, true),
                    background: destructive ? const Color(0xFFCC4F4F) : CottageColors.primary,
                    textColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

class _ConfirmModalButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color background;
  final Color textColor;
  final BoxBorder? border;
  final List<BoxShadow>? shadow;

  const _ConfirmModalButton({
    required this.label,
    required this.onTap,
    required this.background,
    required this.textColor,
    this.border,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(1000),
          border: border,
          boxShadow: shadow,
        ),
        child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
      ),
    );
  }
}
