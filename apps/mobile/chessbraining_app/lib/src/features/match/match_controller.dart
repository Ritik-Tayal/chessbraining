import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../api/chessbraining_api.dart';
import '../../api/match_socket_client.dart';
import '../../models/match_models.dart';
import '../../session/guest_session.dart';
import '../../services/sound_service.dart';

typedef MatchSocketFactory = MatchSocketClient Function({
  required String apiBaseUrl,
  required String matchId,
  required void Function(MatchModel match) onMatch,
  required void Function(bool connected) onConnectionChanged,
});

enum PowerupTargetMode {
  none,
  revivePawn,
}

class MatchController extends ChangeNotifier {
  MatchController({
    required ChessbrainingApi api,
    required MatchSocketFactory socketFactory,
    required GuestSession guestSession,
  })  : _api = api,
        _socketFactory = socketFactory,
        playerId = guestSession.playerId,
        playerName = guestSession.playerName;

  ChessbrainingApi _api;
  final MatchSocketFactory _socketFactory;
  MatchSocketClient? _socket;

  String apiBaseUrl = ChessbrainingApi.defaultBaseUrl;
  final String playerId;
  String playerName;

  MatchModel? match;
  BrainRoundModel? brainRound;
  List<LegalMoveModel> legalMoves = const [];
  String? selectedSquare;
  String? error;
  bool loading = false;
  bool brainRoundLoading = false;
  bool realtimeConnected = false;
  PowerupTargetMode powerupTargetMode = PowerupTargetMode.none;

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

  bool get canArmExtraMove {
    final current = match;
    final currentPlayer = me;
    if (current == null ||
        !current.isChessPhase ||
        currentPlayer == null ||
        !isMyTurn ||
        currentPlayer.brainPoints < 4 ||
        currentPlayer.extraMoveArmed ||
        currentPlayer.extraMoveActive) {
      return false;
    }
    final interval = current.brainRoundIntervalMoves * 2;
    return interval <= 0 || (current.plyCount + 1) % interval != 0;
  }

  bool get canRevivePawn {
    final current = match;
    final currentPlayer = me;
    return current != null &&
        current.isChessPhase &&
        currentPlayer != null &&
        isMyTurn &&
        currentPlayer.brainPoints >= 3 &&
        currentPlayer.revivablePawns > 0;
  }

  bool get isRevivePawnTargeting =>
      powerupTargetMode == PowerupTargetMode.revivePawn;

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
    unawaited(GuestSession.saveName(playerName));
    notifyListeners();
  }

  Future<void> createMatch() {
    return _run(() async {
      _setMatch(await _api.createMatch(
        playerId: playerId,
        playerName: playerName,
      ));
      SoundService.instance.playNotify();
    });
  }

  Future<void> quickplay() {
    return _run(() async {
      _setMatch(await _api.quickplay(
        playerId: playerId,
        playerName: playerName,
      ));
      SoundService.instance.playNotify();
    });
  }

  Future<void> joinMatch(String inviteCode) {
    return _run(() async {
      _setMatch(await _api.joinMatch(
        inviteCode: inviteCode,
        playerId: playerId,
        playerName: playerName,
      ));
      SoundService.instance.playNotify();
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
    if (powerupTargetMode == PowerupTargetMode.revivePawn) {
      await applyRevivePawn(square);
      return;
    }
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
      SoundService.instance.playMove();
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
      error = _friendlyError(exception);
      SoundService.instance.playError();
    } catch (exception) {
      error = _friendlyError(exception);
      SoundService.instance.playError();
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
      final currentRound = brainRound;
      if (currentRound != null) {
        final isWhite = me?.side == 'WHITE';
        final nextWhite = isWhite
            ? min(currentRound.nextWhiteQuestionIndex + 1,
                currentRound.totalQuestions)
            : currentRound.nextWhiteQuestionIndex;
        final nextBlack = isWhite
            ? currentRound.nextBlackQuestionIndex
            : min(currentRound.nextBlackQuestionIndex + 1,
                currentRound.totalQuestions);
        brainRound = BrainRoundModel(
          roundId: currentRound.roundId,
          roundNumber: currentRound.roundNumber,
          status: currentRound.status,
          puzzles: currentRound.puzzles,
          totalQuestions: currentRound.totalQuestions,
          whiteCorrectCount: isWhite
              ? result.playerCorrectCount
              : currentRound.whiteCorrectCount,
          blackCorrectCount: isWhite
              ? currentRound.blackCorrectCount
              : result.playerCorrectCount,
          nextWhiteQuestionIndex: nextWhite,
          nextBlackQuestionIndex: nextBlack,
          winnerPlayerId: currentRound.winnerPlayerId,
          startedAt: currentRound.startedAt,
          expiresAt: currentRound.expiresAt,
        );
      }
      notifyListeners();
      return result;
    } on ApiException catch (exception) {
      error = _friendlyError(exception);
      SoundService.instance.playError();
    } catch (exception) {
      error = _friendlyError(exception);
      SoundService.instance.playError();
    }
    notifyListeners();
    return null;
  }

  Future<BrainRoundSubmissionModel?> submitBrainRoundAnswers(
    Map<int, int> answers,
  ) async {
    final current = match;
    if (current == null) {
      return null;
    }
    try {
      final result = await _api.submitBrainRoundAnswers(
        matchId: current.matchId,
        playerId: playerId,
        answers: answers,
      );
      final currentRound = brainRound;
      if (currentRound != null) {
        final isWhite = me?.side == 'WHITE';
        brainRound = BrainRoundModel(
          roundId: currentRound.roundId,
          roundNumber: currentRound.roundNumber,
          status: currentRound.status,
          puzzles: currentRound.puzzles,
          totalQuestions: currentRound.totalQuestions,
          whiteCorrectCount: isWhite
              ? result.playerCorrectCount
              : currentRound.whiteCorrectCount,
          blackCorrectCount: isWhite
              ? currentRound.blackCorrectCount
              : result.playerCorrectCount,
          nextWhiteQuestionIndex: isWhite
              ? result.playerAnsweredCount
              : currentRound.nextWhiteQuestionIndex,
          nextBlackQuestionIndex: isWhite
              ? currentRound.nextBlackQuestionIndex
              : result.playerAnsweredCount,
          winnerPlayerId: currentRound.winnerPlayerId,
          startedAt: currentRound.startedAt,
          expiresAt: currentRound.expiresAt,
        );
      }
      if (result.roundCompleted) {
        _setMatch(await _api.getMatch(current.matchId));
      } else {
        notifyListeners();
      }
      return result;
    } on ApiException catch (exception) {
      if (exception.code == 'BRAIN_ROUND_NOT_FOUND' ||
          exception.code == 'NOT_IN_BRAIN_ROUND') {
        final latest = await _api.getMatch(current.matchId);
        if (!latest.isBrainRound) {
          brainRound = null;
          _setMatch(latest);
          return null;
        }
      }
      error = _friendlyError(exception);
      SoundService.instance.playError();
    } catch (exception) {
      error = _friendlyError(exception);
      SoundService.instance.playError();
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
      SoundService.instance.playPowerup();
    });
  }

  Future<void> armExtraMove() {
    final current = match;
    if (current == null || !canArmExtraMove) {
      return Future.value();
    }
    return _run(() async {
      _setMatch(await _api.applyPowerup(
        matchId: current.matchId,
        playerId: playerId,
        type: 'EXTRA_MOVE',
      ));
      SoundService.instance.playPowerup();
    });
  }

  void startRevivePawnTargeting() {
    if (!canRevivePawn) {
      return;
    }
    powerupTargetMode = PowerupTargetMode.revivePawn;
    selectedSquare = null;
    error = null;
    notifyListeners();
  }

  void cancelPowerupTargeting() {
    powerupTargetMode = PowerupTargetMode.none;
    notifyListeners();
  }

  Future<void> applyRevivePawn(String targetSquare) {
    final current = match;
    if (current == null || !canRevivePawn) {
      return Future.value();
    }
    if (!isPowerupTarget(targetSquare)) {
      error = 'Choose an empty square between ranks 2 and 7.';
      SoundService.instance.playError();
      notifyListeners();
      return Future.value();
    }
    return _run(() async {
      _setMatch(await _api.applyPowerup(
        matchId: current.matchId,
        playerId: playerId,
        type: 'REVIVE_PAWN',
        targetSquare: targetSquare,
      ));
      SoundService.instance.playPowerup();
      powerupTargetMode = PowerupTargetMode.none;
    });
  }

  bool isLegalTarget(String square) {
    final source = selectedSquare;
    if (source == null) {
      return false;
    }
    return legalMoves.any((move) => move.from == source && move.to == square);
  }

  bool isPowerupTarget(String square) {
    if (!isRevivePawnTargeting || _pieceAt(square) != null) {
      return false;
    }
    final rank = int.tryParse(square.substring(1));
    return rank != 1 && rank != 8;
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
      error = _friendlyError(exception);
      SoundService.instance.playError();
    } catch (exception) {
      legalMoves = const [];
      error = _friendlyError(exception);
      SoundService.instance.playError();
    }
  }

  void _setMatch(MatchModel value) {
    final previousMatch = match;
    final previousMatchId = previousMatch?.matchId;
    final previousPlyCount = previousMatch?.plyCount ?? 0;
    final previousIsBrainRound = previousMatch?.isBrainRound ?? false;
    final previousIsCompleted = previousMatch?.isCompleted ?? false;

    match = value;
    selectedSquare = null;
    powerupTargetMode = PowerupTargetMode.none;
    if (!value.isBrainRound) {
      brainRound = null;
    }
    _connectRealtimeIfNeeded(previousMatchId);

    final plyIncreased = value.plyCount > previousPlyCount;
    final matchJustStarted = previousMatch == null && value.isChessPhase;
    final matchJustCompleted = !previousIsCompleted && value.isCompleted;
    final brainRoundJustStarted = !previousIsBrainRound && value.isBrainRound;
    final brainRoundJustEnded = previousIsBrainRound && !value.isBrainRound;

    if (matchJustStarted) {
      SoundService.instance.playMatchStart();
    } else if (matchJustCompleted) {
      final me = value.playerById(playerId);
      if (me != null) {
        if (value.winnerPlayerId == playerId) {
          SoundService.instance.playMatchEndWin();
        } else if (value.isDraw) {
          SoundService.instance.playMatchEndDraw();
        } else {
          SoundService.instance.playMatchEndLoss();
        }
      }
    } else if (brainRoundJustStarted) {
      SoundService.instance.playBrainRoundStart();
    } else if (brainRoundJustEnded) {
      SoundService.instance.playBrainRoundEnd();
    } else if (plyIncreased && value.isChessPhase) {
      SoundService.instance.playMove();
    }

    if (value.isBrainRound) {
      loadCurrentBrainRound();
      notifyListeners();
    } else {
      _loadLegalMoves().then((_) => notifyListeners());
    }
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
        powerupTargetMode = PowerupTargetMode.none;
        if (!value.isBrainRound) {
          brainRound = null;
        }
        if (value.isBrainRound) {
          loadCurrentBrainRound();
          notifyListeners();
        } else {
          _loadLegalMoves().then((_) => notifyListeners());
        }
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
      error = _friendlyError(exception);
      SoundService.instance.playError();
    } catch (exception) {
      error = _friendlyError(exception);
      SoundService.instance.playError();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  String? _pieceAt(String square) {
    final current = match;
    if (current == null) {
      return null;
    }
    final placement = current.fen.split(' ').first;
    final ranks = placement.split('/');
    for (var rankIndex = 0; rankIndex < ranks.length; rankIndex++) {
      final rank = 8 - rankIndex;
      var fileIndex = 0;
      for (final unit in ranks[rankIndex].split('')) {
        final emptyCount = int.tryParse(unit);
        if (emptyCount != null) {
          fileIndex += emptyCount;
          continue;
        }
        final file = String.fromCharCode('a'.codeUnitAt(0) + fileIndex);
        if ('$file$rank' == square) {
          return unit;
        }
        fileIndex++;
      }
    }
    return null;
  }

  String _friendlyError(Object exception) {
    if (exception is ApiException) {
      return switch (exception.code) {
        'REQUEST_TIMEOUT' =>
          'Could not reach the match server. Render may be waking up, so try again in a few seconds.',
        'MATCH_NOT_FOUND' =>
          'That match could not be found. Check the invite code and try again.',
        'CANNOT_JOIN_OWN_MATCH' =>
          'Open this invite on a second device or share it with a friend.',
        'MATCH_ALREADY_STARTED' =>
          'That table already has two players. Create a new private match instead.',
        'INVITE_CODE_REQUIRED' =>
          'Enter the 6-character invite code from your friend.',
        'INSUFFICIENT_BRAIN_POINTS' =>
          'You need more Brain Points before using that powerup.',
        'POWERUP_NOT_YOUR_TURN' => 'Powerups can only be used on your turn.',
        'POWERUP_TARGET_OCCUPIED' =>
          'Choose an empty square for the revived pawn.',
        'NO_PAWN_TO_REVIVE' => 'You do not have a captured pawn to revive yet.',
        _ => exception.message,
      };
    }

    final raw = exception.toString().toLowerCase();
    if (raw.contains('failed to fetch') ||
        raw.contains('socketexception') ||
        raw.contains('clientexception') ||
        raw.contains('xmlhttprequest')) {
      return 'Could not reach the match server. Check your connection and try again.';
    }
    return 'Something went wrong. Try again in a few seconds.';
  }

  @override
  void dispose() {
    _socket?.disconnect();
    super.dispose();
  }
}
