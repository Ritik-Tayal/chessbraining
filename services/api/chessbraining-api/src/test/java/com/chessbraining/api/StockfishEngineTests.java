package com.chessbraining.api;

import java.util.List;
import com.chessbraining.api.chess.*;
import com.chessbraining.api.match.*;
import com.chessbraining.api.common.ApiException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import static org.junit.jupiter.api.Assertions.*;

class StockfishEngineTests {
    private final ChessService chess = new ChessService();

    @Test void requiredEngineCannotSilentlyFallBackWhenExecutableIsMissing() {
        try (var engine = new EngineResource("missing-stockfish-executable")) {
            assertThrows(ApiException.class, engine.value::requireAvailable);
        }
    }

    @Test
    @EnabledIfEnvironmentVariable(named = "STOCKFISH_TEST_PATH", matches = ".+")
    void realEngineFindsMateWinsQueenPromotesAndRespectsLegalRootsAcrossDifficulties() {
        try (var engine = new EngineResource(System.getenv("STOCKFISH_TEST_PATH"))) {
            engine.value.requireAvailable();
            String mate = "7k/8/5KQ1/8/8/8/8/8 w - - 0 1";
            var best = engine.value.analyze(mate, BotDifficulty.EXPERT, 500, chess.legalMoves(mate), 1);
            assertFalse(best.isEmpty());
            var move = move(best.getFirst().move());
            assertTrue(chess.applyMove(mate, move, "WHITE").checkmate());
            String queen = "4k3/8/8/8/8/8/4q3/4R1K1 w - - 0 1";
            assertEquals("e1e2", engine.value.analyze(queen, BotDifficulty.EXPERT, 500,
                    chess.legalMoves(queen), 1).getFirst().move());
            String promotion = "7k/P7/6K1/8/8/8/8/8 w - - 0 1";
            assertEquals("a7a8q", engine.value.analyze(promotion, BotDifficulty.EXPERT, 500,
                    chess.legalMoves(promotion), 1).getFirst().move());
            var only = new LegalMoveResponse("e2", "e4", null);
            for (var difficulty : BotDifficulty.values()) {
                var result = engine.value.analyze(ChessService.STARTING_FEN, difficulty, 150, List.of(only), 1);
                assertEquals("e2e4", result.getFirst().move());
            }
            // Reusing a single worker must reset difficulty instead of leaking the prior game's settings.
            assertFalse(engine.value.analyze(mate, BotDifficulty.EXPERT, 300, chess.legalMoves(mate), 1).isEmpty());
            var afterDoublePawn = chess.applyMove(ChessService.STARTING_FEN, new ChessMove("e2", "e4", null), "WHITE");
            String retainedTurn = chess.withSideToMove(afterDoublePawn.fen(), "WHITE");
            assertFalse(engine.value.analyze(retainedTurn, BotDifficulty.EXPERT, 100,
                    chess.legalMoves(retainedTurn), 1).isEmpty());
            Process process = (Process) org.springframework.test.util.ReflectionTestUtils.getField(engine.value, "process");
            process.destroyForcibly().onExit().join();
            assertFalse(engine.value.analyze(mate, BotDifficulty.EXPERT, 200, chess.legalMoves(mate), 1).isEmpty());
        }
    }

    private ChessMove move(String uci) {
        return new ChessMove(uci.substring(0, 2), uci.substring(2, 4), uci.length() == 5 ? uci.substring(4) : null);
    }

    private static class EngineResource implements AutoCloseable {
        final StockfishEngine value;
        EngineResource(String path) { value = new StockfishEngine(path, true, 16); }
        public void close() { value.close(); }
    }
}
