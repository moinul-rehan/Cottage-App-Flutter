import 'package:flutter/material.dart';
import '../data/notification.dart';
import 'package:cottage/common_widgets/bottom_nav_shell.dart';
import 'package:cottage/helpers/navigation_service.dart';
import '../../notices/presentation/notices_screen.dart';

/// Routes a notification to the in-app screen it's actually about, instead
/// of always falling back to `openNotificationLink` (which just opens the
/// web app externally) -- e.g. a bazaar-duty notification should land on
/// the Meal tab, not a browser tab. Returns true if it navigated somewhere
/// (caller should treat the notification as handled), false if this
/// notification's `type` has no in-app destination (caller should fall
/// back to opening its `link`, if any -- platform-admin announcements in
/// particular often only make sense as an external link).
bool openNotificationDestination(BuildContext context, AppNotification n) {
  final shell = BottomNavShell.shellKey.currentState;
  if (shell == null) return false;

  final action = _resolve(context, shell, n.type);
  if (action == null) return false;

  // The bell is reachable from pushed screens (AppScaffold's app bar), not
  // just the tab screens themselves -- land on the shell first so the tab
  // switch below is actually visible instead of happening underneath
  // whatever's currently pushed on top of it. Only done once we know
  // there's actually somewhere to go, so an unmapped/link-only
  // notification doesn't close whatever's on screen for no visible outcome.
  NavigationService.popToRoot();
  action();
  return true;
}

/// A no-argument navigation step, or null if [type] has no in-app
/// destination for this member (either the type itself isn't mapped, or it
/// is but this member doesn't have the permission the destination needs --
/// e.g. a plain member has no "my requests" screen to send a meal-request
/// notification to).
VoidCallback? _resolve(BuildContext context, BottomNavShellState shell, String type) {
  switch (type) {
    case 'notice_posted':
      // Tab 1 is the Request inbox for members who review requests, not
      // Notices -- reach the notice board by pushing it directly, same as
      // the Menu tab's own "Notice Board" speed-dial item does in that case.
      return shell.canManageMealRequests
          ? () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NoticesScreen()),
              )
          : () => shell.openTab(1);

    case 'meal_request_submitted':
    case 'meal_cost_request_submitted':
    case 'meal_request_approved':
    case 'meal_cost_request_approved':
    case 'meal_request_rejected':
    case 'meal_cost_request_rejected':
      // Only the members who review requests have a dedicated inbox --
      // everyone else has no in-app "my requests" view yet.
      return shell.canManageMealRequests ? () => shell.openTab(1) : null;

    case 'daily_meal':
    case 'meal_deposit':
    case 'bazaar_entry':
    case 'bazaar_duty_assigned':
    case 'bazaar_duty_removed':
    case 'meal_month_reset':
      return () => shell.openTab(2);

    case 'utility_adjustment':
    case 'utility_adjustment_removed':
    case 'utility_expense_credit':
    case 'utility_deposit':
    case 'utility_month_reset':
      return () => shell.openTab(3);

    case 'month_created':
    case 'month_activated':
      return () => shell.openTab(4, action: 'months');

    // Cottage-wide alerts with no single dedicated screen -- Home at least
    // puts the member back on solid ground to look around from.
    case 'ownership_transferred':
    case 'cottage_deletion_scheduled':
    case 'cottage_deletion_cancelled':
      return () => shell.openTab(0);

    // Platform-admin notices (platform_feature/update/announcement/
    // maintenance/alert) and anything unrecognized: no in-app screen is
    // "about" these, so let the caller fall back to the notification's own
    // `link` if it has one.
    default:
      return null;
  }
}
