import 'package:flutter/material.dart';
import 'package:cottage/common_widgets/app_toast.dart';

/// Shared toast helper -- a one-line call instead of every screen
/// constructing its own toast. Renders the app's own Figma-designed toast
/// card (see app_toast.dart) rather than a stock Material [SnackBar]; every
/// existing call site keeps working unchanged since the signature hasn't
/// moved, it just displays differently now. Callers that want a specific
/// color/icon (success/error/warning) or a two-line title+subtitle layout
/// should call [showAppToast] directly instead -- this wrapper always shows
/// as a single-line, neutral "info" toast.
void showToast(BuildContext context, String message, {Duration? duration}) {
  showAppToast(
    context,
    title: message,
    duration: duration ?? const Duration(seconds: 4),
  );
}
