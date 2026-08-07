import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cottage/constants/theme.dart';

/// Vertical cross-slide used to swap the Login/Signup form content in place
/// (see [LoginScreen]): the outgoing form slides up and fades out while the
/// incoming form slides up from below the fold and fades in, simultaneously
/// -- unlike a route push, the surrounding hero panel never rebuilds, so it
/// reads as "fixed" while only the form swaps underneath it.
///
/// [child] must carry a [Key] that changes whenever the content changes
/// (e.g. `ValueKey(mode)`) so the switch can be detected.
class AuthFormSwitcher extends StatefulWidget {
  const AuthFormSwitcher({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 620),
  });

  final Widget child;
  final Duration duration;

  @override
  State<AuthFormSwitcher> createState() => _AuthFormSwitcherState();
}

class _AuthFormSwitcherState extends State<AuthFormSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Widget? _oldChild;
  late Widget _newChild;

  @override
  void initState() {
    super.initState();
    _newChild = widget.child;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant AuthFormSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.child.key != oldWidget.child.key) {
      _oldChild = oldWidget.child;
      _newChild = widget.child;
      _controller
        ..value = 0
        ..forward().whenComplete(() {
          if (mounted) setState(() => _oldChild = null);
        });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    // Clipped so a form sliding up and out never overflows above this
    // switcher's own bounds -- i.e. it disappears at the boundary with the
    // hero panel above, never visibly crossing onto the brand-color area.
    return ClipRect(
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          if (_oldChild != null)
            SlideTransition(
              position: Tween<Offset>(
                begin: Offset.zero,
                end: const Offset(0, -1),
              ).animate(curved),
              child: FadeTransition(
                opacity: Tween<double>(begin: 1, end: 0).animate(curved),
                child: _oldChild,
              ),
            ),
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: _newChild),
          ),
        ],
      ),
    );
  }
}

/// Shared building blocks for the auth screens (Login/Signup/ForgotPassword)
/// so all three stay pixel-consistent with the web app's mobile auth layout
/// (src/app/login, src/app/signup, src/app/forgot-password).

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

/// Inline "[icon] Cottage" chip used inside the Login/Register subtitle line
/// (Figma: "Sign in to your [icon]Cottage account as a member") -- a small
/// rounded logo mark next to the bold brand name, wrapped in a [Wrap] by the
/// caller alongside the surrounding plain-text spans so the whole sentence
/// reflows naturally on narrow screens.
class AuthInlineBrand extends StatelessWidget {
  const AuthInlineBrand({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20 * 0.22),
          child: Image.asset('assets/images/logo.png', width: 20, height: 20),
        ),
        const SizedBox(width: 5),
        const Text(
          'Cottage',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: CottageColors.primary,
          ),
        ),
      ],
    );
  }
}

/// The single reference for every auth screen's top "brand color greetings"
/// section -- logo size, container padding, title style, and the
/// logo-to-title/title-to-body gaps all come from Figma node 41:820
/// ("Login - Mobile") and must stay identical across every mode of
/// [LoginScreen] (Login/Signup/Forgot Password): only the [title] text and
/// the [body] below it (context line + CTA, or just a subtitle) vary.
///
/// Both cross-fade in place when they change -- keyed by their own value,
/// so [title] only animates when the text actually differs (e.g. switching
/// into/out of Forgot Password), not on every mode change.
class AuthHero extends StatelessWidget {
  const AuthHero({super.key, required this.title, required this.body});

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: const BoxDecoration(
        color: CottageColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(48)),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(40 * 0.22),
            child: Container(
              width: 40,
              height: 40,
              color: Colors.white,
              padding: const EdgeInsets.all(3),
              child: Image.asset('assets/images/logo.png'),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              title,
              key: ValueKey(title),
              textAlign: TextAlign.center,
              style: GoogleFonts.archivo(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          body,
        ],
      ),
    );
  }
}

/// Body text style shared by every [AuthHero] subtitle/context line
/// (fontSize 14, white @ 85% opacity) -- so Forgot Password's plain
/// subtitle and Login/Signup's context line render identically.
TextStyle authHeroBodyTextStyle() =>
    TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.85));

/// Slightly darker orange used by the "Login"/"Register" titles and their
/// primary buttons per Figma nodes 41:820 ("Login - Mobile") and 43:841
/// ("Register - Mobile") -- distinct from [CottageColors.primary] used on
/// the hero panel above them.
const kAuthTitleColor = Color(0xFFD1593B);

/// Auth field styling for the "Login/Register - Mobile" Figma spec: flat
/// #FAFAFA fill, thin #EEE border, 10px radius, no leading icon --
/// visually simpler than [AuthTextField], which those two screens no
/// longer use.
class MobileAuthField extends StatefulWidget {
  const MobileAuthField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.required = true,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.validator,
    this.textInputAction,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool required;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<String>? autofillHints;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;

  @override
  State<MobileAuthField> createState() => _MobileAuthFieldState();
}

class _MobileAuthFieldState extends State<MobileAuthField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF404040)),
            ),
            if (widget.required) ...[
              const SizedBox(width: 2),
              const Text(
                '*',
                style: TextStyle(fontSize: 13, color: Color(0xFFCC4F4F)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          autofillHints: widget.autofillHints,
          validator: widget.validator,
          textInputAction: widget.textInputAction,
          style: const TextStyle(fontSize: 13, color: Color(0xFF404040)),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            hintText: widget.hint,
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: const Color(0xFFAAAAAA),
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : null,
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
              borderSide: const BorderSide(color: kAuthTitleColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: CottageColors.destructive),
            ),
          ),
        ),
      ],
    );
  }
}

/// Thin-line "Or" divider per the "Login/Register - Mobile" spec -- a plain
/// hairline either side of a small grey "Or" label (vs. [AuthOrDivider]'s
/// bolder "OR" chip used elsewhere).
class MobileOrDivider extends StatelessWidget {
  const MobileOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: Divider(color: Color(0xFFEEEEEE), height: 1, thickness: 1),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Or',
            style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
          ),
        ),
        Expanded(
          child: Divider(color: Color(0xFFEEEEEE), height: 1, thickness: 1),
        ),
      ],
    );
  }
}

/// Filled grey "Continue with Google" pill per the "Login/Register -
/// Mobile" spec -- solid #EEE fill (vs. [GoogleSignInButton]'s outlined
/// style).
class MobileGoogleButton extends StatelessWidget {
  const MobileGoogleButton({
    super.key,
    required this.onPressed,
    required this.enabled,
  });

  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEEEEEE),
          disabledBackgroundColor: const Color(0xFFEEEEEE),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const GoogleGlyph(size: 24),
            const SizedBox(width: 8),
            Text(
              'Continue with Google',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF242424),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
