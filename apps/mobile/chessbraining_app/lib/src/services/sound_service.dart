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
  notify('sounds/notify.wav');

  const GameSound(this.assetPath);
  final String assetPath;
}

class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final Map<GameSound, AudioPlayer> _players = {};
  bool _enabled = true;
  double _volume = 0.6;

  bool get enabled => _enabled;
  double get volume => _volume;

  void setEnabled(bool value) {
    _enabled = value;
  }

  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0);
    for (final player in _players.values) {
      player.setVolume(_volume);
    }
  }

  Future<void> play(GameSound sound) async {
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
      await player.setVolume(_volume);
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

  void dispose() {
    for (final player in _players.values) {
      player.dispose();
    }
    _players.clear();
  }
}
