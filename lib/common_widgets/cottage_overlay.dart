import 'package:flutter/material.dart';
import 'package:cottage/common_widgets/cottage_loader.dart';

/// A utility to show a transparent loading overlay on top of the current screen.
/// This keeps the current page fully visible while the loader spins.
class CottageOverlay {
  static OverlayEntry? _overlayEntry;

  /// Shows the transparent loading overlay on top of the current screen.
  static void show(BuildContext context) {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.transparent,
        child: Container(
          color: Colors.black.withValues(alpha: 0.15),
          child: const Center(
            child: CottageLoader(),
          ),
        ),
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  /// Hides the loading overlay.
  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}
