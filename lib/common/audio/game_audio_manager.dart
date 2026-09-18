import 'package:flame_audio/bgm.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/cupertino.dart';

import '../settings/settings_manager.dart';
import 'game_audio.dart';

/// Plays the game's music and sound effects.
///
/// Sound effects are replayed through a small pool of pre-loaded players
/// instead of a new player per effect. Creating a player per effect was the
/// most expensive thing the app did while playing: every player starts a
/// position updater that calls back into the platform once per frame, so a
/// burst of taps meant a burst of platform-channel round trips for a value the
/// effects never read.
class GameAudioManager {
  GameAudioManager({
    required this.settingsManager,
    AudioCache? audioCache,
    Bgm? bgm,
  }) : audioCache = audioCache ?? FlameAudio.audioCache,
       bgm = bgm ?? FlameAudio.bgm {
    // Background music never needs its playback position, and the default
    // updater calls back into the platform once per frame. That polling was
    // the single largest cost while a game was running.
    this.bgm.audioPlayer.positionUpdater = null;
  }

  final AudioCache audioCache;
  final Bgm bgm;
  final SettingsManager settingsManager;

  /// One player per effect file, created on first use.
  final Map<String, AudioPlayer> _players = {};

  /// Guards against overlapping loads for the same file.
  final Map<String, Future<AudioPlayer?>> _pending = {};

  bool _disposed = false;

  /// Every effect file the game can play.
  static const List<String> effectFiles = [
    GameAudio.bombExplosion,
    GameAudio.menuClick,
    GameAudio.menuClickAlt,
    GameAudio.menuClickAlt2,
    GameAudio.openArea0,
    GameAudio.openArea1,
    GameAudio.openArea2,
    GameAudio.openArea3,
    GameAudio.openMultiple0,
    GameAudio.openMultiple1,
    GameAudio.openMultiple2,
    GameAudio.putFlag0,
    GameAudio.putFlag1,
    GameAudio.putFlag2,
    GameAudio.revealMine0,
    GameAudio.revealMine1,
    GameAudio.revealMine2,
    GameAudio.revealMineReload,
    GameAudio.win,
  ];

  Future<void> preLoad() async {
    final settings = settingsManager.cache;
    try {
      if (settings.music) {
        await audioCache.load(GameAudio.music);
      } else {
        await audioCache.clear(GameAudio.music);
      }
    } catch (e) {
      debugPrint('Error preloading music: $e');
    }
    // Effects are prepared on first use rather than eagerly: building every
    // player up front spins up a native decoder for clips that may never play
    // in a given session.
  }

  void playMusic({bool restart = false}) async {
    final settings = settingsManager.cache;
    final currentState = bgm.audioPlayer.state;
    if (settings.music && currentState != PlayerState.playing) {
      try {
        if (!restart && currentState == PlayerState.paused) {
          await bgm.resume();
        } else {
          await bgm.play(GameAudio.music, volume: 0.5);
        }
      } catch (e) {
        debugPrint('Error playing music: $e');
      }
    }
  }

  bool isMusicPlaying() {
    return bgm.audioPlayer.state == PlayerState.playing;
  }

  void pauseMusic() async {
    try {
      await bgm.stop();
    } catch (e) {
      debugPrint('Error pausing music: $e');
    }
  }

  void playBombExplosion() => _play(GameAudio.bombExplosion);

  void playOpenArea() => _play(_pick([
    GameAudio.openArea0,
    GameAudio.openArea1,
    GameAudio.openArea2,
    GameAudio.openArea3,
    GameAudio.openMultiple0,
    GameAudio.openMultiple1,
    GameAudio.openMultiple2,
  ]));

  void playFlag() => _play(_pick([
    GameAudio.putFlag0,
    GameAudio.putFlag1,
    GameAudio.putFlag2,
  ]));

  void playWin() => _play(GameAudio.win);

  void playRevealMine() => _play(_pick([
    GameAudio.revealMine0,
    GameAudio.revealMine1,
    GameAudio.revealMine2,
  ]));

  /// Releases every pooled player. Call when the game is torn down.
  Future<void> dispose() async {
    _disposed = true;
    final players = _players.values.toList();
    _players.clear();
    _pending.clear();
    for (final player in players) {
      try {
        await player.dispose();
      } catch (_) {
        // Disposal failures are not actionable here.
      }
    }
  }

  String _pick(List<String> options) {
    if (options.isEmpty) {
      return GameAudio.menuClick;
    }
    // Random order, but never repeat the current choice back to back so
    // consecutive taps do not sound identical.
    final candidates = options.where((e) => e != _lastPlayed).toList();
    final choice = candidates.isEmpty
        ? options.first
        : candidates[DateTime.now().microsecond % candidates.length];
    return choice;
  }

  String? _lastPlayed;

  void _play(String fileName) async {
    if (!settingsManager.cache.soundEffects || _disposed) {
      return;
    }
    _lastPlayed = fileName;
    final player = await _playerFor(fileName);
    if (player == null || _disposed) {
      return;
    }
    try {
      // Restart from the beginning. `stop` then `resume` is more reliable than
      // `seek` for very short clips, which may already have finished.
      await player.stop();
      await player.resume();
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  /// Returns a ready player for [fileName], creating it once and reusing it.
  Future<AudioPlayer?> _playerFor(String fileName) {
    final existing = _players[fileName];
    if (existing != null) {
      return Future.value(existing);
    }
    return _pending.putIfAbsent(fileName, () async {
      try {
        final player = AudioPlayer();
        // Effects never read the position, and the default updater calls into
        // the platform every frame. Dropping it removes that cost entirely.
        player.positionUpdater = null;
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setSource(AssetSource('audio/$fileName'));
        if (_disposed) {
          await player.dispose();
          return null;
        }
        _players[fileName] = player;
        return player;
      } catch (e) {
        debugPrint('Error preparing audio "$fileName": $e');
        return null;
      } finally {
        _pending.remove(fileName);
      }
    });
  }
}
