import 'guest_store.dart';

class GuestSession {
  const GuestSession({
    required this.playerId,
    required this.playerName,
  });

  static const _playerIdKey = 'guest.playerId';
  static const _playerNameKey = 'guest.playerName';

  final String playerId;
  final String playerName;

  static Future<GuestSession> load() async {
    var playerId = readGuestValue(_playerIdKey);
    if (playerId == null || playerId.trim().isEmpty) {
      playerId = 'guest_${DateTime.now().microsecondsSinceEpoch}';
      await writeGuestValue(_playerIdKey, playerId);
    }

    final storedName = readGuestValue(_playerNameKey);
    final playerName = storedName == null || storedName.trim().isEmpty
        ? 'Guest ${playerId.substring(playerId.length - 4)}'
        : storedName.trim();
    await writeGuestValue(_playerNameKey, playerName);

    return GuestSession(playerId: playerId, playerName: playerName);
  }

  static Future<void> saveName(String value) async {
    final name = value.trim().isEmpty ? 'Player' : value.trim();
    await writeGuestValue(_playerNameKey, name);
  }
}
