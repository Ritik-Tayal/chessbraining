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
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class MatchService {

	private static final int DEFAULT_TIME_CONTROL_SECONDS = 300;
	private static final int DEFAULT_BRAIN_ROUND_INTERVAL_MOVES = 5;
	private static final String BRAIN_ROUND_ACTIVE = "ACTIVE";
	private static final String INVITE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
	private static final SecureRandom RANDOM = new SecureRandom();

	private final MatchRepository matchRepository;
	private final MatchMoveRepository moveRepository;
	private final BrainRoundRepository brainRoundRepository;
	private final ChessService chessService;
	private final ClockService clockService;
	private final MathPuzzleService mathPuzzleService;
	private final tools.jackson.databind.ObjectMapper objectMapper;

	public MatchService(
			MatchRepository matchRepository,
			MatchMoveRepository moveRepository,
			BrainRoundRepository brainRoundRepository,
			ChessService chessService,
			ClockService clockService,
			MathPuzzleService mathPuzzleService,
			tools.jackson.databind.ObjectMapper objectMapper) {
		this.matchRepository = matchRepository;
		this.moveRepository = moveRepository;
		this.brainRoundRepository = brainRoundRepository;
		this.chessService = chessService;
		this.clockService = clockService;
		this.mathPuzzleService = mathPuzzleService;
		this.objectMapper = objectMapper;
	}

	@Transactional
	public MatchResponse createMatch(CreateMatchRequest request) {
		MatchEntity match = new MatchEntity();
		match.setInviteCode(generateInviteCode());
		match.setStatus(MatchStatus.WAITING_FOR_OPPONENT);
		match.setPhase(MatchPhase.WAITING_FOR_OPPONENT);
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
	public MatchResponse quickplay(CreateMatchRequest request) {
		return matchRepository.findFirstByStatusOrderByCreatedAtAsc(MatchStatus.WAITING_FOR_OPPONENT)
				.filter(match -> !match.getWhitePlayerId().equals(playerIdOrEmpty(request == null ? null : request.playerId())))
				.map(match -> joinExistingMatch(match, new JoinMatchRequest(match.getInviteCode(),
						request == null ? null : request.playerId(),
						request == null ? null : request.playerName())))
				.orElseGet(() -> createMatch(request));
	}

	@Transactional
	public MatchResponse joinMatch(JoinMatchRequest request) {
		if (request == null || isBlank(request.inviteCode())) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "INVITE_CODE_REQUIRED", "Invite code is required.");
		}
		MatchEntity match = matchRepository.findByInviteCode(request.inviteCode().trim().toUpperCase(Locale.ROOT))
				.orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "MATCH_NOT_FOUND", "Match not found."));
		return joinExistingMatch(match, request);
	}

	@Transactional
	public MatchResponse getMatch(String matchId) {
		MatchEntity match = loadMatch(matchId);
		if (match.getStatus() == MatchStatus.ACTIVE && match.getPhase() == MatchPhase.CHESS_PHASE) {
			String timedOutWinner = clockService.checkTimeout(match);
			if (timedOutWinner != null) {
				completeMatch(match, timedOutWinner, "TIMEOUT");
				matchRepository.save(match);
			}
		}
		return toResponse(match, moveRepository.findByMatchIdOrderByPlyNumberAsc(match.getId()));
	}

	@Transactional(readOnly = true)
	public List<LegalMoveResponse> legalMoves(String matchId, String playerId) {
		MatchEntity match = loadMatch(matchId);
		requireActiveChessPhase(match);
		requirePlayerTurn(match, playerId);
		return chessService.legalMoves(match.getFen());
	}

	@Transactional
	public MatchResponse submitMove(String matchId, SubmitMoveRequest request) {
		if (request == null) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "MOVE_REQUIRED", "Move request is required.");
		}

		MatchEntity match = loadMatch(matchId);
		requireActiveChessPhase(match);
		String side = requirePlayerTurn(match, request.playerId());
		String fenBefore = match.getFen();

		ChessMoveResult result = chessService.applyMove(fenBefore,
				new ChessMove(request.from(), request.to(), request.promotion()),
				side);

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
			completeMatch(match, request.playerId(), "CHECKMATE");
		}
		else if (result.stalemate()) {
			completeMatch(match, null, "STALEMATE");
		}
		else if (result.draw()) {
			completeMatch(match, null, "DRAW");
		}
		else {
			String timedOutWinner = clockService.tickAfterMove(match);
			if (timedOutWinner != null) {
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
		MatchEntity match = loadMatch(matchId);
		requirePlayerInMatch(match, playerId);
		if (match.getStatus() == MatchStatus.COMPLETED) {
			return toResponse(match, moveRepository.findByMatchIdOrderByPlyNumberAsc(match.getId()));
		}

		String winner = playerId.equals(match.getWhitePlayerId()) ? match.getBlackPlayerId() : match.getWhitePlayerId();
		completeMatch(match, winner, "RESIGNATION");
		MatchEntity saved = matchRepository.save(match);
		return toResponse(saved, moveRepository.findByMatchIdOrderByPlyNumberAsc(saved.getId()));
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

	private void startBrainRound(MatchEntity match) {
		match.setPhase(MatchPhase.BRAIN_ROUND);
		match.setBrainRoundCount(match.getBrainRoundCount() + 1);

		MathPuzzleService.PuzzleSet puzzleSet = mathPuzzleService.generatePuzzles();

		BrainRoundEntity round = new BrainRoundEntity();
		round.setMatchId(match.getId());
		round.setRoundNumber(match.getBrainRoundCount());
		round.setStatus(BRAIN_ROUND_ACTIVE);
		try {
			round.setPuzzleExpressions(objectMapper.writeValueAsString(puzzleSet.expressions()));
			round.setPuzzleAnswers(objectMapper.writeValueAsString(puzzleSet.answers()));
		} catch (tools.jackson.core.JacksonException e) {
			throw new org.springframework.web.server.ResponseStatusException(
					org.springframework.http.HttpStatus.INTERNAL_SERVER_ERROR, "Failed to serialize puzzles");
		}
		round.setTotalQuestions(puzzleSet.expressions().size());
		round.setWhiteCorrectCount(0);
		round.setBlackCorrectCount(0);
		brainRoundRepository.save(round);
	}

	private void completeMatch(MatchEntity match, String winnerPlayerId, String reason) {
		match.setStatus(MatchStatus.COMPLETED);
		match.setPhase(MatchPhase.COMPLETED);
		match.setWinnerPlayerId(winnerPlayerId);
		match.setResultReason(reason);
		match.setCompletedAt(Instant.now());
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
				new PlayerResponse(match.getWhitePlayerId(), match.getWhitePlayerName(), "WHITE",
						match.getWhiteBrainPoints(), match.getWhiteClockMs()),
				match.getBlackPlayerId() == null ? null :
						new PlayerResponse(match.getBlackPlayerId(), match.getBlackPlayerName(), "BLACK",
								match.getBlackBrainPoints(), match.getBlackClockMs()),
				match.getWinnerPlayerId(),
				match.getResultReason(),
				moves.stream().map(this::toMoveResponse).toList(),
				match.getClockDeadlineAt(),
				match.getCreatedAt(),
				match.getUpdatedAt());
	}

	private MoveResponse toMoveResponse(MatchMoveEntity move) {
		return new MoveResponse(
				move.getPlyNumber(),
				move.getPlayerId(),
				move.getSide(),
				move.getFromSquare(),
				move.getToSquare(),
				move.getPromotion(),
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

	private String playerIdOrNew(String playerId) {
		if (!isBlank(playerId)) {
			return playerId.trim();
		}
		return "player_" + UUID.randomUUID();
	}

	private String playerIdOrEmpty(String playerId) {
		return isBlank(playerId) ? "" : playerId.trim();
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
