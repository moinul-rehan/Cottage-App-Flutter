import 'package:flutter/material.dart';

/// Shared SnackBar helper -- a one-line toast instead of every screen
/// constructing its own `ScaffoldMessenger.of(context).showSnackBar(...)`
/// call. Mirrors the template's helpers/toast.dart + ui_helpers.dart role.
void showToast(BuildContext context, String message, {Duration? duration}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: duration ?? const Duration(seconds: 4)),
  );
}
