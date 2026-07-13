import 'package:chessbraining_app/src/api/chessbraining_api.dart';
import 'package:chessbraining_app/src/api/match_socket_client.dart';
import 'package:chessbraining_app/src/features/match/fen.dart';
import 'package:chessbraining_app/src/features/match/match_controller.dart';
import 'package:chessbraining_app/src/models/match_models.dart';
import 'package:chessbraining_app/src/session/guest_session.dart';
import 'package:chessbraining_app/src/services/sound_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SoundService.instance.setEnabled(false);
  });

  test('keeps brain round when an older same-ply chess snapshot arrives',
      () async {
    late void Function(MatchModel match) pushRealtimeMatch;
    final api = _FakeApi(
      initialMatch: _match(phase: 'CHESS_PHASE', plyCount: 9),
      currentRound: _brainRound(),
    );
    final controller = MatchController(
      api: api,
      guestSession: const GuestSession(
        playerId: 'white-player',
        playerName: 'White',
      ),
      socketFactory: ({
        required apiBaseUrl,
        required matchId,
        required onMatch,
        required onConnectionChanged,
      }) {
        pushRealtimeMatch = onMatch;
        return _FakeSocket(
          apiBaseUrl: apiBaseUrl,
          matchId: matchId,
          onMatch: onMatch,
          onConnectionChanged: onConnectionChanged,
        );
      },
    );

    await controller.createMatch();
    expect(controller.match?.phase, 'CHESS_PHASE');

    pushRealtimeMatch(_match(
      phase: 'BRAIN_ROUND',
      plyCount: 10,
      brainRoundCount: 1,
    ));
    await Future<void>.delayed(Duration.zero);

    expect(controller.match?.phase, 'BRAIN_ROUND');
    expect(controller.brainRound?.roundId, 'round-1');

    pushRealtimeMatch(_match(
      phase: 'CHESS_PHASE',
      plyCount: 10,
      brainRoundCount: 0,
    ));

    expect(controller.match?.phase, 'BRAIN_ROUND');
    expect(controller.match?.brainRoundCount, 1);
  });

  test(
      'accepts brain round completion but ignores stale active round snapshots',
      () async {
    late void Function(MatchModel match) pushRealtimeMatch;
    final api = _FakeApi(
      initialMatch:
          _match(phase: 'BRAIN_ROUND', plyCount: 10, brainRoundCount: 1),
      currentRound: _brainRound(),
    );
    final controller = MatchController(
      api: api,
      guestSession: const GuestSession(
        playerId: 'white-player',
        playerName: 'White',
      ),
      socketFactory: ({
        required apiBaseUrl,
        required matchId,
        required onMatch,
        required onConnectionChanged,
      }) {
        pushRealtimeMatch = onMatch;
        return _FakeSocket(
          apiBaseUrl: apiBaseUrl,
          matchId: matchId,
          onMatch: onMatch,
          onConnectionChanged: onConnectionChanged,
        );
      },
    );

    await controller.createMatch();
    expect(controller.match?.phase, 'BRAIN_ROUND');

    pushRealtimeMatch(_match(
      phase: 'CHESS_PHASE',
      plyCount: 10,
      brainRoundCount: 1,
      latestBrainRoundResult: _brainRoundResult(),
    ));

    expect(controller.match?.phase, 'CHESS_PHASE');
    expect(controller.match?.latestBrainRoundResult?.roundId, 'round-1');

    pushRealtimeMatch(_match(
      phase: 'BRAIN_ROUND',
      plyCount: 10,
      brainRoundCount: 1,
    ));

    expect(controller.match?.phase, 'CHESS_PHASE');
    expect(controller.match?.latestBrainRoundResult?.roundId, 'round-1');
  });
}

class _FakeApi extends ChessbrainingApi {
  _FakeApi({required this.initialMatch, required this.currentRound});

  final MatchModel initialMatch;
  final BrainRoundModel currentRound;

  @override
  Future<MatchModel> createMatch({
    required String playerId,
    required String playerName,
    int timeControlSeconds = 300,
    int brainRoundIntervalMoves = 5,
  }) async {
    return initialMatch;
  }

  @override
  Future<List<LegalMoveModel>> legalMoves({
    required String matchId,
    required String playerId,
  }) async {
    return const [];
  }

  @override
  Future<BrainRoundModel> getCurrentBrainRound(String matchId) async {
    return currentRound;
  }
}

class _FakeSocket extends MatchSocketClient {
  _FakeSocket({
    required super.apiBaseUrl,
    required super.matchId,
    required super.onMatch,
    required super.onConnectionChanged,
  });

  @override
  void connect() {}

  @override
  void disconnect() {}
}

MatchModel _match({
  required String phase,
  required int plyCount,
  int brainRoundCount = 0,
  BrainRoundResultModel? latestBrainRoundResult,
}) {
  return MatchModel(
    matchId: 'match-1',
    inviteCode: 'ABC123',
    status: phase == 'COMPLETED' ? 'COMPLETED' : 'ACTIVE',
    phase: phase,
    fen: startingFen,
    sideToMove: 'WHITE',
    plyCount: plyCount,
    brainRoundIntervalMoves: 5,
    brainRoundCount: brainRoundCount,
    latestBrainRoundResult: latestBrainRoundResult,
    white: _player('white-player', 'White', 'WHITE'),
    black: _player('black-player', 'Black', 'BLACK'),
    winnerPlayerId: null,
    resultReason: null,
    rematchRequestedByPlayerId: null,
    rematchMatchId: null,
    moves: const [],
    clockDeadlineAt: null,
  );
}

PlayerModel _player(String id, String name, String side) {
  return PlayerModel(
    playerId: id,
    playerName: name,
    side: side,
    brainPoints: 0,
    clockMs: 300000,
    extraMoveArmed: false,
    extraMoveActive: false,
    revivablePawns: 0,
    bot: false,
    botDifficulty: null,
  );
}

BrainRoundModel _brainRound() {
  final now = DateTime.utc(2026, 7, 10, 12);
  return BrainRoundModel(
    roundId: 'round-1',
    roundNumber: 1,
    status: 'ACTIVE',
    puzzleType: 'MENTAL_MATH',
    puzzles: const ['1 + 1'],
    totalQuestions: 1,
    whiteCorrectCount: 0,
    blackCorrectCount: 0,
    nextWhiteQuestionIndex: 0,
    nextBlackQuestionIndex: 0,
    winnerPlayerId: null,
    startedAt: now,
    expiresAt: now.add(const Duration(seconds: 30)),
    completedAt: null,
  );
}

BrainRoundResultModel _brainRoundResult() {
  return BrainRoundResultModel(
    roundId: 'round-1',
    roundNumber: 1,
    whiteCorrectCount: 1,
    blackCorrectCount: 0,
    winnerPlayerId: 'white-player',
    awardedBrainPoints: 2,
    completedAt: DateTime.utc(2026, 7, 10, 12, 1),
  );
}
