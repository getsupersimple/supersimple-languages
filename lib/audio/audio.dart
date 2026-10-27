import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../packs/models.dart';

/// Plays one file at a time. A seam so tests can record what would play.
abstract class AudioPlayerService {
  Future<void> playFile(String path);
  Future<void> stop();
  Future<void> dispose();
}

class JustAudioPlayerService implements AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  /// Bumped by every play and stop, so a clip still loading when the learner
  /// moves on is dropped instead of starting late.
  int _generation = 0;

  @override
  Future<void> playFile(String path) async {
    final generation = ++_generation;
    try {
      await _player.stop();
      await _player.setFilePath(path);
      if (generation != _generation) return;
      // Not awaited: play() completes when the clip ends, and callers only
      // need it to start.
      _player.play();
    } catch (error) {
      // A missing or undecodable clip must never break a lesson.
      debugPrint('Audio failed for $path: $error');
    }
  }

  @override
  Future<void> stop() {
    _generation++;
    return _player.stop();
  }

  @override
  Future<void> dispose() => _player.dispose();
}

/// Plays recordings of an installed unit.
///
/// Items can have several recordings (voices). The lesson picks a voice per
/// exercise, so a prompt and its tiles share a speaker, and variety comes from
/// exercise to exercise.
class LessonAudio {
  LessonAudio({required this.player, required this.pathFor});

  final AudioPlayerService player;

  /// Absolute path of a recording on disk.
  final String Function(Recording) pathFor;

  Future<void> play(List<Recording> recordings, {String? voiceId}) async {
    final recording = chooseRecording(recordings, voiceId);
    if (recording == null) return;
    await player.playFile(pathFor(recording));
  }

  Future<void> stop() => player.stop();
}

/// The recording by [voiceId] if there is one, otherwise the first.
Recording? chooseRecording(List<Recording> recordings, String? voiceId) {
  if (recordings.isEmpty) return null;
  return recordings.firstWhere(
    (r) => r.voiceId == voiceId,
    orElse: () => recordings.first,
  );
}
