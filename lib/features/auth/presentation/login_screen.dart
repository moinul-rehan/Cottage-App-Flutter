import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cottage/helpers/supabase_service.dart';
import 'package:cottage/constants/theme.dart';
import 'widgets/auth_widgets.dart';

enum _AuthMode { login, signup, forgotPassword }

/// Unified Login/Signup/Forgot-Password screen -- Figma nodes 41:820
/// ("Login - Mobile"), 43:841 ("Register - Mobile"), and 50:863/50:899
/// ("Forgot Password - Mobile" + its "Sent" state). All three modes live
/// in this ONE widget instance; switching between them is a local
/// [setState], not a route push, so the hero panel is never rebuilt while
/// it happens -- only its title/context line/CTA cross-fade (see
/// [AuthHero]) and the form section below cross-slides vertically (see
/// [AuthFormSwitcher]): the outgoing form slides up and out while the
/// incoming one slides up from the bottom into view. "Forgot password?"
/// gets the exact same interaction as the Login<->Signup toggle rather
/// than a distinct push-navigated screen.
///
/// Pixel-faithful mobile port of src/app/login/page.tsx + LoginForm.tsx,
/// src/app/signup/page.tsx + SignupForm.tsx, and
/// src/app/forgot-password/page.tsx + ForgotPasswordForm.tsx. The
/// cottage-creation logic itself is NOT reimplemented here: per
/// supabase/migrations/0003_cottages_and_multitenancy.sql, `auth.signUp`
/// with `options.data = {mode: "create_cottage", cottage_name, first_name,
/// last_name}` fires a `handle_new_user()` DB trigger that creates the
/// cottage and admin membership server-side -- exactly what
/// src/app/signup/actions.ts relies on. So calling `signUp` with the same
/// metadata from the client is a faithful, safe port; no elevated-privilege
/// operations need to happen on-device.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  _AuthMode _mode = _AuthMode.login;

  // --- Login form state ---
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginSubmitting = false;
  bool _loginGoogleSubmitting = false;
  String? _loginError;

  // --- Signup form state ---
  final _signupFormKey = GlobalKey<FormState>();
  final _cottageNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _signupSubmitting = false;
  bool _signupGoogleSubmitting = false;
  String? _signupError;
  String? _signupSuccess;

  // --- Forgot password form state ---
  final _forgotFormKey = GlobalKey<FormState>();
  final _forgotEmailController = TextEditingController();
  bool _forgotSubmitting = false;
  bool _forgotSuccess = false;
  String? _forgotError;

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _cottageNameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _confirmPasswordController.dispose();
    _forgotEmailController.dispose();
    super.dispose();
  }

  /// Switches auth mode, clearing every mode's leftover error banner. Modes
  /// toggle in place via [setState] rather than a route push (see class
  /// doc), so this [State] -- and any error string set on it -- survives
  /// across switches; without this, a stale "Google sign-in failed" (or any
  /// other) banner from an earlier attempt in one mode could resurface after
  /// switching to/from an unrelated mode.
  void _switchMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _loginError = null;
      _signupError = null;
      _forgotError = null;
    });
  }

  Future<void> _submitLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() {
      _loginSubmitting = true;
      _loginError = null;
    });

    try {
      // No manual navigation on success -- the root _AuthGate (main.dart)
      // listens to onAuthStateChange and swaps to BottomNavShell on its own,
      // the same mechanism Google sign-in's async deep-link return relies on.
      await SupabaseService.client.auth.signInWithPassword(
        email: _loginEmailController.text.trim(),
        password: _loginPasswordController.text,
      );
    } on AuthException {
      setState(() => _loginError = 'Invalid email or password.');
    } catch (_) {
      setState(() => _loginError = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _loginSubmitting = false);
    }
  }

  /// Mirrors LoginForm.tsx's handleGoogleLogin, but via native Google
  /// sign-in (the OS account-chooser shown in-app, e.g. Android's Credential
  /// Manager) instead of a browser round-trip -- see
  /// [SupabaseService.signInWithGoogleNative]. The root _AuthGate
  /// (main.dart) picks up the resulting session automatically once it's set.
  Future<void> _signInWithGoogle() async {
    setState(() => _loginGoogleSubmitting = true);
    try {
      await SupabaseService.signInWithGoogleNative();
    } on GoogleSignInException catch (e) {
      // User dismissed the account picker -- not an error worth surfacing.
      if (e.code != GoogleSignInExceptionCode.canceled && mounted) {
        setState(
          () => _loginError = 'Google sign-in failed. Please try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _loginError = 'Google sign-in failed. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loginGoogleSubmitting = false);
    }
  }

  Future<void> _submitSignup() async {
    if (!_signupFormKey.currentState!.validate()) return;

    setState(() {
      _signupSubmitting = true;
      _signupError = null;
      _signupSuccess = null;
    });

    try {
      final response = await SupabaseService.client.auth.signUp(
        email: _signupEmailController.text.trim(),
        password: _signupPasswordController.text,
        data: {
          'mode': 'create_cottage',
          'cottage_name': _cottageNameController.text.trim(),
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim().isEmpty
              ? null
              : _lastNameController.text.trim(),
        },
      );
      if (!mounted) return;
      if (response.session == null) {
        setState(
          () => _signupSuccess =
              'Check your email to confirm your account, then sign in.',
        );
      }
      // If a session came back immediately (email confirmation disabled), no
      // manual navigation needed -- the root _AuthGate (main.dart) picks up
      // the new session via onAuthStateChange and pops back to it on its own.
    } on AuthException catch (e) {
      setState(() {
        _signupError = e.message.toLowerCase().contains('already registered')
            ? 'An account with this email already exists.'
            : 'Could not create your account.';
      });
    } catch (_) {
      setState(() => _signupError = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _signupSubmitting = false);
    }
  }

  /// Mirrors SignupForm.tsx's handleGoogleSignup -- see [_signInWithGoogle]'s
  /// doc comment for how native sign-in and auto-navigation work.
  ///
  /// NOTE (follow-up, still out of scope): unlike email/password signUp
  /// above, there's no way to pass `mode: "create_cottage"` metadata through
  /// Supabase's Google OAuth handshake from the client, so a Google account
  /// with no existing cottage will sign in successfully here but land with no
  /// cottage membership -- the web app handles this cottage-creation case in
  /// its server-side `/auth/callback?mode=signup` route, which this client
  /// button doesn't have an equivalent of yet.
  Future<void> _signUpWithGoogle() async {
    setState(() => _signupGoogleSubmitting = true);
    try {
      await SupabaseService.signInWithGoogleNative();
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled && mounted) {
        setState(
          () => _signupError = 'Google sign-in failed. Please try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _signupError = 'Google sign-in failed. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _signupGoogleSubmitting = false);
    }
  }

  Future<void> _submitForgotPassword() async {
    if (!_forgotFormKey.currentState!.validate()) return;

    setState(() {
      _forgotSubmitting = true;
      _forgotError = null;
    });

    try {
      // Without an explicit redirectTo, Supabase falls back to the
      // project's dashboard "Site URL" -- which is the web app's own
      // domain -- so the email link opens a browser straight into the web
      // dashboard (the recovery session alone reads as "logged in" there)
      // instead of ever reaching this app. Reusing the same custom-scheme
      // redirect already registered for Google sign-in (see
      // [SupabaseService.oauthRedirectUrl] and the matching intent-filter in
      // AndroidManifest.xml/Info.plist -- already allow-listed in Supabase's
      // Auth > URL Configuration > Redirect URLs for that flow) makes the
      // link open this app instead, where supabase_flutter's built-in deep
      // link handling picks up the recovery session and _AuthGate (main.dart)
      // routes to [ResetPasswordScreen].
      await SupabaseService.client.auth.resetPasswordForEmail(
        _forgotEmailController.text.trim(),
        redirectTo: SupabaseService.oauthRedirectUrl,
      );
      if (!mounted) return;
      setState(() => _forgotSuccess = true);
    } on AuthException {
      setState(
        () => _forgotError = 'Could not send reset link. Please try again.',
      );
    } catch (_) {
      setState(() => _forgotError = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _forgotSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget form;
    switch (_mode) {
      case _AuthMode.login:
        form = KeyedSubtree(
          key: const ValueKey('login'),
          child: _buildLoginForm(),
        );
        break;
      case _AuthMode.signup:
        form = KeyedSubtree(
          key: const ValueKey('signup'),
          child: _buildSignupForm(),
        );
        break;
      case _AuthMode.forgotPassword:
        form = KeyedSubtree(
          key: const ValueKey('forgot'),
          child: _buildForgotPasswordForm(),
        );
        break;
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Fixed in place (outside the form switcher) so it stays
            // visible -- and visually static -- while the form below
            // cross-slides between modes; only its title/body cross-fade
            // (see [AuthHero]) whenever they actually change.
            AuthHero(
              title: _mode == _AuthMode.forgotPassword
                  ? 'Reset your password'
                  : 'Welcome to Cottage!',
              body: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _buildHeroBody(),
              ),
            ),
            Expanded(child: AuthFormSwitcher(child: form)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBody() {
    if (_mode == _AuthMode.forgotPassword) {
      return Text(
        "We'll email you a secure reset link",
        key: const ValueKey('forgot-body'),
        textAlign: TextAlign.center,
        style: authHeroBodyTextStyle(),
      );
    }
    final isLogin = _mode == _AuthMode.login;
    return Column(
      key: ValueKey(isLogin ? 'login-body' : 'signup-body'),
      children: [
        Text(
          isLogin
              ? "Don't have a Cottage?"
              : 'Already a member of any Cottage?',
          textAlign: TextAlign.center,
          style: authHeroBodyTextStyle(),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () =>
              _switchMode(isLogin ? _AuthMode.signup : _AuthMode.login),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            isLogin ? 'Create your own Cottage' : 'Log In',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return SingleChildScrollView(
      child: Padding(
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
                    fontSize: 30,
                    fontWeight: FontWeight.w500,
                    color: kAuthTitleColor,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    const Text(
                      'Sign in to your',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B727E)),
                    ),
                    const AuthInlineBrand(),
                    const Text(
                      'account as a member',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B727E)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Form(
                  key: _loginFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MobileAuthField(
                        label: 'Email',
                        hint: 'johndoe@gmail.com',
                        controller: _loginEmailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Email is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      MobileAuthField(
                        label: 'Password',
                        hint: '••••••••',
                        controller: _loginPasswordController,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Password is required'
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.center,
                        child: GestureDetector(
                          onTap: () => _switchMode(_AuthMode.forgotPassword),
                          child: const Text(
                            'Forgot password?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFD40924),
                            ),
                          ),
                        ),
                      ),
                      if (_loginError != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _loginError!,
                          style: const TextStyle(
                            color: CottageColors.destructive,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loginSubmitting ? null : _submitLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAuthTitleColor,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          textStyle: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: _loginSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Sign In'),
                      ),
                      const SizedBox(height: 16),
                      const MobileOrDivider(),
                      const SizedBox(height: 16),
                      MobileGoogleButton(
                        onPressed: _signInWithGoogle,
                        enabled: !_loginGoogleSubmitting,
                        loading: _loginGoogleSubmitting,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignupForm() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 384),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Register',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.archivo(
                    fontSize: 30,
                    fontWeight: FontWeight.w500,
                    color: kAuthTitleColor,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    const Text(
                      'Sign up for new',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B727E)),
                    ),
                    const AuthInlineBrand(),
                    const Text(
                      '· You\'ll be its admin',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B727E)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Form(
                  key: _signupFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MobileAuthField(
                        label: 'Cottage Name',
                        hint: 'e.g. Rose Villa',
                        controller: _cottageNameController,
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Cottage name is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: MobileAuthField(
                              label: 'First Name',
                              hint: 'John',
                              required: false,
                              controller: _firstNameController,
                              textInputAction: TextInputAction.next,
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MobileAuthField(
                              label: 'Last Name',
                              hint: 'Doe',
                              required: false,
                              controller: _lastNameController,
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      MobileAuthField(
                        label: 'Email',
                        hint: 'johndoe@gmail.com',
                        controller: _signupEmailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Email is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: MobileAuthField(
                              label: 'Password',
                              hint: '••••••••',
                              controller: _signupPasswordController,
                              obscureText: true,
                              autofillHints: const [AutofillHints.newPassword],
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                if (value.length < 8) return 'Min 8 characters';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MobileAuthField(
                              label: 'Confirm',
                              hint: '••••••••',
                              controller: _confirmPasswordController,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              validator: (value) =>
                                  value != _signupPasswordController.text
                                  ? "Doesn't match"
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      if (_signupError != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _signupError!,
                          style: const TextStyle(
                            color: CottageColors.destructive,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      if (_signupSuccess != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _signupSuccess!,
                          style: const TextStyle(
                            color: Color(0xFF059669),
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _signupSubmitting ? null : _submitSignup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAuthTitleColor,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          textStyle: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: _signupSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Sign up for a new Cottage'),
                      ),
                      const SizedBox(height: 16),
                      const MobileOrDivider(),
                      const SizedBox(height: 16),
                      MobileGoogleButton(
                        onPressed: _signUpWithGoogle,
                        enabled: !_signupGoogleSubmitting,
                        loading: _signupGoogleSubmitting,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPasswordForm() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 384),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_forgotSuccess)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5EC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Check your email for a link to reset your password.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF059669)),
                    ),
                  )
                else ...[
                  const Text(
                    "Enter the email on your account and we'll send you a link to reset your password.",
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B727E)),
                  ),
                  const SizedBox(height: 16),
                  Form(
                    key: _forgotFormKey,
                    child: MobileAuthField(
                      label: 'Email',
                      hint: 'johndoe@gmail.com',
                      controller: _forgotEmailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.done,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Email is required'
                          : null,
                    ),
                  ),
                  if (_forgotError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _forgotError!,
                      style: const TextStyle(
                        color: CottageColors.destructive,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _forgotSubmitting ? null : _submitForgotPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAuthTitleColor,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      textStyle: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: _forgotSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Send reset link'),
                  ),
                ],
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: () => _switchMode(_AuthMode.login),
                    child: const Text(
                      'Back to sign in',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kAuthTitleColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
