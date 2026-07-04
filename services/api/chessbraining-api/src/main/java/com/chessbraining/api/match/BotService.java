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
import com.fasterxml.jackson.core.JacksonException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.github.bhlangonijr.chesslib.Board;
import com.github.bhlangonijr.chesslib.Piece;
import com.github.bhlangonijr.chesslib.Side;
import com.github.bhlangonijr.chesslib.Square;
import jakarta.annotation.PreDestroy;
import org.springframework.stereotype.Service;

@Service
public class BotService {

	private static final String BRAIN_ROUND_ACTIVE = "ACTIVE";
	private static final int WIN_BONUS = 30_000;
	private static final int CHECK_BONUS = 180;
	private static final int CHECK_MATE_PENALTY = -10_000;
	private static final SecureRandom RANDOM = new SecureRandom();

	private final MatchService matchService;
	private final PowerupService powerupService;
	private final BrainRoundService brainRoundService;
	private final BrainRoundRepository brainRoundRepository;
	private final ChessService chessService;
	private final ObjectMapper objectMapper;
	private final MatchRealtimeService realtimeService;
	private final ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(2);
	private final Set<String> queuedMatches = ConcurrentHashMap.newKeySet();

	public BotService(
			MatchService matchService,
			PowerupService powerupService,
			BrainRoundService brainRoundService,
			BrainRoundRepository brainRoundRepository,
			ChessService chessService,
			ObjectMapper objectMapper,
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
			try {
				if (submitBotBrainRound(match)) {
					MatchResponse latest = matchService.getMatch(matchId);
					if (latest.phase() != MatchPhase.BRAIN_ROUND) {
						realtimeService.publishMatchState(latest);
						return latest;
					}
				}
			} catch (RuntimeException ignored) {
				return match;
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
		LegalMoveResponse openingMove = chooseOpeningMove(match.fen(), match.plyCount(), bot.side(), moves, bot.botDifficulty());
		if (openingMove != null) {
			try {
				return matchService.submitMove(match.matchId(),
						new SubmitMoveRequest(bot.playerId(), openingMove.from(), openingMove.to(), openingMove.promotion()));
			} catch (ApiException ignored) {
				// fall back to search result
			}
		}
		BotDifficulty difficulty = difficulty(bot);
		int searchDepth = searchDepth(difficulty);
		int scoreWidth = moveCandidateWidth(moves.size(), difficulty);

		List<ScoredMove> scored = new ArrayList<>(moves.size());
		for (LegalMoveResponse move : moves) {
			double score = evaluateMove(match.fen(), bot.side(), move, difficulty, searchDepth);
			scored.add(new ScoredMove(move, score));
		}

		scored.sort(Comparator.comparingDouble((ScoredMove m) -> m.score).reversed());
		int candidateCount = Math.max(1, Math.min(scored.size(), scoreWidth));
		for (int i = 0; i < candidateCount; i++) {
			LegalMoveResponse move = scored.get(i).move;
			try {
				return matchService.submitMove(match.matchId(),
						new SubmitMoveRequest(bot.playerId(), move.from(), move.to(), move.promotion()));
			} catch (ApiException ignored) {
				// Move was rejected by game-state race/policy after scoring; try next candidate.
			}
		}
		return null;
	}

	private LegalMoveResponse chooseOpeningMove(
			String fen,
			int plyCount,
			String side,
			List<LegalMoveResponse> legalMoves,
			BotDifficulty difficulty) {
		if (difficulty != BotDifficulty.EXPERT && difficulty != BotDifficulty.HARD) {
			return null;
		}
		if (plyCount > 6) {
			return null;
		}
		if ("WHITE".equals(side) && plyCount == 0) {
			for (String to : List.of("e4", "d4", "c4", "g3")) {
				LegalMoveResponse move = findMove(legalMoves, "e2", to);
				if (move != null) {
					return move;
				}
			}
		} else if ("BLACK".equals(side) && (plyCount == 1 || plyCount == 3 || plyCount == 5)) {
			for (String to : List.of("e5", "c5", "d5", "f6")) {
				LegalMoveResponse move = findMove(legalMoves, "e7", to);
				if (move != null) {
					return move;
				}
			}
		}
		return null;
	}

	private LegalMoveResponse findMove(List<LegalMoveResponse> legalMoves, String from, String to) {
		for (LegalMoveResponse move : legalMoves) {
			if (from.equals(move.from()) && to.equals(move.to())) {
				return move;
			}
		}
		return null;
	}

	private double evaluateMove(String fen, String botSide, LegalMoveResponse move, BotDifficulty difficulty, int searchDepth) {
		try {
			ChessMoveResult result = chessService.applyMove(fen, new ChessMove(move.from(), move.to(), move.promotion()), botSide);
			double score = evaluateResult(result, botSide, difficulty) + tacticalValue(move, botSide);
			score += positionFeatureBonus(move, result, botSide);

			if (result.draw()) {
				score -= 40;
			}
			if (result.stalemate()) {
				score -= 55;
			}
			if (searchDepth > 0) {
				score += searchPositionValue(result.fen(), result.sideToMove(), botSide, searchDepth - 1,
						difficulty, -1_000_000d, 1_000_000d);
			}
			return score + RANDOM.nextDouble() * (1.0 - difficulty.tacticalBias()) * 2.5;
		} catch (ApiException ignored) {
			return -1_000_000d;
		}
	}

	private double evaluateResult(ChessMoveResult result, String botSide, BotDifficulty difficulty) {
		if (result.checkmate()) {
			return WIN_BONUS;
		}
		double score = 0;
		if (result.check()) {
			score += CHECK_BONUS * difficulty.tacticalBias();
		}
		return score + staticBoardScore(result.fen(), botSide);
	}

	private double searchPositionValue(
			String fen,
			String sideToMove,
			String botSide,
			int depth,
			BotDifficulty difficulty,
			double alpha,
			double beta) {
		List<LegalMoveResponse> moves = chessService.legalMoves(fen);
		if (moves.isEmpty() && depth > 0) {
			Board terminalBoard = loadBoard(fen);
			if (terminalBoard.isMated()) {
				return botSide.equals(sideToMove) ? CHECK_MATE_PENALTY : WIN_BONUS;
			}
			return 0;
		}
		if (moves.isEmpty() || depth <= 0) {
			return staticBoardScore(fen, botSide);
		}
		boolean maximizing = botSide.equals(sideToMove);
		List<ScoredMove> scored = new ArrayList<>(moves.size());
		for (LegalMoveResponse move : moves) {
			double quickScore = quickHeuristic(fen, move, sideToMove, difficulty);
			scored.add(new ScoredMove(move, quickScore));
		}
		scored.sort(Comparator.comparingDouble((ScoredMove m) -> m.score).reversed());
		int branch = searchBranching(difficulty, moves.size());

		if (maximizing) {
			double best = -1_000_000d;
			boolean found = false;
			int maxDepth = Math.min(branch, scored.size());
			for (int i = 0; i < maxDepth; i++) {
				ScoredMove item = scored.get(i);
				try {
					ChessMoveResult child = chessService.applyMove(fen,
							new ChessMove(item.move.from(), item.move.to(), item.move.promotion()), sideToMove);
					double value = minimaxValueFromMove(child, botSide, difficulty, depth);
					best = Math.max(best, value);
					found = true;
					alpha = Math.max(alpha, best);
					if (alpha >= beta) {
						break;
					}
				} catch (ApiException ignored) {
					// ignore
				}
			}
			return found ? best : staticBoardScore(fen, botSide);
		}
		double best = 1_000_000d;
		int maxDepth = Math.min(branch, scored.size());
		for (int i = 0; i < maxDepth; i++) {
			ScoredMove item = scored.get(i);
			try {
				ChessMoveResult child = chessService.applyMove(fen,
						new ChessMove(item.move.from(), item.move.to(), item.move.promotion()), sideToMove);
				double value = minimaxValueFromMove(child, botSide, difficulty, depth);
				best = Math.min(best, value);
				beta = Math.min(beta, best);
				if (beta <= alpha) {
					break;
				}
			} catch (ApiException ignored) {
				// ignore
			}
		}
		return best;
	}

	private double minimaxValueFromMove(ChessMoveResult child, String botSide, BotDifficulty difficulty, int depth) {
		if (child.checkmate()) {
			// The side who just moved is the winner, i.e., opposite of next-to-move side.
			String winner = child.sideToMove().equals("WHITE") ? "BLACK" : "WHITE";
			return botSide.equals(winner) ? WIN_BONUS : CHECK_MATE_PENALTY;
		}
		if (child.draw() || child.stalemate()) {
			return 0;
		}
		if (depth <= 1) {
			return staticBoardScore(child.fen(), botSide);
		}
		return searchPositionValue(child.fen(), child.sideToMove(), botSide, depth - 1, difficulty,
				-1_000_000d, 1_000_000d) * searchDepthWeight(difficulty);
	}

	private MatchResponse maybeUsePowerup(MatchResponse match, PlayerResponse bot) {
		BotDifficulty difficulty = difficulty(bot);
		if (bot.clockMs() < 45_000 && bot.brainPoints() >= PowerupType.CLOCK_BOOST_30.cost()) {
			MatchResponse boosted = safePowerup(match, bot, PowerupType.CLOCK_BOOST_30, null);
			if (boosted != null) {
				return boosted;
			}
		}

		if (shouldUseExtraMove(match, bot, difficulty)) {
			MatchResponse powered = safePowerup(match, bot, PowerupType.EXTRA_MOVE, null);
			if (powered != null) {
				return powered;
			}
		}

		if (shouldUseRevivePawn(match, bot, difficulty)) {
			for (String square : reviveCandidates(bot.side())) {
				MatchResponse revived = safePowerup(match, bot, PowerupType.REVIVE_PAWN, square);
				if (revived != null) {
					return revived;
				}
			}
		}
		return null;
	}

	private boolean shouldUseExtraMove(MatchResponse match, PlayerResponse bot, BotDifficulty difficulty) {
		if (bot.extraMoveArmed() || bot.extraMoveActive()) {
			return false;
		}
		if (bot.brainPoints() < PowerupType.EXTRA_MOVE.cost()) {
			return false;
		}
		if (match.plyCount() < 6) {
			return false;
		}

		double board = staticBoardScore(match.fen(), bot.side());
		double winPressure = Math.max(0d, board / 120d);
		double useProbability = difficulty.tacticalBias() * 0.5 + (0.4 - winPressure);
		if (bot.clockMs() < 90_000) {
			useProbability += 0.10;
		}
		return RANDOM.nextDouble() < Math.max(0.18d, Math.min(0.92d, useProbability));
	}

	private boolean shouldUseRevivePawn(MatchResponse match, PlayerResponse bot, BotDifficulty difficulty) {
		if (bot.revivablePawns() <= 0 || bot.brainPoints() < PowerupType.REVIVE_PAWN.cost()) {
			return false;
		}
		if (difficulty == BotDifficulty.EASY) {
			return RANDOM.nextDouble() < 0.12;
		}
		if (match.plyCount() < 12) {
			return false;
		}
		double boardScore = staticBoardScore(match.fen(), bot.side());
		if (boardScore >= 20) {
			return false;
		}
		return RANDOM.nextDouble() < (difficulty == BotDifficulty.EXPERT ? 0.40 : difficulty == BotDifficulty.HARD ? 0.32 : 0.24);
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
		if (round == null || botAlreadyAnswered(round, bot.side())) {
			return false;
		}
		int totalQuestions = Math.max(0, round.getTotalQuestions());
		if (totalQuestions == 0) {
			return false;
		}
		List<Integer> answers = safeParseAnswers(round.getPuzzleAnswers(), totalQuestions, match.matchId(), match.brainRoundCount());
		if (answers.isEmpty()) {
			answers = syntheticFallbackAnswers(totalQuestions, match.matchId());
		}
		totalQuestions = Math.min(totalQuestions, answers.size());
		if (totalQuestions == 0) {
			return false;
		}
		int targetScore = Math.min(botScore(bot, totalQuestions, match.brainRoundCount()), totalQuestions);
		if (targetScore <= 0) {
			targetScore = 1;
		}
		List<SubmitAnswerBatchRequest.SubmittedAnswer> submitted = new ArrayList<>();
		for (int i = 0; i < totalQuestions; i++) {
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

	private List<Integer> safeParseAnswers(
			String puzzleAnswersJson,
			int expectedCount,
			String matchId,
			int roundNumber) {
		try {
			List<Integer> parsed = parseAnswers(puzzleAnswersJson);
			if (parsed.size() >= expectedCount) {
				return parsed;
			}
			List<Integer> merged = new ArrayList<>(parsed);
			for (int i = merged.size(); i < expectedCount; i++) {
				merged.add(fallbackAnswer(matchId, roundNumber, i));
			}
			return merged;
		} catch (IllegalStateException ex) {
			return syntheticFallbackAnswers(expectedCount, matchId);
		}
	}

	private int fallbackAnswer(String matchId, int roundNumber, int index) {
		int seed = matchId.hashCode() ^ (roundNumber * 37) ^ index;
		return (seed & 0x7) + 1;
	}

	private List<Integer> syntheticFallbackAnswers(int expectedCount, String matchId) {
		List<Integer> answers = new ArrayList<>(expectedCount);
		for (int i = 0; i < expectedCount; i++) {
			answers.add(fallbackAnswer(matchId, i % 3, i));
		}
		return answers;
	}

	private int botScore(PlayerResponse bot, int totalQuestions, int roundNumber) {
		BotDifficulty difficulty = difficulty(bot);
		double target = difficulty.brainMean();
		double noise = RANDOM.nextGaussian() * difficulty.brainSpread();
		target += noise;
		if (roundNumber % 2 == 0) {
			target += 0.03;
		}
		if (roundNumber % 5 == 0) {
			target += 0.02;
		}
		target = clamp(target, 0.0d, 1.0d);
		int minScore = minimumBotScore(totalQuestions, difficulty);
		int score = (int) Math.round(totalQuestions * target);
		if (difficulty == BotDifficulty.EXPERT && score < (int) Math.ceil(totalQuestions * 0.88)) {
			score = (int) Math.ceil(totalQuestions * 0.88);
		}
		return Math.max(minScore, Math.min(totalQuestions, score));
	}

	private int minimumBotScore(int totalQuestions, BotDifficulty difficulty) {
		return switch (difficulty) {
			case EASY -> Math.max(0, totalQuestions == 1 ? 1 : totalQuestions / 4);
			case NORMAL -> Math.max(1, (int) Math.ceil(totalQuestions * 0.32));
			case HARD -> Math.max(2, (int) Math.ceil(totalQuestions * 0.62));
			case EXPERT -> Math.max(4, (int) Math.ceil(totalQuestions * 0.90));
		};
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
		} catch (JacksonException e) {
			throw new IllegalStateException("Failed to parse bot brain-round answers.", e);
		}
	}

	private double quickHeuristic(String fen, LegalMoveResponse move, String side, BotDifficulty difficulty) {
		Board board = loadBoard(fen);
		Square to = Square.valueOf(move.to().toUpperCase());
		Piece captured = board.getPiece(to);
		double score = 0;
		if (captured != Piece.NONE) {
			score += pieceValue(captured) * 1.5;
		}
		if (move.promotion() != null) {
			score += 45;
		}

		double fromFileDistance = Math.abs((move.from().charAt(0) - 'a') - 3.5);
		double toFileDistance = Math.abs((move.to().charAt(0) - 'a') - 3.5);
		double fromRankDistance = Math.abs((move.from().charAt(1) - '1') - 3.5);
		double toRankDistance = Math.abs((move.to().charAt(1) - '1') - 3.5);
		// Prefer moves toward center and forward progress.
		score += (fromFileDistance - toFileDistance);
		score += (fromRankDistance - toRankDistance) * 0.4;
		if ("WHITE".equals(side)) {
			score += (move.to().charAt(1) - move.from().charAt(1)) * 0.12;
		} else {
			score += (move.from().charAt(1) - move.to().charAt(1)) * 0.12;
		}
		return score + randomJitter(difficulty);
	}

	private double tacticalValue(LegalMoveResponse move, String side) {
		if (move == null || move.to() == null || move.to().isEmpty()) {
			return 0;
		}
		int toFile = move.to().charAt(0) - 'a';
		int toRank = move.to().charAt(1) - '1';
		int fromFile = move.from().charAt(0) - 'a';
		int fromRank = move.from().charAt(1) - '1';
		double centerTo = 3.5 - Math.abs(toFile - 3.5) + 3.5 - Math.abs(toRank - 3.5);
		double centerFrom = 3.5 - Math.abs(fromFile - 3.5) + 3.5 - Math.abs(fromRank - 3.5);
		double value = (centerTo - centerFrom) * 2.0;
		if ("WHITE".equals(side)) {
			value += (toRank - fromRank) * 0.7;
		} else {
			value += (fromRank - toRank) * 0.7;
		}
		return value;
	}

	private double staticBoardScore(String fen, String side) {
		Board board = loadBoard(fen);
		Side botSide = Side.valueOf(side);
		double material = materialValue(board, botSide) - materialValue(board, botSide.flip());
		double mobility = sideMobilityBonus(board, botSide) - sideMobilityBonus(board, botSide.flip());
		double safety = kingSafetyScore(board, botSide) - kingSafetyScore(board, botSide.flip()) * 0.6;
		return material + mobility * 0.6 + safety;
	}

	private double positionFeatureBonus(LegalMoveResponse move, ChessMoveResult result, String botSide) {
		Board board = loadBoard(result.fen());
		Side side = Side.valueOf(botSide);
		Side opponent = side.flip();

		double bonus = 0;
		double kingDistance = kingDistanceToCenter(board, opponent);
		bonus += 2.5 * kingDistance;
		Square opponentKing = board.getKingSquare(opponent);
		double kingAttackerPressure = opponentKing != Square.NONE && board.squareAttackedBy(opponentKing, side) != 0 ? 12.0 : 0.0;
		bonus += kingAttackerPressure;

		Square to = Square.valueOf(move.to().toUpperCase());
		Piece captured = board.getPiece(to);
		if (captured != Piece.NONE && pieceColor(captured) != side) {
			bonus += pieceValue(captured) * 0.3;
		}
		return bonus;
	}

	private double kingSafetyScore(Board board, Side side) {
		Square king = board.getKingSquare(side);
		if (king == Square.NONE) {
			return 0;
		}
		if (board.squareAttackedBy(king, side.flip()) != 0) {
			return -80;
		}
		return 0;
	}

	private double sideMobilityBonus(Board board, Side side) {
		Side current = board.getSideToMove();
		board.setSideToMove(side);
		double mobility = board.legalMoves().size();
		board.setSideToMove(current);
		return mobility;
	}

	private double materialValue(Board board, Side side) {
		return pieceValue(Piece.WHITE_PAWN) * pieceCount(board, side == Side.WHITE ? Piece.WHITE_PAWN : Piece.BLACK_PAWN)
				+ pieceValue(Piece.WHITE_KNIGHT) * pieceCount(board, side == Side.WHITE ? Piece.WHITE_KNIGHT : Piece.BLACK_KNIGHT)
				+ pieceValue(Piece.WHITE_BISHOP) * pieceCount(board, side == Side.WHITE ? Piece.WHITE_BISHOP : Piece.BLACK_BISHOP)
				+ pieceValue(Piece.WHITE_ROOK) * pieceCount(board, side == Side.WHITE ? Piece.WHITE_ROOK : Piece.BLACK_ROOK)
				+ pieceValue(Piece.WHITE_QUEEN) * pieceCount(board, side == Side.WHITE ? Piece.WHITE_QUEEN : Piece.BLACK_QUEEN)
				+ pieceValue(Piece.WHITE_KING) * pieceCount(board, side == Side.WHITE ? Piece.WHITE_KING : Piece.BLACK_KING);
	}

	private double pieceValue(Piece piece) {
		return switch (piece) {
			case WHITE_PAWN, BLACK_PAWN -> 100;
			case WHITE_KNIGHT, BLACK_KNIGHT -> 300;
			case WHITE_BISHOP, BLACK_BISHOP -> 320;
			case WHITE_ROOK, BLACK_ROOK -> 500;
			case WHITE_QUEEN, BLACK_QUEEN -> 900;
			case WHITE_KING, BLACK_KING -> 0;
			default -> 0;
		};
	}

	private Side pieceColor(Piece piece) {
		return switch (piece) {
			case WHITE_PAWN, WHITE_KNIGHT, WHITE_BISHOP, WHITE_ROOK, WHITE_QUEEN, WHITE_KING -> Side.WHITE;
			case BLACK_PAWN, BLACK_KNIGHT, BLACK_BISHOP, BLACK_ROOK, BLACK_QUEEN, BLACK_KING -> Side.BLACK;
			default -> Side.WHITE;
		};
	}

	private double kingDistanceToCenter(Board board, Side side) {
		Square king = board.getKingSquare(side);
		if (king == Square.NONE) {
			return 0;
		}
		int file = king.getFile().value();
		int rank = king.getRank().value();
		double centerFile = Math.abs(file - 4);
		double centerRank = Math.abs(rank - 4);
		return centerFile + centerRank;
	}

	private int pieceCount(Board board, Piece piece) {
		return board.getPieceLocation(piece).size();
	}

	private Board loadBoard(String fen) {
		Board board = new Board();
		board.loadFromFen(fen);
		return board;
	}

	private double clamp(double value, double min, double max) {
		if (value < min) {
			return min;
		}
		if (value > max) {
			return max;
		}
		return value;
	}

	private double randomJitter(BotDifficulty difficulty) {
		double noiseRange = switch (difficulty) {
			case EASY -> 0.35;
			case NORMAL -> 0.22;
			case HARD -> 0.12;
			case EXPERT -> 0.01;
		};
		return (RANDOM.nextDouble() * 2.0 - 1.0) * noiseRange;
	}

	private int searchDepth(BotDifficulty difficulty) {
		return switch (difficulty) {
			case EASY -> 1;
			case NORMAL -> 2;
			case HARD -> 3;
			case EXPERT -> 4;
		};
	}

	private int searchBranching(BotDifficulty difficulty, int totalMoves) {
		int max = switch (difficulty) {
			case EASY -> 12;
			case NORMAL -> 11;
			case HARD -> 8;
			case EXPERT -> 10;
		};
		return Math.max(1, Math.min(totalMoves, max));
	}

	private double searchDepthWeight(BotDifficulty difficulty) {
		return switch (difficulty) {
			case EASY -> 0.35;
			case NORMAL -> 0.52;
			case HARD -> 0.78;
			case EXPERT -> 0.95;
		};
	}

	private int moveCandidateWidth(int totalMoves, BotDifficulty difficulty) {
		int max = switch (difficulty) {
			case EASY -> 24;
			case NORMAL -> 16;
			case HARD -> 14;
			case EXPERT -> 16;
		};
		return Math.max(1, Math.min(totalMoves, max));
	}

	private List<String> reviveCandidates(String side) {
		if ("WHITE".equals(side)) {
			return List.of("a3", "b3", "c3", "d3", "e3", "f3", "g3", "h3", "a4", "b4", "c4", "d4", "e4", "f4", "g4", "h4");
		}
		return List.of("a6", "b6", "c6", "d6", "e6", "f6", "g6", "h6", "a5", "b5", "c5", "d5", "e5", "f5", "g5", "h5");
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

	private record ScoredMove(LegalMoveResponse move, double score) {
	}
}
