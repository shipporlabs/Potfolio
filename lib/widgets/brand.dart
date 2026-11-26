import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

/// Colours for one rendering of the mark.
class MarkPalette {
  final Color a, b, c, e, k;
  const MarkPalette(this.a, this.b, this.c, this.e, this.k);
  static const light = MarkPalette(PColors.blue, PColors.midBlue, PColors.sky, PColors.clay, PColors.navy);
  static const onNavy = MarkPalette(Color(0xFF3D7BFF), Color(0xFF6F9BFF), Color(0xFFA8C2FF), Color(0xFFF08A5D), Colors.white);
  static const onBlue = MarkPalette(Colors.white, Color(0xFFCCDCFF), PColors.sky, Color(0xFFFFB48F), Colors.white);
}

/// The Potfolio mark: a P whose bowl is a segmented portfolio ring with a kolo neck.
/// Drawn on a 120x120 grid, matching the brand artwork.
class PotfolioMark extends StatelessWidget {
  final double size;
  final MarkPalette palette;
  final Color background;
  const PotfolioMark({super.key, this.size = 40, this.palette = MarkPalette.light, this.background = Colors.white});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Potfolio',
        image: true,
        child: CustomPaint(size: Size.square(size), painter: _MarkPainter(palette, background)),
      );
}

class _MarkPainter extends CustomPainter {
  final MarkPalette p;
  final Color bg;
  _MarkPainter(this.p, this.bg);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 120;
    canvas.save();
    canvas.scale(s);
    canvas.translate(4, 0);
    final fill = Paint()..style = PaintingStyle.fill;
    // kolo neck
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(51, 12, 16, 16), const Radius.circular(5)), fill..color = p.k);
    // ring segments (start angle degrees, arc length in px along r=22)
    const r = 22.0;
    final rect = Rect.fromCircle(center: const Offset(59, 54), radius: r);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.butt;
    void seg(double startDeg, double len, Color c) =>
        canvas.drawArc(rect, startDeg * math.pi / 180, len / r, false, ring..color = c);
    seg(-140, 47.9, p.a);
    seg(-10, 24.9, p.b);
    seg(60, 13.4, p.e);
    seg(100, 15.4, p.c);
    // stem with a gap outline
    final stem = RRect.fromRectAndRadius(const Rect.fromLTWH(24, 24, 20, 84), const Radius.circular(10));
    canvas.drawRRect(stem.inflate(1.5), fill..color = bg);
    canvas.drawRRect(stem, fill..color = p.k);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) => old.p != p || old.bg != bg;
}

/// A four-slice donut used as the "o" in the wordmark.
class DonutO extends StatelessWidget {
  final double size;
  final MarkPalette palette;
  const DonutO({super.key, required this.size, this.palette = MarkPalette.light});
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _DonutPainter(palette));
}

class _DonutPainter extends CustomPainter {
  final MarkPalette p;
  _DonutPainter(this.p);
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final stroke = w * 20 / 120;
    final rect = Rect.fromCircle(center: Offset(w / 2, w / 2), radius: w * 40 / 120);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    const parts = [0.40, 0.25, 0.18, 0.13];
    final colors = [p.a, p.b, p.e, p.c];
    var start = -math.pi / 2;
    const gap = 0.08;
    for (var i = 0; i < parts.length; i++) {
      final sweep = parts[i] * 2 * math.pi;
      canvas.drawArc(rect, start, sweep - gap, false, paint..color = colors[i]);
      start += sweep + (i == parts.length - 1 ? 0 : 0);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.p != p;
}

/// "p◐tfolio" wordmark, or any word with its first "o" replaced by the donut.
class Wordmark extends StatelessWidget {
  final double fontSize;
  final Color color;
  final MarkPalette palette;
  final String word;
  const Wordmark({super.key, this.fontSize = 24, this.color = PColors.navy, this.palette = MarkPalette.light, this.word = 'potfolio'});

  @override
  Widget build(BuildContext context) {
    final i = word.indexOf('o');
    final style = GoogleFonts.interTight(fontSize: fontSize, fontWeight: FontWeight.w800, color: color, letterSpacing: -fontSize * 0.045, height: 1);
    if (i < 0) return Text(word, style: style);
    return Semantics(
      label: word,
      excludeSemantics: true,
      child: Text.rich(TextSpan(style: style, children: [
        TextSpan(text: word.substring(0, i)),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: fontSize * 0.02),
            child: DonutO(size: fontSize * 0.62, palette: palette),
          ),
        ),
        TextSpan(text: word.substring(i + 1)),
      ])),
    );
  }
}

class Lockup extends StatelessWidget {
  final double markSize;
  final Color textColor;
  final MarkPalette palette;
  final Color background;
  const Lockup({super.key, this.markSize = 32, this.textColor = PColors.navy, this.palette = MarkPalette.light, this.background = PColors.mist});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        PotfolioMark(size: markSize, palette: palette, background: background),
        SizedBox(width: markSize * 0.22),
        Wordmark(fontSize: markSize * 0.8, color: textColor, palette: palette),
      ]);
}

/// Segmented pill bar showing a mix of weights.
class AllocationBar extends StatelessWidget {
  final List<double> weights;
  final double height;
  final List<Color>? colors;
  const AllocationBar({super.key, required this.weights, this.height = 10, this.colors});
  @override
  Widget build(BuildContext context) {
    final cs = colors ?? PColors.chart;
    if (weights.isEmpty) return SizedBox(height: height);
    return SizedBox(
      height: height,
      child: Row(children: [
        for (var i = 0; i < weights.length; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(
            flex: math.max(1, (weights[i] * 10).round()),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              decoration: BoxDecoration(color: cs[i % cs.length], borderRadius: BorderRadius.circular(height)),
            ),
          ),
        ],
      ]),
    );
  }
}

/// Simple donut chart for a pot.
class PotDonut extends StatelessWidget {
  final List<double> weights;
  final double size;
  final double stroke;
  const PotDonut({super.key, required this.weights, this.size = 140, this.stroke = 18});
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _PotDonutPainter(weights, stroke));
}

class _PotDonutPainter extends CustomPainter {
  final List<double> w;
  final double stroke;
  _PotDonutPainter(this.w, this.stroke);
  @override
  void paint(Canvas canvas, Size size) {
    final total = w.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2 - stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    var start = -math.pi / 2;
    for (var i = 0; i < w.length; i++) {
      final sweep = w[i] / total * 2 * math.pi;
      canvas.drawArc(rect, start, math.max(0, sweep - 0.06), false, paint..color = PColors.chart[i % PColors.chart.length]);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PotDonutPainter old) => old.w != w;
}

/// Small rounded label.
class Tag extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const Tag(this.text, {super.key, this.bg = PColors.mist, this.fg = PColors.slate});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
      );
}

/// White rounded card.
class PCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final VoidCallback? onTap;
  const PCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color = Colors.white, this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: color,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: PColors.line)),
            child: child,
          ),
        ),
      );
}

/// Guardian note: clay accent, used only for risk and attention.
class GuardianNote extends StatelessWidget {
  final String text;
  final String title;
  const GuardianNote(this.text, {super.key, this.title = 'Guardian check'});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: PColors.clayTint, borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.shield_outlined, color: PColors.clay, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: text),
            ]), style: const TextStyle(fontSize: 14, height: 1.45, color: PColors.navy)),
          ),
        ]),
      );
}

const disclaimer = 'Educational, not financial advice.';
