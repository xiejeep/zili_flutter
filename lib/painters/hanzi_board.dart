import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/stroke_codec.dart';
import '../theme/app_theme.dart';

enum _Phase { idle, drawing, pause, hold }

/// Drives the stroke order animation for one character.
///
/// Direct port of the mini program board: the same 1024 unit grid, the same
/// median based progress sweep and the same colour states.
///
/// There is deliberately no finger tracing here. Drawing a stroke with a finger
/// on a phone or tablet teaches nothing about handwriting, so the board only
/// plays the order back and lets a single stroke be inspected.
class HanziBoardController extends ChangeNotifier {
  HanziBoardController();

  static const double _gridSize = 1024;
  static const double _padRatio = 0.065;

  StrokeGlyph? _glyph;
  Ticker? _ticker;
  Duration _accum = Duration.zero;
  Duration _lastElapsed = Duration.zero;
  _Phase _phase = _Phase.idle;
  double _speed = 1;

  int index = -1;
  bool playing = false;
  double partial = 0;
  String message = '点「播放笔顺」，看汉字一笔一画写出来';

  StrokeGlyph? get glyph => _glyph;
  int get total => _glyph?.strokeCount ?? 0;

  Duration strokeDuration = const Duration(milliseconds: 650);
  Duration strokeGap = const Duration(milliseconds: 180);

  /// How long the finished character stays on screen before the loop restarts.
  Duration loopHold = const Duration(milliseconds: 1400);

  static const String _playingHint = '正在播放笔顺，点「停止播放」可以随时停下';

  void attach(TickerProvider vsync) {
    _ticker ??= vsync.createTicker(tick);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void load(StrokeGlyph? glyph) {
    cancel();
    _glyph = glyph;
    index = -1;
    partial = 0;
    message = '点「播放笔顺」，看汉字一笔一画写出来';
    notifyListeners();
  }

  void cancel() {
    _ticker?.stop();
    playing = false;
    _phase = _Phase.idle;
    _accum = Duration.zero;
  }

  void reset() {
    cancel();
    index = -1;
    partial = 0;
    message = '点「播放笔顺」，看汉字一笔一画写出来';
    notifyListeners();
  }

  /// Highlights a single stroke, used by the stroke breakdown chips.
  void select(int strokeIndex) {
    cancel();
    index = strokeIndex;
    partial = 0;
    notifyListeners();
  }

  /// Starts the loop: the strokes are drawn in order, then the finished
  /// character is held briefly before it starts over, until [reset] or
  /// [cancel] stops it.
  void play(double speed) {
    if (_glyph == null || total == 0) return;
    cancel();
    playing = true;
    index = 0;
    partial = 0;
    _phase = _Phase.drawing;
    _accum = Duration.zero;
    _lastElapsed = Duration.zero;
    _speed = speed;
    _ticker?.start();
    message = _playingHint;
    notifyListeners();
  }

  Duration get _strokeSpan => Duration(
        milliseconds: (strokeDuration.inMilliseconds / _speed).round(),
      );

  Duration get _gapSpan => Duration(
        milliseconds: (strokeGap.inMilliseconds / _speed).round(),
      );

  /// Advances the animation to [elapsed], the time since playback started.
  ///
  /// Driven by the ticker. It is public so the timing can be replayed
  /// deterministically from tests instead of waiting on real frames.
  void tick(Duration elapsed) {
    final delta = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    _accum += delta;

    if (_phase == _Phase.drawing) {
      final t = _accum.inMilliseconds / _strokeSpan.inMilliseconds;
      if (t >= 1) {
        partial = 1;
        _phase = _Phase.pause;
        _accum = Duration.zero;
      } else {
        partial = t;
      }
      notifyListeners();
      return;
    }

    if (_phase == _Phase.pause) {
      if (_accum < _gapSpan) return;
      _accum = Duration.zero;
      if (index < total - 1) {
        index++;
        partial = 0;
        // Without this the next stroke never gets drawn: the controller would
        // stay in the pause phase and simply step the index every gap, making
        // every stroke after the first flash past.
        _phase = _Phase.drawing;
      } else {
        // Every stroke is on screen: hold the finished character so it can be
        // taken in, then loop.
        index = total;
        partial = 0;
        _phase = _Phase.hold;
        message = '写完啦，再看一遍';
      }
      notifyListeners();
      return;
    }

    if (_phase == _Phase.hold) {
      if (_accum < loopHold) return;
      _accum = Duration.zero;
      index = 0;
      partial = 0;
      _phase = _Phase.drawing;
      message = _playingHint;
      notifyListeners();
    }
  }

  /// Resamples a polyline into [count] evenly spaced points, used to sweep the
  /// progress marker along a stroke.
  List<Offset> _sample(List<Offset> pts, int count) {
    if (pts.length == 1) return List.filled(count, pts.first);
    final lengths = <double>[0];
    for (var i = 1; i < pts.length; i++) {
      lengths.add(lengths[i - 1] + (pts[i] - pts[i - 1]).distance);
    }
    final totalLength = lengths.last;
    final out = <Offset>[];
    for (var j = 0; j < count; j++) {
      final target = totalLength * j / (count - 1);
      var k = 1;
      while (k < lengths.length - 1 && lengths[k] < target) {
        k++;
      }
      final span = lengths[k] - lengths[k - 1];
      final t = span == 0 ? 0.0 : (target - lengths[k - 1]) / span;
      out.add(Offset.lerp(pts[k - 1], pts[k], t)!);
    }
    return out;
  }
}

class HanziBoard extends StatefulWidget {
  const HanziBoard({
    super.key,
    required this.controller,
    this.size = 248,
  });

  final HanziBoardController controller;
  final double size;

  @override
  State<HanziBoard> createState() => _HanziBoardState();
}

class _HanziBoardState extends State<HanziBoard>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    widget.controller.attach(this);
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(widget.size),
        painter: _HanziBoardPainter(widget.controller),
      );
}

class _HanziBoardPainter extends CustomPainter {
  _HanziBoardPainter(this.controller) : super(repaint: controller);

  final HanziBoardController controller;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final pad = s * HanziBoardController._padRatio;
    final k = (s - 2 * pad) / HanziBoardController._gridSize;

    _paintGrid(canvas, s);

    final glyph = controller.glyph;
    if (glyph == null) return;

    canvas.save();
    canvas.translate(pad, pad + 900 * k);
    canvas.scale(k, -k);

    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < glyph.paths.length; i++) {
      paint.color = _strokeColor(i);
      canvas.drawPath(glyph.paths[i], paint);
    }

    if (controller.partial > 0 &&
        controller.index >= 0 &&
        controller.index < glyph.paths.length) {
      canvas.save();
      canvas.clipPath(glyph.paths[controller.index]);
      _paintProgress(canvas, glyph.medians[controller.index]);
      canvas.restore();
    }

    canvas.restore();
  }

  Color _strokeColor(int i) {
    const ink = ZiliColors.ink;
    const faint = Color(0xFFE5DCCC);

    if (controller.playing) {
      return i < controller.index ? ink : faint;
    }
    if (controller.index >= 0) {
      if (i == controller.index) return ZiliColors.cinnabar;
      return i < controller.index ? ink : faint;
    }
    return ink;
  }

  void _paintProgress(Canvas canvas, List<Offset> median) {
    if (median.length < 2) return;
    final pts = controller._sample(median, 70);
    final end = math.max(2, (controller.partial * pts.length).ceil());
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < end; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = ZiliColors.cinnabar
        ..style = PaintingStyle.stroke
        ..strokeWidth = 160
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintGrid(Canvas canvas, double s) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, s, s),
      Paint()..color = Colors.white,
    );
    final grid = Paint()
      ..color = ZiliColors.gridLine
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const dash = 5.0;
    _dashedLine(canvas, Offset(s / 2, 0), Offset(s / 2, s), grid, dash);
    _dashedLine(canvas, Offset(0, s / 2), Offset(s, s / 2), grid, dash);
    _dashedLine(canvas, Offset.zero, Offset(s, s), grid, dash);
    _dashedLine(canvas, Offset(s, 0), Offset(0, s), grid, dash);
  }

  void _dashedLine(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint,
    double dash,
  ) {
    final total = (to - from).distance;
    if (total == 0) return;
    final dir = (to - from) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final end = math.min(travelled + dash, total);
      canvas.drawLine(from + dir * travelled, from + dir * end, paint);
      travelled = end + dash;
    }
  }

  @override
  bool shouldRepaint(covariant _HanziBoardPainter oldDelegate) => true;
}
