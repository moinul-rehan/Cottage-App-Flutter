import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'package:cottage/helpers/onboarding_service.dart';
import 'package:cottage/helpers/push_notification_service.dart';
import 'package:cottage/helpers/supabase_service.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/common_widgets/bottom_nav_shell.dart';
import 'package:cottage/constants/app_constants.dart';
import 'package:cottage/helpers/navigation_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  await PushNotificationService.initialize();
  await OnboardingService.load();
  runApp(const CottageApp());
}

final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

class CottageApp extends StatefulWidget {
  const CottageApp({super.key});

  @override
  State<CottageApp> createState() => _CottageAppState();
}

class _CottageAppState extends State<CottageApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          navigatorKey: NavigationService.navigatorKey,
          title: AppConstants.appName,
          theme: buildCottageTheme(Brightness.light),
          darkTheme: buildCottageTheme(Brightness.dark),
          themeMode: mode,
          debugShowCheckedModeBanner: false,
          home: !SupabaseService.isInitialized
              ? _SupabaseErrorScreen(error: SupabaseService.initializationError)
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: _showSplash
                      ? SplashScreen(
                          key: const ValueKey('splash'),
                          onFinished: () => setState(() => _showSplash = false),
                        )
                      : ValueListenableBuilder<bool>(
                          key: const ValueKey('app'),
                          valueListenable: OnboardingService.completed,
                          builder: (context, seenOnboarding, _) {
                            return seenOnboarding
                                ? const _AuthGate()
                                : const OnboardingScreen();
                          },
                        ),
                ),
        );
      },
    );
  }
}

/// Root auth-aware screen picker. Needed (rather than a one-off check at
/// launch) because Google sign-in completes asynchronously: the browser
/// closes, the OS hands control back to the app via the deep link registered
/// in AndroidManifest.xml/Info.plist, and Supabase's client picks up the
/// session from that redirect on its own -- nothing in the button's tap
/// handler is still around to react to it. Listening to [onAuthStateChange]
/// here means both that flow and plain email/password sign-in (and sign-out,
/// from anywhere) all route through the same place.
///
/// Rebuilding alone isn't enough, though: if the user was on the pushed
/// Forgot Password screen when a session appears (e.g. Google sign-in
/// finishing while it's on top -- Login/Signup itself is a single
/// never-pushed screen that toggles mode in place, so it can't be "on top"
/// this way), that pushed route would keep covering the now-rebuilt
/// BottomNavShell underneath it. So on every signed-in transition, this
/// also pops back to the root route via [NavigationService.popToRoot], the
/// same way a successful password sign-in/signup used to navigate manually.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  StreamSubscription<AuthState>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = SupabaseService.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (state.session != null) {
        NavigationService.popToRoot();
        PushNotificationService.registerToken();
      } else if (state.event == AuthChangeEvent.signedOut) {
        PushNotificationService.unregisterToken();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: SupabaseService.client.auth.onAuthStateChange,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        SupabaseService.currentSession,
      ),
      builder: (context, snapshot) {
        final session =
            snapshot.data?.session ?? SupabaseService.currentSession;
        return session != null ? const BottomNavShell() : const LoginScreen();
      },
    );
  }
}

class _SupabaseErrorScreen extends StatelessWidget {
  final String? error;
  const _SupabaseErrorScreen({this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 64,
                    color: CottageColors.destructive,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Configuration Required',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    error ?? 'Unknown initialization error.',
                    style: const TextStyle(fontSize: 14, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'To run the application, make sure to pass your env.json configurations to the run command:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const SelectableText(
                      'flutter run --dart-define-from-file=env.json',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
