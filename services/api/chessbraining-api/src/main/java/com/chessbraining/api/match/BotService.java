package com.chessbraining.api.match;

import java.security.SecureRandom;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

import com.chessbraining.api.chess.ChessMove;
import com.chessbraining.api.chess.ChessMoveResult;
import com.chessbraining.api.chess.ChessService;
import com.chessbraining.api.chess.LegalMoveResponse;
import com.chessbraining.api.common.ApiException;
import com.chessbraining.api.websocket.MatchRealtimeService;
import jakarta.annotation.PreDestroy;
import org.springframework.stereotype.Service;

@Service
public class BotService {

	private static final String BRAIN_ROUND_ACTIVE = "ACTIVE";
	private static final SecureRandom RANDOM = new SecureRandom();

	private final MatchService matchService;
	private final PowerupService powerupService;
	private final BrainRoundService brainRoundService;
	private final BrainRoundRepository brainRoundRepository;
	private final ChessService chessService;
	private final tools.jackson.databind.ObjectMapper objectMapper;
	private final MatchRealtimeService realtimeService;
	private final ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(2);
	private final Set<String> queuedMatches = ConcurrentHashMap.newKeySet();

	public BotService(
			MatchService matchService,
			PowerupService powerupService,
			BrainRoundService brainRoundService,
			BrainRoundRepository brainRoundRepository,
			ChessService chessService,
			tools.jackson.databind.ObjectMapper objectMapper,
			MatchRealtimeService realtimeService) {
		this.matchService = matchService;
		this.powerupService = powerupService;
		this.brainRoundService = brainRoundService;
		this.brainRoundRepository = brainRoundRepository;
		this.chessService = chessService;
		this.objectMapper = objectMapper;
		this.realtimeService = realtimeService;
	}

	public MatchResponse createBotMatch(CreateBotMatchRequest request) {
		MatchResponse match = matchService.createBotMatch(request);
		scheduleContinuation(match);
		return match;
	}

	public void scheduleContinuation(String matchId) {
		scheduleContinuation(matchService.getMatch(matchId));
	}

	public void scheduleContinuation(MatchResponse match) {
		PlayerResponse bot = activeBot(match);
		if (bot == null) {
			return;
		}
		BotDifficulty difficulty = bot.botDifficulty() == null ? BotDifficulty.NORMAL : bot.botDifficulty();
		int delayMs = randomBetween(difficulty.minThinkMs(), difficulty.maxThinkMs());
		if (!queuedMatches.add(match.matchId())) {
			return;
		}
		scheduler.schedule(() -> {
			MatchResponse next = null;
			try {
				next = continueBotMatch(match.matchId());
			} finally {
				queuedMatches.remove(match.matchId());
				if (next != null) {
					scheduleContinuation(next);
				}
			}
		}, delayMs, TimeUnit.MILLISECONDS);
	}

	private MatchResponse continueBotMatch(String matchId) {
		MatchResponse match = matchService.getMatch(matchId);
		if (match.status() != MatchStatus.ACTIVE) {
			return null;
		}
		if (match.phase() == MatchPhase.BRAIN_ROUND) {
			if (submitBotBrainRound(match)) {
				MatchResponse latest = matchService.getMatch(matchId);
				realtimeService.publishMatchState(latest);
				return latest;
			}
			return null;
		}
		if (match.phase() != MatchPhase.CHESS_PHASE) {
			return null;
		}
		PlayerResponse bot = botToMove(match);
		if (bot == null) {
			return null;
		}
		MatchResponse afterPowerup = maybeUsePowerup(match, bot);
		if (afterPowerup != null) {
			realtimeService.publishMatchState(afterPowerup);
			if (!afterPowerup.sideToMove().equals(bot.side()) || afterPowerup.phase() != MatchPhase.CHESS_PHASE) {
				return afterPowerup;
			}
			match = afterPowerup;
			bot = botToMove(match);
			if (bot == null) {
				return null;
			}
		}

		MatchResponse moved = submitBotMove(match, bot);
		if (moved == null) {
			return null;
		}
		realtimeService.publishMatchState(moved);
		return moved;
	}

	private MatchResponse submitBotMove(MatchResponse match, PlayerResponse bot) {
		List<LegalMoveResponse> moves = new ArrayList<>(chessService.legalMoves(match.fen()));
		if (moves.isEmpty()) {
			return null;
		}
		BotDifficulty difficulty = difficulty(bot);
		moves.sort(Comparator
				.comparingDouble((LegalMoveResponse move) -> scoreMove(match.fen(), bot.side(), move, difficulty))
				.reversed());
		int candidateLimit = candidateLimit(moves.size(), difficulty);
		List<LegalMoveResponse> candidates = new ArrayList<>(moves.subList(0, candidateLimit));
		shuffleTail(candidates, difficulty);

		for (LegalMoveResponse move : candidates) {
			try {
				return matchService.submitMove(match.matchId(),
						new SubmitMoveRequest(bot.playerId(), move.from(), move.to(), move.promotion()));
			} catch (ApiException ignored) {
				// Extra-move constraints can reject otherwise legal moves; try another candidate.
			}
		}
		return null;
	}

	private MatchResponse maybeUsePowerup(MatchResponse match, PlayerResponse bot) {
		BotDifficulty difficulty = difficulty(bot);
		if (bot.clockMs() < 30_000 && bot.brainPoints() >= PowerupType.CLOCK_BOOST_30.cost()) {
			return safePowerup(match, bot, PowerupType.CLOCK_BOOST_30, null);
		}
		if (!bot.extraMoveArmed() &&
				!bot.extraMoveActive() &&
				bot.brainPoints() >= PowerupType.EXTRA_MOVE.cost() &&
				RANDOM.nextDouble() < difficulty.tacticalBias() * 0.35) {
			MatchResponse powered = safePowerup(match, bot, PowerupType.EXTRA_MOVE, null);
			if (powered != null) {
				return powered;
			}
		}
		if (bot.revivablePawns() > 0 &&
				bot.brainPoints() >= PowerupType.REVIVE_PAWN.cost() &&
				RANDOM.nextDouble() < difficulty.tacticalBias() * 0.18) {
			for (String square : reviveCandidates(bot.side())) {
				MatchResponse powered = safePowerup(match, bot, PowerupType.REVIVE_PAWN, square);
				if (powered != null) {
					return powered;
				}
			}
		}
		return null;
	}

	private MatchResponse safePowerup(MatchResponse match, PlayerResponse bot, PowerupType type, String targetSquare) {
		try {
			return powerupService.applyPowerup(match.matchId(), new ApplyPowerupRequest(bot.playerId(), type, targetSquare));
		} catch (ApiException ignored) {
			return null;
		}
	}

	private boolean submitBotBrainRound(MatchResponse match) {
		PlayerResponse bot = botInMatch(match);
		if (bot == null) {
			return false;
		}
		BrainRoundEntity round = brainRoundRepository
				.findFirstByMatchIdAndStatusOrderByStartedAtDesc(match.matchId(), BRAIN_ROUND_ACTIVE)
				.orElse(null);
		if (round == null ||
				(!BrainRoundPuzzleType.MEMORY.name().equals(round.getPuzzleType()) && botAlreadyAnswered(round, bot.side()))) {
			return false;
		}
		if (BrainRoundPuzzleType.DOT_CONNECT.name().equals(round.getPuzzleType())) {
			return submitBotDotConnectRound(match, bot, round);
		}
		if (BrainRoundPuzzleType.MEMORY.name().equals(round.getPuzzleType())) {
			return submitBotMemoryTurn(match, bot, round);
		}
		List<Integer> answers = parseAnswers(round.getPuzzleAnswers());
		int targetScore = botScore(bot, round.getTotalQuestions(), match.brainRoundCount());
		List<SubmitAnswerBatchRequest.SubmittedAnswer> submitted = new ArrayList<>();
		for (int i = 0; i < round.getTotalQuestions(); i++) {
			int answer = answers.get(i);
			if (i >= targetScore) {
				answer += answer == 0 ? 1 : -1;
			}
			submitted.add(new SubmitAnswerBatchRequest.SubmittedAnswer(i, answer));
		}
		BrainRoundSubmissionResponse response = brainRoundService.submitAnswerBatch(
				match.matchId(),
				new SubmitAnswerBatchRequest(bot.playerId(), submitted));
		return response.roundCompleted();
	}

	private boolean submitBotDotConnectRound(MatchResponse match, PlayerResponse bot, BrainRoundEntity round) {
		List<String> puzzles = parseExpressions(round.getPuzzleExpressions());
		int targetScore = botScore(bot, round.getTotalQuestions(), match.brainRoundCount());
		int submittedCount = 0;
		for (int i = 0; i < round.getTotalQuestions() && i < puzzles.size(); i++) {
			List<List<Integer>> path = i < targetScore
					? solutionPath(puzzles.get(i))
					: List.of(List.of(0, 0), List.of(0, 1));
			try {
				brainRoundService.submitPath(
						match.matchId(),
						new SubmitPathRequest(bot.playerId(), i, path));
				submittedCount++;
			} catch (ApiException ex) {
				if ("NOT_IN_BRAIN_ROUND".equals(ex.getCode()) ||
						"BRAIN_ROUND_NOT_FOUND".equals(ex.getCode())) {
					break;
				}
				throw ex;
			}
		}
		return submittedCount > 0 && matchService.getMatch(match.matchId()).phase() != MatchPhase.BRAIN_ROUND;
	}

	private boolean submitBotMemoryTurn(MatchResponse match, PlayerResponse bot, BrainRoundEntity round) {
		MemoryPuzzleService.MemoryState state = parseMemoryState(round.getPuzzleAnswers());
		if (!bot.side().equals(state.turnSide())) {
			return false;
		}
		List<Integer> pair = chooseBotMemoryPair(bot, state, match.brainRoundCount());
		if (pair.size() < 2) {
			return false;
		}
		try {
			brainRoundService.submitMemoryTurn(
					match.matchId(),
					new SubmitMemoryTurnRequest(bot.playerId(), pair.get(0), pair.get(1)));
			return true;
		} catch (ApiException ex) {
			if ("NOT_IN_BRAIN_ROUND".equals(ex.getCode()) ||
					"BRAIN_ROUND_NOT_FOUND".equals(ex.getCode())) {
				return false;
			}
			throw ex;
		}
	}

	private List<Integer> chooseBotMemoryPair(PlayerResponse bot, MemoryPuzzleService.MemoryState state, int roundNumber) {
		boolean shouldMatch = botScore(bot, state.cards().size() / 2, roundNumber) > 0 && RANDOM.nextDouble() < difficulty(bot).brainMean();
		if (shouldMatch) {
			for (int i = 0; i < state.cards().size(); i++) {
				if (memoryMatched(state, i)) {
					continue;
				}
				for (int j = i + 1; j < state.cards().size(); j++) {
					if (!memoryMatched(state, j) && state.cards().get(i).equals(state.cards().get(j))) {
						return List.of(i, j);
					}
				}
			}
		}
		List<Integer> unmatched = new ArrayList<>();
		for (int i = 0; i < state.cards().size(); i++) {
			if (!memoryMatched(state, i)) {
				unmatched.add(i);
			}
		}
		if (unmatched.size() < 2) {
			return List.of();
		}
		return List.of(unmatched.get(0), unmatched.get(1));
	}

	private boolean memoryMatched(MemoryPuzzleService.MemoryState state, int index) {
		return (state.matchedMask() & (1 << index)) != 0;
	}

	private int botScore(PlayerResponse bot, int totalQuestions, int roundNumber) {
		BotDifficulty difficulty = difficulty(bot);
		double wave = (RANDOM.nextDouble() * 2.0) - 1.0;
		double rate = difficulty.brainMean() + (wave * difficulty.brainSpread());
		if (roundNumber % 3 == 0) {
			rate += 0.04;
		}
		int score = (int) Math.round(totalQuestions * rate);
		return Math.max(0, Math.min(totalQuestions, score));
	}

	private PlayerResponse activeBot(MatchResponse match) {
		if (match.status() != MatchStatus.ACTIVE) {
			return null;
		}
		if (match.phase() == MatchPhase.BRAIN_ROUND) {
			return botInMatch(match);
		}
		if (match.phase() == MatchPhase.CHESS_PHASE) {
			return botToMove(match);
		}
		return null;
	}

	private PlayerResponse botToMove(MatchResponse match) {
		PlayerResponse player = playerToMove(match);
		return player != null && player.bot() ? player : null;
	}

	private PlayerResponse botInMatch(MatchResponse match) {
		if (match.white().bot()) {
			return match.white();
		}
		if (match.black() != null && match.black().bot()) {
			return match.black();
		}
		return null;
	}

	private PlayerResponse playerToMove(MatchResponse match) {
		if ("WHITE".equals(match.sideToMove())) {
			return match.white();
		}
		if (match.black() != null && "BLACK".equals(match.sideToMove())) {
			return match.black();
		}
		return null;
	}

	private BotDifficulty difficulty(PlayerResponse bot) {
		return bot.botDifficulty() == null ? BotDifficulty.NORMAL : bot.botDifficulty();
	}

	private boolean botAlreadyAnswered(BrainRoundEntity round, String side) {
		int mask = (1 << round.getTotalQuestions()) - 1;
		return "WHITE".equals(side)
				? (round.getWhiteAnsweredMask() & mask) == mask
				: (round.getBlackAnsweredMask() & mask) == mask;
	}

	private List<Integer> parseAnswers(String json) {
		try {
			return List.of(objectMapper.readValue(json, Integer[].class));
		} catch (tools.jackson.core.JacksonException e) {
			throw new IllegalStateException("Failed to parse bot brain-round answers.", e);
		}
	}

	private List<String> parseExpressions(String json) {
		try {
			return List.of(objectMapper.readValue(json, String[].class));
		} catch (tools.jackson.core.JacksonException e) {
			throw new IllegalStateException("Failed to parse bot brain-round puzzles.", e);
		}
	}

	private MemoryPuzzleService.MemoryState parseMemoryState(String json) {
		try {
			return objectMapper.readValue(json, MemoryPuzzleService.MemoryState.class);
		} catch (tools.jackson.core.JacksonException e) {
			throw new IllegalStateException("Failed to parse bot memory state.", e);
		}
	}

	private List<List<Integer>> solutionPath(String puzzleJson) {
		try {
			DotConnectPuzzleService.PuzzleData puzzle =
					objectMapper.readValue(puzzleJson, DotConnectPuzzleService.PuzzleData.class);
			return puzzle.solutionPath().stream()
					.map(dot -> List.of(dot.row(), dot.col()))
					.toList();
		} catch (tools.jackson.core.JacksonException e) {
			return List.of(List.of(0, 0), List.of(0, 1));
		}
	}

	private double scoreMove(String fen, String side, LegalMoveResponse move, BotDifficulty difficulty) {
		try {
			ChessMoveResult result = chessService.applyMove(fen, new ChessMove(move.from(), move.to(), move.promotion()), side);
			double score = RANDOM.nextDouble() * (1.0 - difficulty.tacticalBias()) * 12.0;
			if (result.checkmate()) {
				score += 10_000;
			}
			if (result.check()) {
				score += 24 * difficulty.tacticalBias();
			}
			if (move.promotion() != null) {
				score += 50;
			}
			score += advancementScore(move, side) * (2 + difficulty.tacticalBias() * 4);
			score += centerScore(move.to()) * (1 + difficulty.tacticalBias() * 3);
			return score;
		} catch (ApiException ignored) {
			return -1_000;
		}
	}

	private double advancementScore(LegalMoveResponse move, String side) {
		int fromRank = Character.digit(move.from().charAt(1), 10);
		int toRank = Character.digit(move.to().charAt(1), 10);
		return "WHITE".equals(side) ? toRank - fromRank : fromRank - toRank;
	}

	private double centerScore(String square) {
		char file = square.charAt(0);
		int rank = Character.digit(square.charAt(1), 10);
		double fileDistance = Math.abs(file - 'd') <= Math.abs(file - 'e')
				? Math.abs(file - 'd')
				: Math.abs(file - 'e');
		double rankDistance = Math.min(Math.abs(rank - 4), Math.abs(rank - 5));
		return Math.max(0, 4 - fileDistance - rankDistance);
	}

	private int candidateLimit(int size, BotDifficulty difficulty) {
		return switch (difficulty) {
			case EASY -> Math.max(1, Math.min(size, 10));
			case NORMAL -> Math.max(1, Math.min(size, 6));
			case HARD -> Math.max(1, Math.min(size, 4));
			case EXPERT -> Math.max(1, Math.min(size, 2));
		};
	}

	private void shuffleTail(List<LegalMoveResponse> candidates, BotDifficulty difficulty) {
		if (difficulty == BotDifficulty.EXPERT || candidates.size() <= 1) {
			return;
		}
		for (int i = 1; i < candidates.size(); i++) {
			int swap = 1 + RANDOM.nextInt(candidates.size() - 1);
			LegalMoveResponse temp = candidates.get(i);
			candidates.set(i, candidates.get(swap));
			candidates.set(swap, temp);
		}
	}

	private List<String> reviveCandidates(String side) {
		if ("WHITE".equals(side)) {
			return List.of("d4", "e4", "c4", "f4", "d3", "e3", "c3", "f3", "a3", "h3", "a4", "h4");
		}
		return List.of("d5", "e5", "c5", "f5", "d6", "e6", "c6", "f6", "a6", "h6", "a5", "h5");
	}

	private int randomBetween(int min, int max) {
		if (max <= min) {
			return min;
		}
		return min + RANDOM.nextInt(max - min + 1);
	}

	@PreDestroy
	void shutdown() {
		scheduler.shutdownNow();
		try {
			scheduler.awaitTermination(Duration.ofSeconds(2).toMillis(), TimeUnit.MILLISECONDS);
		} catch (InterruptedException e) {
			Thread.currentThread().interrupt();
		}
	}
}
