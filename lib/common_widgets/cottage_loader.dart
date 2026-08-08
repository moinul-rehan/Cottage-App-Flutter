import 'package:flutter/material.dart';

/// A reusable loading spinner that uses the Cottage logo spinning continuously,
/// matching the style of the splash screen.
class CottageLoader extends StatefulWidget {
  final double size;
  
  const CottageLoader({
    super.key,
    this.size = 48.0,
  });

  @override
  State<CottageLoader> createState() => _CottageLoaderState();
}

class _CottageLoaderState extends State<CottageLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // A faster rotation duration (1000ms)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    // Easing curve: starts slow, goes fast in the middle, slows down at the end
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _animation,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.size * 0.22),
        child: Container(
          width: widget.size,
          height: widget.size,
          color: Colors.white,
          padding: EdgeInsets.all(widget.size * 0.08),
          child: Image.asset('assets/images/logo.png'),
        ),
      ),
    );
  }
}
