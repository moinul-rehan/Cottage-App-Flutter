import 'package:flutter/material.dart';
import 'package:cottage/constants/theme.dart';

/// Shared building blocks for the auth screens (Login/Signup/ForgotPassword)
/// so all three stay pixel-consistent with the web app's mobile auth layout
/// (src/app/login, src/app/signup, src/app/forgot-password).
///
/// Uses the same `public/logo.png` asset as the web's `<Logo size={32} />`
/// (copied to `assets/images/logo.png`, registered in pubspec.yaml), with the
/// same `rounded-[22%]` corner treatment.
class AuthWordmark extends StatelessWidget {
  const AuthWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(32 * 0.22),
          child: Image.asset('assets/images/logo.png', width: 32, height: 32),
        ),
        const SizedBox(width: 8),
        Text(
          'Cottage',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
            color: context.surface.foreground,
          ),
        ),
      ],
    );
  }
}

/// Mirrors the web's `<Input className="h-12 rounded-2xl px-4 text-base" />`
/// styling: 48px tall, 24px-radius rounded corners, muted/40%-opacity fill.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.validator,
    this.textInputAction,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<String>? autofillHints;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: surface.foreground),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          validator: validator,
          textInputAction: textInputAction,
          style: TextStyle(fontSize: 16, color: surface.foreground),
          decoration: InputDecoration(
            filled: true,
            fillColor: surface.muted.withValues(alpha: 0.4),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: surface.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: surface.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: CottageColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: CottageColors.destructive),
            ),
          ),
        ),
      ],
    );
  }
}

/// Rounded pill error banner: `bg-destructive/10 text-destructive`.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CottageColors.destructive.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: const TextStyle(color: CottageColors.destructive, fontSize: 14)),
    );
  }
}

/// Rounded success banner used by Forgot Password -- web hardcodes emerald
/// here rather than a theme token (`bg-emerald-50 text-emerald-700`).
class AuthSuccessBanner extends StatelessWidget {
  const AuthSuccessBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF047857), fontSize: 14),
      ),
    );
  }
}

/// A horizontal rule with a centered "Or" label cutting through it, matching
/// the web's absolutely-positioned divider + centered uppercase label combo.
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return SizedBox(
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Divider(color: surface.border, thickness: 1, height: 1),
          Container(
            color: surface.background,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'OR',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 0.5,
                color: surface.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Standard 4-color Google "G" glyph, painted to match src/components/google-icon.tsx.
class GoogleGlyph extends StatelessWidget {
  const GoogleGlyph({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGlyphPainter()),
    );
  }
}

class _GoogleGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.save();
    canvas.scale(scale, scale);

    final blue = Paint()..color = const Color(0xFF4285F4);
    final green = Paint()..color = const Color(0xFF34A853);
    final yellow = Paint()..color = const Color(0xFFFBBC05);
    final red = Paint()..color = const Color(0xFFEA4335);

    final bluePath = Path()
      ..moveTo(23.52, 12.27)
      ..cubicTo(23.52, 11.42, 23.44, 10.6, 23.3, 9.82)
      ..lineTo(12, 9.82)
      ..lineTo(12, 14.46)
      ..lineTo(18.47, 14.46)
      ..cubicTo(18.19, 15.99, 17.32, 17.29, 16.07, 18.09)
      ..lineTo(16.07, 21.09)
      ..lineTo(19.96, 21.09)
      ..cubicTo(22.24, 18.99, 23.52, 15.89, 23.52, 12.27)
      ..close();
    canvas.drawPath(bluePath, blue);

    final greenPath = Path()
      ..moveTo(12, 24)
      ..cubicTo(15.24, 24, 17.96, 22.93, 19.95, 21.09)
      ..lineTo(16.06, 18.09)
      ..cubicTo(14.98, 18.81, 13.6, 19.24, 12, 19.24)
      ..cubicTo(8.88, 19.24, 6.23, 17.13, 5.29, 14.3)
      ..lineTo(1.27, 14.3)
      ..lineTo(1.27, 17.4)
      ..cubicTo(3.26, 21.3, 7.31, 24, 12, 24)
      ..close();
    canvas.drawPath(greenPath, green);

    final yellowPath = Path()
      ..moveTo(5.29, 14.3)
      ..cubicTo(5.05, 13.57, 4.91, 12.8, 4.91, 12)
      ..cubicTo(4.91, 11.2, 5.05, 10.43, 5.29, 9.7)
      ..lineTo(5.29, 6.6)
      ..lineTo(1.27, 6.6)
      ..cubicTo(0.46, 8.23, 0, 10.06, 0, 12)
      ..cubicTo(0, 13.94, 0.46, 15.77, 1.27, 17.4)
      ..lineTo(5.29, 14.3)
      ..close();
    canvas.drawPath(yellowPath, yellow);

    final redPath = Path()
      ..moveTo(12, 4.75)
      ..cubicTo(13.76, 4.75, 15.34, 5.35, 16.58, 6.54)
      ..lineTo(20.02, 3.1)
      ..cubicTo(17.95, 1.19, 15.24, 0, 12, 0)
      ..cubicTo(7.31, 0, 3.26, 2.7, 1.27, 6.6)
      ..lineTo(5.29, 9.7)
      ..cubicTo(6.23, 6.86, 8.88, 4.75, 12, 4.75)
      ..close();
    canvas.drawPath(redPath, red);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Outline "Continue with Google" button -- background = page background
/// (NOT primary-filled), bordered, pill-shaped, 48px tall.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, required this.onPressed, this.enabled = true});

  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: surface.background,
          side: BorderSide(color: surface.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const GoogleGlyph(size: 20),
            const SizedBox(width: 10),
            Text(
              'Continue with Google',
              style: TextStyle(fontSize: 16, color: surface.foreground, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
