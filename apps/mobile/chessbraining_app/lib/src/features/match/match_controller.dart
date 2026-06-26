import 'package:flutter/foundation.dart';

import '../../api/chessbraining_api.dart';
import '../../api/match_socket_client.dart';
import '../../models/match_models.dart';

typedef MatchSocketFactory = MatchSocketClient Function({
  required String apiBaseUrl,
  required String matchId,
  required void Function(MatchModel match) onMatch,
  required void Function(bool connected) onConnectionChanged,
});

class MatchController extends ChangeNotifier {
  MatchController({
    required ChessbrainingApi api,
    required MatchSocketFactory socketFactory,
  })  : _api = api,
        _socketFactory = socketFactory;

  ChessbrainingApi _api;
  final MatchSocketFactory _socketFactory;
  MatchSocketClient? _socket;

  String apiBaseUrl = 'http://localhost:8080/api/v1';
  String playerName = 'Player';
  late final String playerId = 'player_${DateTime.now().microsecondsSinceEpoch}';

  MatchModel? match;
  List<LegalMoveModel> legalMoves = const [];
  String? selectedSquare;
  String? error;
  bool loading = false;
  bool realtimeConnected = false;

  PlayerModel? get me => match?.playerById(playerId);
  bool get isMyTurn => me != null && match?.sideToMove == me!.side;
  bool get canMove => match?.isChessPhase == true && isMyTurn;

  void updateApiBaseUrl(String value) {
    apiBaseUrl = value.trim();
    _api = _api.copyWithBaseUrl(apiBaseUrl);
    notifyListeners();
  }

  void updatePlayerName(String value) {
    playerName = value.trim().isEmpty ? 'Player' : value.trim();
    notifyListeners();
  }

  Future<void> createMatch() {
    return _run(() async {
      _setMatch(await _api.createMatch(
        playerId: playerId,
        playerName: playerName,
      ));
    });
  }

  Future<void> quickplay() {
    return _run(() async {
      _setMatch(await _api.quickplay(
        playerId: playerId,
        playerName: playerName,
      ));
    });
  }

  Future<void> joinMatch(String inviteCode) {
    return _run(() async {
      _setMatch(await _api.joinMatch(
        inviteCode: inviteCode,
        playerId: playerId,
        playerName: playerName,
      ));
    });
  }

  Future<void> refresh() {
    final current = match;
    if (current == null) {
      return Future.value();
    }
    return _run(() async {
      _setMatch(await _api.getMatch(current.matchId));
    });
  }

  Future<void> selectSquare(String square) async {
    if (!canMove) {
      return;
    }
    final currentSelection = selectedSquare;
    if (currentSelection == null) {
      selectedSquare = square;
      notifyListeners();
      return;
    }

    final move = legalMoves.where((item) {
      return item.from == currentSelection && item.to == square;
    }).firstOrNull;

    if (move == null) {
      selectedSquare = square;
      notifyListeners();
      return;
    }

    await _run(() async {
      _setMatch(await _api.submitMove(
        matchId: match!.matchId,
        playerId: playerId,
        from: move.from,
        to: move.to,
        promotion: move.promotion,
      ));
    });
  }

  Future<void> completeBrainRound(
    String? winnerPlayerId, {
    int? whiteScore,
    int? blackScore,
  }) {
    final current = match;
    if (current == null) {
      return Future.value();
    }
    return _run(() async {
      _setMatch(await _api.completeBrainRound(
        matchId: current.matchId,
        winnerPlayerId: winnerPlayerId,
        whiteScore: whiteScore ?? (winnerPlayerId == current.white.playerId ? 5 : 3),
        blackScore: blackScore ?? (winnerPlayerId == current.black?.playerId ? 5 : 3),
      ));
    });
  }

  Future<void> claimBrainRoundWin(int score) {
    final current = match;
    if (current == null) {
      return Future.value();
    }
    return completeBrainRound(
      playerId,
      whiteScore: current.white.playerId == playerId ? score : 0,
      blackScore: current.black?.playerId == playerId ? score : 0,
    );
  }

  Future<void> resign() {
    final current = match;
    if (current == null) {
      return Future.value();
    }
    return _run(() async {
      _setMatch(await _api.resign(
        matchId: current.matchId,
        playerId: playerId,
      ));
    });
  }

  bool isLegalTarget(String square) {
    final source = selectedSquare;
    if (source == null) {
      return false;
    }
    return legalMoves.any((move) => move.from == source && move.to == square);
  }

  Future<void> _loadLegalMoves() async {
    final current = match;
    if (current == null || !canMove) {
      legalMoves = const [];
      return;
    }
    legalMoves = await _api.legalMoves(
      matchId: current.matchId,
      playerId: playerId,
    );
  }

  void _setMatch(MatchModel value) {
    final previousMatchId = match?.matchId;
    match = value;
    selectedSquare = null;
    _connectRealtimeIfNeeded(previousMatchId);
    _loadLegalMoves().then((_) => notifyListeners());
    notifyListeners();
  }

  void _connectRealtimeIfNeeded(String? previousMatchId) {
    final current = match;
    if (current == null || previousMatchId == current.matchId) {
      return;
    }
    _socket?.disconnect();
    _socket = _socketFactory(
      apiBaseUrl: apiBaseUrl,
      matchId: current.matchId,
      onMatch: (value) {
        match = value;
        selectedSquare = null;
        _loadLegalMoves().then((_) => notifyListeners());
        notifyListeners();
      },
      onConnectionChanged: (value) {
        realtimeConnected = value;
        notifyListeners();
      },
    )..connect();
  }

  Future<void> _run(Future<void> Function() action) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } on ApiException catch (exception) {
      error = exception.message;
    } catch (exception) {
      error = exception.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _socket?.disconnect();
    super.dispose();
  }
}
