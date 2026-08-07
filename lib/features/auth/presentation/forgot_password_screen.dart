import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cottage/helpers/supabase_service.dart';
import 'package:cottage/constants/theme.dart';
import 'widgets/auth_widgets.dart';

/// Pixel-faithful mobile port of src/app/forgot-password/page.tsx +
/// ForgotPasswordForm.tsx.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _submitting = false;
  bool _success = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await SupabaseService.client.auth.resetPasswordForEmail(_emailController.text.trim());
      if (!mounted) return;
      setState(() => _success = true);
    } on AuthException {
      setState(() => _error = 'Could not send reset link. Please try again.');
    } catch (_) {
      setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
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
                        'Reset your password',
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: context.surface.foreground),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Enter the email on your account and we'll send you a link to reset your password.",
                        style: TextStyle(fontSize: 14, color: context.surface.mutedForeground),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  if (_success)
                    const AuthSuccessBanner(message: 'Check your email for a link to reset your password.')
                  else
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
                            textInputAction: TextInputAction.done,
                            validator: (value) =>
                                (value == null || value.trim().isEmpty) ? 'Email is required' : null,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Text(_error!, style: const TextStyle(color: CottageColors.destructive, fontSize: 14)),
                          ],
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _submitting ? null : _submit,
                            child: Text(_submitting ? 'Sending…' : 'Send reset link'),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 32),
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Back to sign in',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CottageColors.primary),
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
