class MatchModel {
  const MatchModel({
    required this.matchId,
    required this.inviteCode,
    required this.status,
    required this.phase,
    required this.fen,
    required this.sideToMove,
    required this.plyCount,
    required this.brainRoundIntervalMoves,
    required this.brainRoundCount,
    required this.white,
    required this.black,
    required this.winnerPlayerId,
    required this.resultReason,
    required this.moves,
    required this.clockDeadlineAt,
  });

  final String matchId;
  final String inviteCode;
  final String status;
  final String phase;
  final String fen;
  final String sideToMove;
  final int plyCount;
  final int brainRoundIntervalMoves;
  final int brainRoundCount;
  final PlayerModel white;
  final PlayerModel? black;
  final String? winnerPlayerId;
  final String? resultReason;
  final List<MoveModel> moves;
  final DateTime? clockDeadlineAt;

  bool get isWaiting => phase == 'WAITING_FOR_OPPONENT';
  bool get isChessPhase => phase == 'CHESS_PHASE';
  bool get isBrainRound => phase == 'BRAIN_ROUND';
  bool get isCompleted => phase == 'COMPLETED';

  PlayerModel? playerById(String playerId) {
    if (white.playerId == playerId) {
      return white;
    }
    if (black?.playerId == playerId) {
      return black;
    }
    return null;
  }

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    return MatchModel(
      matchId: json['matchId'] as String,
      inviteCode: json['inviteCode'] as String,
      status: json['status'] as String,
      phase: json['phase'] as String,
      fen: json['fen'] as String,
      sideToMove: json['sideToMove'] as String,
      plyCount: json['plyCount'] as int,
      brainRoundIntervalMoves: json['brainRoundIntervalMoves'] as int,
      brainRoundCount: json['brainRoundCount'] as int,
      white: PlayerModel.fromJson(json['white'] as Map<String, dynamic>),
      black: json['black'] == null
          ? null
          : PlayerModel.fromJson(json['black'] as Map<String, dynamic>),
      winnerPlayerId: json['winnerPlayerId'] as String?,
      resultReason: json['resultReason'] as String?,
      moves: (json['moves'] as List<dynamic>)
          .map((item) => MoveModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      clockDeadlineAt: json['clockDeadlineAt'] == null
          ? null
          : DateTime.parse(json['clockDeadlineAt'] as String),
    );
  }
}

class PlayerModel {
  const PlayerModel({
    required this.playerId,
    required this.playerName,
    required this.side,
    required this.brainPoints,
    required this.clockMs,
    required this.extraMoveArmed,
    required this.extraMoveActive,
    required this.revivablePawns,
  });

  final String playerId;
  final String playerName;
  final String side;
  final int brainPoints;
  final int clockMs;
  final bool extraMoveArmed;
  final bool extraMoveActive;
  final int revivablePawns;

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      playerId: json['playerId'] as String,
      playerName: json['playerName'] as String,
      side: json['side'] as String,
      brainPoints: json['brainPoints'] as int,
      clockMs: json['clockMs'] as int,
      extraMoveArmed: json['extraMoveArmed'] as bool? ?? false,
      extraMoveActive: json['extraMoveActive'] as bool? ?? false,
      revivablePawns: json['revivablePawns'] as int? ?? 0,
    );
  }
}

class MoveModel {
  const MoveModel({
    required this.plyNumber,
    required this.playerId,
    required this.side,
    required this.from,
    required this.to,
    required this.promotion,
    required this.fenAfter,
  });

  final int plyNumber;
  final String playerId;
  final String side;
  final String from;
  final String to;
  final String? promotion;
  final String fenAfter;

  factory MoveModel.fromJson(Map<String, dynamic> json) {
    return MoveModel(
      plyNumber: json['plyNumber'] as int,
      playerId: json['playerId'] as String,
      side: json['side'] as String,
      from: json['from'] as String,
      to: json['to'] as String,
      promotion: json['promotion'] as String?,
      fenAfter: json['fenAfter'] as String,
    );
  }
}

class LegalMoveModel {
  const LegalMoveModel({
    required this.from,
    required this.to,
    required this.promotion,
  });

  final String from;
  final String to;
  final String? promotion;

  factory LegalMoveModel.fromJson(Map<String, dynamic> json) {
    return LegalMoveModel(
      from: json['from'] as String,
      to: json['to'] as String,
      promotion: json['promotion'] as String?,
    );
  }
}

class BrainRoundModel {
  const BrainRoundModel({
    required this.roundId,
    required this.roundNumber,
    required this.status,
    required this.puzzleType,
    required this.puzzles,
    required this.totalQuestions,
    required this.whiteCorrectCount,
    required this.blackCorrectCount,
    required this.nextWhiteQuestionIndex,
    required this.nextBlackQuestionIndex,
    required this.winnerPlayerId,
    required this.startedAt,
    required this.expiresAt,
  });

  final String roundId;
  final int roundNumber;
  final String status;
  final String puzzleType;
  final List<String> puzzles;
  final int totalQuestions;
  final int whiteCorrectCount;
  final int blackCorrectCount;
  final int nextWhiteQuestionIndex;
  final int nextBlackQuestionIndex;
  final String? winnerPlayerId;
  final DateTime startedAt;
  final DateTime expiresAt;

  bool get isMathPuzzle => puzzleType == 'MENTAL_MATH';
  bool get isDotConnect => puzzleType == 'DOT_CONNECT';

  factory BrainRoundModel.fromJson(Map<String, dynamic> json) {
    return BrainRoundModel(
      roundId: json['roundId'] as String,
      roundNumber: json['roundNumber'] as int,
      status: json['status'] as String,
      puzzleType: json['puzzleType'] as String? ?? 'MENTAL_MATH',
      puzzles: (json['puzzles'] as List<dynamic>)
          .map((item) => item.toString())
          .toList(),
      totalQuestions: json['totalQuestions'] as int,
      whiteCorrectCount: json['whiteCorrectCount'] as int,
      blackCorrectCount: json['blackCorrectCount'] as int,
      nextWhiteQuestionIndex: json['nextWhiteQuestionIndex'] as int,
      nextBlackQuestionIndex: json['nextBlackQuestionIndex'] as int,
      winnerPlayerId: json['winnerPlayerId'] as String?,
      startedAt: DateTime.parse(json['startedAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
}

class DotConnectPuzzle {
  const DotConnectPuzzle({
    required this.rows,
    required this.cols,
    required this.dots,
  });

  final int rows;
  final int cols;
  final List<List<int>> dots;

  factory DotConnectPuzzle.fromJson(Map<String, dynamic> json) {
    return DotConnectPuzzle(
      rows: json['rows'] as int,
      cols: json['cols'] as int,
      dots: (json['dots'] as List<dynamic>)
          .map((dot) => (dot as List<dynamic>)
              .map((e) => e as int)
              .toList())
          .toList(),
    );
  }
}

class AnswerResultModel {
  const AnswerResultModel({
    required this.correct,
    required this.playerCorrectCount,
    required this.totalQuestions,
  });

  final bool correct;
  final int playerCorrectCount;
  final int totalQuestions;

  factory AnswerResultModel.fromJson(Map<String, dynamic> json) {
    return AnswerResultModel(
      correct: json['correct'] as bool,
      playerCorrectCount: json['playerCorrectCount'] as int,
      totalQuestions: json['totalQuestions'] as int,
    );
  }
}

class BrainRoundSubmissionModel {
  const BrainRoundSubmissionModel({
    required this.playerCorrectCount,
    required this.playerAnsweredCount,
    required this.totalQuestions,
    required this.roundCompleted,
  });

  final int playerCorrectCount;
  final int playerAnsweredCount;
  final int totalQuestions;
  final bool roundCompleted;

  factory BrainRoundSubmissionModel.fromJson(Map<String, dynamic> json) {
    return BrainRoundSubmissionModel(
      playerCorrectCount: json['playerCorrectCount'] as int,
      playerAnsweredCount: json['playerAnsweredCount'] as int,
      totalQuestions: json['totalQuestions'] as int,
      roundCompleted: json['roundCompleted'] as bool,
    );
  }
}
