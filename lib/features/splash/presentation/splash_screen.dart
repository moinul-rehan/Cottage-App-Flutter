import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/constants/app_constants.dart';

/// First screen shown on launch: solid brand-orange background, the logo
/// spins like a loading spinner and decelerates to a stop, then the
/// "Cottage" wordmark fades/slides into place under it, then [onFinished]
/// fires so the caller can cross-fade into onboarding/the app. The app
/// version is pinned to the bottom throughout.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const _spinInterval = Interval(0.0, 0.55, curve: Curves.easeOutCubic);
  static const _wordmarkInterval = Interval(0.55, 0.9, curve: Curves.easeOutCubic);

  late final AnimationController _controller;
  late final Animation<double> _spin;
  late final Animation<double> _wordmarkOpacity;
  late final Animation<Offset> _wordmarkSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));

    // 3 full spins, fast at first and easing to a smooth stop -- like a
    // spinner winding down rather than an abrupt cut.
    _spin = Tween<double>(begin: 0, end: 3 * 2 * math.pi).animate(CurvedAnimation(parent: _controller, curve: _spinInterval));

    _wordmarkOpacity = CurvedAnimation(parent: _controller, curve: _wordmarkInterval);
    _wordmarkSlide = Tween<Offset>(begin: const Offset(0, -0.35), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: _wordmarkInterval));

    _controller.forward().whenComplete(() async {
      await Future.delayed(const Duration(milliseconds: 350));
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CottageColors.primary,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _spin,
                    builder: (context, child) => Transform.rotate(angle: _spin.value, child: child),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(96 * 0.22),
                      child: Container(
                        width: 96,
                        height: 96,
                        color: Colors.white,
                        padding: const EdgeInsets.all(8),
                        child: Image.asset('assets/images/logo.png'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeTransition(
                    opacity: _wordmarkOpacity,
                    child: SlideTransition(
                      position: _wordmarkSlide,
                      child: const Text(
                        AppConstants.appName,
                        style: TextStyle(
                          fontFamily: kAppFontFamily,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Text(
                'v${AppConstants.version}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: kAppFontFamily,
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
