import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays a sequence of bundled syllable clips back to back.
///
/// The library ships one clip per pinyin syllable instead of one per word or
/// sentence, so a word is pronounced by queueing its syllables. All clips live
/// under `assets/audio/syllables/`.
class SyllablePlayer extends ChangeNotifier {
  SyllablePlayer() {
    _player.setReleaseMode(ReleaseMode.stop);
    _completeSub = _player.onPlayerComplete.listen((_) => _playNext());
    _errorSub = _player.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.stopped) _playing = false;
    });
  }

  static const String _prefix = 'audio/syllables/';

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _completeSub;
  StreamSubscription<PlayerState>? _errorSub;
  final List<String> _queue = [];
  bool _playing = false;
  String? _failed;

  bool get playing => _playing;

  /// Set when the last playback attempt failed, so the UI can surface it once.
  String? takeError() {
    final message = _failed;
    _failed = null;
    return message;
  }

  /// Plays one syllable, e.g. `ni3.m4a`.
  Future<void> playSyllable(String clip) => playSequence([clip]);

  /// Plays several syllables in order, e.g. the two characters of a word.
  Future<void> playSequence(List<String> clips) async {
    final usable = clips.where((c) => c.isNotEmpty).toList();
    if (usable.isEmpty) return;
    await _player.stop();
    _queue
      ..clear()
      ..addAll(usable);
    await _playNext();
  }

  Future<void> _playNext() async {
    if (_queue.isEmpty) {
      _playing = false;
      notifyListeners();
      return;
    }
    final clip = _queue.removeAt(0);
    try {
      _playing = true;
      notifyListeners();
      await _player.play(AssetSource('$_prefix$clip'));
    } catch (error) {
      _failed = '音频播放失败，请重试';
      _playing = false;
      _queue.clear();
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _queue.clear();
    _playing = false;
    notifyListeners();
    await _player.stop();
  }

  @override
  void dispose() {
    _completeSub?.cancel();
    _errorSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
