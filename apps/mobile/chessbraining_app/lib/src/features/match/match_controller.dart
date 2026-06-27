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
  BrainRoundModel? brainRound;
  List<LegalMoveModel> legalMoves = const [];
  String? selectedSquare;
  String? error;
  bool loading = false;
  bool brainRoundLoading = false;
  bool realtimeConnected = false;

  PlayerModel? get me => match?.playerById(playerId);
  bool get isMyTurn => me != null && match?.sideToMove == me!.side;
  bool get canMove => match?.isChessPhase == true && isMyTurn;
  bool get canUseClockBoost {
    final current = match;
    final currentPlayer = me;
    return current != null &&
        current.isChessPhase &&
        currentPlayer != null &&
        currentPlayer.brainPoints >= 1;
  }

  int get nextBrainQuestionIndex {
    final round = brainRound;
    final currentPlayer = me;
    if (round == null || currentPlayer == null) {
      return 0;
    }
    return currentPlayer.side == 'WHITE'
        ? round.nextWhiteQuestionIndex
        : round.nextBlackQuestionIndex;
  }

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

  Future<void> loadCurrentBrainRound() async {
    final current = match;
    if (current == null || !current.isBrainRound) {
      brainRound = null;
      return;
    }
    brainRoundLoading = true;
    notifyListeners();
    try {
      final round = await _api.getCurrentBrainRound(current.matchId);
      brainRound = round;
      if (round.status != 'ACTIVE') {
        _setMatch(await _api.getMatch(current.matchId));
      }
    } on ApiException catch (exception) {
      if (exception.code == 'BRAIN_ROUND_NOT_FOUND' ||
          exception.code == 'NOT_IN_BRAIN_ROUND') {
        final latest = await _api.getMatch(current.matchId);
        if (!latest.isBrainRound) {
          brainRound = null;
          _setMatch(latest);
          return;
        }
      }
      error = exception.message;
    } catch (exception) {
      error = exception.toString();
    } finally {
      brainRoundLoading = false;
      notifyListeners();
    }
  }

  Future<AnswerResultModel?> submitBrainRoundAnswer({
    required int questionIndex,
    required int answer,
  }) async {
    final current = match;
    if (current == null) {
      return null;
    }
    try {
      final result = await _api.submitBrainRoundAnswer(
        matchId: current.matchId,
        playerId: playerId,
        questionIndex: questionIndex,
        answer: answer,
      );
      await loadCurrentBrainRound();
      return result;
    } on ApiException catch (exception) {
      error = exception.message;
    } catch (exception) {
      error = exception.toString();
    }
    notifyListeners();
    return null;
  }

  Future<void> completeBrainRound() {
    final current = match;
    if (current == null) {
      return Future.value();
    }
    return _run(() async {
      _setMatch(await _api.completeBrainRound(matchId: current.matchId));
    });
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

  Future<void> applyClockBoost() {
    final current = match;
    if (current == null || !canUseClockBoost) {
      return Future.value();
    }
    return _run(() async {
      _setMatch(await _api.applyPowerup(
        matchId: current.matchId,
        playerId: playerId,
        type: 'CLOCK_BOOST_30',
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
    try {
      legalMoves = await _api.legalMoves(
        matchId: current.matchId,
        playerId: playerId,
      );
    } on ApiException catch (exception) {
      legalMoves = const [];
      error = exception.message;
    } catch (exception) {
      legalMoves = const [];
      error = exception.toString();
    }
  }

  void _setMatch(MatchModel value) {
    final previousMatchId = match?.matchId;
    match = value;
    selectedSquare = null;
    if (!value.isBrainRound) {
      brainRound = null;
    }
    _connectRealtimeIfNeeded(previousMatchId);
    _loadLegalMoves().then((_) => notifyListeners());
    if (value.isBrainRound) {
      loadCurrentBrainRound();
    }
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
        if (!value.isBrainRound) {
          brainRound = null;
        }
        _loadLegalMoves().then((_) => notifyListeners());
        if (value.isBrainRound) {
          loadCurrentBrainRound();
        }
        notifyListeners();
      },
      onConnectionChanged: (value) {
        realtimeConnected = value;
        if (value) {
          refresh();
        }
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
