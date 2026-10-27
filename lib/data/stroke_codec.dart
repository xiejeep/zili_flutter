import 'dart:ui';

/// One drawing command of a stroke outline, in the 1024 unit grid with the y
/// axis pointing up.
class StrokeOp {
  const StrokeOp(this.op, this.coords);

  /// One of `M`, `L`, `Q`, `C`, `Z`.
  final String op;
  final List<double> coords;

  Path applyTo(Path path) {
    switch (op) {
      case 'M':
        path.moveTo(coords[0], coords[1]);
        break;
      case 'L':
        path.lineTo(coords[0], coords[1]);
        break;
      case 'Q':
        path.quadraticBezierTo(coords[0], coords[1], coords[2], coords[3]);
        break;
      case 'C':
        path.cubicTo(
            coords[0], coords[1], coords[2], coords[3], coords[4], coords[5]);
        break;
      case 'Z':
        path.close();
        break;
    }
    return path;
  }
}

/// A decoded stroke outline, replayable onto any canvas (Flutter or PDF).
class StrokeOutline {
  const StrokeOutline(this.ops, this.points);

  final List<StrokeOp> ops;

  /// End point of every command, i.e. the stroke skeleton.
  final List<Offset> points;

  Path toPath() {
    final path = Path();
    for (final op in ops) {
      op.applyTo(path);
    }
    return path;
  }
}

class StrokeGlyph {
  const StrokeGlyph({required this.paths, required this.medians});

  final List<Path> paths;
  final List<List<Offset>> medians;

  int get strokeCount => paths.length;
}

/// Decodes the compact stroke payload produced by the build pipeline.
///
/// Coordinates are halved before delta encoding in the source data and restored
/// here, so a decoded glyph is expressed in the original 1024 unit grid with the
/// y axis pointing up (the painter flips it back).
class StrokeCodec {
  StrokeCodec._();

  static const int _scale = 2;
  static const int _short = 44;
  static const int _escapeOffset = 4000;

  static final String _chars = _buildChars();
  static final int _base = _chars.length;
  static final int _escape = _base - 1;
  static final Map<String, int> _index = {
    for (var i = 0; i < _chars.length; i++) _chars[i]: i,
  };

  static String _buildChars() {
    final buffer = StringBuffer();
    for (var code = 33; code <= 126; code++) {
      // Skip the quote and the JSON escape characters.
      if (code == 34 || code == 39 || code == 92) continue;
      buffer.writeCharCode(code);
    }
    return buffer.toString();
  }

  /// Decodes one packed payload into drawable paths plus stroke medians.
  static StrokeGlyph decode(String payload) {
    final parts = payload.split('\n');
    final outlines = _outlines(parts[0]);
    final medians = outlines.map((o) => o.points).toList();

    if (parts.length > 1 && parts[1].isNotEmpty) {
      // Shipped medians are denser than the skeleton recovered from paths and
      // drive both the animation and the tracing check.
      medians
        ..clear()
        ..addAll(parts[1].split(' ').map(_decodePoints));
    }

    return StrokeGlyph(
      paths: outlines.map((o) => o.toPath()).toList(),
      medians: medians,
    );
  }

  /// Outlines only, used by the worksheet PDF which replays the commands.
  static List<StrokeOutline> outlines(String payload) =>
      _outlines(payload.split('\n').first);

  static List<StrokeOutline> _outlines(String text) {
    if (text.isEmpty) return const [];
    return text.split(' ').map(_parsePath).toList();
  }

  static StrokeOutline _parsePath(String text) {
    final ops = <StrokeOp>[];
    final points = <Offset>[];
    var i = 0;
    var x = 0;
    var y = 0;

    while (i < text.length) {
      final op = text[i++];
      if (op == 'Z') {
        ops.add(const StrokeOp('Z', []));
        continue;
      }
      final count = op == 'Q' ? 2 : (op == 'C' ? 3 : 1);
      final coords = <double>[];
      for (var k = 0; k < count; k++) {
        final rx = _read(text, i);
        x += rx.value;
        i = rx.next;
        final ry = _read(text, i);
        y += ry.value;
        i = ry.next;
        coords
          ..add((x * _scale).toDouble())
          ..add((y * _scale).toDouble());
      }
      ops.add(StrokeOp(op, coords));
      points.add(Offset(coords[coords.length - 2], coords[coords.length - 1]));
    }

    return StrokeOutline(ops, points);
  }

  static List<Offset> _decodePoints(String text) {
    final out = <Offset>[];
    var i = 0;
    var x = 0;
    var y = 0;
    while (i < text.length) {
      final rx = _read(text, i);
      x += rx.value;
      i = rx.next;
      final ry = _read(text, i);
      y += ry.value;
      i = ry.next;
      out.add(Offset((x * _scale).toDouble(), (y * _scale).toDouble()));
    }
    return out;
  }

  static _Read _read(String text, int pos) {
    final code = _index[text[pos]];
    if (code == null) {
      throw FormatException('bad stroke payload at $pos');
    }
    if (code == _escape) {
      final value =
          _index[text[pos + 1]]! * _base + _index[text[pos + 2]]! - _escapeOffset;
      return _Read(value, pos + 3);
    }
    return _Read(code - _short, pos + 1);
  }
}

class _Read {
  const _Read(this.value, this.next);
  final int value;
  final int next;
}
