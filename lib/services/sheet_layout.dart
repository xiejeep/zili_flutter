import '../data/library_repository.dart';
import '../data/stroke_codec.dart';
import '../models/hanzi_entry.dart';

/// Which bundled face a label belongs to.
///
/// The PDF has to embed fonts, so it keeps a subset for Chinese labels and a
/// Latin subset for pinyin. The raster renderer ignores the role and uses the
/// system font, which covers everything.
enum SheetFontRole { cjk, latin }

/// One drawing primitive, in sheet space: origin at the bottom left, y growing
/// upwards, units are PDF points. The raster renderer flips y when it draws.
sealed class SheetOp {
  const SheetOp();
}

/// A run of text that may mix faces. Each span advances the pen by its own
/// measured width, so the renderer never needs to guess where the next one goes.
class SheetText extends SheetOp {
  const SheetText({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.spans,
  });

  final double x;
  final double y;
  final double size;
  final int color;
  final List<SheetTextSpan> spans;
}

class SheetTextSpan {
  const SheetTextSpan(this.text, this.role);

  final String text;
  final SheetFontRole role;
}

/// A solid rule.
class SheetRule extends SheetOp {
  const SheetRule({
    required this.from,
    required this.to,
    required this.color,
    required this.width,
  });

  final Offset2 from;
  final Offset2 to;
  final int color;
  final double width;
}

/// A dashed rule, used for the 田字格 guides. Renderers segment it themselves
/// so the op list stays small.
class SheetDashedRule extends SheetOp {
  const SheetDashedRule({
    required this.from,
    required this.to,
    required this.color,
    required this.width,
    this.dash = 1.5,
    this.gap = 1.5,
  });

  final Offset2 from;
  final Offset2 to;
  final int color;
  final double width;
  final double dash;
  final double gap;
}

/// An outlined rectangle, used for the cell borders.
class SheetRect extends SheetOp {
  const SheetRect({
    required this.rect,
    required this.color,
    required this.width,
  });

  final SheetBox rect;
  final int color;
  final double width;
}

/// A stroke outline replayed at [origin] and scaled to fit [size].
class SheetGlyph extends SheetOp {
  const SheetGlyph({
    required this.outlines,
    required this.origin,
    required this.size,
    required this.color,
  });

  final List<StrokeOutline> outlines;
  final Offset2 origin;
  final double size;
  final int color;
}

/// Minimal point, kept independent of Flutter's Offset so the layout can be
/// built and asserted without a rendering backend.
class Offset2 {
  const Offset2(this.x, this.y);
  final double x;
  final double y;
}

class SheetBox {
  const SheetBox(this.x, this.y, this.width, this.height);
  final double x;
  final double y;
  final double width;
  final double height;
}

/// The finished page: a size plus an ordered list of primitives.
class SheetLayout {
  const SheetLayout({required this.width, required this.height, required this.ops});

  final double width;
  final double height;
  final List<SheetOp> ops;

  /// Convenience for tests: every text run flattened to plain strings.
  List<String> get texts => [
        for (final op in ops)
          if (op is SheetText) op.spans.map((s) => s.text).join(),
      ];
}

/// Lays out the A4 practice sheet.
///
/// Five characters per page, each with two rows of ten 田字格 cells. The first
/// cell of the top row shows the character in ink, the next two show it pale
/// for tracing, the rest stay empty for free writing.
///
/// This is pure geometry: no fonts, no I/O, no platform. Both the PDF and the
/// raster renderer replay the result, so the two outputs cannot drift apart.
class SheetLayoutBuilder {
  SheetLayoutBuilder._();

  static const int perPage = 5;
  static const int columns = 10;
  static const int rows = 2;

  /// A4 in points, the unit the whole layout is expressed in.
  static const double pageWidth = 595.276;
  static const double pageHeight = 841.89;

  static const int ink = 0xFF2A2724;
  static const int faint = 0xFFDCD2C0;
  static const int gridInner = 0xFFEDE5D8;
  static const int soft = 0xFF8C8378;

  static const double margin = 36;
  static const double entryHeight = 136;

  static int pageCount(int entryCount) => (entryCount / perPage).ceil();

  /// Builds one page. [pageIndex] is zero based, [totalPages] is used for the
  /// footer.
  static SheetLayout build({
    required List<HanziEntry> entries,
    required Library library,
    required int pageIndex,
    required int totalPages,
  }) {
    final ops = <SheetOp>[];
    const width = pageWidth;
    const height = pageHeight;
    final cell = (width - margin * 2) / columns;

    // ---- Header -----------------------------------------------------------
    // The fill in blanks are rules rather than underscore characters, which
    // keeps them out of the font subset.
    ops.add(const SheetText(
      x: margin,
      y: height - 48,
      size: 15,
      color: ink,
      spans: [SheetTextSpan('字里 · 汉字练习', SheetFontRole.cjk)],
    ));
    ops.add(const SheetText(
      x: margin,
      y: height - 72,
      size: 9,
      color: soft,
      spans: [SheetTextSpan('姓名：', SheetFontRole.cjk)],
    ));
    ops.add(const SheetText(
      x: margin + 170,
      y: height - 72,
      size: 9,
      color: soft,
      spans: [SheetTextSpan('日期：', SheetFontRole.cjk)],
    ));
    ops.add(SheetRule(
      from: Offset2(margin + 30, height - 75),
      to: Offset2(margin + 130, height - 75),
      color: faint,
      width: 0.7,
    ));
    ops.add(SheetRule(
      from: Offset2(margin + 200, height - 75),
      to: Offset2(margin + 300, height - 75),
      color: faint,
      width: 0.7,
    ));
    ops.add(SheetRule(
      from: Offset2(margin, height - 84),
      to: Offset2(width - margin, height - 84),
      color: faint,
      width: 0.7,
    ));

    // ---- Entries ----------------------------------------------------------
    const firstTop = height - 104;
    final slice = entries.sublist(
      pageIndex * perPage,
      (pageIndex * perPage + perPage).clamp(0, entries.length),
    );

    for (var i = 0; i < slice.length; i++) {
      final entry = slice[i];
      final top = firstTop - i * entryHeight;
      final labelY = top - 12;

      final packed = library.packedStrokes[entry.char];
      final outlines =
          packed == null ? const <StrokeOutline>[] : StrokeCodec.outlines(packed);

      // The practice character is never drawn as text: it always comes from the
      // stroke data, so any glyph can be practised regardless of the font.
      if (outlines.isNotEmpty) {
        ops.add(SheetGlyph(
          outlines: outlines,
          origin: Offset2(margin, labelY - 3),
          size: 15,
          color: ink,
        ));
      }

      ops.add(SheetText(
        x: margin + 20,
        y: labelY,
        size: 9,
        color: soft,
        spans: [
          SheetTextSpan('${entry.pinyin}   ${entry.strokeCount} ', SheetFontRole.latin),
          const SheetTextSpan('笔', SheetFontRole.cjk),
        ],
      ));

      final gridTop = top - 20;

      for (var row = 0; row < rows; row++) {
        for (var col = 0; col < columns; col++) {
          final cx = margin + col * cell;
          final cy = gridTop - (row + 1) * cell;
          ops.addAll(_gridCell(cx, cy, cell));

          if (row == 0 && col < 3 && outlines.isNotEmpty) {
            ops.add(SheetGlyph(
              outlines: outlines,
              origin: Offset2(cx, cy),
              size: cell,
              color: col == 0 ? ink : faint,
            ));
          }
        }
      }
    }

    // ---- Footer -----------------------------------------------------------
    ops.add(const SheetText(
      x: margin,
      y: 48,
      size: 8,
      color: soft,
      spans: [
        SheetTextSpan('先描红，再独立书写。一笔一画，每天进步一点点。', SheetFontRole.cjk),
      ],
    ));
    ops.add(SheetText(
      x: width - margin - 30,
      y: 48,
      size: 8,
      color: soft,
      spans: [
        SheetTextSpan('${pageIndex + 1} / $totalPages', SheetFontRole.latin),
      ],
    ));

    return SheetLayout(width: width, height: height, ops: ops);
  }

  static List<SheetOp> _gridCell(double x, double y, double size) => [
        SheetRect(
          rect: SheetBox(x, y, size, size),
          color: faint,
          width: 0.6,
        ),
        // Dashed cross guides, matching the on screen 田字格.
        SheetDashedRule(
          from: Offset2(x + size / 2, y),
          to: Offset2(x + size / 2, y + size),
          color: gridInner,
          width: 0.4,
        ),
        SheetDashedRule(
          from: Offset2(x, y + size / 2),
          to: Offset2(x + size, y + size / 2),
          color: gridInner,
          width: 0.4,
        ),
      ];

  /// Padding and scale that position a glyph inside a cell. Shared by both
  /// renderers so the character sits identically in the PDF and the image.
  /// The glyph origin is `(originX + glyphPad, originY + glyphPad)` in sheet
  /// space, and its outline coordinates are multiplied by `glyphScale`.
  static double glyphPad(double cellSize) => cellSize * 0.07;
  static double glyphScale(double cellSize) => cellSize * 0.86 / 1024;
}
