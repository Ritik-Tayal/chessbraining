import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../api/chessbraining_api.dart';
import '../../api/match_socket_client.dart';
import '../../models/match_models.dart';
import '../../session/guest_session.dart';
import '../../services/sound_service.dart';
import 'fen.dart';

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

enum PowerupEffectType {
  clockBoost,
  extraMove,
  revivePawn,
}

class BoardMoveAnimation {
  const BoardMoveAnimation({
    required this.id,
    required this.from,
    required this.to,
    required this.piece,
  });

  final int id;
  final String from;
  final String to;
  final String piece;
}

class PowerupEffect {
  const PowerupEffect({
    required this.id,
    required this.type,
    required this.playerName,
    required this.side,
  });

  final int id;
  final PowerupEffectType type;
  final String playerName;
  final String side;
}

class BrainRoundResultNotice {
  const BrainRoundResultNotice({
    required this.id,
    required this.roundId,
    required this.roundNumber,
    required this.whiteName,
    required this.blackName,
    required this.whiteScore,
    required this.blackScore,
    required this.winnerPlayerId,
    required this.winnerName,
    required this.awardedPoints,
  });

  final int id;
  final String roundId;
  final int roundNumber;
  final String whiteName;
  final String blackName;
  final int whiteScore;
  final int blackScore;
  final String? winnerPlayerId;
  final String winnerName;
  final int awardedPoints;

  bool get isTie => winnerPlayerId == null;
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
  bool movePending = false;
  BoardMoveAnimation? boardMoveAnimation;
  String? reviewFen;
  MoveModel? reviewMove;
  PowerupEffect? powerupEffect;
  BrainRoundResultNotice? brainRoundResultNotice;
  PowerupTargetMode powerupTargetMode = PowerupTargetMode.none;
  int _boardAnimationSequence = 0;
  int _powerupEffectSequence = 0;
  int _brainRoundResultSequence = 0;
  String? _lastBrainRoundResultRoundId;
  String? _loadingRematchMatchId;

  PlayerModel? get me => match?.playerById(playerId);
  bool get isMyTurn => me != null && match?.sideToMove == me!.side;
  bool get isReviewingMove => reviewFen != null;
  String? get boardFen => reviewFen ?? match?.fen;
  MoveModel? get boardLastMove {
    if (reviewMove != null) {
      return reviewMove;
    }
    final moves = match?.moves;
    if (moves == null || moves.isEmpty) {
      return null;
    }
    return moves.last;
  }

  bool get canMove =>
      !isReviewingMove &&
      match?.isChessPhase == true &&
      isMyTurn &&
      !movePending;
  bool get canUseClockBoost {
    final current = match;
    final currentPlayer = me;
    return current != null &&
        current.isChessPhase &&
        !isReviewingMove &&
        currentPlayer != null &&
        currentPlayer.brainPoints >= 1;
  }

  bool get canArmExtraMove {
    final current = match;
    final currentPlayer = me;
    if (current == null ||
        !current.isChessPhase ||
        isReviewingMove ||
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
        !isReviewingMove &&
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

  void dismissPowerupEffect(int id) {
    if (powerupEffect?.id != id) {
      return;
    }
    powerupEffect = null;
    notifyListeners();
  }

  void dismissBrainRoundResult(int id) {
    if (brainRoundResultNotice?.id != id) {
      return;
    }
    brainRoundResultNotice = null;
    notifyListeners();
  }

  void viewMovePosition(MoveModel move) {
    reviewFen = move.fenAfter;
    reviewMove = move;
    selectedSquare = null;
    legalMoves = const [];
    powerupTargetMode = PowerupTargetMode.none;
    boardMoveAnimation = null;
    notifyListeners();
  }

  void returnToLivePosition() {
    if (!isReviewingMove) {
      return;
    }
    reviewFen = null;
    reviewMove = null;
    selectedSquare = null;
    notifyListeners();
    unawaited(_loadLegalMoves().then((_) => notifyListeners()));
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
    if (isReviewingMove) {
      returnToLivePosition();
      return;
    }
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

    final current = match!;
    final previousMatch = current;
    final previousLegalMoves = legalMoves;
    final piece = parseFenBoard(current.fen)[move.from];
    if (piece == null) {
      selectedSquare = square;
      notifyListeners();
      return;
    }

    final optimisticFen = applyMoveToFen(
      fen: current.fen,
      from: move.from,
      to: move.to,
      promotion: move.promotion,
    );
    final optimisticMove = MoveModel(
      plyNumber: current.plyCount + 1,
      playerId: playerId,
      side: current.sideToMove,
      from: move.from,
      to: move.to,
      promotion: move.promotion,
      fenBefore: current.fen,
      fenAfter: optimisticFen,
    );

    match = current.copyWith(
      fen: optimisticFen,
      sideToMove: _oppositeSide(current.sideToMove),
      plyCount: current.plyCount + 1,
      moves: List.unmodifiable([...current.moves, optimisticMove]),
    );
    selectedSquare = null;
    legalMoves = const [];
    movePending = true;
    error = null;
    boardMoveAnimation = BoardMoveAnimation(
      id: ++_boardAnimationSequence,
      from: move.from,
      to: move.to,
      piece: piece,
    );
    notifyListeners();
    unawaited(SoundService.instance.playMove());

    try {
      final confirmed = await _api.submitMove(
        matchId: current.matchId,
        playerId: playerId,
        from: move.from,
        to: move.to,
        promotion: move.promotion,
      );
      movePending = false;
      _setMatch(confirmed);
    } on ApiException catch (exception) {
      match = previousMatch;
      legalMoves = previousLegalMoves;
      movePending = false;
      boardMoveAnimation = null;
      error = _friendlyError(exception);
      SoundService.instance.playError();
      notifyListeners();
    } catch (exception) {
      match = previousMatch;
      legalMoves = previousLegalMoves;
      movePending = false;
      boardMoveAnimation = null;
      error = _friendlyError(exception);
      SoundService.instance.playError();
      notifyListeners();
    }
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
      if (round.isCompleted) {
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
          completedAt: currentRound.completedAt,
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
          completedAt: currentRound.completedAt,
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
      await _api.completeBrainRound(matchId: current.matchId);
      _setMatch(await _api.getMatch(current.matchId));
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

  Future<void> requestRematch() {
    final current = match;
    if (current == null || !current.isCompleted) {
      return Future.value();
    }
    return _run(() async {
      _setMatch(await _api.requestRematch(
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
    if (isReviewingMove || !isRevivePawnTargeting || _pieceAt(square) != null) {
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
    final currentMatch = match;
    if (movePending &&
        currentMatch != null &&
        value.matchId == currentMatch.matchId &&
        value.plyCount < currentMatch.plyCount) {
      return;
    }

    final previousMatch = match;
    final previousMatchId = previousMatch?.matchId;
    final previousPlyCount = previousMatch?.plyCount ?? 0;
    final previousIsBrainRound = previousMatch?.isBrainRound ?? false;
    final previousIsCompleted = previousMatch?.isCompleted ?? false;

    final shouldClearReview = isReviewingMove &&
        (previousMatchId != value.matchId ||
            previousMatch?.plyCount != value.plyCount ||
            previousMatch?.fen != value.fen ||
            previousMatch?.phase != value.phase);

    match = value;
    if (shouldClearReview) {
      reviewFen = null;
      reviewMove = null;
    }
    selectedSquare = null;
    powerupTargetMode = PowerupTargetMode.none;
    movePending = false;
    if (!value.isBrainRound) {
      brainRound = null;
    }
    _connectRealtimeIfNeeded(previousMatchId);
    _loadAcceptedRematchIfNeeded(value);

    final plyIncreased = value.plyCount > previousPlyCount;
    final moveForAnimation = _animationForServerMove(previousMatch, value);
    if (moveForAnimation != null) {
      boardMoveAnimation = moveForAnimation;
    }
    final powerupForAnimation = _powerupEffectForMatchChange(
      previousMatch,
      value,
    );
    if (powerupForAnimation != null) {
      _showPowerupEffect(powerupForAnimation);
    }
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

    if (brainRoundJustEnded && value.latestBrainRoundResult != null) {
      _showBrainRoundResultFromMatch(value.latestBrainRoundResult!, value);
    }

    if (value.isBrainRound) {
      notifyListeners();
      unawaited(loadCurrentBrainRound());
    } else {
      notifyListeners();
      unawaited(_loadLegalMoves().then((_) => notifyListeners()));
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
        _setMatch(value);
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

  void _loadAcceptedRematchIfNeeded(MatchModel value) {
    final rematchMatchId = value.rematchMatchId;
    if (!value.isCompleted ||
        rematchMatchId == null ||
        rematchMatchId.isEmpty ||
        _loadingRematchMatchId == rematchMatchId) {
      return;
    }
    _loadingRematchMatchId = rematchMatchId;
    unawaited(_api.getMatch(rematchMatchId).then((rematch) {
      _loadingRematchMatchId = null;
      _setMatch(rematch);
    }).catchError((Object exception) {
      _loadingRematchMatchId = null;
      error = _friendlyError(exception);
      SoundService.instance.playError();
      notifyListeners();
    }));
  }

  BoardMoveAnimation? _animationForServerMove(
    MatchModel? previous,
    MatchModel next,
  ) {
    if (previous == null || next.plyCount <= previous.plyCount) {
      return null;
    }
    if (next.moves.isEmpty) {
      return null;
    }
    final move = next.moves.last;
    final piece = parseFenBoard(previous.fen)[move.from] ??
        parseFenBoard(next.fen)[move.to];
    if (piece == null) {
      return null;
    }
    return BoardMoveAnimation(
      id: ++_boardAnimationSequence,
      from: move.from,
      to: move.to,
      piece: piece,
    );
  }

  PowerupEffect? _powerupEffectForMatchChange(
    MatchModel? previous,
    MatchModel next,
  ) {
    if (previous == null || previous.matchId != next.matchId) {
      return null;
    }
    return _powerupEffectForPlayerChange(
          previousPlayer: previous.white,
          nextPlayer: next.white,
          previousMatch: previous,
          nextMatch: next,
        ) ??
        (previous.black == null || next.black == null
            ? null
            : _powerupEffectForPlayerChange(
                previousPlayer: previous.black!,
                nextPlayer: next.black!,
                previousMatch: previous,
                nextMatch: next,
              ));
  }

  PowerupEffect? _powerupEffectForPlayerChange({
    required PlayerModel previousPlayer,
    required PlayerModel nextPlayer,
    required MatchModel previousMatch,
    required MatchModel nextMatch,
  }) {
    final brainPointSpend = previousPlayer.brainPoints - nextPlayer.brainPoints;
    if (brainPointSpend <= 0) {
      return null;
    }

    final type = switch (brainPointSpend) {
      1 when nextPlayer.clockMs > previousPlayer.clockMs =>
        PowerupEffectType.clockBoost,
      4 when !previousPlayer.extraMoveArmed && nextPlayer.extraMoveArmed =>
        PowerupEffectType.extraMove,
      3
          when nextMatch.fen != previousMatch.fen &&
              nextMatch.moves.length == previousMatch.moves.length =>
        PowerupEffectType.revivePawn,
      _ => null,
    };
    if (type == null) {
      return null;
    }

    return PowerupEffect(
      id: _powerupEffectSequence + 1,
      type: type,
      playerName: nextPlayer.playerName,
      side: nextPlayer.side,
    );
  }

  void _showPowerupEffect(PowerupEffect effect) {
    powerupEffect = PowerupEffect(
      id: ++_powerupEffectSequence,
      type: effect.type,
      playerName: effect.playerName,
      side: effect.side,
    );
    SoundService.instance.playPowerup();
  }

  void _showBrainRoundResultFromMatch(
    BrainRoundResultModel result,
    MatchModel currentMatch,
  ) {
    if (_lastBrainRoundResultRoundId == result.roundId) {
      return;
    }

    final winner = result.winnerPlayerId == null
        ? null
        : currentMatch.playerById(result.winnerPlayerId!);
    brainRoundResultNotice = BrainRoundResultNotice(
      id: ++_brainRoundResultSequence,
      roundId: result.roundId,
      roundNumber: result.roundNumber,
      whiteName: currentMatch.white.playerName,
      blackName: currentMatch.black?.playerName ?? 'Black',
      whiteScore: result.whiteCorrectCount,
      blackScore: result.blackCorrectCount,
      winnerPlayerId: result.winnerPlayerId,
      winnerName: result.isTie ? 'Draw' : winner?.playerName ?? 'Winner',
      awardedPoints: result.awardedBrainPoints,
    );
    _lastBrainRoundResultRoundId = result.roundId;
  }

  String _oppositeSide(String side) => side == 'WHITE' ? 'BLACK' : 'WHITE';

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
