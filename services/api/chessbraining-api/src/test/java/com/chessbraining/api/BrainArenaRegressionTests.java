package com.chessbraining.api;

import java.time.Instant;
import java.util.List;
import com.chessbraining.api.common.ApiException;
import com.chessbraining.api.match.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@ActiveProfiles("test")
class BrainArenaRegressionTests {
    @Autowired BrainMatchService service;
    @Autowired BrainMatchRepository repository;

    private String createMath() {
        var created = service.create(new CreateBrainMatchRequest("arena-white", "White", BrainMatchMode.MENTAL_MATH));
        service.join(new JoinBrainMatchRequest(created.inviteCode(), "arena-black", "Black"));
        var entity = repository.findById(created.matchId()).orElseThrow();
        entity.setPuzzleExpressions("[\"1 + 1\",\"2 + 2\"]");
        entity.setPuzzleAnswers("[2,4]");
        entity.setTotalQuestions(2);
        repository.save(entity);
        return created.matchId();
    }

    private SubmitAnswerBatchRequest answers(String player, int... values) {
        var list = new java.util.ArrayList<SubmitAnswerBatchRequest.SubmittedAnswer>();
        for (int i = 0; i < values.length; i++) list.add(new SubmitAnswerBatchRequest.SubmittedAnswer(i, values[i]));
        return new SubmitAnswerBatchRequest(player, list);
    }

    @Test void cannotEndMatchBeforeDeadline() {
        String id = createMath();
        assertThrows(ApiException.class, () -> service.complete(id));
        assertEquals("ACTIVE", service.get(id).status());
    }

    @Test void progressUpdatesAreValidatedMonotonicAndDoNotFinalize() {
        String id = createMath();
        assertEquals(List.of(2, 4), service.get(id).solutions());
        var first = new SubmitAnswerBatchRequest.SubmittedAnswer(0, 2);
        var progress = service.submitMath(id, new SubmitAnswerBatchRequest("arena-white", List.of(first), false));
        assertEquals(1, progress.whiteScore());
        assertEquals(0, progress.nextWhiteQuestionIndex());
        assertEquals("ACTIVE", progress.status());
        service.submitMath(id, new SubmitAnswerBatchRequest("arena-white", List.of(), false));
        assertEquals(1, service.get(id).whiteScore());
        assertThrows(ApiException.class, () -> service.submitMath(id, new SubmitAnswerBatchRequest("outsider", List.of(first), false)));
        service.submitMath(id, answers("arena-white", 2, 4));
        var done = service.submitMath(id, answers("arena-black", 2, 0));
        assertEquals(2, done.whiteScore());
        assertEquals(1, done.blackScore());
    }

    @Test void waitingBrainMatchCanBeCancelledOnlyByItsHost() {
        var created=service.create(new CreateBrainMatchRequest("host", "Host", BrainMatchMode.MEMORY));
        assertThrows(ApiException.class,()->service.cancelWaitingMatch(created.matchId(),"outsider"));
        service.cancelWaitingMatch(created.matchId(),"host");
        assertFalse(repository.existsById(created.matchId()));
    }

    @Test void memoryGetPersistsExpiredTurnAndClearsFirstPick() throws Exception {
        var created = service.create(new CreateBrainMatchRequest("memory-white", "White", BrainMatchMode.MEMORY));
        var joined = service.join(new JoinBrainMatchRequest(created.inviteCode(), "memory-black", "Black"));
        assertEquals(12, joined.totalQuestions());
        assertEquals(120, java.time.Duration.between(joined.startedAt(), joined.expiresAt()).toSeconds());
        service.submitMemoryTurn(created.matchId(), new SubmitMemoryTurnRequest("memory-white", 0, -1));
        var mapper = new tools.jackson.databind.ObjectMapper();
        var entity = repository.findById(created.matchId()).orElseThrow();
        var state = mapper.readValue(entity.getPuzzleAnswers(), MemoryPuzzleService.MemoryState.class);
        entity.setPuzzleAnswers(mapper.writeValueAsString(new MemoryPuzzleService.MemoryState(state.cards(),
                state.matchedMask(), state.turnSide(), state.lastFlipped(), false, state.pendingFirstIndex(), null,
                System.currentTimeMillis() - 100)));
        repository.save(entity);
        var response = service.get(created.matchId());
        var board = mapper.readTree(response.puzzles().getFirst());
        assertEquals("BLACK", board.get("turnSide").asText());
        assertTrue(board.get("pendingFirstIndex").isNull());
        assertEquals(24, board.get("cards").size());
        assertEquals(0, response.whiteScore());
        assertFalse(response.puzzles().getFirst().contains("WHITE_KING"));
    }

    @Test void duplicateQuestionsCannotInflateScore() {
        String id = createMath();
        var same = new SubmitAnswerBatchRequest.SubmittedAnswer(0, 2);
        assertThrows(ApiException.class, () -> service.submitMath(id,
                new SubmitAnswerBatchRequest("arena-white", List.of(same, same))));
        assertEquals(0, service.get(id).whiteScore());
    }

    @Test void deadlineSubmissionsPreserveBothScoresAndRematchSwapsPlayers() {
        String id = createMath();
        var entity = repository.findById(id).orElseThrow();
        entity.setExpiresAt(Instant.now().minusMillis(100));
        repository.save(entity);
        var first = service.submitMath(id, answers("arena-white", 2, 4));
        assertEquals("ACTIVE", first.status());
        var finished = service.submitMath(id, answers("arena-black", 2, 0));
        assertEquals("COMPLETED", finished.status());
        assertEquals(2, finished.whiteScore());
        assertEquals(1, finished.blackScore());
        assertEquals("arena-white", finished.winnerPlayerId());
        assertEquals("COMPLETED", service.complete(id).status());
        service.rematch(id, new RematchRequest("arena-white"));
        var rematch = service.rematch(id, new RematchRequest("arena-black"));
        assertEquals("arena-black", rematch.white().playerId());
        assertEquals("MENTAL_MATH", rematch.puzzleType());
    }
}
