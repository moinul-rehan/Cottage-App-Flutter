import 'package:flutter/material.dart';
import 'package:cottage/helpers/supabase_service.dart';
import 'package:cottage/features/notifications/presentation/notification_bell.dart';
import 'package:cottage/constants/theme.dart';

/// Shared top bar for each tab under [BottomNavShell] -- Cottage wordmark,
/// with sign-out surfaced only where [showLogout] is true (the Menu tab).
class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final bool showLogout;

  const AppScaffold({super.key, required this.title, required this.body, this.showLogout = true});

  /// No manual navigation to LoginScreen here -- the root _AuthGate
  /// (main.dart) listens to onAuthStateChange and swaps to it on its own,
  /// same as the sign-in side of that flow.
  Future<void> _logout(BuildContext context) => SupabaseService.signOut();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.home_rounded, color: CottageColors.primary, size: 22),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        actions: [
          const NotificationBell(),
          if (showLogout)
            IconButton(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out',
            ),
        ],
      ),
      body: body,
    );
  }
}
