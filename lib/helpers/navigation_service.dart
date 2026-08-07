import 'package:flutter/material.dart';

/// Global navigation access without a BuildContext -- lets code outside any
/// widget's build method (deep-link handlers, auth-state listeners) push,
/// pop, or read the current route. Mirrors the template's
/// helpers/navigation_service.dart.
class NavigationService {
  NavigationService._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static void popToRoot() {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }
}
