import 'package:flutter/material.dart';

/// Material 3 window-size-class breakpoints.
class Breakpoints {
  Breakpoints._();

  /// Phone portrait — most of the app runs here.
  static const double compact = 600;

  /// Small tablet / large phone landscape.
  static const double medium = 840;
}

/// Quick helpers so screens can branch on width without boilerplate.
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// True for phones in portrait (<600 dp).
  bool get isCompact => screenWidth < Breakpoints.compact;

  /// True for small tablets / large phones (600–840 dp).
  bool get isMedium =>
      screenWidth >= Breakpoints.compact && screenWidth < Breakpoints.medium;

  /// True for tablets in landscape (>840 dp).
  bool get isExpanded => screenWidth >= Breakpoints.medium;

  /// Horizontal page padding that grows with width.
  double get responsivePadding {
    if (isCompact) return 16;
    if (isMedium) return 24;
    return 32;
  }

  /// Number of grid columns for card grids.
  int get gridColumns {
    if (isCompact) return 1;
    if (isMedium) return 2;
    return 3;
  }
}
