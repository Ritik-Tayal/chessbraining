package com.chessbraining.api.match;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
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
	private static final org.slf4j.Logger LOG = org.slf4j.LoggerFactory.getLogger(BotService.class);

	private static final String BRAIN_ROUND_ACTIVE = "ACTIVE";
	private static final SecureRandom RANDOM = new SecureRandom();

	private final MatchService matchService;
	private final PowerupService powerupService;
	private final BrainRoundService brainRoundService;
	private final BrainRoundRepository brainRoundRepository;
	private final ChessService chessService;
	private final tools.jackson.databind.ObjectMapper objectMapper;
	private final MatchRealtimeService realtimeService;
	private final StockfishEngine stockfish;
	private final BotMovePlanner movePlanner;
	private final ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(2);
	private final ScheduledExecutorService brainScheduler = Executors.newSingleThreadScheduledExecutor();
	private final BotMemoryPlayer memoryPlayer = new BotMemoryPlayer();
	private final Set<String> queuedMatches = ConcurrentHashMap.newKeySet();

	public BotService(
			MatchService matchService,
			PowerupService powerupService,
			BrainRoundService brainRoundService,
			BrainRoundRepository brainRoundRepository,
			ChessService chessService,
			tools.jackson.databind.ObjectMapper objectMapper,
			MatchRealtimeService realtimeService,
			StockfishEngine stockfish,
			BotMovePlanner movePlanner) {
		this.matchService = matchService;
		this.powerupService = powerupService;
		this.brainRoundService = brainRoundService;
		this.brainRoundRepository = brainRoundRepository;
		this.chessService = chessService;
		this.objectMapper = objectMapper;
		this.realtimeService = realtimeService;
		this.stockfish = stockfish;
		this.movePlanner = movePlanner;
	}

	public MatchResponse createBotMatch(CreateBotMatchRequest request) {
		stockfish.requireAvailable();
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
		boolean brain = match.phase() == MatchPhase.BRAIN_ROUND;
		int delayMs = brain ? 500 : randomBetween(difficulty.minThinkMs(), difficulty.maxThinkMs());
		if (!queuedMatches.add(match.matchId())) {
			return;
		}
		(brain ? brainScheduler : scheduler).schedule(() -> {
			MatchResponse next = null;
			try {
				next = continueBotMatch(match.matchId());
			} catch (RuntimeException e) {
				LOG.warn("Bot continuation failed for {}: {}", match.matchId(), e.getMessage());
				// Retry from fresh state; never silently downgrade a production expert to the heuristic bot.
				try { next = matchService.getMatch(match.matchId()); } catch (RuntimeException ignored) { }
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
			memoryPlayer.forget(matchId);
			return null;
		}
		if (match.phase() == MatchPhase.BRAIN_ROUND) {
			if (submitBotBrainRound(match)) {
				MatchResponse latest = matchService.getMatch(matchId);
				if (latest.phase() != MatchPhase.BRAIN_ROUND) realtimeService.publishMatchState(latest);
				return latest;
			}
			return null;
		}
		if (match.phase() != MatchPhase.CHESS_PHASE) {
			return null;
		}
		memoryPlayer.forget(matchId);
		PlayerResponse bot = botToMove(match);
		if (bot == null) {
			return null;
		}
		MatchResponse afterPowerup = null;
		if (bot.clockMs() < 30_000 && bot.brainPoints() >= PowerupType.CLOCK_BOOST_30.cost())
			afterPowerup = safePowerup(match, bot, PowerupType.CLOCK_BOOST_30, null);
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

		var plan = movePlanner.choose(match, bot);
		if (plan != null && plan.powerup() != null) {
			var powered = safePowerup(match, bot, plan.powerup(), plan.targetSquare());
			if (powered != null) {
				realtimeService.publishMatchState(powered);
				if (plan.powerup() == PowerupType.REVIVE_PAWN) return powered;
				match = powered;
			} else plan = movePlanner.choose(match, bot);
		}
		MatchResponse moved;
		if (plan != null && plan.move() != null) {
			var move = plan.move();
			moved = matchService.submitMove(match.matchId(),
					new SubmitMoveRequest(bot.playerId(), move.from(), move.to(), move.promotion()));
		} else moved = submitBotMove(match, bot);
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
		if (round != null && "PIECE_SWITCH".equals(round.getPuzzleType())) {
			var response = brainRoundService.pieceSwitchBot(match.matchId(), round.getId(), bot);
			realtimeService.publishPieceSwitch(response.roundId(), response.progress());
			return true;
		}
		if (round == null) return false;
		if (!BrainRoundPuzzleType.MEMORY.name().equals(round.getPuzzleType()) && botAlreadyAnswered(round, bot.side())) {
			brainRoundService.getCurrentRound(match.matchId());
			return true;
		}
		if (BrainRoundPuzzleType.DOT_CONNECT.name().equals(round.getPuzzleType())) {
			return submitBotDotConnectRound(match, bot, round);
		}
		if (BrainRoundPuzzleType.MEMORY.name().equals(round.getPuzzleType())) {
			return submitBotMemoryTurn(match, bot, round);
		}
		List<Integer> answers = parseAnswers(round.getPuzzleAnswers());
		Instant now = Instant.now();
		int targetScore = BotBrainPace.target(round.getId(), difficulty(bot), round.getTotalQuestions());
		int due = BotBrainPace.due(round, now);
		List<SubmitAnswerBatchRequest.SubmittedAnswer> submitted = new ArrayList<>();
		int expectedScore = 0;
		for (int i = 0; i < due; i++) {
			int answer = answers.get(i);
			if (!BotBrainPace.correct(i, targetScore, round.getTotalQuestions())) {
				answer += answer == 0 ? 1 : -1;
			} else expectedScore++;
			submitted.add(new SubmitAnswerBatchRequest.SubmittedAnswer(i, answer));
		}
		boolean finished = !now.isBefore(round.getExpiresAt());
		int score = "WHITE".equals(bot.side()) ? round.getWhiteCorrectCount() : round.getBlackCorrectCount();
		if (!finished && expectedScore <= score) return true;
		brainRoundService.submitAnswerBatch(
				match.matchId(),
				new SubmitAnswerBatchRequest(bot.playerId(), submitted, finished));
		return true;
	}

	private boolean submitBotDotConnectRound(MatchResponse match, PlayerResponse bot, BrainRoundEntity round) {
		List<String> puzzles = parseExpressions(round.getPuzzleExpressions());
		int targetScore = BotBrainPace.target(round.getId(), difficulty(bot), round.getTotalQuestions());
		int mask = "WHITE".equals(bot.side()) ? round.getWhiteAnsweredMask() : round.getBlackAnsweredMask();
		int due = BotBrainPace.due(round, Instant.now());
		for (int i = 0; i < due && i < puzzles.size(); i++) {
			if ((mask & (1 << i)) != 0) continue;
			List<List<Integer>> path = BotBrainPace.correct(i, targetScore, round.getTotalQuestions())
					? solutionPath(puzzles.get(i))
					: List.of(List.of(0, 0), List.of(0, 1));
			try {
				brainRoundService.submitPath(
						match.matchId(),
						new SubmitPathRequest(bot.playerId(), i, path));
			} catch (ApiException ex) {
				if ("NOT_IN_BRAIN_ROUND".equals(ex.getCode()) ||
						"BRAIN_ROUND_NOT_FOUND".equals(ex.getCode())) {
					break;
				}
				throw ex;
			}
		}
		if (matchService.getMatch(match.matchId()).phase() == MatchPhase.BRAIN_ROUND)
			brainRoundService.getCurrentRound(match.matchId());
		return true;
	}

	private boolean submitBotMemoryTurn(MatchResponse match, PlayerResponse bot, BrainRoundEntity round) {
		var current = brainRoundService.getCurrentRound(match.matchId());
		if ("COMPLETED".equals(current.status())) return true;
		round = brainRoundRepository.findById(round.getId()).orElseThrow();
		MemoryPuzzleService.MemoryState state = parseMemoryState(round.getPuzzleAnswers());
		long now = System.currentTimeMillis();
		int card = memoryPlayer.choose(match.matchId(), round.getId(), state, difficulty(bot), bot.side(), now);
		if (card < 0) return true;
		try {
			brainRoundService.submitMemoryTurn(
					match.matchId(),
					state.pendingFirstIndex() == null ? new SubmitMemoryTurnRequest(bot.playerId(), card, -1)
							: new SubmitMemoryTurnRequest(bot.playerId(), state.pendingFirstIndex(), card));
			memoryPlayer.played(match.matchId(), now);
			return true;
		} catch (ApiException ex) {
			if ("NOT_IN_BRAIN_ROUND".equals(ex.getCode()) ||
					"BRAIN_ROUND_NOT_FOUND".equals(ex.getCode())) {
				return false;
			}
			throw ex;
		}
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

	private int randomBetween(int min, int max) {
		if (max <= min) {
			return min;
		}
		return min + RANDOM.nextInt(max - min + 1);
	}

	@PreDestroy
	void shutdown() {
		brainScheduler.shutdownNow();
		scheduler.shutdownNow();
		try {
			brainScheduler.awaitTermination(Duration.ofSeconds(2).toMillis(), TimeUnit.MILLISECONDS);
			scheduler.awaitTermination(Duration.ofSeconds(2).toMillis(), TimeUnit.MILLISECONDS);
		} catch (InterruptedException e) {
			Thread.currentThread().interrupt();
		}
	}
}
