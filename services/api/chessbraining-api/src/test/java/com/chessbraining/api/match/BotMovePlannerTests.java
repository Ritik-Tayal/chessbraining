package com.chessbraining.api.match;

import java.time.Instant;
import java.util.List;
import com.chessbraining.api.chess.*;
import com.chessbraining.api.common.ApiException;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

class BotMovePlannerTests {
    final StockfishEngine engine = mock(StockfishEngine.class);
    final ChessService chess = new ChessService();
    final BotMovePlanner planner = new BotMovePlanner(engine, chess);

    PlayerResponse bot(int points, int pawns, boolean armed) {
        return new PlayerResponse("bot", "Bot", "WHITE", points, 300000, armed, false, pawns, true, BotDifficulty.EXPERT);
    }

    MatchResponse match(String fen, PlayerResponse bot, int ply) {
        var opponent = new PlayerResponse("human", "Human", "BLACK", 0, 300000, false, false, 0, false, null);
        return new MatchResponse("match", "ABC123", MatchStatus.ACTIVE, MatchPhase.CHESS_PHASE, fen, "WHITE",
                ply, 5, 0, null, bot, opponent, null, null, null, null, List.of(), null, Instant.now(), Instant.now());
    }

    void scorePositions(int whiteScore, int blackScore) {
        when(engine.analyze(anyString(), any(), anyInt(), anyList(), anyInt())).thenAnswer(invocation -> {
            String fen = invocation.getArgument(0);
            List<LegalMoveResponse> moves = invocation.getArgument(3);
            if (moves.isEmpty()) return List.of();
            int ms = invocation.getArgument(2);
            int score = ms == 1000 ? 0 : fen.split(" ")[1].equals("w") ? whiteScore : blackScore;
            return List.of(new StockfishEngine.Analysis(StockfishEngine.uci(moves.getFirst()), score));
        });
    }

    @Test void extraMoveIsChosenOnlyWhenTwoMoveGainPaysForPoints() {
        scorePositions(1000, 0);
        var bot = bot(4, 0, false);
        var plan = planner.choose(match(ChessService.STARTING_FEN, bot, 0), bot);
        assertEquals(PowerupType.EXTRA_MOVE, plan.powerup());
        var result = chess.applyMove(ChessService.STARTING_FEN,
                new ChessMove(plan.move().from(), plan.move().to(), plan.move().promotion()), "WHITE");
        assertFalse(result.check());
        assertFalse(result.draw());
    }

    @Test void noExtraMoveAtBrainBoundaryAndNoSpendingWithoutBenefit() {
        scorePositions(1000, 0);
        var bot = bot(4, 0, false);
        assertNull(planner.choose(match(ChessService.STARTING_FEN, bot, 9), bot).powerup());
        scorePositions(0, 0);
        assertNull(planner.choose(match(ChessService.STARTING_FEN, bot, 0), bot).powerup());
        var poor = bot(0, 0, false);
        assertNull(planner.choose(match(ChessService.STARTING_FEN, poor, 0), poor).powerup());
    }

    @Test void revivalEvaluationGivesOpponentNextTurnAndOnlyUsesLegalSquares() {
        scorePositions(0, -600);
        String fen = "4k3/8/8/8/8/8/8/4K3 w - - 0 1";
        var bot = bot(3, 1, false);
        var plan = planner.choose(match(fen, bot, 0), bot);
        assertEquals(PowerupType.REVIVE_PAWN, plan.powerup());
        assertNotNull(chess.revivePawn(fen, "WHITE", plan.targetSquare()));
        verify(engine, atLeastOnce()).analyze(contains(" b "), eq(BotDifficulty.EXPERT), eq(60), anyList(), eq(1));
    }

    @Test void armedExtraMoveNeverChoosesCheckingOrTerminalOpening() {
        String fen = "7k/8/5KQ1/8/8/8/8/8 w - - 0 1";
        var allowed = planner.allowedMoves(fen, "WHITE", true);
        assertFalse(allowed.isEmpty());
        assertTrue(allowed.size() < chess.legalMoves(fen).size());
        for (var move : allowed) {
            var result = chess.applyMove(fen, new ChessMove(move.from(), move.to(), move.promotion()), "WHITE");
            assertFalse(result.check() || result.checkmate() || result.stalemate() || result.draw());
        }
    }

    @Test void requiredSearchFailureDoesNotBecomeWeakFallback() {
        when(engine.required()).thenReturn(true);
        var bot = bot(0, 0, false);
        assertThrows(ApiException.class, () -> planner.choose(match(ChessService.STARTING_FEN, bot, 0), bot));
    }
}
