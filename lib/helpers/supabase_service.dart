import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

// The "Web application" OAuth client already registered under this
// project's Google Sign In provider in the Supabase dashboard (Authentication
// > Providers > Google > Client IDs). Passed as google_sign_in's
// serverClientId so the ID token it returns is issued for an audience
// Supabase already trusts -- no separate Android client ID needed here, the
// Android OAuth client (package name + SHA-1, registered in Google Cloud
// Console) only has to exist for the native picker to be allowed to run.
const _googleWebClientId = '1035030975534-6qfdt9srfrt6d7nitd7eihsd0anag8ue.apps.googleusercontent.com';

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

  // Raw nonce handed to GoogleSignIn.initialize() (hashed) at startup, then
  // re-supplied in plaintext to signInWithIdToken() so Supabase can verify
  // it against the hash embedded in Google's returned ID token.
  static String? _googleNonce;
  static bool _googleSignInReady = false;

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
    // Best-effort: native Google sign-in just falls back to unavailable
    // (callers still get a clear error) if this fails, it shouldn't block
    // the rest of the app from starting.
    try {
      await _initGoogleSignIn();
    } catch (_) {
      _googleSignInReady = false;
    }
  }

  static Future<void> _initGoogleSignIn() async {
    _googleNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(_googleNonce!)).toString();
    await GoogleSignIn.instance.initialize(
      serverClientId: _googleWebClientId,
      nonce: hashedNonce,
    );
    _googleSignInReady = true;
  }

  static String _generateNonce([int length = 32]) {
    const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// Native Google sign-in: shows the OS account-chooser in-app (Credential
  /// Manager on Android) instead of a browser round-trip, then exchanges the
  /// resulting ID token for a Supabase session. Throws [GoogleSignInException]
  /// with code [GoogleSignInExceptionCode.canceled] if the user dismisses the
  /// picker -- callers should treat that as a silent no-op, not an error.
  static Future<void> signInWithGoogleNative() async {
    if (!_googleSignInReady) {
      await _initGoogleSignIn();
    }
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('Google sign-in did not return an ID token.');
    }
    await client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      nonce: _googleNonce,
    );
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
