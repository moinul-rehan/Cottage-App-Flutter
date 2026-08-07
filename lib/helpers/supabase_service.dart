import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

class SupabaseService {
  SupabaseService._();

  /// Where Supabase redirects back to after a Google OAuth round-trip in the
  /// browser. Must match the custom-scheme intent-filter registered in
  /// android/app/src/main/AndroidManifest.xml and the CFBundleURLTypes entry
  /// in ios/Runner/Info.plist, AND must be added to the Supabase project's
  /// Auth > URL Configuration > Redirect URLs allow-list (that part can't be
  /// done from the app - it's a Supabase dashboard setting).
  static const oauthRedirectUrl = 'com.cottage.cottage://login-callback';

  static String? initializationError;
  static bool get isInitialized => initializationError == null && _isInitDone;
  static bool _isInitDone = false;

  static Future<void> initialize() async {
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      initializationError =
          'SUPABASE_URL or SUPABASE_ANON_KEY is empty.\n\n'
          'Please ensure you run the app with the correct configurations:\n'
          'flutter run --dart-define-from-file=env.json';
      return;
    }
    try {
      await Supabase.initialize(
        url: _supabaseUrl,
        publishableKey: _supabaseAnonKey,
      );
      _isInitDone = true;
    } catch (e) {
      initializationError = 'Failed to initialize Supabase:\n$e';
    }
  }

  static SupabaseClient get client {
    if (!isInitialized) {
      throw StateError('Supabase has not been initialized. Details: $initializationError');
    }
    return Supabase.instance.client;
  }

  static User? get currentUser => isInitialized ? client.auth.currentUser : null;

  static Session? get currentSession => isInitialized ? client.auth.currentSession : null;

  static Future<void> signOut() async {
    if (isInitialized) {
      await client.auth.signOut();
    }
  }
}
