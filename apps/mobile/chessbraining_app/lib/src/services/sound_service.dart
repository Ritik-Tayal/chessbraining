import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum GameSound {
  move('sounds/move.mp3'),
  matchStart('sounds/match_start.mp3'),
  matchEndWin('sounds/match_end_win.mp3'),
  matchEndLoss('sounds/match_end_loss.mp3'),
  matchEndDraw('sounds/match_end_draw.mp3'),
  brainRoundStart('sounds/brain_round_start.mp3'),
  brainRoundEnd('sounds/brain_round_end.mp3'),
  powerup('sounds/powerup.mp3'),
  error('sounds/error.mp3'),
  notify('sounds/notify.mp3');

  const GameSound(this.assetPath);
  final String assetPath;
}

class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final AudioPlayer _player = AudioPlayer();
  bool _enabled = true;
  double _volume = 0.6;

  bool get enabled => _enabled;
  double get volume => _volume;

  void setEnabled(bool value) {
    _enabled = value;
  }

  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0);
    _player.setVolume(_volume);
  }

  Future<void> play(GameSound sound) async {
    if (!_enabled) return;
    try {
      await _player.play(AssetSource(sound.assetPath));
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
    _player.dispose();
  }
}
