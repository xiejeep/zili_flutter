import 'package:flutter_test/flutter_test.dart';
import 'package:zili_flutter/data/library_repository.dart';
import 'package:zili_flutter/data/stroke_codec.dart';
import 'package:zili_flutter/painters/hanzi_board.dart';

/// Drives the stroke animation frame by frame instead of waiting on a real
/// ticker, so the timing can be asserted exactly.
///
/// This exists because of two real defects found on device:
///  1. the pause phase never handed back to the drawing phase, so only the
///     first stroke was animated and the rest were skipped through in one gap
///     each;
///  2. the play/stop button did not listen to the controller, so after the run
///     finished it still read "停止播放" and tapping it restarted playback.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Library library;

  setUpAll(() async => library = await Library.load());

  StrokeGlyph glyphOf(String char) => library.glyph(char)!;

  /// Plays [glyph] at a 10 ms frame rate and reports what happened.
  _Run run(
    StrokeGlyph glyph, {
    double speed = 1,
    Duration stroke = const Duration(milliseconds: 100),
    Duration gap = const Duration(milliseconds: 20),
    Duration hold = const Duration(milliseconds: 50),
    int loops = 1,
  }) {
    final controller = HanziBoardController()
      ..strokeDuration = stroke
      ..strokeGap = gap
      ..loopHold = hold;
    controller.load(glyph);
    controller.play(speed);

    const frame = Duration(milliseconds: 10);
    final drawnFrames = <int, int>{};
    final partials = <int, List<double>>{};
    var elapsed = Duration.zero;
    var holds = 0;
    var inHold = false;
    var firstPass = Duration.zero;
    var restarts = 0;
    var previousIndex = controller.index;
    var guard = 0;

    while (holds < loops && guard++ < 50000) {
      elapsed += frame;
      controller.tick(elapsed);

      if (controller.partial > 0 && controller.partial < 1) {
        drawnFrames[controller.index] = (drawnFrames[controller.index] ?? 0) + 1;
        partials
            .putIfAbsent(controller.index, () => <double>[])
            .add(controller.partial);
      }

      // The hold phase is the only time the index sits past the last stroke.
      final holding = controller.index >= glyph.strokeCount;
      if (holding && !inHold) {
        holds++;
        if (holds == 1) firstPass = elapsed;
      }
      inHold = holding;

      if (previousIndex >= glyph.strokeCount && controller.index == 0) {
        restarts++;
      }
      previousIndex = controller.index;
    }

    return _Run(
      strokeCount: glyph.strokeCount,
      elapsed: elapsed,
      firstPass: firstPass,
      restarts: restarts,
      drawnFrames: drawnFrames,
      partials: partials,
      controller: controller,
    );
  }

  test('every stroke is animated, not just the first', () {
    final result = run(glyphOf('你'));

    expect(
      result.drawnFrames.keys.length,
      result.strokeCount,
      reason: '只有 ${result.drawnFrames.keys.length} 笔被真正绘制，共 ${result.strokeCount} 笔',
    );

    // 100 ms of drawing at a 10 ms frame rate is about 10 frames per stroke.
    for (final entry in result.drawnFrames.entries) {
      expect(
        entry.value,
        greaterThanOrEqualTo(8),
        reason: '第 ${entry.key + 1} 笔只画了 ${entry.value} 帧',
      );
    }
  });

  test('the progress sweeps from start to finish within each stroke', () {
    final result = run(glyphOf('国'));

    for (final entry in result.partials.entries) {
      final values = entry.value;
      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThan(values[i - 1]));
      }
      expect(values.first, lessThan(0.3));
      expect(values.last, greaterThan(0.7));
    }
  });

  test('one pass takes about a span plus a gap per stroke', () {
    final glyph = glyphOf('你');
    final result = run(glyph);

    final expected = glyph.strokeCount * 120;
    expect(result.firstPass.inMilliseconds, closeTo(expected, 40));
  });

  test('it keeps looping until stopped', () {
    final result = run(glyphOf('你'), loops: 3);

    expect(result.restarts, greaterThanOrEqualTo(2), reason: '应当反复从头播放');
    expect(result.controller.playing, isTrue, reason: '循环期间应保持播放状态');
  });

  test('the hold shows the whole character', () {
    final glyph = glyphOf('你');
    final result = run(glyph);

    // During the hold every stroke is past the cursor, so all of them render
    // in ink and nothing is left pale.
    expect(result.controller.index, glyph.strokeCount);
    expect(result.controller.partial, 0);
    expect(result.controller.message, '写完啦，再看一遍');
  });

  test('speed shortens a pass', () {
    final glyph = glyphOf('你');
    final normal = run(glyph, speed: 1);
    final fast = run(glyph, speed: 2);

    expect(fast.firstPass.inMilliseconds, lessThan(normal.firstPass.inMilliseconds));
    expect(
      fast.firstPass.inMilliseconds,
      closeTo(normal.firstPass.inMilliseconds / 2, 60),
    );
  });

  test('stopping mid play leaves nothing running', () {
    final controller = HanziBoardController()
      ..strokeDuration = const Duration(milliseconds: 100)
      ..strokeGap = const Duration(milliseconds: 20);
    controller.load(glyphOf('你'));
    controller.play(1);

    controller.tick(const Duration(milliseconds: 40));
    expect(controller.playing, isTrue);
    expect(controller.index, 0);

    controller.reset();
    expect(controller.playing, isFalse);
    expect(controller.index, -1);
    expect(controller.partial, 0);
    expect(controller.message, '点「播放笔顺」，看汉字一笔一画写出来');
  });

  test('switching character stops playback', () {
    final controller = HanziBoardController();
    controller.load(glyphOf('你'));
    controller.play(1);
    controller.tick(const Duration(milliseconds: 40));
    expect(controller.playing, isTrue);

    controller.load(glyphOf('好'));
    expect(controller.playing, isFalse);
    expect(controller.index, -1);
  });
}

class _Run {
  _Run({
    required this.strokeCount,
    required this.elapsed,
    required this.firstPass,
    required this.restarts,
    required this.drawnFrames,
    required this.partials,
    required this.controller,
  });

  final int strokeCount;
  final Duration elapsed;

  /// Time until the first pass reached the hold phase.
  final Duration firstPass;

  /// How many times playback wrapped back to the first stroke.
  final int restarts;

  /// Stroke index to the number of frames where it was partially drawn.
  final Map<int, int> drawnFrames;
  final Map<int, List<double>> partials;
  final HanziBoardController controller;
}
