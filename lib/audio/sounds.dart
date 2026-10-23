import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Feedback sounds that belong to the app, not to a language pack.
enum Sound {
  /// A correct answer.
  correct,

  /// The unit is finished.
  unitComplete,
}

/// Plays feedback sounds. A seam so tests can record what would play.
///
/// Separate from [AudioPlayerService]: a chime must not cut off the spoken phrase
/// that starts at the same moment, so it uses its own players.
abstract class SoundPlayer {
  Future<void> play(Sound sound);
  Future<void> dispose();
}

/// Plays nothing; the default where sounds are not wired up.
class SilentSoundPlayer implements SoundPlayer {
  const SilentSoundPlayer();

  @override
  Future<void> play(Sound sound) async {}

  @override
  Future<void> dispose() async {}
}

class JustAudioSoundPlayer implements SoundPlayer {
  static const _assets = {
    Sound.correct: 'assets/sounds/success-chime.m4a',
    Sound.unitComplete: 'assets/sounds/success-ring.m4a',
  };

  final Map<Sound, Future<AudioPlayer>> _players = {};

  Future<AudioPlayer> _load(Sound sound) => _players.putIfAbsent(sound, () async {
        final player = AudioPlayer();
        await player.setAsset(_assets[sound]!);
        return player;
      });

  /// Loads every sound so the first one plays without delay.
  Future<void> preload() async {
    for (final sound in Sound.values) {
      try {
        await _load(sound);
      } catch (error) {
        debugPrint('Sound $sound failed to load: $error');
      }
    }
  }

  @override
  Future<void> play(Sound sound) async {
    try {
      final player = await _load(sound);
      await player.seek(Duration.zero);
      // Not awaited: play() completes when the clip ends.
      player.play();
    } catch (error) {
      // A missing sound must never break a lesson.
      debugPrint('Sound $sound failed: $error');
    }
  }

  @override
  Future<void> dispose() async {
    for (final player in _players.values) {
      (await player).dispose();
    }
    _players.clear();
  }
}
