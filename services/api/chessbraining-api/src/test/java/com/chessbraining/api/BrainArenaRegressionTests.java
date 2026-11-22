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
    @Autowired MatchService matches;
    @Autowired MatchRepository chessMatches;
    @Autowired BrainRoundRepository roundRepository;
    @Autowired BrainRoundService rounds;

    @Test void pieceSwitchBotPlaysGraduallyAndCompletionResumesChessWithoutDuplicateRewards() {
        var mapper = new tools.jackson.databind.ObjectMapper();
        var created = matches.createMatch(new CreateMatchRequest("switch-human", "Human", 600, 1));
        var joined = matches.joinMatch(new JoinMatchRequest(created.inviteCode(), "switch-bot", "Bot"));
        var id = joined.matchId();
        matches.submitMove(id,new SubmitMoveRequest("switch-human","e2","e4",null));
        matches.submitMove(id,new SubmitMoveRequest("switch-bot","e7","e5",null));
        var round = roundRepository.findFirstByMatchIdAndStatusOrderByStartedAtDesc(id,"ACTIVE").orElseThrow();
        round.setPuzzleType("PIECE_SWITCH");
        round.setTotalQuestions(PieceSwitchEngine.QUESTION_COUNT);
        round.setPuzzleExpressions(PieceSwitchEngine.writeQuestions(mapper,PieceSwitchEngine.questions()));
        round.setPuzzleAnswers(mapper.writeValueAsString(PieceSwitchEngine.initial(System.currentTimeMillis())));
        roundRepository.save(round);
        var botReady = rounds.pieceSwitchBot(id,round.getId(),joined.black());
        assertTrue(botReady.pieceSwitch().blackReady());
        assertEquals(0,botReady.pieceSwitch().blackAcknowledged());
        rounds.pieceSwitch(id,new PieceSwitchEngine.Submission("switch-human",round.getId(),List.of(),false),true);
        round = roundRepository.findById(round.getId()).orElseThrow();
        var state = PieceSwitchEngine.read(mapper,round.getPuzzleAnswers());
        round.setPuzzleAnswers(mapper.writeValueAsString(new PieceSwitchEngine.State(state.readyDeadline(),System.currentTimeMillis()-10_000,state.revision(),state.white(),state.black())));
        roundRepository.save(round);
        var progressing = rounds.pieceSwitchBot(id,round.getId(),joined.black());
        assertTrue(progressing.pieceSwitch().blackAcknowledged() > 0);
        assertTrue(progressing.pieceSwitch().blackAcknowledged() < 10);
        assertEquals(MatchPhase.BRAIN_ROUND,matches.getMatch(id).phase());
        round = roundRepository.findById(round.getId()).orElseThrow();
        state = PieceSwitchEngine.read(mapper,round.getPuzzleAnswers());
        round.setPuzzleAnswers(mapper.writeValueAsString(new PieceSwitchEngine.State(state.readyDeadline(),System.currentTimeMillis()-45_100,state.revision(),state.white(),state.black())));
        roundRepository.save(round);
        rounds.pieceSwitch(id,new PieceSwitchEngine.Submission("switch-human",round.getId(),List.of(),true),false);
        var finished = rounds.pieceSwitchBot(id,round.getId(),joined.black());
        assertEquals("COMPLETED",finished.status());
        var resumed = matches.getMatch(id);
        assertEquals(MatchPhase.CHESS_PHASE,resumed.phase());
        assertEquals(2,resumed.white().brainPoints()+resumed.black().brainPoints());
        rounds.pieceSwitch(id,new PieceSwitchEngine.Submission("switch-human",round.getId(),List.of(),true),false);
        var repeated = matches.getMatch(id);
        assertEquals(2,repeated.white().brainPoints()+repeated.black().brainPoints());
    }

    @Test void pieceSwitchScoresBothPlayersAndRejectsOutsidersAndStaleRounds() {
        var mapper = new tools.jackson.databind.ObjectMapper();
        var created = service.create(new CreateBrainMatchRequest("switch-white", "White", BrainMatchMode.PIECE_SWITCH));
        var joined = service.join(new JoinBrainMatchRequest(created.inviteCode(), "switch-black", "Black"));
        var id = joined.matchId();
        assertNotNull(joined.pieceSwitch());
        assertEquals(243, joined.totalQuestions());
        var empty = new PieceSwitchEngine.Submission("switch-white", id, List.of(), false);
        var ready = service.pieceSwitch(id, empty, true);
        assertTrue(ready.puzzles().isEmpty(), "Progress acknowledgements must not rebuild the question payload");
        var unchanged = service.pieceSwitch(id, empty, true);
        assertEquals(ready.pieceSwitch().revision(), unchanged.pieceSwitch().revision());
        service.pieceSwitch(id, new PieceSwitchEngine.Submission("switch-black", id, List.of(), false), true);
        assertThrows(ApiException.class, () -> service.pieceSwitch(id, new PieceSwitchEngine.Submission("outsider", id, List.of(), false), false));
        assertThrows(ApiException.class, () -> service.pieceSwitch(id, new PieceSwitchEngine.Submission("switch-white", "old-round", List.of(), false), false));
        var entity = repository.findById(id).orElseThrow();
        var state = PieceSwitchEngine.read(mapper, entity.getPuzzleAnswers());
        entity.setPuzzleAnswers(mapper.writeValueAsString(new PieceSwitchEngine.State(state.readyDeadline(), System.currentTimeMillis() - 1000, state.revision(), state.white(), state.black())));
        repository.save(entity);
        var questions = PieceSwitchEngine.readQuestions(mapper, entity.getPuzzleExpressions());
        var white = List.of(new PieceSwitchEngine.Answer(0,questions.get(0).solution(),100), new PieceSwitchEngine.Answer(1,questions.get(1).solution(),400));
        var black = List.of(new PieceSwitchEngine.Answer(0,questions.get(0).solution(),100));
        service.pieceSwitch(id,new PieceSwitchEngine.Submission("switch-white",id,white,false),false);
        service.pieceSwitch(id,new PieceSwitchEngine.Submission("switch-black",id,black,false),false);
        assertEquals(2, service.get(id).whiteScore());
        assertEquals(1, service.get(id).blackScore());
        service.pieceSwitch(id,new PieceSwitchEngine.Submission("switch-white",id,white,false),false);
        assertEquals(2, service.get(id).whiteScore());
        entity = repository.findById(id).orElseThrow();
        state = PieceSwitchEngine.read(mapper, entity.getPuzzleAnswers());
        entity.setPuzzleAnswers(mapper.writeValueAsString(new PieceSwitchEngine.State(state.readyDeadline(), System.currentTimeMillis() - 45_100, state.revision(), state.white(), state.black())));
        repository.save(entity);
        service.pieceSwitch(id,new PieceSwitchEngine.Submission("switch-white",id,white,true),false);
        var finished = service.pieceSwitch(id,new PieceSwitchEngine.Submission("switch-black",id,black,true),false);
        assertEquals("COMPLETED", finished.status());
        assertEquals("switch-white", finished.winnerPlayerId());
        assertEquals(1, finished.blackScore());
        assertEquals("COMPLETED", service.pieceSwitch(id,new PieceSwitchEngine.Submission("switch-black",id,black,true),false).status());
    }

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

    @Test void rematchPreservesExplicitModesAcrossSuccessiveMatches() {
        for (var mode : BrainMatchMode.values()) {
            if (mode == BrainMatchMode.RANDOM) continue;
            var created = service.create(new CreateBrainMatchRequest("mode-white", "White", mode));
            var current = service.join(new JoinBrainMatchRequest(created.inviteCode(), "mode-black", "Black"));
            for (int i = 0; i < 2; i++) {
                current = finishAndRematch(current);
                assertEquals(mode, current.mode());
                assertEquals(mode.name(), current.puzzleType());
                if (mode == BrainMatchMode.PIECE_SWITCH) {
                    assertEquals(45_000, current.expiresAt().toEpochMilli() - current.pieceSwitch().startsAt());
                } else {
                    assertEquals(mode == BrainMatchMode.MEMORY ? 120 : 30,
                            java.time.Duration.between(current.startedAt(), current.expiresAt()).toSeconds());
                }
                assertEquals(0, current.whiteScore());
                assertEquals(0, current.blackScore());
            }
        }
    }

    @Test void randomRematchKeepsRandomModeAndDrawsFreshGames() {
        var created = service.create(new CreateBrainMatchRequest("random-white", "White", BrainMatchMode.RANDOM));
        var current = service.join(new JoinBrainMatchRequest(created.inviteCode(), "random-black", "Black"));
        var types = new java.util.HashSet<String>();
        types.add(current.puzzleType());
        for (int i = 0; i < 30; i++) {
            current = finishAndRematch(current);
            assertEquals(BrainMatchMode.RANDOM, current.mode());
            assertNotNull(BrainRoundPuzzleType.valueOf(current.puzzleType()));
            types.add(current.puzzleType());
        }
        // Thirty identical independent draws have probability below 1 in 200 trillion.
        assertTrue(types.size() > 1, "Random rematches must not be pinned to the first game");
    }

    private BrainMatchResponse finishAndRematch(BrainMatchResponse current) {
        var entity = repository.findById(current.matchId()).orElseThrow();
        entity.setExpiresAt(Instant.now().minusSeconds(10));
        repository.save(entity);
        service.complete(current.matchId());
        var requested = service.rematch(current.matchId(), new RematchRequest(current.white().playerId()));
        assertNull(requested.rematchMatchId());
        var accepted = service.rematch(current.matchId(), new RematchRequest(current.black().playerId()));
        assertEquals("ACTIVE", accepted.status());
        assertNotEquals(current.matchId(), accepted.matchId());
        assertEquals(current.black().playerId(), accepted.white().playerId());
        assertEquals(current.white().playerId(), accepted.black().playerId());
        assertEquals(accepted.matchId(), service.get(current.matchId()).rematchMatchId());
        assertEquals(accepted.matchId(), service.rematch(current.matchId(),
                new RematchRequest(current.white().playerId())).rematchMatchId());
        return accepted;
    }
}
