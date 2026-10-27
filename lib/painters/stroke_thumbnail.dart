import 'package:flutter/material.dart';

import '../data/stroke_codec.dart';
import '../theme/app_theme.dart';

/// Draws a single stroke of a glyph, with the earlier strokes kept pale so the
/// stroke order stays readable. The mini program generated one PNG per stroke;
/// here it is painted on the fly.
class StrokeThumbnail extends StatelessWidget {
  const StrokeThumbnail({
    super.key,
    required this.glyph,
    required this.index,
    this.size = 40,
  });

  final StrokeGlyph? glyph;
  final int index;
  final double size;

  @override
  Widget build(BuildContext context) {
    final data = glyph;
    if (data == null || index >= data.paths.length) {
      return SizedBox.square(dimension: size);
    }
    return CustomPaint(
      size: Size.square(size),
      painter: _StrokeThumbnailPainter(data, index),
    );
  }
}

/// Draws stroke [index] of [glyph] into [size], earlier strokes stay pale so the
/// stroke order reads at a glance. Exposed separately from the widget so it can
/// be exercised without pumping a widget tree.
void paintStrokeThumbnail(
  Canvas canvas,
  Size size,
  StrokeGlyph glyph,
  int index,
) {
  final pad = size.width * 0.08;
  final scale = (size.width - 2 * pad) / 1024;

  canvas.save();
  canvas.translate(pad, pad + 900 * scale);
  canvas.scale(scale, -scale);

  final paint = Paint()..style = PaintingStyle.fill;
  for (var i = 0; i <= index && i < glyph.paths.length; i++) {
    paint.color = i == index ? _ink : _pale;
    canvas.drawPath(glyph.paths[i], paint);
  }

  canvas.restore();
}

const Color _ink = ZiliColors.ink;
const Color _pale = Color(0xFFDCD2C0);

class _StrokeThumbnailPainter extends CustomPainter {
  const _StrokeThumbnailPainter(this.glyph, this.index);

  final StrokeGlyph glyph;
  final int index;

  @override
  void paint(Canvas canvas, Size size) =>
      paintStrokeThumbnail(canvas, size, glyph, index);

  @override
  bool shouldRepaint(covariant _StrokeThumbnailPainter oldDelegate) =>
      oldDelegate.index != index || oldDelegate.glyph != glyph;
}
