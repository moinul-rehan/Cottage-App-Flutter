import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/helpers/supabase_service.dart';

/// Password-gated confirmation for destructive/administrative actions (the
/// Months screen's "All actions require your password to confirm"). Rather
/// than inventing a bespoke check, this re-authenticates the signed-in
/// user's own email/password pair via Supabase -- a wrong password fails
/// exactly the way signing in with a wrong password does, and a right one
/// proves it's really them without needing any new backend endpoint.
///
/// Returns true once the password has been verified and the dialog
/// dismissed for a real confirm; false/null if the user cancelled.
Future<bool> showPasswordConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: const Color(0x8C0F0F0F),
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      return FadeScaleTransition(animation: animation, child: child);
    },
    pageBuilder: (ctx, animation, secondaryAnimation) => _PasswordConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      destructive: destructive,
    ),
  );
  return result ?? false;
}

class _PasswordConfirmDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;

  const _PasswordConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.destructive,
  });

  @override
  State<_PasswordConfirmDialog> createState() => _PasswordConfirmDialogState();
}

class _PasswordConfirmDialogState extends State<_PasswordConfirmDialog> {
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final password = _passwordCtrl.text;
    final email = SupabaseService.currentUser?.email;
    if (password.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }
    if (email == null) {
      setState(
        () => _error = 'Could not verify your account. Try signing in again.',
      );
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (mounted) Navigator.pop(context, true);
    } on AuthException {
      setState(() {
        _verifying = false;
        _error = 'Incorrect password.';
      });
    } catch (e) {
      setState(() {
        _verifying = false;
        _error = 'Could not verify your password. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        width: 311,
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 32,
              offset: const Offset(0, 12),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.destructive
                      ? const Color(0xFFFFE9E9)
                      : const Color(0xFFFBE9E2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: 24,
                  color: widget.destructive
                      ? const Color(0xFFCC4F4F)
                      : CottageColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2A2A2A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Color(0xFF707070),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              autofocus: true,
              onSubmitted: (_) => _confirm(),
              decoration: InputDecoration(
                hintText: 'Your password',
                filled: true,
                fillColor: const Color(0xFFFAFAFA),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFCC4F4F)),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _DialogButton(
                    label: 'Cancel',
                    onTap: _verifying
                        ? null
                        : () => Navigator.pop(context, false),
                    background: Colors.white,
                    textColor: const Color(0xFF404040),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DialogButton(
                    label: _verifying ? 'Verifying…' : widget.confirmLabel,
                    onTap: _verifying ? null : _confirm,
                    background: widget.destructive
                        ? const Color(0xFFCC4F4F)
                        : CottageColors.primary,
                    textColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color background;
  final Color textColor;
  final BoxBorder? border;

  const _DialogButton({
    required this.label,
    required this.onTap,
    required this.background,
    required this.textColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(1000),
          border: border,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
