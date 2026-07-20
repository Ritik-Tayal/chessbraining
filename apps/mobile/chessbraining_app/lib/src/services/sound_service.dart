import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum GameSound {
  move('sounds/move.wav'),
  matchStart('sounds/match_start.wav'),
  matchEndWin('sounds/match_end_win.wav'),
  matchEndLoss('sounds/match_end_loss.wav'),
  matchEndDraw('sounds/match_end_draw.wav'),
  brainRoundStart('sounds/brain_round_start.wav'),
  brainRoundEnd('sounds/brain_round_end.wav'),
  powerup('sounds/powerup.wav'),
  error('sounds/error.wav'),
  notify('sounds/notify.wav'),
  unlock('sounds/unlock.wav'),
  musicLoop('sounds/music_loop.wav');

  const GameSound(this.assetPath);
  final String assetPath;
}

class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final Map<GameSound, AudioPlayer> _players = {};
  AudioPlayer? _musicPlayer;
  bool _enabled = true;
  bool _musicEnabled = true;
  bool _unlocked = false;
  double _volume = 0.6;
  double _musicVolume = 0.18;

  bool get enabled => _enabled;
  bool get musicEnabled => _musicEnabled;
  double get volume => _volume;
  double get musicVolume => _musicVolume;

  void setEnabled(bool value) {
    _enabled = value;
    if (!value) {
      stopMusic();
    }
  }

  void setMusicEnabled(bool value) {
    _musicEnabled = value;
    if (!value) {
      stopMusic();
    }
  }

  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0);
    for (final player in _players.values) {
      player.setVolume(_volume);
    }
  }

  void setMusicVolume(double value) {
    _musicVolume = value.clamp(0.0, 1.0);
    _musicPlayer?.setVolume(_musicVolume);
  }

  Future<void> unlock() async {
    if (_unlocked || !_enabled) return;
    _unlocked = true;
    await play(GameSound.unlock, volumeOverride: 0.02);
  }

  Future<void> play(GameSound sound, {double? volumeOverride}) async {
    if (!_enabled) return;
    try {
      var player = _players[sound];
      if (player == null) {
        player = AudioPlayer();
        _players[sound] = player;
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);
      }
      await player.stop();
      await player.setVolume(volumeOverride ?? _volume);
      await player.play(AssetSource(sound.assetPath));
    } catch (e) {
      if (kDebugMode) {
        print('Failed to play sound ${sound.assetPath}: $e');
      }
    }
  }

  Future<void> playMove() => play(GameSound.move);
  Future<void> playMatchStart() => play(GameSound.matchStart);
  Future<void> playMatchEndWin() => play(GameSound.matchEndWin);
  Future<void> playMatchEndLoss() => play(GameSound.matchEndLoss);
  Future<void> playMatchEndDraw() => play(GameSound.matchEndDraw);
  Future<void> playBrainRoundStart() => play(GameSound.brainRoundStart);
  Future<void> playBrainRoundEnd() => play(GameSound.brainRoundEnd);
  Future<void> playPowerup() => play(GameSound.powerup);
  Future<void> playError() => play(GameSound.error);
  Future<void> playNotify() => play(GameSound.notify);

  Future<void> startMusic() async {
    if (!_enabled || !_musicEnabled) return;
    try {
      final player = _musicPlayer ??= AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(_musicVolume);
      await player.play(AssetSource(GameSound.musicLoop.assetPath));
    } catch (e) {
      if (kDebugMode) {
        print('Failed to start music: $e');
      }
    }
  }

  Future<void> stopMusic() async {
    try {
      await _musicPlayer?.stop();
    } catch (_) {
      // Stopping music is best effort.
    }
  }

  void dispose() {
    for (final player in _players.values) {
      player.dispose();
    }
    _players.clear();
    _musicPlayer?.dispose();
    _musicPlayer = null;
  }
}
