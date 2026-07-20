package com.chessbraining.api.match;

import java.security.SecureRandom;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

import com.chessbraining.api.chess.ChessMove;
import com.chessbraining.api.chess.ChessMoveResult;
import com.chessbraining.api.chess.ChessService;
import com.chessbraining.api.chess.LegalMoveResponse;
import com.chessbraining.api.common.ApiException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

@Service
public class MatchService {

	private static final int DEFAULT_TIME_CONTROL_SECONDS = 300;
	private static final int DEFAULT_BRAIN_ROUND_INTERVAL_MOVES = 5;
	private static final int DEFAULT_BRAIN_ROUND_SECONDS = 30;
	private static final int MEMORY_BRAIN_ROUND_SECONDS = 120;
	private static final int DOT_CONNECT_PUZZLE_COUNT = 5;
	private static final int QUICKPLAY_WAITING_TTL_SECONDS = 600;
	private static final int WINNER_BRAIN_POINTS = 2;
	private static final int TIE_BRAIN_POINTS = 1;
	private static final String BRAIN_ROUND_ACTIVE = "ACTIVE";
	private static final String BRAIN_ROUND_COMPLETED = "COMPLETED";
	private static final String INVITE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
	private static final SecureRandom RANDOM = new SecureRandom();
	private final Object quickplayLock = new Object();

	private final MatchRepository matchRepository;
	private final MatchMoveRepository moveRepository;
	private final BrainRoundRepository brainRoundRepository;
	private final 	ChessService chessService;
	private static final Logger log = LoggerFactory.getLogger(MatchService.class);
	private final ClockService clockService;
	private final MathPuzzleService mathPuzzleService;
	private final DotConnectPuzzleService dotConnectPuzzleService;
	private final MemoryPuzzleService memoryPuzzleService;
	private final tools.jackson.databind.ObjectMapper objectMapper;
	private final TransactionTemplate transactionTemplate;

	public MatchService(
			MatchRepository matchRepository,
			MatchMoveRepository moveRepository,
			BrainRoundRepository brainRoundRepository,
			ChessService chessService,
			ClockService clockService,
			MathPuzzleService mathPuzzleService,
			DotConnectPuzzleService dotConnectPuzzleService,
			MemoryPuzzleService memoryPuzzleService,
			tools.jackson.databind.ObjectMapper objectMapper,
			TransactionTemplate transactionTemplate) {
		this.matchRepository = matchRepository;
		this.moveRepository = moveRepository;
		this.brainRoundRepository = brainRoundRepository;
		this.chessService = chessService;
		this.clockService = clockService;
		this.mathPuzzleService = mathPuzzleService;
		this.dotConnectPuzzleService = dotConnectPuzzleService;
		this.memoryPuzzleService = memoryPuzzleService;
		this.objectMapper = objectMapper;
		this.transactionTemplate = transactionTemplate;
	}

	@Transactional
	public MatchResponse createMatch(CreateMatchRequest request) {
		return createWaitingMatch(request, MatchmakingMode.PRIVATE);
	}

	@Transactional
	public MatchResponse createBotMatch(CreateBotMatchRequest request) {
		String humanPlayerId = playerIdOrNew(request == null ? null : request.playerId());
		String humanPlayerName = playerNameOrDefault(request == null ? null : request.playerName(), "Player");
		BotDifficulty difficulty = request == null || request.difficulty() == null
				? BotDifficulty.NORMAL
				: request.difficulty();
		String humanSide = normalizePreferredSide(request == null ? null : request.preferredSide());
		boolean humanPlaysWhite = !"BLACK".equals(humanSide);
		String botPlayerId = "bot-" + difficulty.name().toLowerCase(Locale.ROOT) + "-" + UUID.randomUUID();

		MatchEntity match = new MatchEntity();
		match.setInviteCode(generateInviteCode());
		match.setStatus(MatchStatus.ACTIVE);
		match.setPhase(MatchPhase.CHESS_PHASE);
		match.setMatchmakingMode(MatchmakingMode.PRIVATE);
		match.setFen(ChessService.STARTING_FEN);
		match.setSideToMove("WHITE");
		match.setTimeControlSeconds(resolveTimeControlSeconds(request == null ? null : request.timeControlSeconds()));
		match.setWhiteClockMs(match.getTimeControlSeconds() * 1000);
		match.setBlackClockMs(match.getTimeControlSeconds() * 1000);
		match.setBrainRoundIntervalMoves(resolveBrainRoundInterval(request == null ? null : request.brainRoundIntervalMoves()));
		match.setStartedAt(Instant.now());

		if (humanPlaysWhite) {
			match.setWhitePlayerId(humanPlayerId);
			match.setWhitePlayerName(humanPlayerName);
			match.setBlackPlayerId(botPlayerId);
			match.setBlackPlayerName(botName(difficulty));
			match.setBlackBot(true);
			match.setBlackBotDifficulty(difficulty);
		} else {
			match.setWhitePlayerId(botPlayerId);
			match.setWhitePlayerName(botName(difficulty));
			match.setWhiteBot(true);
			match.setWhiteBotDifficulty(difficulty);
			match.setBlackPlayerId(humanPlayerId);
			match.setBlackPlayerName(humanPlayerName);
		}
		clockService.startClocks(match);
		MatchEntity saved = matchRepository.save(match);
		return toResponse(saved, List.of());
	}

	public MatchResponse quickplay(CreateMatchRequest request) {
		synchronized (quickplayLock) {
			return transactionTemplate.execute(status -> quickplayInTransaction(request));
		}
	}

	private MatchResponse quickplayInTransaction(CreateMatchRequest request) {
		String playerId = playerIdOrNew(request == null ? null : request.playerId());
		CreateMatchRequest normalizedRequest = new CreateMatchRequest(
				playerId,
				request == null ? null : request.playerName(),
				request == null ? null : request.timeControlSeconds(),
				request == null ? null : request.brainRoundIntervalMoves());
		Instant activeSince = Instant.now().minusSeconds(QUICKPLAY_WAITING_TTL_SECONDS);

		return matchRepository
				.findFirstByStatusAndMatchmakingModeAndWhitePlayerIdAndCreatedAtAfterOrderByCreatedAtAsc(
						MatchStatus.WAITING_FOR_OPPONENT,
						MatchmakingMode.QUICKPLAY,
						playerId,
						activeSince)
				.map(match -> toResponse(match, List.of()))
				.or(() -> matchRepository
						.findFirstByStatusAndMatchmakingModeAndWhitePlayerIdNotAndCreatedAtAfterOrderByCreatedAtAsc(
								MatchStatus.WAITING_FOR_OPPONENT,
								MatchmakingMode.QUICKPLAY,
								playerId,
								activeSince)
						.map(match -> joinExistingMatch(match, new JoinMatchRequest(match.getInviteCode(),
								playerId,
								normalizedRequest.playerName()))))
				.orElseGet(() -> createWaitingMatch(normalizedRequest, MatchmakingMode.QUICKPLAY));
	}

	private MatchResponse createWaitingMatch(CreateMatchRequest request, MatchmakingMode matchmakingMode) {
		MatchEntity match = new MatchEntity();
		match.setInviteCode(generateInviteCode());
		match.setStatus(MatchStatus.WAITING_FOR_OPPONENT);
		match.setPhase(MatchPhase.WAITING_FOR_OPPONENT);
		match.setMatchmakingMode(matchmakingMode);
		match.setFen(ChessService.STARTING_FEN);
		match.setSideToMove("WHITE");
		match.setWhitePlayerId(playerIdOrNew(request == null ? null : request.playerId()));
		match.setWhitePlayerName(playerNameOrDefault(request == null ? null : request.playerName(), "White Player"));
		match.setTimeControlSeconds(resolveTimeControlSeconds(request == null ? null : request.timeControlSeconds()));
		match.setWhiteClockMs(match.getTimeControlSeconds() * 1000);
		match.setBlackClockMs(match.getTimeControlSeconds() * 1000);
		match.setBrainRoundIntervalMoves(resolveBrainRoundInterval(request == null ? null : request.brainRoundIntervalMoves()));
		return toResponse(matchRepository.save(match), List.of());
	}

	@Transactional
	public MatchResponse joinMatch(JoinMatchRequest request) {
		if (request == null || isBlank(request.inviteCode())) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "INVITE_CODE_REQUIRED", "Invite code is required.");
		}
		MatchEntity match = matchRepository.findByInviteCodeForUpdate(request.inviteCode().trim().toUpperCase(Locale.ROOT))
				.orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "MATCH_NOT_FOUND", "Match not found."));
		return joinExistingMatch(match, request);
	}

	@Transactional
	public MatchResponse getMatch(String matchId) {
		MatchEntity match = loadMatchForUpdate(matchId);
		completeOnTimeoutIfNeeded(match);
		return toResponse(match, moveRepository.findByMatchIdOrderByPlyNumberAsc(match.getId()));
	}

	@Transactional
	public List<LegalMoveResponse> legalMoves(String matchId, String playerId) {
		MatchEntity match = loadMatchForUpdate(matchId);
		if (completeOnTimeoutIfNeeded(match)) {
			throw new ApiException(HttpStatus.CONFLICT, "MATCH_TIMED_OUT", "The active player has timed out.");
		}
		requireActiveChessPhase(match);
		requirePlayerTurn(match, playerId);
		return chessService.legalMoves(match.getFen());
	}

	@Transactional
	public MatchResponse submitMove(String matchId, SubmitMoveRequest request) {
		if (request == null) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "MOVE_REQUIRED", "Move request is required.");
		}

		MatchEntity match = loadMatchForUpdate(matchId);
		if (completeOnTimeoutIfNeeded(match)) {
			return toResponse(match, moveRepository.findByMatchIdOrderByPlyNumberAsc(match.getId()));
		}
		requireActiveChessPhase(match);
		String side = requirePlayerTurn(match, request.playerId());
		String fenBefore = match.getFen();
		boolean extraMoveArmed = isExtraMoveArmed(match, side);
		boolean extraMoveContinuation = isExtraMoveActive(match, side);

		ChessMoveResult result = chessService.applyMove(fenBefore,
				new ChessMove(request.from(), request.to(), request.promotion()),
				side);
		if (extraMoveArmed && result.check()) {
			throw new ApiException(HttpStatus.CONFLICT, "EXTRA_MOVE_CANNOT_GIVE_CHECK",
					"The first extra-move turn cannot give check. Choose a quiet move or use the power later.");
		}
		if (extraMoveArmed && (result.checkmate() || result.stalemate() || result.draw())) {
			throw new ApiException(HttpStatus.CONFLICT, "EXTRA_MOVE_TERMINAL_MOVE",
					"Extra move cannot be opened with a move that ends the game.");
		}

		int nextPly = match.getPlyCount() + 1;
		MatchMoveEntity move = new MatchMoveEntity();
		move.setMatchId(match.getId());
		move.setPlyNumber(nextPly);
		move.setPlayerId(request.playerId());
		move.setSide(side);
		move.setFromSquare(request.from().toLowerCase(Locale.ROOT));
		move.setToSquare(request.to().toLowerCase(Locale.ROOT));
		move.setPromotion(normalizePromotion(request.promotion()));
		move.setFenBefore(fenBefore);
		move.setFenAfter(result.fen());
		moveRepository.save(move);

		match.setFen(result.fen());
		match.setSideToMove(result.sideToMove());
		match.setPlyCount(nextPly);

		if (result.checkmate()) {
			clearExtraMoveState(match, side);
			completeMatch(match, request.playerId(), "CHECKMATE");
		}
		else if (result.stalemate()) {
			clearExtraMoveState(match, side);
			completeMatch(match, null, "STALEMATE");
		}
		else if (result.draw()) {
			clearExtraMoveState(match, side);
			completeMatch(match, null, "DRAW");
		}
		else if (extraMoveArmed) {
			String timedOutWinner = clockService.tickAfterMoveKeepingTurn(match, side);
			if (timedOutWinner != null) {
				clearExtraMoveState(match, side);
				completeMatch(match, timedOutWinner, "TIMEOUT");
			} else {
				match.setFen(chessService.withSideToMove(result.fen(), side));
				match.setSideToMove(side);
				setExtraMoveArmed(match, side, false);
				setExtraMoveActive(match, side, true);
			}
		}
		else {
			if (extraMoveContinuation) {
				setExtraMoveActive(match, side, false);
			}
			String timedOutWinner = clockService.tickAfterMove(match);
			if (timedOutWinner != null) {
				clearExtraMoveState(match, side);
				completeMatch(match, timedOutWinner, "TIMEOUT");
			}
			else if (shouldStartBrainRound(match)) {
				clockService.pauseForBrainRound(match);
				startBrainRound(match);
			}
		}

		MatchEntity saved = matchRepository.save(match);
		return toResponse(saved, moveRepository.findByMatchIdOrderByPlyNumberAsc(saved.getId()));
	}

	@Transactional
	public MatchResponse resign(String matchId, String playerId) {
		MatchEntity match = loadMatchForUpdate(matchId);
		requirePlayerInMatch(match, playerId);
		if (match.getStatus() == MatchStatus.COMPLETED) {
			return toResponse(match, moveRepository.findByMatchIdOrderByPlyNumberAsc(match.getId()));
		}
		if (match.getStatus() != MatchStatus.ACTIVE) {
			throw new ApiException(HttpStatus.CONFLICT, "MATCH_NOT_ACTIVE", "Only active matches can be resigned.");
		}

		String winner = playerId.equals(match.getWhitePlayerId()) ? match.getBlackPlayerId() : match.getWhitePlayerId();
		completeMatch(match, winner, "RESIGNATION");
		MatchEntity saved = matchRepository.save(match);
		return toResponse(saved, moveRepository.findByMatchIdOrderByPlyNumberAsc(saved.getId()));
	}

	@Transactional
	public MatchResponse requestRematch(String matchId, String playerId) {
		MatchEntity match = loadMatchForUpdate(matchId);
		requirePlayerInMatch(match, playerId);
		if (match.getStatus() != MatchStatus.COMPLETED || match.getPhase() != MatchPhase.COMPLETED) {
			throw new ApiException(HttpStatus.CONFLICT, "REMATCH_NOT_AVAILABLE",
					"Rematch can only be requested after a completed match.");
		}
		if (match.getBlackPlayerId() == null) {
			throw new ApiException(HttpStatus.CONFLICT, "REMATCH_REQUIRES_TWO_PLAYERS",
					"Rematch requires both players from the completed match.");
		}
		if (match.getRematchMatchId() != null) {
			return toResponse(match, moveRepository.findByMatchIdOrderByPlyNumberAsc(match.getId()));
		}

		String requester = playerId.trim();
		String currentRequest = match.getRematchRequestedByPlayerId();
		if (currentRequest == null || currentRequest.isBlank()) {
			if (hasBotPlayer(match) && !isBotPlayer(match, requester)) {
				MatchEntity rematch = createRematchMatch(match);
				MatchEntity savedRematch = matchRepository.save(rematch);
				match.setRematchRequestedByPlayerId(requester);
				match.setRematchMatchId(savedRematch.getId());
				MatchEntity saved = matchRepository.save(match);
				return toResponse(saved, moveRepository.findByMatchIdOrderByPlyNumberAsc(saved.getId()));
			}
			match.setRematchRequestedByPlayerId(requester);
			MatchEntity saved = matchRepository.save(match);
			return toResponse(saved, moveRepository.findByMatchIdOrderByPlyNumberAsc(saved.getId()));
		}
		if (currentRequest.equals(requester)) {
			return toResponse(match, moveRepository.findByMatchIdOrderByPlyNumberAsc(match.getId()));
		}

		MatchEntity rematch = createRematchMatch(match);
		MatchEntity savedRematch = matchRepository.save(rematch);
		match.setRematchMatchId(savedRematch.getId());
		MatchEntity saved = matchRepository.save(match);
		return toResponse(saved, moveRepository.findByMatchIdOrderByPlyNumberAsc(saved.getId()));
	}

	private MatchEntity createRematchMatch(MatchEntity previous) {
		MatchEntity match = new MatchEntity();
		match.setInviteCode(generateInviteCode());
		match.setStatus(MatchStatus.ACTIVE);
		match.setPhase(MatchPhase.CHESS_PHASE);
		match.setMatchmakingMode(MatchmakingMode.PRIVATE);
		match.setFen(ChessService.STARTING_FEN);
		match.setSideToMove("WHITE");
		match.setWhitePlayerId(previous.getBlackPlayerId());
		match.setWhitePlayerName(previous.getBlackPlayerName());
		match.setWhiteBot(previous.isBlackBot());
		match.setWhiteBotDifficulty(previous.getBlackBotDifficulty());
		match.setBlackPlayerId(previous.getWhitePlayerId());
		match.setBlackPlayerName(previous.getWhitePlayerName());
		match.setBlackBot(previous.isWhiteBot());
		match.setBlackBotDifficulty(previous.getWhiteBotDifficulty());
		match.setTimeControlSeconds(previous.getTimeControlSeconds());
		match.setWhiteClockMs(match.getTimeControlSeconds() * 1000);
		match.setBlackClockMs(match.getTimeControlSeconds() * 1000);
		match.setBrainRoundIntervalMoves(previous.getBrainRoundIntervalMoves());
		match.setStartedAt(Instant.now());
		clockService.startClocks(match);
		return match;
	}

	private boolean hasBotPlayer(MatchEntity match) {
		return match.isWhiteBot() || match.isBlackBot();
	}

	private boolean isBotPlayer(MatchEntity match, String playerId) {
		return (match.isWhiteBot() && playerId.equals(match.getWhitePlayerId())) ||
				(match.isBlackBot() && playerId.equals(match.getBlackPlayerId()));
	}

	private MatchResponse joinExistingMatch(MatchEntity match, JoinMatchRequest request) {
		if (match.getStatus() != MatchStatus.WAITING_FOR_OPPONENT) {
			throw new ApiException(HttpStatus.CONFLICT, "MATCH_ALREADY_STARTED", "Match already has two players.");
		}

		String blackPlayerId = playerIdOrNew(request == null ? null : request.playerId());
		if (blackPlayerId.equals(match.getWhitePlayerId())) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "CANNOT_JOIN_OWN_MATCH",
					"A player cannot join their own waiting match.");
		}

		match.setBlackPlayerId(blackPlayerId);
		match.setBlackPlayerName(playerNameOrDefault(request == null ? null : request.playerName(), "Black Player"));
		match.setStatus(MatchStatus.ACTIVE);
		match.setPhase(MatchPhase.CHESS_PHASE);
		match.setStartedAt(Instant.now());
		clockService.startClocks(match);
		MatchEntity saved = matchRepository.save(match);
		return toResponse(saved, moveRepository.findByMatchIdOrderByPlyNumberAsc(saved.getId()));
	}

	private MatchEntity loadMatch(String matchId) {
		return matchRepository.findById(matchId)
				.orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "MATCH_NOT_FOUND", "Match not found."));
	}

	private MatchEntity loadMatchForUpdate(String matchId) {
		return matchRepository.findByIdForUpdate(matchId)
				.orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "MATCH_NOT_FOUND", "Match not found."));
	}

	private void requireActiveChessPhase(MatchEntity match) {
		if (match.getStatus() != MatchStatus.ACTIVE || match.getPhase() != MatchPhase.CHESS_PHASE) {
			throw new ApiException(HttpStatus.CONFLICT, "MATCH_NOT_READY_FOR_CHESS",
					"Match is not currently accepting chess moves.");
		}
	}

	private String requirePlayerTurn(MatchEntity match, String playerId) {
		requirePlayerInMatch(match, playerId);
		String expectedPlayerId = "WHITE".equals(match.getSideToMove()) ? match.getWhitePlayerId() : match.getBlackPlayerId();
		if (!expectedPlayerId.equals(playerId)) {
			throw new ApiException(HttpStatus.CONFLICT, "NOT_YOUR_TURN", "It is not this player's turn.");
		}
		return match.getSideToMove();
	}

	private void requirePlayerInMatch(MatchEntity match, String playerId) {
		if (isBlank(playerId) ||
				(!playerId.equals(match.getWhitePlayerId()) && !playerId.equals(match.getBlackPlayerId()))) {
			throw new ApiException(HttpStatus.FORBIDDEN, "PLAYER_NOT_IN_MATCH",
					"Player is not part of this match.");
		}
	}

	private boolean shouldStartBrainRound(MatchEntity match) {
		int intervalPlyCount = match.getBrainRoundIntervalMoves() * 2;
		return intervalPlyCount > 0 && match.getPlyCount() > 0 && match.getPlyCount() % intervalPlyCount == 0;
	}

	boolean nextMoveWouldStartBrainRound(MatchEntity match) {
		int intervalPlyCount = match.getBrainRoundIntervalMoves() * 2;
		int nextPly = match.getPlyCount() + 1;
		return intervalPlyCount > 0 && nextPly > 0 && nextPly % intervalPlyCount == 0;
	}

	void completePowerupTurn(MatchEntity match, String movingSide, String fenAfterPowerup) {
		String nextSide = oppositeSide(movingSide);
		match.setFen(chessService.withSideToMove(fenAfterPowerup, nextSide));
		match.setSideToMove(nextSide);
		match.setPlyCount(match.getPlyCount() + 1);
		clearExtraMoveState(match, movingSide);

		String timedOutWinner = clockService.tickAfterMove(match);
		if (timedOutWinner != null) {
			completeMatch(match, timedOutWinner, "TIMEOUT");
		}
		else if (shouldStartBrainRound(match)) {
			clockService.pauseForBrainRound(match);
			startBrainRound(match);
		}
	}

	private String oppositeSide(String side) {
		return "WHITE".equals(side) ? "BLACK" : "WHITE";
	}

	private boolean isExtraMoveArmed(MatchEntity match, String side) {
		return "WHITE".equals(side) ? match.isWhiteExtraMoveArmed() : match.isBlackExtraMoveArmed();
	}

	private boolean isExtraMoveActive(MatchEntity match, String side) {
		return "WHITE".equals(side) ? match.isWhiteExtraMoveActive() : match.isBlackExtraMoveActive();
	}

	private void setExtraMoveArmed(MatchEntity match, String side, boolean value) {
		if ("WHITE".equals(side)) {
			match.setWhiteExtraMoveArmed(value);
		} else {
			match.setBlackExtraMoveArmed(value);
		}
	}

	private void setExtraMoveActive(MatchEntity match, String side, boolean value) {
		if ("WHITE".equals(side)) {
			match.setWhiteExtraMoveActive(value);
		} else {
			match.setBlackExtraMoveActive(value);
		}
	}

	private void clearExtraMoveState(MatchEntity match, String side) {
		setExtraMoveArmed(match, side, false);
		setExtraMoveActive(match, side, false);
	}

	private void startBrainRound(MatchEntity match) {
		match.setPhase(MatchPhase.BRAIN_ROUND);
		match.setBrainRoundCount(match.getBrainRoundCount() + 1);

		BrainRoundPuzzleType selectedType = BrainRoundPuzzleType.values()[RANDOM.nextInt(BrainRoundPuzzleType.values().length)];
		String puzzleType = selectedType.name();
		Instant now = Instant.now();

		BrainRoundEntity round = new BrainRoundEntity();
		round.setMatchId(match.getId());
		round.setRoundNumber(match.getBrainRoundCount());
		round.setStatus(BRAIN_ROUND_ACTIVE);
		round.setPuzzleType(puzzleType);
		round.setStartedAt(now);
		round.setExpiresAt(now.plusSeconds(selectedType == BrainRoundPuzzleType.MEMORY
				? MEMORY_BRAIN_ROUND_SECONDS
				: DEFAULT_BRAIN_ROUND_SECONDS));
		round.setWhiteCorrectCount(0);
		round.setBlackCorrectCount(0);
		round.setWhiteAnsweredMask(0);
		round.setBlackAnsweredMask(0);

		try {
			if (selectedType == BrainRoundPuzzleType.DOT_CONNECT) {
				DotConnectPuzzleService.PuzzleSet puzzleSet = dotConnectPuzzleService.generatePuzzleSet(DOT_CONNECT_PUZZLE_COUNT);
				round.setPuzzleExpressions(objectMapper.writeValueAsString(puzzleSet.puzzles()));
				round.setPuzzleAnswers(objectMapper.writeValueAsString(puzzleSet.answers()));
				round.setTotalQuestions(puzzleSet.puzzles().size());
			} else if (selectedType == BrainRoundPuzzleType.MEMORY) {
				MemoryPuzzleService.MemoryState state = memoryPuzzleService.newGame();
				round.setPuzzleExpressions(objectMapper.writeValueAsString(new String[] {
						memoryPuzzleService.publicBoardJson(state)
				}));
				round.setPuzzleAnswers(objectMapper.writeValueAsString(state));
				round.setTotalQuestions(memoryPuzzleService.pairCount());
			} else {
				MathPuzzleService.PuzzleSet puzzleSet = mathPuzzleService.generatePuzzles();
				round.setPuzzleExpressions(objectMapper.writeValueAsString(puzzleSet.expressions()));
				round.setPuzzleAnswers(objectMapper.writeValueAsString(puzzleSet.answers()));
				round.setTotalQuestions(puzzleSet.expressions().size());
			}
		} catch (Exception e) {
			// The triggering chess move must never be lost because brain-round
			// puzzle generation/serialization failed. Fall back to mental math so
			// the round still starts and the match continues.
			log.warn("Brain round puzzle setup failed for {}; falling back to MENTAL_MATH", puzzleType, e);
			MathPuzzleService.PuzzleSet fallback = mathPuzzleService.generatePuzzles();
			round.setPuzzleType(BrainRoundPuzzleType.MENTAL_MATH.name());
			try {
				round.setPuzzleExpressions(objectMapper.writeValueAsString(fallback.expressions()));
				round.setPuzzleAnswers(objectMapper.writeValueAsString(fallback.answers()));
			} catch (tools.jackson.core.JacksonException ignored) {
				round.setPuzzleExpressions("[]");
				round.setPuzzleAnswers("[]");
			}
			round.setTotalQuestions(fallback.expressions().size());
		}

		brainRoundRepository.save(round);
	}

	private void completeMatch(MatchEntity match, String winnerPlayerId, String reason) {
		match.setStatus(MatchStatus.COMPLETED);
		match.setPhase(MatchPhase.COMPLETED);
		match.setWinnerPlayerId(winnerPlayerId);
		match.setResultReason(reason);
		match.setCompletedAt(Instant.now());
		match.setClockDeadlineAt(null);
		match.setWhiteExtraMoveArmed(false);
		match.setBlackExtraMoveArmed(false);
		match.setWhiteExtraMoveActive(false);
		match.setBlackExtraMoveActive(false);
	}

	private boolean completeOnTimeoutIfNeeded(MatchEntity match) {
		if (match.getStatus() != MatchStatus.ACTIVE || match.getPhase() != MatchPhase.CHESS_PHASE) {
			return false;
		}
		String timedOutWinner = clockService.checkTimeout(match);
		if (timedOutWinner == null) {
			return false;
		}
		completeMatch(match, timedOutWinner, "TIMEOUT");
		matchRepository.save(match);
		return true;
	}

	private MatchResponse toResponse(MatchEntity match, List<MatchMoveEntity> moves) {
		return new MatchResponse(
				match.getId(),
				match.getInviteCode(),
				match.getStatus(),
				match.getPhase(),
				match.getFen(),
				match.getSideToMove(),
				match.getPlyCount(),
				match.getBrainRoundIntervalMoves(),
				match.getBrainRoundCount(),
				latestBrainRoundResult(match),
				new PlayerResponse(match.getWhitePlayerId(), match.getWhitePlayerName(), "WHITE",
						match.getWhiteBrainPoints(), match.getWhiteClockMs(),
						match.isWhiteExtraMoveArmed(), match.isWhiteExtraMoveActive(),
						chessService.revivablePawnCount(match.getFen(), "WHITE"),
						match.isWhiteBot(), match.getWhiteBotDifficulty()),
				match.getBlackPlayerId() == null ? null :
						new PlayerResponse(match.getBlackPlayerId(), match.getBlackPlayerName(), "BLACK",
								match.getBlackBrainPoints(), match.getBlackClockMs(),
								match.isBlackExtraMoveArmed(), match.isBlackExtraMoveActive(),
								chessService.revivablePawnCount(match.getFen(), "BLACK"),
								match.isBlackBot(), match.getBlackBotDifficulty()),
				match.getWinnerPlayerId(),
				match.getResultReason(),
				match.getRematchRequestedByPlayerId(),
				match.getRematchMatchId(),
				moves.stream().map(this::toMoveResponse).toList(),
				match.getClockDeadlineAt(),
				match.getCreatedAt(),
				match.getUpdatedAt());
	}

	private BrainRoundResultResponse latestBrainRoundResult(MatchEntity match) {
		if (match.getPhase() == MatchPhase.BRAIN_ROUND || match.getBrainRoundCount() == 0) {
			return null;
		}
		return brainRoundRepository
				.findFirstByMatchIdAndStatusOrderByRoundNumberDesc(match.getId(), BRAIN_ROUND_COMPLETED)
				.map(round -> new BrainRoundResultResponse(
						round.getId(),
						round.getRoundNumber(),
						round.getWhiteScore() == null ? round.getWhiteCorrectCount() : round.getWhiteScore(),
						round.getBlackScore() == null ? round.getBlackCorrectCount() : round.getBlackScore(),
						round.getWinnerPlayerId(),
						round.getWinnerPlayerId() == null ? TIE_BRAIN_POINTS : WINNER_BRAIN_POINTS,
						round.getCompletedAt()))
				.orElse(null);
	}

	private MoveResponse toMoveResponse(MatchMoveEntity move) {
		return new MoveResponse(
				move.getPlyNumber(),
				move.getPlayerId(),
				move.getSide(),
				move.getFromSquare(),
				move.getToSquare(),
				move.getPromotion(),
				move.getFenBefore(),
				move.getFenAfter(),
				move.getCreatedAt());
	}

	private String generateInviteCode() {
		for (int attempt = 0; attempt < 10; attempt++) {
			StringBuilder builder = new StringBuilder();
			for (int i = 0; i < 6; i++) {
				builder.append(INVITE_ALPHABET.charAt(RANDOM.nextInt(INVITE_ALPHABET.length())));
			}
			String inviteCode = builder.toString();
			if (!matchRepository.existsByInviteCode(inviteCode)) {
				return inviteCode;
			}
		}
		throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "INVITE_CODE_GENERATION_FAILED",
				"Could not generate a unique invite code.");
	}

	private int resolveTimeControlSeconds(Integer value) {
		if (value == null) {
			return DEFAULT_TIME_CONTROL_SECONDS;
		}
		if (value < 30 || value > 7200) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_TIME_CONTROL",
					"Time control must be between 30 and 7200 seconds.");
		}
		return value;
	}

	private int resolveBrainRoundInterval(Integer value) {
		if (value == null) {
			return DEFAULT_BRAIN_ROUND_INTERVAL_MOVES;
		}
		if (value < 1 || value > 20) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_BRAIN_ROUND_INTERVAL",
					"Brain round interval must be between 1 and 20 moves per player.");
		}
		return value;
	}

	private String normalizePreferredSide(String value) {
		if (value == null || value.isBlank()) {
			return "WHITE";
		}
		String normalized = value.trim().toUpperCase(Locale.ROOT);
		return "BLACK".equals(normalized) ? "BLACK" : "WHITE";
	}

	private String botName(BotDifficulty difficulty) {
		return switch (difficulty) {
			case EASY -> "NeuroBot Easy";
			case NORMAL -> "NeuroBot";
			case HARD -> "NeuroBot Hard";
			case EXPERT -> "NeuroBot Expert";
		};
	}

	private String playerIdOrNew(String playerId) {
		if (!isBlank(playerId)) {
			return playerId.trim();
		}
		return "player_" + UUID.randomUUID();
	}

	private String playerNameOrDefault(String playerName, String fallback) {
		return isBlank(playerName) ? fallback : playerName.trim();
	}

	private String normalizePromotion(String promotion) {
		return isBlank(promotion) ? null : promotion.trim().toLowerCase(Locale.ROOT);
	}

	private boolean isBlank(String value) {
		return value == null || value.isBlank();
	}
}
