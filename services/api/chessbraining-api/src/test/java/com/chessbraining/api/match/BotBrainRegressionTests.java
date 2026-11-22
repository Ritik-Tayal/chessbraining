package com.chessbraining.api.match;

import java.time.Instant;
import java.util.AbstractList;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.util.ReflectionTestUtils;
import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@ActiveProfiles("test")
class BotBrainRegressionTests {
    @Autowired MatchService matches;
    @Autowired BotService bots;
    @Autowired BrainRoundService rounds;
    @Autowired BrainRoundRepository repository;
    @Autowired MatchRepository matchRepository;
    @Autowired MathPuzzleService math;
    @Autowired DotConnectPuzzleService dots;
    @Autowired tools.jackson.databind.ObjectMapper mapper;

    record Game(MatchResponse match, BrainRoundEntity round) { }

    Game game(BotDifficulty difficulty, String type) {
        var match = matches.createBotMatch(new CreateBotMatchRequest("human_" + UUID.randomUUID(), "Human", difficulty, "WHITE", 600, 1));
        matches.submitMove(match.matchId(), new SubmitMoveRequest(match.white().playerId(), "e2", "e4", null));
        matches.submitMove(match.matchId(), new SubmitMoveRequest(match.black().playerId(), "e7", "e5", null));
        var round = repository.findFirstByMatchIdAndStatusOrderByStartedAtDesc(match.matchId(), "ACTIVE").orElseThrow();
        round.setPuzzleType(type);
        round.setStartedAt(Instant.now().minusSeconds(15));
        round.setExpiresAt(Instant.now().plusSeconds(15));
        round.setWhiteAnsweredMask(0);
        round.setBlackAnsweredMask(0);
        round.setWhiteCorrectCount(0);
        round.setBlackCorrectCount(0);
        return new Game(match, round);
    }

    void step(Game game) { ReflectionTestUtils.invokeMethod(bots, "continueBotMatch", game.match.matchId()); }

    void wonOnce(Game game) {
        var result = rounds.getLatestResult(game.match.matchId());
        assertTrue(result.blackCorrectCount() > 0);
        assertEquals(game.match.black().playerId(), result.winnerPlayerId());
        assertEquals(2, matches.getMatch(game.match.matchId()).black().brainPoints());
        step(game);
        assertEquals(2, matches.getMatch(game.match.matchId()).black().brainPoints());
    }

    @ParameterizedTest @EnumSource(BotDifficulty.class)
    void mathScoresGraduallyAndAwardsPointsAfterFinalSubmission(BotDifficulty difficulty) {
        var game = game(difficulty, "MENTAL_MATH");
        var puzzles = math.generatePuzzles();
        game.round.setPuzzleExpressions(mapper.writeValueAsString(puzzles.expressions()));
        game.round.setPuzzleAnswers(mapper.writeValueAsString(puzzles.answers()));
        game.round.setTotalQuestions(30);
        repository.save(game.round);
        step(game);
        int midway = rounds.getCurrentRound(game.match.matchId()).blackCorrectCount();
        int target = BotBrainPace.target(game.round.getId(), difficulty, 30);
        assertTrue(midway > 0 && midway < target);
        step(game);
        assertTrue(rounds.getCurrentRound(game.match.matchId()).blackCorrectCount() >= midway);
        var round = repository.findById(game.round.getId()).orElseThrow();
        round.setStartedAt(Instant.now().minusSeconds(30));
        round.setExpiresAt(Instant.now().minusMillis(100));
        repository.save(round);
        rounds.submitAnswerBatch(game.match.matchId(), new SubmitAnswerBatchRequest(game.match.white().playerId(), List.of(), true));
        step(game);
        assertEquals(target, rounds.getLatestResult(game.match.matchId()).blackCorrectCount());
        wonOnce(game);
    }

    @ParameterizedTest @EnumSource(BotDifficulty.class)
    void dotsSubmitOnlyDuePuzzlesAndDoNotLoseTheFinalScore(BotDifficulty difficulty) {
        var game = game(difficulty, "DOT_CONNECT");
        var puzzles = dots.generatePuzzleSet(5);
        game.round.setPuzzleExpressions(mapper.writeValueAsString(puzzles.puzzles()));
        game.round.setPuzzleAnswers(mapper.writeValueAsString(puzzles.answers()));
        game.round.setTotalQuestions(5);
        repository.save(game.round);
        step(game);
        var midway = rounds.getCurrentRound(game.match.matchId());
        assertTrue(midway.blackCorrectCount() > 0);
        assertTrue(midway.nextBlackQuestionIndex() < 5);
        var round = repository.findById(game.round.getId()).orElseThrow();
        round.setStartedAt(Instant.now().minusSeconds(29));
        round.setExpiresAt(Instant.now().plusSeconds(1));
        round.setWhiteAnsweredMask(31);
        repository.save(round);
        step(game);
        assertEquals(BotBrainPace.target(round.getId(), difficulty, 5), rounds.getLatestResult(game.match.matchId()).blackCorrectCount());
        wonOnce(game);
    }

    @ParameterizedTest @EnumSource(BotDifficulty.class)
    void pieceSwitchScoresAtEveryLevelAndCanWinBrainPoints(BotDifficulty difficulty) {
        var game = game(difficulty, "PIECE_SWITCH");
        game.round.setPuzzleExpressions(PieceSwitchEngine.writeQuestions(mapper, PieceSwitchEngine.questions()));
        game.round.setPuzzleAnswers(mapper.writeValueAsString(PieceSwitchEngine.initial(System.currentTimeMillis())));
        game.round.setTotalQuestions(PieceSwitchEngine.QUESTION_COUNT);
        repository.save(game.round);
        step(game);
        rounds.pieceSwitch(game.match.matchId(), new PieceSwitchEngine.Submission(game.match.white().playerId(), game.round.getId(), List.of(), false), true);
        var round = repository.findById(game.round.getId()).orElseThrow();
        var state = PieceSwitchEngine.read(mapper, round.getPuzzleAnswers());
        round.setPuzzleAnswers(mapper.writeValueAsString(new PieceSwitchEngine.State(state.readyDeadline(), System.currentTimeMillis() - 12000, state.revision(), state.white(), state.black())));
        repository.save(round);
        step(game);
        assertTrue(rounds.getCurrentRound(game.match.matchId()).blackCorrectCount() > 0);
        round = repository.findById(round.getId()).orElseThrow();
        state = PieceSwitchEngine.read(mapper, round.getPuzzleAnswers());
        round.setPuzzleAnswers(mapper.writeValueAsString(new PieceSwitchEngine.State(state.readyDeadline(), System.currentTimeMillis() - 45100, state.revision(), state.white(), state.black())));
        repository.save(round);
        rounds.pieceSwitch(game.match.matchId(), new PieceSwitchEngine.Submission(game.match.white().playerId(), round.getId(), List.of(), true), false);
        step(game);
        wonOnce(game);
    }

    @ParameterizedTest @EnumSource(BotDifficulty.class)
    void memoryWaitsForHumanTimeoutThenRevealsTwoCardsAndCollectsAPair(BotDifficulty difficulty) {
        var game = game(difficulty, "MEMORY");
        var cards = java.util.Collections.nCopies(24, "WHITE_KING");
        var state = new MemoryPuzzleService.MemoryState(cards, ((1 << 24) - 1) ^ 3, "WHITE", List.of(0), false, null, null, System.currentTimeMillis() - 3000);
        game.round.setPuzzleAnswers(mapper.writeValueAsString(state));
        game.round.setPuzzleExpressions(mapper.writeValueAsString(new String[] {new MemoryPuzzleService().publicBoardJson(state)}));
        game.round.setTotalQuestions(12);
        repository.save(game.round);
        step(game);
        var round = repository.findById(game.round.getId()).orElseThrow();
        var pending = mapper.readValue(round.getPuzzleAnswers(), MemoryPuzzleService.MemoryState.class);
        assertEquals("BLACK", pending.turnSide());
        assertNotNull(pending.pendingFirstIndex());
        assertEquals(0, round.getBlackCorrectCount());
        step(game);
        assertEquals(0, repository.findById(round.getId()).orElseThrow().getBlackCorrectCount());
        var player = (BotMemoryPlayer) ReflectionTestUtils.getField(bots, "memoryPlayer");
        player.played(game.match.matchId(), System.currentTimeMillis() - 3000);
        step(game);
        wonOnce(game);
    }

    @Test void memoryDoesNotInspectHiddenPieces() {
        var hidden = new AbstractList<String>() {
            public int size() { return 24; }
            public String get(int index) { fail("Bot inspected a hidden card: " + index); return null; }
        };
        var state = new MemoryPuzzleService.MemoryState(hidden, 0, "BLACK", List.of(), false, null, null, 20000L);
        int card = new BotMemoryPlayer().choose("m", "r", state, BotDifficulty.EXPERT, "BLACK", 15000);
        assertTrue(card >= 0 && card < 24);
    }

    @Test void botSpendsEarnedBrainPointsOnAClockBoostAndMakesALegalMove() {
        var game = game(BotDifficulty.EASY, "MENTAL_MATH");
        var puzzles = math.generatePuzzles();
        game.round.setPuzzleExpressions(mapper.writeValueAsString(puzzles.expressions()));
        game.round.setPuzzleAnswers(mapper.writeValueAsString(puzzles.answers()));
        game.round.setTotalQuestions(30);
        game.round.setStartedAt(Instant.now().minusSeconds(30));
        game.round.setExpiresAt(Instant.now().minusMillis(100));
        repository.save(game.round);
        rounds.submitAnswerBatch(game.match.matchId(), new SubmitAnswerBatchRequest(game.match.white().playerId(), List.of(), true));
        step(game);
        assertEquals(2, matches.getMatch(game.match.matchId()).black().brainPoints());
        var entity = matchRepository.findById(game.match.matchId()).orElseThrow();
        entity.setBlackClockMs(25000);
        entity.setBrainRoundIntervalMoves(5);
        matchRepository.save(entity);
        matches.submitMove(entity.getId(), new SubmitMoveRequest(game.match.white().playerId(), "g1", "f3", null));
        step(game);
        var after = matches.getMatch(entity.getId());
        assertEquals(1, after.black().brainPoints());
        assertTrue(after.black().clockMs() > 40000);
        assertEquals(4, after.plyCount());
        assertEquals("WHITE", after.sideToMove());
    }

    @Test void performancePlansAreStableVariedAndStrongerAtHigherDifficulty() {
        double previous = 0;
        for (var difficulty : BotDifficulty.values()) {
            int sum = 0;
            var scores = new java.util.HashSet<Integer>();
            for (int game = 0; game < 100; game++) {
                int target = BotBrainPace.target("round_" + game, difficulty, 30);
                assertEquals(target, BotBrainPace.target("round_" + game, difficulty, 30));
                int correct = 0;
                for (int i = 0; i < 30; i++) if (BotBrainPace.correct(i, target, 30)) correct++;
                assertEquals(target, correct);
                sum += target;
                scores.add(target);
            }
            assertTrue(scores.size() > 1);
            assertTrue(sum / 100.0 > previous);
            previous = sum / 100.0;
        }
    }
}
