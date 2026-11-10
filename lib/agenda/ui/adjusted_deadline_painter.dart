import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Coordinates relative to the viewport-clipped adjusted-deadline surface.
/// The original body stays fixed-width even when only the extension is visible.
class AdjustedDeadlineGeometry {
  const AdjustedDeadlineGeometry({
    required this.bodyLeft,
    required this.effectiveX,
    required this.realX,
  });

  final double bodyLeft;
  final double effectiveX;
  final double realX;
}

/// Screen-space stripes, not time-space stripes: zoom stretches the interval,
/// but never the width or 45-degree angle of each band.
class AdjustedDeadlineExtensionPainter extends CustomPainter {
  const AdjustedDeadlineExtensionPainter({
    required this.effectiveX,
    required this.realX,
    required this.color,
    this.stripeWidth = 16,
    this.highOpacity = 0.32,
    this.lowOpacity = 0.16,
  });

  final double effectiveX;
  final double realX;
  final Color color;
  final double stripeWidth;
  final double highOpacity;
  final double lowOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final left = math.max(0.0, effectiveX);
    final right = math.min(size.width, realX);
    if (right <= left || size.height <= 0) return;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(left, 0, right, size.height));
    // Only visit stripes intersecting this small, clipped canvas. The original
    // interval can span years at maximum zoom without allocating a huge layer.
    final first = ((left - effectiveX) / stripeWidth).floor();
    final last = ((right + size.height - effectiveX) / stripeWidth).ceil();
    for (var index = first; index <= last; index++) {
      final x = effectiveX + index * stripeWidth;
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + stripeWidth, 0)
        ..lineTo(x + stripeWidth - size.height, size.height)
        ..lineTo(x - size.height, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(
            alpha: color.a * (index.isEven ? highOpacity : lowOpacity),
          ),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(AdjustedDeadlineExtensionPainter oldDelegate) =>
      oldDelegate.effectiveX != effectiveX ||
      oldDelegate.realX != realX ||
      oldDelegate.color != color ||
      oldDelegate.stripeWidth != stripeWidth ||
      oldDelegate.highOpacity != highOpacity ||
      oldDelegate.lowOpacity != lowOpacity;
}

/// Always used as a foreground painter: even a subpixel interval must draw the
/// real deadline OVER the effective boundary rather than dropping either line.
class AdjustedDeadlineMarkerPainter extends CustomPainter {
  const AdjustedDeadlineMarkerPainter({
    required this.realX,
    required this.color,
    this.lineWidth = 3,
  });

  final double realX;
  final Color color;
  final double lineWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
      Rect.fromLTRB(realX - lineWidth, 0, realX, size.height),
      Paint()..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(AdjustedDeadlineMarkerPainter oldDelegate) =>
      oldDelegate.realX != realX ||
      oldDelegate.color != color ||
      oldDelegate.lineWidth != lineWidth;
}

/// A bounded hit/paint surface. [body] may extend a few baseline days outside
/// it, but the extension never creates a time-span-sized widget or canvas.
class AdjustedDeadlineSurface extends StatelessWidget {
  const AdjustedDeadlineSurface({
    super.key,
    required this.geometry,
    required this.bodyWidth,
    required this.fill,
    required this.realMarkerColor,
    required this.body,
    required this.onTap,
    required this.semanticsLabel,
  });

  final AdjustedDeadlineGeometry geometry;
  final double bodyWidth;
  final Color fill;
  final Color realMarkerColor;
  final Widget body;
  final VoidCallback onTap;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticsLabel,
    onTap: onTap,
    child: ExcludeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ClipRect(
          child: CustomPaint(
            painter: AdjustedDeadlineExtensionPainter(
              effectiveX: geometry.effectiveX,
              realX: geometry.realX,
              color: fill,
            ),
            foregroundPainter: AdjustedDeadlineMarkerPainter(
              realX: geometry.realX,
              color: realMarkerColor,
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: geometry.bodyLeft,
                  top: 0,
                  bottom: 0,
                  width: bodyWidth,
                  child: body,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
