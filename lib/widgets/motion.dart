import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'stock_widgets.dart';

/// Progress bar that fills smoothly, from 0 on first build and from the old
/// value whenever it changes (e.g. after a deposit).
class AnimatedProgressBar extends StatelessWidget {
  final double value; // 0..1
  final double height;
  final Color color;
  final Color background;
  final Duration duration;
  const AnimatedProgressBar({
    super.key,
    required this.value,
    required this.color,
    required this.background,
    this.height = 10,
    this.duration = const Duration(milliseconds: 1100),
  });

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: Stack(children: [
            Container(height: height, color: background),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: v,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(height),
                  gradient: LinearGradient(colors: [color.withValues(alpha: 0.75), color]),
                ),
              ),
            ),
          ]),
        ),
      );
}

/// A money amount that counts up to its value.
class CountUpMoney extends StatelessWidget {
  final double value;
  final TextStyle style;
  final Duration duration;
  const CountUpMoney(this.value, {super.key, required this.style, this.duration = const Duration(milliseconds: 1100)});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Text(money(v), style: style),
      );
}

/// A percentage that counts up.
class CountUpPercent extends StatelessWidget {
  final double value; // 0..1
  final TextStyle style;
  const CountUpPercent(this.value, {super.key, required this.style});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble() * 100),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Text('${v.round()}%', style: style),
      );
}

/// Illustration that gently floats, for goal cards.
class FloatingArt extends StatefulWidget {
  final String asset;
  final double height;
  final bool animate;
  const FloatingArt(this.asset, {super.key, required this.height, this.animate = true});
  @override
  State<FloatingArt> createState() => _FloatingArtState();
}

class _FloatingArtState extends State<FloatingArt> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(FloatingArt old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.animate && _c.isAnimating) {
      _c.animateTo(0, duration: const Duration(milliseconds: 300));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final art = SvgPicture.asset(widget.asset, height: widget.height, fit: BoxFit.contain);
    if (MediaQuery.of(context).disableAnimations) return art;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.translate(offset: Offset(0, -4 * Curves.easeInOut.transform(_c.value)), child: child),
      child: art,
    );
  }
}
