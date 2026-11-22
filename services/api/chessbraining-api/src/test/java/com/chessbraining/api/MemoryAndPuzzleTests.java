package com.chessbraining.api;

import java.util.List;
import com.chessbraining.api.common.ApiException;
import com.chessbraining.api.match.MemoryPuzzleService;
import com.chessbraining.api.match.DotConnectPuzzleService;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class MemoryAndPuzzleTests {
    final MemoryPuzzleService memory = new MemoryPuzzleService();
    @Test void expandedBoardHasTwelveDistinctColoredPairs() {
        var state = memory.newGame();
        assertEquals(24, state.cards().size());
        assertEquals(12, memory.pairCount());
        var frequencies = state.cards().stream().collect(java.util.stream.Collectors.groupingBy(v -> v, java.util.stream.Collectors.counting()));
        assertEquals(12, frequencies.size());
        assertTrue(frequencies.values().stream().allMatch(n -> n == 2));
        assertTrue(frequencies.containsKey("WHITE_KING"));
        assertTrue(frequencies.containsKey("BLACK_KING"));
        assertFalse(memory.publicBoardJson(state).contains("WHITE_KING"));
    }
    @Test void timeoutPassesTurnWithoutScoringOrLeakingPendingCard() {
        long before = System.currentTimeMillis();
        var state = memory.newGame();
        assertTrue(state.turnExpiresAt() >= before + 8000);
        assertTrue(state.turnExpiresAt() <= System.currentTimeMillis() + 8000);
        var first = memory.playTurn(state, "WHITE", 0, -1).state();
        assertEquals(state.turnExpiresAt(), first.turnExpiresAt());
        var timed = memory.advanceExpiredTurns(first, first.turnExpiresAt());
        assertEquals("BLACK", timed.turnSide());
        assertNull(timed.pendingFirstIndex());
        assertTrue(timed.lastFlipped().isEmpty());
        assertEquals(0, timed.matchedMask());
        assertEquals(first, memory.advanceExpiredTurns(first, first.turnExpiresAt() - 1));
        assertEquals(first.turnExpiresAt() + 8000, timed.turnExpiresAt());
        assertEquals("WHITE", memory.advanceExpiredTurns(first, first.turnExpiresAt() + 8000).turnSide());
    }
    @Test void oppositeColorsOfSamePieceDoNotMatch() {
        var state = memory.newGame();
        var result = memory.playTurn(state, "WHITE", state.cards().indexOf("WHITE_KING"), state.cards().indexOf("BLACK_KING"));
        assertFalse(result.matched());
        assertEquals("BLACK", result.state().turnSide());
    }
    private MemoryPuzzleService.MemoryState board() {
        return new MemoryPuzzleService.MemoryState(List.of("PAWN","PAWN","KING","KING","QUEEN","QUEEN","ROOK","ROOK","BISHOP","BISHOP","KNIGHT","KNIGHT"),0,"WHITE",List.of(),false,null,null);
    }
    @Test void firstPickRevealsOneCardAndSecondPickScoresPair() {
        var first = memory.playTurn(board(),"WHITE",0,-1);
        assertEquals(0, first.state().pendingFirstIndex());
        assertFalse(first.matched());
        assertThrows(ApiException.class,()->memory.playTurn(first.state(),"BLACK",0,1));
        var second = memory.playTurn(first.state(),"WHITE",0,1);
        assertTrue(second.matched());
        assertEquals("WHITE",second.state().turnSide());
        assertNull(second.state().pendingFirstIndex());
        assertNotNull(second.state().lastFlipAt());
        assertThrows(ApiException.class,()->memory.playTurn(second.state(),"WHITE",0,-1));
    }
    @Test void mismatchPassesTurnAndExposesOnlyPreviouslyChosenPieces() {
        var first=memory.playTurn(board(),"WHITE",0,-1);
        var second=memory.playTurn(first.state(),"WHITE",0,2);
        assertFalse(second.matched());
        assertEquals("BLACK",second.state().turnSide());
        String json=memory.publicBoardJson(second.state());
        assertTrue(json.contains("lastFlipAt"));
        assertTrue(json.contains("PAWN"));
        assertTrue(json.contains("KING"));
        assertFalse(json.contains("QUEEN"));
    }
    @Test void publicDotPuzzleDoesNotLeakSolutionButServerCanStillValidateIt() throws Exception {
        var dots=new DotConnectPuzzleService();
        String internal=dots.generatePuzzleSet(1).puzzles().getFirst();
        String external=dots.publicPuzzle(internal);
        assertFalse(external.contains("solutionPath"));
        var data=new tools.jackson.databind.ObjectMapper().readValue(internal,DotConnectPuzzleService.PuzzleData.class);
        var path=data.solutionPath().stream().map(d->List.of(d.row(),d.col())).toList();
        assertTrue(dots.validatePath(internal,path));
        assertTrue(dots.validatePath(external,path));
    }
}
