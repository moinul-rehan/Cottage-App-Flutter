import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'supabase_service.dart';

/// Native push delivery (Firebase Cloud Messaging) to the device's system
/// notification tray -- distinct from the in-app notification bell
/// (`features/notifications/`, which reads the `notifications` table) and
/// from the web app's browser Web Push (`push_subscriptions` table, VAPID),
/// neither of which can reach a native Android app.
///
/// Requires `android/app/google-services.json` (gitignored, see
/// `Flutter App/.gitignore` and the README) -- without it, [initialize]
/// still runs but [Firebase.initializeApp] throws, so every method here
/// fails soft (caught, logged, no-op) rather than crashing the app for
/// members who haven't set it up yet.
class PushNotificationService {
  PushNotificationService._();

  static const _channel = AndroidNotificationChannel(
    'cottage_default',
    'Cottage notifications',
    description: 'Meal, utility, notice, and platform-admin updates.',
    importance: Importance.high,
  );

  static final _local = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Call once at app startup (after Supabase is initialized, before or
  /// after sign-in -- this only sets up listeners; [registerToken] is what
  /// actually needs a signed-in user).
  static Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('PushNotificationService: Firebase.initializeApp failed (is google-services.json present?): $e');
      return;
    }

    await _local.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Android suppresses the system tray notification for a foreground app
    // by design (FCM assumes the app will show its own UI) -- show it
    // ourselves via flutter_local_notifications so a member using the app
    // right now still sees it, matching what happens when backgrounded.
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  }

  /// Requests notification permission, gets this device's FCM token, and
  /// upserts it into `fcm_tokens` for the signed-in user so the backend
  /// (src/lib/data/push.ts) can target it. Call after sign-in (see
  /// _AuthGate in main.dart) and again on `onTokenRefresh` (FCM rotates
  /// tokens occasionally).
  static Future<void> registerToken() async {
    if (kIsWeb || !_initialized) return;
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _upsertToken(userId, token);

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        final currentUserId = SupabaseService.currentUser?.id;
        if (currentUserId != null) _upsertToken(currentUserId, newToken);
      });
    } catch (e) {
      debugPrint('PushNotificationService: registerToken failed: $e');
    }
  }

  static Future<void> _upsertToken(String userId, String token) async {
    await SupabaseService.client.from('fcm_tokens').upsert(
      {'user_id': userId, 'token': token, 'platform': 'android', 'updated_at': DateTime.now().toIso8601String()},
      onConflict: 'token',
    );
  }

  /// Best-effort cleanup on sign-out so a shared/reset device stops
  /// receiving that member's pushes. Not calling this isn't a correctness
  /// bug (the row just goes stale and gets pruned server-side once FCM
  /// reports the token invalid), just a courtesy.
  static Future<void> unregisterToken() async {
    if (kIsWeb || !_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await SupabaseService.client.from('fcm_tokens').delete().eq('token', token);
    } catch (e) {
      debugPrint('PushNotificationService: unregisterToken failed: $e');
    }
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _local.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(_channelId, _channelName, importance: Importance.high, priority: Priority.high),
      ),
    );
  }

  static const _channelId = 'cottage_default';
  static const _channelName = 'Cottage notifications';
}

/// Top-level, not a class method -- required by firebase_messaging so it can
/// be invoked on a separate isolate when the app is backgrounded/terminated.
/// The OS already shows the system tray notification on its own in that
/// case (as long as the FCM payload has a `notification` block, which
/// src/lib/data/push.ts's server-side send always includes) -- this handler
/// just needs to exist and re-init Firebase for that isolate; no extra work
/// is needed here today.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}
