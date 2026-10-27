import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/library_repository.dart';
import '../models/hanzi_entry.dart';
import 'sheet_layout.dart';

/// Renders the practice worksheet as PNG pages.
///
/// Reads exactly the same [SheetLayout] ops as the PDF renderer, so the image
/// and the PDF cannot drift apart. Only the drawing backend differs.
///
/// Text uses the platform font rather than the bundled subsets: raster output
/// needs no embedding, and the system face covers every label, so a missing
/// glyph can never turn into a blank box here.
class WorksheetImage {
  WorksheetImage._();

  /// Pixels per PDF point. 3.0 gives roughly 216 DPI on A4, sharp enough to
  /// read on screen and to print.
  static const double scale = 3.0;

  /// One PNG per page.
  static Future<List<Uint8List>> build({
    required List<HanziEntry> entries,
    required Library library,
  }) async {
    final totalPages = SheetLayoutBuilder.pageCount(entries.length);
    final pages = <Uint8List>[];
    for (var page = 0; page < totalPages; page++) {
      final layout = SheetLayoutBuilder.build(
        entries: entries,
        library: library,
        pageIndex: page,
        totalPages: totalPages,
      );
      pages.add(await render(layout));
    }
    return pages;
  }

  /// Rasterises a single layout. Exposed so it can be exercised directly.
  static Future<Uint8List> render(SheetLayout layout) async {
    final width = (layout.width * scale).round();
    final height = (layout.height * scale).round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
    // Paper white, the gallery shows this on a dark background too.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = Colors.white,
    );

    for (final op in layout.ops) {
      switch (op) {
        case SheetText():
          _text(canvas, layout, op);
        case SheetRule():
          _line(canvas, layout, op.from, op.to, op.color, op.width);
        case SheetDashedRule():
          _dashed(canvas, layout, op);
        case SheetRect():
          canvas.drawRect(
            _box(layout, op.rect),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = op.width * scale
              ..color = _color(op.color),
          );
        case SheetGlyph():
          _glyph(canvas, layout, op);
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    if (data == null) {
      throw StateError('无法把字帖转成 PNG');
    }
    return data.buffer.asUint8List();
  }

  static void _text(Canvas canvas, SheetLayout layout, SheetText op) {
    var x = op.x;
    for (final span in op.spans) {
      final painter = TextPainter(
        text: TextSpan(
          text: span.text,
          style: TextStyle(fontSize: op.size * scale, color: _color(op.color)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // Sheet coordinates carry the baseline; TextPainter paints from the top.
      final baseline = painter.computeDistanceToActualBaseline(
        TextBaseline.alphabetic,
      );
      painter.paint(
        canvas,
        Offset(x * scale, (layout.height - op.y) * scale - baseline),
      );
      x += painter.width / scale;
      painter.dispose();
    }
  }

  static void _glyph(Canvas canvas, SheetLayout layout, SheetGlyph op) {
    final pad = SheetLayoutBuilder.glyphPad(op.size);
    final k = SheetLayoutBuilder.glyphScale(op.size);

    canvas.save();
    // Sheet space has y pointing up, the canvas has it pointing down, so the
    // glyph is drawn through a mirrored transform.
    canvas.translate(
      (op.origin.x + pad) * scale,
      (layout.height - op.origin.y - pad) * scale,
    );
    canvas.scale(scale * k, -scale * k);

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = _color(op.color);
    for (final outline in op.outlines) {
      final path = Path();
      for (final command in outline.ops) {
        command.applyTo(path);
      }
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  static void _line(
    Canvas canvas,
    SheetLayout layout,
    Offset2 from,
    Offset2 to,
    int color,
    double width,
  ) {
    canvas.drawLine(
      _point(layout, from),
      _point(layout, to),
      Paint()
        ..strokeWidth = width * scale
        ..color = _color(color),
    );
  }

  static void _dashed(Canvas canvas, SheetLayout layout, SheetDashedRule op) {
    final totalX = op.to.x - op.from.x;
    final totalY = op.to.y - op.from.y;
    final length = totalX.abs() + totalY.abs();
    if (length == 0) return;

    final paint = Paint()
      ..strokeWidth = op.width * scale
      ..color = _color(op.color);
    final steps = (length / (op.dash + op.gap)).floor();
    for (var i = 0; i <= steps; i++) {
      final start = i * (op.dash + op.gap) / length;
      final end = (i * (op.dash + op.gap) + op.dash) / length;
      if (end > 1) break;
      canvas.drawLine(
        _point(layout, Offset2(
          op.from.x + totalX * start,
          op.from.y + totalY * start,
        )),
        _point(layout, Offset2(
          op.from.x + totalX * end,
          op.from.y + totalY * end,
        )),
        paint,
      );
    }
  }

  static Offset _point(SheetLayout layout, Offset2 p) =>
      Offset(p.x * scale, (layout.height - p.y) * scale);

  static Rect _box(SheetLayout layout, SheetBox box) => Rect.fromLTRB(
        box.x * scale,
        (layout.height - box.y - box.height) * scale,
        (box.x + box.width) * scale,
        (layout.height - box.y) * scale,
      );

  static Color _color(int argb) => Color(argb);
}
