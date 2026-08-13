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

  /// Bottom padding a scrollable needs so its last item clears the floating
  /// pill nav bar instead of being hidden behind it, with only a small
  /// visual gap left over. Backed by [measuredNavBarFootprint] -- an actual
  /// measurement of the nav bar's rendered position (see
  /// bottom_nav_shell.dart's `_NavBarFootprintMeasurer`) rather than
  /// recomputed `SafeArea`/`MediaQuery` math, which drifted from the real
  /// on-device layout (some Android nav-bar/inset combinations don't behave
  /// the way `extendBody` + `SafeArea` math predicts on paper). Only needed
  /// by screens that live inside BottomNavShell's IndexedStack (Dashboard/
  /// Meal/Utilities/Menu/Notices/Requests tabs); screens reached via
  /// Navigator.push sit above the shell and don't need it (though adding it
  /// there is harmless).
  double get bottomNavClearance => measuredNavBarFootprint.value + 8;
}

/// Distance from the very bottom of the screen to the top of the floating
/// pill nav bar, in logical pixels -- kept up to date by BottomNavShell's
/// `_NavBarFootprintMeasurer`, which measures the nav bar's actual rendered
/// position after every layout. Starts at a reasonable guess so the very
/// first frame (before the nav bar has measured itself even once) isn't
/// completely unpadded.
final ValueNotifier<double> measuredNavBarFootprint = ValueNotifier<double>(76);
