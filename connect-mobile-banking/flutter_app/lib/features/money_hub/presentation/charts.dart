import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/tokens.dart';

// Small charts for the Money Hub, drawn by hand: stacked monthly bars, and share bars for categories.

class BarSegment {
  const BarSegment(this.value, this.color);

  final double value;
  final Color color;
}

class StackedBar {
  const StackedBar({required this.label, required this.segments});

  final String label;
  final List<BarSegment> segments;

  double get total => segments.fold(0, (sum, s) => sum + s.value);
}

/// Monthly bars, each stacked from its segments, with the total above.
class StackedBarChart extends StatelessWidget {
  const StackedBarChart({super.key, required this.bars, this.height = 180, required this.semanticLabel});

  final List<StackedBar> bars;
  final double height;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.bank;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: CustomPaint(
          size: Size.infinite,
          painter: _StackedBarsPainter(bars: bars, ink: c.ink, muted: c.muted, line: c.line),
        ),
      ),
    );
  }
}

class _StackedBarsPainter extends CustomPainter {
  _StackedBarsPainter({required this.bars, required this.ink, required this.muted, required this.line});

  final List<StackedBar> bars;
  final Color ink, muted, line;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    const labelHeight = 20.0, topRoom = 20.0;
    final chartHeight = size.height - labelHeight - topRoom;
    final most = bars.map((b) => b.total).fold<double>(0, math.max);
    final slot = size.width / bars.length;
    final barWidth = math.min(44.0, slot * 0.56);
    canvas.drawLine(Offset(0, topRoom + chartHeight), Offset(size.width, topRoom + chartHeight), Paint()..color = line);
    for (var i = 0; i < bars.length; i++) {
      final bar = bars[i];
      final left = slot * i + (slot - barWidth) / 2;
      var bottom = topRoom + chartHeight;
      for (var s = 0; s < bar.segments.length; s++) {
        final segment = bar.segments[s];
        final h = most <= 0 ? 0.0 : chartHeight * segment.value / most;
        final rect = Rect.fromLTWH(left, bottom - h, barWidth, h);
        final top = s == bar.segments.length - 1;
        canvas.drawRRect(
          RRect.fromRectAndCorners(rect, topLeft: top ? const Radius.circular(6) : Radius.zero, topRight: top ? const Radius.circular(6) : Radius.zero),
          Paint()..color = segment.color,
        );
        bottom -= h;
      }
      _text(canvas, pounds(bar.total), Offset(left + barWidth / 2, bottom - 16), ink, 11, FontWeight.w700);
      _text(canvas, bar.label, Offset(left + barWidth / 2, size.height - labelHeight + 4), muted, 12, FontWeight.w500);
    }
  }

  void _text(Canvas canvas, String text, Offset centre, Color color, double size, FontWeight weight) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(centre.dx - painter.width / 2, centre.dy));
  }

  @override
  bool shouldRepaint(_StackedBarsPainter old) => old.bars != bars || old.ink != ink;
}

/// A category's share as a labelled bar.
class ShareBar extends StatelessWidget {
  const ShareBar({super.key, required this.label, required this.amount, required this.share, required this.color});

  final String label;
  final double amount;
  final int share;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.bank;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(gbp(amount), style: const TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(width: 44, child: Text('$share%', textAlign: TextAlign.right, style: TextStyle(color: c.muted, fontSize: 13))),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: share / 100, minHeight: 8, color: color, backgroundColor: c.line),
        ),
      ]),
    );
  }
}

class Legend extends StatelessWidget {
  const Legend({super.key, required this.items});

  final List<(String, Color)> items;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 16, runSpacing: 4, children: [
        for (final (label, color) in items)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ]),
      ]);
}
