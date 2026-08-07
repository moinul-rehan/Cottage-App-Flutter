import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cottage/helpers/supabase_service.dart';
import 'package:cottage/constants/theme.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';
import 'widgets/auth_widgets.dart';

/// Pixel-faithful mobile port of src/app/login/page.tsx + LoginForm.tsx.
/// Includes email/password sign-in, Google sign-in, "Forgot password?", and
/// the "Sign up for a new Cottage" footer link -- all present, none deferred.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  bool _googleSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      // No manual navigation on success -- the root _AuthGate (main.dart)
      // listens to onAuthStateChange and swaps to BottomNavShell on its own,
      // the same mechanism Google sign-in's async deep-link return relies on.
      await SupabaseService.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on AuthException {
      setState(() => _error = 'Invalid email or password.');
    } catch (_) {
      setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Mirrors LoginForm.tsx's handleGoogleLogin, using Supabase's OAuth flow.
  /// The browser round-trip redirects to [SupabaseService.oauthRedirectUrl],
  /// which the OS hands back to this app via the intent-filter/URL-scheme
  /// registered in AndroidManifest.xml/Info.plist; the root _AuthGate
  /// (main.dart) then picks up the resulting session automatically.
  Future<void> _signInWithGoogle() async {
    setState(() => _googleSubmitting = true);
    try {
      await SupabaseService.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: SupabaseService.oauthRedirectUrl,
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _googleSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 384),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthWordmark(),
                  const SizedBox(height: 32),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back',
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: context.surface.foreground),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sign in with the account your admin created for you.',
                        style: TextStyle(fontSize: 14, color: context.surface.mutedForeground),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AuthTextField(
                          label: 'Email',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          validator: (value) =>
                              (value == null || value.trim().isEmpty) ? 'Email is required' : null,
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          label: 'Password',
                          controller: _passwordController,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          validator: (value) =>
                              (value == null || value.isEmpty) ? 'Password is required' : null,
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                            ),
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: CottageColors.primary),
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(_error!, style: const TextStyle(color: CottageColors.destructive, fontSize: 14)),
                        ],
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          child: Text(_submitting ? 'Signing in…' : 'Sign in as Cottage member'),
                        ),
                        const SizedBox(height: 20),
                        const AuthOrDivider(),
                        const SizedBox(height: 20),
                        GoogleSignInButton(onPressed: _signInWithGoogle, enabled: !_googleSubmitting),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text.rich(
                    TextSpan(
                      style: TextStyle(fontSize: 14, color: context.surface.mutedForeground),
                      children: [
                        const TextSpan(text: 'Starting a new house? '),
                        TextSpan(
                          text: 'Sign up for a new Cottage',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: CottageColors.primary),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                                ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
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
