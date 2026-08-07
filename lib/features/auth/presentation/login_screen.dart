import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Figma node 1:3661 "Login page": the desktop split-panel's
              // orange side becomes this rounded-bottom hero banner on
              // mobile, with the same "switch to the other auth screen" CTA.
              AuthHeroPanel(
                contextLine: "Don't have a Cottage?",
                ctaLabel: 'Create your own Cottage',
                onCtaPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 384),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Login',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.archivo(
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                            color: CottageColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          children: [
                            Text('Sign in to your', style: TextStyle(fontSize: 14, color: context.surface.mutedForeground)),
                            const AuthInlineBrand(),
                            Text('account as a member', style: TextStyle(fontSize: 14, color: context.surface.mutedForeground)),
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
                                required: true,
                                leadingIcon: Icons.mail_outline,
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
                                required: true,
                                leadingIcon: Icons.lock_outline,
                                controller: _passwordController,
                                obscureText: true,
                                autofillHints: const [AutofillHints.password],
                                textInputAction: TextInputAction.done,
                                validator: (value) =>
                                    (value == null || value.isEmpty) ? 'Password is required' : null,
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.center,
                                child: GestureDetector(
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                                  ),
                                  child: const Text(
                                    'Forgot password?',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFD40924)),
                                  ),
                                ),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 10),
                                Text(_error!, style: const TextStyle(color: CottageColors.destructive, fontSize: 14)),
                              ],
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _submitting ? null : _submit,
                                child: Text(_submitting ? 'Signing in…' : 'Sign In'),
                              ),
                              const SizedBox(height: 16),
                              const AuthOrDivider(),
                              const SizedBox(height: 16),
                              GoogleSignInButton(onPressed: _signInWithGoogle, enabled: !_googleSubmitting),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
