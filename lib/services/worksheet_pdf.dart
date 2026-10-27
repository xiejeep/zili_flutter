import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/library_repository.dart';
import '../data/stroke_codec.dart';
import '../models/hanzi_entry.dart';
import 'sheet_layout.dart';

/// Renders the practice worksheet as an A4 PDF.
///
/// The geometry comes from [SheetLayoutBuilder]; this class only turns the ops
/// into PDF drawing calls. The raster renderer in `worksheet_image.dart` reads
/// the same ops, so the two outputs stay in step.
///
/// Label text must stay in sync with `tool/build_font.cjs`, which subsets the
/// bundled fonts down to exactly these glyphs.
class WorksheetPdf {
  WorksheetPdf._();

  static Future<Uint8List> build({
    required List<HanziEntry> entries,
    required Library library,
  }) async {
    final cjkData = await rootBundle.load('assets/fonts/zili_label.ttf');
    final latinData = await rootBundle.load('assets/fonts/zili_latin.ttf');
    final cjkFont = pw.Font.ttf(cjkData);
    final latinFont = pw.Font.ttf(latinData);

    final document = pw.Document();
    final totalPages = SheetLayoutBuilder.pageCount(entries.length);

    for (var page = 0; page < totalPages; page++) {
      final layout = SheetLayoutBuilder.build(
        entries: entries,
        library: library,
        pageIndex: page,
        totalPages: totalPages,
      );
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          // Zero margin so the painter receives the full page as its canvas and
          // the layout coordinates can be used as absolute page coordinates.
          margin: pw.EdgeInsets.zero,
          build: (context) => pw.Stack(
            children: [
              pw.Positioned.fill(
                child: pw.CustomPaint(
                  painter: (canvas, size) => _paint(
                    canvas,
                    layout,
                    cjkFont.getFont(context),
                    latinFont.getFont(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return document.save();
  }

  static void _paint(
    PdfGraphics canvas,
    SheetLayout layout,
    PdfFont cjk,
    PdfFont latin,
  ) {
    for (final op in layout.ops) {
      switch (op) {
        case SheetText():
          _text(canvas, op, cjk, latin);
        case SheetRule():
          canvas
            ..setStrokeColor(PdfColor.fromInt(op.color))
            ..setLineWidth(op.width)
            ..moveTo(op.from.x, op.from.y)
            ..lineTo(op.to.x, op.to.y)
            ..strokePath();
        case SheetDashedRule():
          _dashed(canvas, op);
        case SheetRect():
          canvas
            ..setStrokeColor(PdfColor.fromInt(op.color))
            ..setLineWidth(op.width)
            ..drawRect(op.rect.x, op.rect.y, op.rect.width, op.rect.height)
            ..strokePath();
        case SheetGlyph():
          _glyph(canvas, op);
      }
    }
  }

  /// Draws each span in its own face, advancing the pen by the measured width.
  static void _text(
    PdfGraphics canvas,
    SheetText op,
    PdfFont cjk,
    PdfFont latin,
  ) {
    canvas.setColor(PdfColor.fromInt(op.color));
    var x = op.x;
    for (final span in op.spans) {
      final font = span.role == SheetFontRole.cjk ? cjk : latin;
      canvas.drawString(font, op.size, span.text, x, op.y);
      x += (font.stringMetrics(span.text) * op.size).advanceWidth;
    }
  }

  static void _glyph(PdfGraphics canvas, SheetGlyph op) {
    final pad = SheetLayoutBuilder.glyphPad(op.size);
    final k = SheetLayoutBuilder.glyphScale(op.size);
    canvas.setFillColor(PdfColor.fromInt(op.color));
    for (final outline in op.outlines) {
      _replay(canvas, outline, op.origin.x + pad, op.origin.y + pad, k);
      canvas.fillPath();
    }
  }

  /// Replays a stroke outline, converting quadratic segments to cubics because
  /// PdfGraphics only exposes cubic curves.
  static void _replay(
    PdfGraphics canvas,
    StrokeOutline outline,
    double ox,
    double oy,
    double k,
  ) {
    var currentX = 0.0;
    var currentY = 0.0;

    for (final op in outline.ops) {
      final c = op.coords;
      switch (op.op) {
        case 'M':
          currentX = c[0];
          currentY = c[1];
          canvas.moveTo(ox + currentX * k, oy + currentY * k);
          break;
        case 'L':
          currentX = c[0];
          currentY = c[1];
          canvas.lineTo(ox + currentX * k, oy + currentY * k);
          break;
        case 'Q':
          // Control point, then the end point.
          final c1x = currentX + 2 / 3 * (c[0] - currentX);
          final c1y = currentY + 2 / 3 * (c[1] - currentY);
          final c2x = c[2] + 2 / 3 * (c[0] - c[2]);
          final c2y = c[3] + 2 / 3 * (c[1] - c[3]);
          canvas.curveTo(
            ox + c1x * k,
            oy + c1y * k,
            ox + c2x * k,
            oy + c2y * k,
            ox + c[2] * k,
            oy + c[3] * k,
          );
          currentX = c[2];
          currentY = c[3];
          break;
        case 'C':
          canvas.curveTo(
            ox + c[0] * k,
            oy + c[1] * k,
            ox + c[2] * k,
            oy + c[3] * k,
            ox + c[4] * k,
            oy + c[5] * k,
          );
          currentX = c[4];
          currentY = c[5];
          break;
        case 'Z':
          canvas.closePath();
          break;
      }
    }
  }

  static void _dashed(PdfGraphics canvas, SheetDashedRule op) {
    final totalX = op.to.x - op.from.x;
    final totalY = op.to.y - op.from.y;
    final length = totalX.abs() + totalY.abs();
    if (length == 0) return;
    final steps = (length / (op.dash + op.gap)).floor();
    canvas
      ..setStrokeColor(PdfColor.fromInt(op.color))
      ..setLineWidth(op.width);
    for (var i = 0; i <= steps; i++) {
      final start = i * (op.dash + op.gap) / length;
      final end = (i * (op.dash + op.gap) + op.dash) / length;
      if (end > 1) break;
      canvas
        ..moveTo(op.from.x + totalX * start, op.from.y + totalY * start)
        ..lineTo(op.from.x + totalX * end, op.from.y + totalY * end)
        ..strokePath();
    }
  }
}
