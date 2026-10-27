import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zili_flutter/data/library_repository.dart';

/// Guards the coordinate mapping used by the stroke thumbnails and the board.
///
/// Rendering a real image is not possible here (see docs/PROGRESS.md note 7),
/// so instead the glyph bounds are pushed through the exact same transform and
/// checked against the canvas box. This catches the failure mode that would
/// otherwise only show up as a silently clipped stroke on screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const box = 38.0;
  const pad = box * 0.08;
  const scale = (box - 2 * pad) / 1024;
  const yBaseline = 900.0;

  Rect transform(Rect glyph) => Rect.fromLTRB(
        pad + glyph.left * scale,
        pad + (yBaseline - glyph.bottom) * scale,
        pad + glyph.right * scale,
        pad + (yBaseline - glyph.top) * scale,
      );

  test('every glyph stays inside the thumbnail box', () async {
    final library = await Library.load();
    var worst = 0.0;
    String? worstChar;

    for (final entry in library.entries) {
      final glyph = library.glyph(entry.char);
      if (glyph == null) continue;
      for (final path in glyph.paths) {
        final rect = transform(path.getBounds());
        final overflow = [
          0.0 - rect.left,
          rect.right - box,
          0.0 - rect.top,
          rect.bottom - box,
        ].reduce((a, b) => a > b ? a : b);
        if (overflow > worst) {
          worst = overflow;
          worstChar = entry.char;
        }
      }
    }

    expect(
      worst,
      lessThan(0.5),
      reason: '最严重的溢出 ${worst.toStringAsFixed(2)}px 出现在「$worstChar」',
    );
  });

  test('the glyph actually fills most of the box', () async {
    // A transform bug could also shrink everything to a dot, which the overflow
    // check above would happily pass. Confirm the ink covers the box instead.
    final library = await Library.load();
    final glyph = library.glyph('国')!;

    final union = glyph.paths
        .map((p) => transform(p.getBounds()))
        .reduce((a, b) => a.expandToInclude(b));

    expect(union.width, greaterThan(box * 0.5));
    expect(union.height, greaterThan(box * 0.5));
  });
}
