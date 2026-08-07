import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cottage/helpers/supabase_service.dart';
import 'package:cottage/constants/theme.dart';
import 'login_screen.dart';
import 'widgets/auth_widgets.dart';

/// Pixel-faithful mobile port of src/app/signup/page.tsx + SignupForm.tsx.
///
/// The cottage-creation logic itself is NOT reimplemented here: per
/// supabase/migrations/0003_cottages_and_multitenancy.sql, `auth.signUp` with
/// `options.data = {mode: "create_cottage", cottage_name, first_name,
/// last_name}` fires a `handle_new_user()` DB trigger that creates the
/// cottage and admin membership server-side -- exactly what
/// src/app/signup/actions.ts relies on. So calling `signUp` with the same
/// metadata from the client is a faithful, safe port; no elevated-privilege
/// operations need to happen on-device.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cottageNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  bool _googleSubmitting = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _cottageNameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
      _success = null;
    });

    try {
      final response = await SupabaseService.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'mode': 'create_cottage',
          'cottage_name': _cottageNameController.text.trim(),
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim().isEmpty ? null : _lastNameController.text.trim(),
        },
      );
      if (!mounted) return;
      if (response.session == null) {
        setState(() => _success = 'Check your email to confirm your account, then sign in.');
      }
      // If a session came back immediately (email confirmation disabled), no
      // manual navigation needed -- the root _AuthGate (main.dart) picks up
      // the new session via onAuthStateChange and pops back to it on its own.
    } on AuthException catch (e) {
      setState(() {
        _error = e.message.toLowerCase().contains('already registered')
            ? 'An account with this email already exists.'
            : 'Could not create your account.';
      });
    } catch (_) {
      setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Mirrors SignupForm.tsx's handleGoogleSignup -- see
  /// LoginScreen._signInWithGoogle's doc comment for how the deep-link
  /// redirect and auto-navigation work.
  ///
  /// NOTE (follow-up, still out of scope): unlike email/password signUp
  /// above, there's no way to pass `mode: "create_cottage"` metadata through
  /// Supabase's Google OAuth handshake from the client, so a Google account
  /// with no existing cottage will sign in successfully here but land with no
  /// cottage membership -- the web app handles this cottage-creation case in
  /// its server-side `/auth/callback?mode=signup` route, which this client
  /// button doesn't have an equivalent of yet.
  Future<void> _signUpWithGoogle() async {
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
                        'Start a Cottage',
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: context.surface.foreground),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Sign up for a new Cottage - you'll be its admin.",
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
                          label: 'Cottage name',
                          controller: _cottageNameController,
                          textInputAction: TextInputAction.next,
                          validator: (value) =>
                              (value == null || value.trim().isEmpty) ? 'Cottage name is required' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AuthTextField(
                                label: 'First name',
                                controller: _firstNameController,
                                textInputAction: TextInputAction.next,
                                validator: (value) =>
                                    (value == null || value.trim().isEmpty) ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AuthTextField(
                                label: 'Last name',
                                controller: _lastNameController,
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
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
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.done,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Password is required';
                            if (value.length < 8) return 'Password must be at least 8 characters.';
                            return null;
                          },
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(_error!, style: const TextStyle(color: CottageColors.destructive, fontSize: 14)),
                        ],
                        if (_success != null) ...[
                          const SizedBox(height: 10),
                          Text(_success!, style: const TextStyle(color: Color(0xFF059669), fontSize: 14)),
                        ],
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          child: Text(_submitting ? 'Creating your cottage…' : 'Sign up for a new Cottage'),
                        ),
                        const SizedBox(height: 20),
                        const AuthOrDivider(),
                        const SizedBox(height: 20),
                        GoogleSignInButton(onPressed: _signUpWithGoogle, enabled: !_googleSubmitting),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text.rich(
                    TextSpan(
                      style: TextStyle(fontSize: 14, color: context.surface.mutedForeground),
                      children: [
                        const TextSpan(text: 'Already have an account? '),
                        TextSpan(
                          text: 'Sign in as a Cottage member',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: CottageColors.primary),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (_) => const LoginScreen()),
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
