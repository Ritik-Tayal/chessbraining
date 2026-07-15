import 'dart:convert';

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
    required this.latestBrainRoundResult,
    required this.white,
    required this.black,
    required this.winnerPlayerId,
    required this.resultReason,
    required this.rematchRequestedByPlayerId,
    required this.rematchMatchId,
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
  final BrainRoundResultModel? latestBrainRoundResult;
  final PlayerModel white;
  final PlayerModel? black;
  final String? winnerPlayerId;
  final String? resultReason;
  final String? rematchRequestedByPlayerId;
  final String? rematchMatchId;
  final List<MoveModel> moves;
  final DateTime? clockDeadlineAt;

  bool get isWaiting => phase == 'WAITING_FOR_OPPONENT';
  bool get isChessPhase => phase == 'CHESS_PHASE';
  bool get isBrainRound => phase == 'BRAIN_ROUND';
  bool get isCompleted => phase == 'COMPLETED';
  bool get isDraw => isCompleted && winnerPlayerId == null;

  PlayerModel? playerById(String playerId) {
    if (white.playerId == playerId) {
      return white;
    }
    if (black?.playerId == playerId) {
      return black;
    }
    return null;
  }

  MatchModel copyWith({
    String? fen,
    String? sideToMove,
    int? plyCount,
    List<MoveModel>? moves,
    DateTime? clockDeadlineAt,
  }) {
    return MatchModel(
      matchId: matchId,
      inviteCode: inviteCode,
      status: status,
      phase: phase,
      fen: fen ?? this.fen,
      sideToMove: sideToMove ?? this.sideToMove,
      plyCount: plyCount ?? this.plyCount,
      brainRoundIntervalMoves: brainRoundIntervalMoves,
      brainRoundCount: brainRoundCount,
      latestBrainRoundResult: latestBrainRoundResult,
      white: white,
      black: black,
      winnerPlayerId: winnerPlayerId,
      resultReason: resultReason,
      rematchRequestedByPlayerId: rematchRequestedByPlayerId,
      rematchMatchId: rematchMatchId,
      moves: moves ?? this.moves,
      clockDeadlineAt: clockDeadlineAt ?? this.clockDeadlineAt,
    );
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
      latestBrainRoundResult: json['latestBrainRoundResult'] == null
          ? null
          : BrainRoundResultModel.fromJson(
              json['latestBrainRoundResult'] as Map<String, dynamic>,
            ),
      white: PlayerModel.fromJson(json['white'] as Map<String, dynamic>),
      black: json['black'] == null
          ? null
          : PlayerModel.fromJson(json['black'] as Map<String, dynamic>),
      winnerPlayerId: json['winnerPlayerId'] as String?,
      resultReason: json['resultReason'] as String?,
      rematchRequestedByPlayerId: json['rematchRequestedByPlayerId'] as String?,
      rematchMatchId: json['rematchMatchId'] as String?,
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
    required this.bot,
    required this.botDifficulty,
  });

  final String playerId;
  final String playerName;
  final String side;
  final int brainPoints;
  final int clockMs;
  final bool extraMoveArmed;
  final bool extraMoveActive;
  final int revivablePawns;
  final bool bot;
  final String? botDifficulty;

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
      bot: json['bot'] as bool? ?? false,
      botDifficulty: json['botDifficulty'] as String?,
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
    required this.fenBefore,
    required this.fenAfter,
  });

  final int plyNumber;
  final String playerId;
  final String side;
  final String from;
  final String to;
  final String? promotion;
  final String fenBefore;
  final String fenAfter;

  factory MoveModel.fromJson(Map<String, dynamic> json) {
    final fenAfter = json['fenAfter'] as String;
    return MoveModel(
      plyNumber: json['plyNumber'] as int,
      playerId: json['playerId'] as String,
      side: json['side'] as String,
      from: json['from'] as String,
      to: json['to'] as String,
      promotion: json['promotion'] as String?,
      fenBefore: json['fenBefore'] as String? ?? '',
      fenAfter: fenAfter,
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

class GuestProfileModel {
  const GuestProfileModel({
    required this.playerId,
    required this.playerName,
    required this.rating,
    required this.gamesPlayed,
    required this.activeMatches,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.recentMatches,
  });

  final String playerId;
  final String playerName;
  final int rating;
  final int gamesPlayed;
  final int activeMatches;
  final int wins;
  final int losses;
  final int draws;
  final List<MatchHistoryModel> recentMatches;

  factory GuestProfileModel.fromJson(Map<String, dynamic> json) {
    return GuestProfileModel(
      playerId: json['playerId'] as String,
      playerName: json['playerName'] as String,
      rating: json['rating'] as int? ?? 1000,
      gamesPlayed: json['gamesPlayed'] as int? ?? 0,
      activeMatches: json['activeMatches'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      draws: json['draws'] as int? ?? 0,
      recentMatches: (json['recentMatches'] as List<dynamic>? ?? const [])
          .map((item) => MatchHistoryModel.fromJson(
                item as Map<String, dynamic>,
              ))
          .toList(),
    );
  }
}

class MatchHistoryModel {
  const MatchHistoryModel({
    required this.matchId,
    required this.inviteCode,
    required this.opponentName,
    required this.opponentBot,
    required this.opponentDifficulty,
    required this.result,
    required this.resultReason,
    required this.ratingChange,
    required this.ratingAfter,
    required this.plyCount,
    required this.brainRoundCount,
    required this.playedAt,
  });

  final String matchId;
  final String inviteCode;
  final String opponentName;
  final bool opponentBot;
  final String? opponentDifficulty;
  final String result;
  final String? resultReason;
  final int ratingChange;
  final int ratingAfter;
  final int plyCount;
  final int brainRoundCount;
  final DateTime? playedAt;

  factory MatchHistoryModel.fromJson(Map<String, dynamic> json) {
    return MatchHistoryModel(
      matchId: json['matchId'] as String,
      inviteCode: json['inviteCode'] as String,
      opponentName: json['opponentName'] as String? ?? 'Waiting player',
      opponentBot: json['opponentBot'] as bool? ?? false,
      opponentDifficulty: json['opponentDifficulty'] as String?,
      result: json['result'] as String? ?? 'ACTIVE',
      resultReason: json['resultReason'] as String?,
      ratingChange: json['ratingChange'] as int? ?? 0,
      ratingAfter: json['ratingAfter'] as int? ?? 1000,
      plyCount: json['plyCount'] as int? ?? 0,
      brainRoundCount: json['brainRoundCount'] as int? ?? 0,
      playedAt: json['playedAt'] == null
          ? null
          : DateTime.parse(json['playedAt'] as String),
    );
  }
}

class BrainRoundResultModel {
  const BrainRoundResultModel({
    required this.roundId,
    required this.roundNumber,
    required this.whiteCorrectCount,
    required this.blackCorrectCount,
    required this.winnerPlayerId,
    required this.awardedBrainPoints,
    required this.completedAt,
  });

  final String roundId;
  final int roundNumber;
  final int whiteCorrectCount;
  final int blackCorrectCount;
  final String? winnerPlayerId;
  final int awardedBrainPoints;
  final DateTime completedAt;

  bool get isTie => winnerPlayerId == null;

  factory BrainRoundResultModel.fromJson(Map<String, dynamic> json) {
    return BrainRoundResultModel(
      roundId: json['roundId'] as String,
      roundNumber: json['roundNumber'] as int,
      whiteCorrectCount: json['whiteCorrectCount'] as int,
      blackCorrectCount: json['blackCorrectCount'] as int,
      winnerPlayerId: json['winnerPlayerId'] as String?,
      awardedBrainPoints: json['awardedBrainPoints'] as int,
      completedAt: DateTime.parse(json['completedAt'] as String),
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
    required this.completedAt,
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
  final DateTime? completedAt;

  bool get isCompleted => status == 'COMPLETED';

  bool get isMathPuzzle => puzzleType == 'MENTAL_MATH';
  bool get isDotConnect => puzzleType == 'DOT_CONNECT';
  bool get isMemory => puzzleType == 'MEMORY';

  MemoryBoardModel? get memoryBoard {
    if (!isMemory || puzzles.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(puzzles.first);
      if (decoded is Map<String, dynamic>) {
        return MemoryBoardModel.fromJson(decoded);
      }
    } on FormatException {
      return null;
    }
    return null;
  }

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
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
    );
  }
}

class MemoryBoardModel {
  const MemoryBoardModel({
    required this.turnSide,
    required this.lastMatched,
    required this.lastFlipped,
    required this.cards,
  });

  final String turnSide;
  final bool lastMatched;
  final List<int> lastFlipped;
  final List<MemoryCardModel> cards;

  factory MemoryBoardModel.fromJson(Map<String, dynamic> json) {
    return MemoryBoardModel(
      turnSide: json['turnSide'] as String? ?? 'WHITE',
      lastMatched: json['lastMatched'] as bool? ?? false,
      lastFlipped: (json['lastFlipped'] as List<dynamic>? ?? const [])
          .map((item) => (item as num).toInt())
          .toList(),
      cards: (json['cards'] as List<dynamic>? ?? const [])
          .map((item) => MemoryCardModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MemoryCardModel {
  const MemoryCardModel({
    required this.index,
    required this.matched,
    required this.revealed,
    required this.piece,
  });

  final int index;
  final bool matched;
  final bool revealed;
  final String? piece;

  factory MemoryCardModel.fromJson(Map<String, dynamic> json) {
    return MemoryCardModel(
      index: (json['index'] as num).toInt(),
      matched: json['matched'] as bool? ?? false,
      revealed: json['revealed'] as bool? ?? false,
      piece: json['piece'] as String?,
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
      dots: (json['dots'] as List<dynamic>).map(_dotFromJson).toList(),
    );
  }

  static List<int> _dotFromJson(Object? value) {
    if (value is List<dynamic> && value.length >= 2) {
      return [
        (value[0] as num).toInt(),
        (value[1] as num).toInt(),
      ];
    }
    if (value is Map<String, dynamic>) {
      return [
        (value['row'] as num).toInt(),
        (value['col'] as num).toInt(),
      ];
    }
    throw const FormatException('Invalid dot-connect coordinate.');
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
