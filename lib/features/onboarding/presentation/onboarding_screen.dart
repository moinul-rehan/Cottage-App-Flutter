import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/helpers/onboarding_service.dart';

class _OnboardingSlide {
  final String image;
  final String title;
  final String subtitle;
  const _OnboardingSlide({
    required this.image,
    required this.title,
    required this.subtitle,
  });
}

const _slides = [
  _OnboardingSlide(
    image: 'assets/images/onboarding_1.png',
    title: 'Welcome to your Cottage',
    subtitle:
        'Split rent, bills, and daily expenses with your roommates — all organized in one simple app.',
  ),
  _OnboardingSlide(
    image: 'assets/images/onboarding_2.png',
    title: 'Meals & Bazar, Sorted',
    subtitle:
        'Log daily meals and rotate bazar duty automatically, so nobody keeps track on paper.',
  ),
  _OnboardingSlide(
    image: 'assets/images/onboarding_3.png',
    title: 'Know Who Owes What',
    subtitle:
        'See monthly dues, deposits, and balances at a glance — no more awkward money talks.',
  ),
];

/// First-launch onboarding carousel (Figma node 73:1061, "Onboarding
/// screen 1/2/3") -- three full-bleed photo slides with a title/subtitle
/// over a bottom gradient, pill progress dots, and back/next controls.
/// Shown once ever (see [OnboardingService]) before the auth gate.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onFinished});

  /// Optional extra hook run after [OnboardingService.markComplete].
  /// Navigation itself doesn't need this: the root widget already listens
  /// to [OnboardingService.completed] and swaps away reactively.
  final VoidCallback? onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await OnboardingService.markComplete();
    widget.onFinished?.call();
  }

  void _next() {
    if (_index == _slides.length - 1) {
      _finish();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _back() {
    if (_index == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) =>
                  _OnboardingSlideView(slide: _slides[i]),
            ),
            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Row(
                      children: [
                        Row(
                          children: [
                            for (var i = 0; i < _slides.length; i++) ...[
                              if (i > 0) const SizedBox(width: 6),
                              _ProgressDot(active: i == _index),
                            ],
                          ],
                        ),
                        const Spacer(),
                        _RoundButton(
                          icon: Icons.chevron_left_rounded,
                          filled: false,
                          onTap: _index == 0 ? null : _back,
                        ),
                        const SizedBox(width: 12),
                        _RoundButton(
                          icon: Icons.chevron_right_rounded,
                          filled: true,
                          onTap: _next,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlideView extends StatelessWidget {
  final _OnboardingSlide slide;
  const _OnboardingSlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(slide.image, fit: BoxFit.cover),
        // Top gradient: keeps the status bar legible over a bright photo.
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            height: 140,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xE6000000), Colors.transparent],
              ),
            ),
          ),
        ),
        // Bottom gradient: keeps the title/subtitle/controls legible.
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 420,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black, Colors.transparent],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 100),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    slide.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    slide.subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFEEEEEE),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressDot extends StatelessWidget {
  final bool active;
  const _ProgressDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: active ? 27 : 15,
      height: 5,
      decoration: BoxDecoration(
        color: active ? CottageColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;
  const _RoundButton({
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: filled ? CottageColors.primary : Colors.transparent,
          border: filled
              ? null
              : Border.all(
                  color: Colors.white.withValues(alpha: enabled ? 1 : 0.4),
                ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: enabled || filled ? 1 : 0.4),
          size: 24,
        ),
      ),
    );
  }
}
