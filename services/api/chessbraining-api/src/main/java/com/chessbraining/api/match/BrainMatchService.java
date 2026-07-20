package com.chessbraining.api.match;

import java.security.SecureRandom;
import java.time.Instant;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

import com.chessbraining.api.common.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.ObjectMapper;

@Service
public class BrainMatchService {

	private static final String WAITING = "WAITING_FOR_OPPONENT";
	private static final String ACTIVE = "ACTIVE";
	private static final String COMPLETED = "COMPLETED";
	private static final int DEFAULT_SECONDS = 30;
	private static final int MEMORY_SECONDS = 120;
	private static final int DOT_CONNECT_PUZZLE_COUNT = 5;
	private static final String INVITE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
	private static final SecureRandom RANDOM = new SecureRandom();

	private final BrainMatchRepository repository;
	private final MathPuzzleService mathPuzzleService;
	private final DotConnectPuzzleService dotConnectPuzzleService;
	private final MemoryPuzzleService memoryPuzzleService;
	private final ObjectMapper objectMapper;

	public BrainMatchService(
			BrainMatchRepository repository,
			MathPuzzleService mathPuzzleService,
			DotConnectPuzzleService dotConnectPuzzleService,
			MemoryPuzzleService memoryPuzzleService,
			ObjectMapper objectMapper) {
		this.repository = repository;
		this.mathPuzzleService = mathPuzzleService;
		this.dotConnectPuzzleService = dotConnectPuzzleService;
		this.memoryPuzzleService = memoryPuzzleService;
		this.objectMapper = objectMapper;
	}

	@Transactional
	public BrainMatchResponse create(CreateBrainMatchRequest request) {
		BrainMatchEntity match = new BrainMatchEntity();
		match.setInviteCode(generateInviteCode());
		match.setStatus(WAITING);
		match.setMode(request == null || request.mode() == null ? BrainMatchMode.RANDOM : request.mode());
		match.setPuzzleType(resolvePuzzleType(match.getMode()).name());
		match.setWhitePlayerId(playerIdOrNew(request == null ? null : request.playerId()));
		match.setWhitePlayerName(playerNameOrDefault(request == null ? null : request.playerName(), "Player"));
		match.setPuzzleExpressions("[]");
		match.setPuzzleAnswers("[]");
		match.setTotalQuestions(0);
		return toResponse(repository.save(match));
	}

	@Transactional
	public BrainMatchResponse join(JoinBrainMatchRequest request) {
		if (request == null || request.inviteCode() == null || request.inviteCode().isBlank()) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "INVITE_CODE_REQUIRED", "Friend code is required.");
		}
		BrainMatchEntity match = repository.findByInviteCodeForUpdate(request.inviteCode().trim().toUpperCase(Locale.ROOT))
				.orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "BRAIN_MATCH_NOT_FOUND", "Brain match not found."));
		if (COMPLETED.equals(match.getStatus())) {
			throw new ApiException(HttpStatus.CONFLICT, "BRAIN_MATCH_COMPLETED", "This brain match is already complete.");
		}
		String playerId = playerIdOrNew(request.playerId());
		if (playerId.equals(match.getWhitePlayerId())) {
			return toResponse(match);
		}
		if (match.getBlackPlayerId() != null && !playerId.equals(match.getBlackPlayerId())) {
			throw new ApiException(HttpStatus.CONFLICT, "BRAIN_MATCH_FULL", "This brain match already has two players.");
		}
		match.setBlackPlayerId(playerId);
		match.setBlackPlayerName(playerNameOrDefault(request.playerName(), "Opponent"));
		if (!ACTIVE.equals(match.getStatus())) {
			start(match);
		}
		return toResponse(repository.save(match));
	}

	@Transactional(readOnly = true)
	public BrainMatchResponse get(String matchId) {
		return toResponse(repository.findById(matchId)
				.orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "BRAIN_MATCH_NOT_FOUND", "Brain match not found.")));
	}

	@Transactional
	public BrainMatchResponse submitMath(String matchId, SubmitAnswerBatchRequest request) {
		BrainMatchEntity match = loadActive(matchId);
		requirePuzzleType(match, BrainRoundPuzzleType.MENTAL_MATH);
		String side = requirePlayer(match, request == null ? null : request.playerId());
		if (isExpired(match)) {
			return complete(match);
		}
		if (answered(side, match)) {
			return toResponse(match);
		}
		if (request == null || request.answers() == null) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "ANSWERS_REQUIRED", "Answers are required.");
		}
		List<Integer> answers = parseAnswers(match.getPuzzleAnswers());
		int correct = 0;
		for (SubmitAnswerBatchRequest.SubmittedAnswer answer : request.answers()) {
			if (answer == null) continue;
			if (answer.questionIndex() < 0 || answer.questionIndex() >= answers.size()) continue;
			if (mathPuzzleService.validateAnswer(answers, answer.questionIndex(), answer.answer())) {
				correct++;
			}
		}
		setScore(match, side, correct);
		setAnsweredMask(match, side, allMask(match));
		if (bothAnswered(match) || isExpired(match)) {
			return complete(match);
		}
		return toResponse(repository.save(match));
	}

	@Transactional
	public BrainMatchResponse submitPath(String matchId, SubmitPathRequest request) {
		BrainMatchEntity match = loadActive(matchId);
		requirePuzzleType(match, BrainRoundPuzzleType.DOT_CONNECT);
		String side = requirePlayer(match, request == null ? null : request.playerId());
		if (isExpired(match)) {
			return complete(match);
		}
		if (request == null || request.path() == null) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "PATH_REQUIRED", "Dot path is required.");
		}
		if ((answeredMask(match, side) & (1 << request.puzzleIndex())) != 0) {
			return toResponse(match);
		}
		List<String> puzzles = parseExpressions(match.getPuzzleExpressions());
		if (request.puzzleIndex() < 0 || request.puzzleIndex() >= puzzles.size()) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_PUZZLE_INDEX", "Puzzle index is out of range.");
		}
		boolean correct = dotConnectPuzzleService.validatePath(puzzles.get(request.puzzleIndex()), request.path());
		setAnsweredMask(match, side, answeredMask(match, side) | (1 << request.puzzleIndex()));
		if (correct) {
			setScore(match, side, score(match, side) + 1);
		}
		if (bothAnswered(match) || isExpired(match)) {
			return complete(match);
		}
		return toResponse(repository.save(match));
	}

	@Transactional
	public BrainMatchResponse submitMemoryTurn(String matchId, SubmitMemoryTurnRequest request) {
		BrainMatchEntity match = loadActive(matchId);
		requirePuzzleType(match, BrainRoundPuzzleType.MEMORY);
		String side = requirePlayer(match, request == null ? null : request.playerId());
		if (isExpired(match)) {
			return complete(match);
		}
		if (request == null) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "MEMORY_TURN_REQUIRED", "Memory turn is required.");
		}
		MemoryPuzzleService.MemoryState state = parseMemoryState(match.getPuzzleAnswers());
		MemoryPuzzleService.TurnResult result = memoryPuzzleService.playTurn(
				state,
				side,
				request.firstIndex(),
				request.secondIndex());
		if (result.matched()) {
			setScore(match, side, score(match, side) + 1);
		}
		match.setPuzzleAnswers(writeMemoryState(result.state()));
		match.setPuzzleExpressions(writePublicMemoryBoard(result.state()));
		if (result.completed()) {
			return complete(match);
		}
		return toResponse(repository.save(match));
	}

	@Transactional
	public BrainMatchResponse complete(String matchId) {
		return complete(loadActive(matchId));
	}

	@Transactional
	public BrainMatchResponse rematch(String matchId, RematchRequest request) {
		BrainMatchEntity match = repository.findByIdForUpdate(matchId)
				.orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "BRAIN_MATCH_NOT_FOUND", "Brain match not found."));
		String playerId = request == null ? null : request.playerId();
		requirePlayer(match, playerId);
		if (!COMPLETED.equals(match.getStatus())) {
			throw new ApiException(HttpStatus.CONFLICT, "BRAIN_MATCH_NOT_COMPLETE", "Brain match must finish before rematch.");
		}
		if (match.getRematchMatchId() != null) {
			return toResponse(match);
		}
		if (match.getRematchRequestedByPlayerId() == null) {
			match.setRematchRequestedByPlayerId(playerId);
			return toResponse(repository.save(match));
		}
		if (playerId.equals(match.getRematchRequestedByPlayerId())) {
			return toResponse(match);
		}
		BrainMatchEntity rematch = createRematch(match);
		BrainMatchEntity saved = repository.save(rematch);
		match.setRematchMatchId(saved.getId());
		repository.save(match);
		return toResponse(saved);
	}

	private void start(BrainMatchEntity match) {
		match.setStatus(ACTIVE);
		match.setStartedAt(Instant.now());
		BrainRoundPuzzleType type = BrainRoundPuzzleType.valueOf(match.getPuzzleType());
		match.setExpiresAt(match.getStartedAt().plusSeconds(type == BrainRoundPuzzleType.MEMORY ? MEMORY_SECONDS : DEFAULT_SECONDS));
		if (type == BrainRoundPuzzleType.DOT_CONNECT) {
			DotConnectPuzzleService.PuzzleSet set = dotConnectPuzzleService.generatePuzzleSet(DOT_CONNECT_PUZZLE_COUNT);
			writePuzzles(match, set.puzzles(), set.answers());
		} else if (type == BrainRoundPuzzleType.MEMORY) {
			MemoryPuzzleService.MemoryState state = memoryPuzzleService.newGame();
			match.setPuzzleExpressions(writePublicMemoryBoard(state));
			match.setPuzzleAnswers(writeMemoryState(state));
			match.setTotalQuestions(memoryPuzzleService.pairCount());
		} else {
			MathPuzzleService.PuzzleSet set = mathPuzzleService.generatePuzzles();
			writePuzzles(match, set.expressions(), set.answers());
		}
	}

	private BrainMatchResponse complete(BrainMatchEntity match) {
		if (match.getWhiteScore() > match.getBlackScore()) {
			match.setWinnerPlayerId(match.getWhitePlayerId());
		} else if (match.getBlackScore() > match.getWhiteScore()) {
			match.setWinnerPlayerId(match.getBlackPlayerId());
		} else {
			match.setWinnerPlayerId(null);
		}
		match.setStatus(COMPLETED);
		match.setCompletedAt(Instant.now());
		return toResponse(repository.save(match));
	}

	private BrainMatchEntity createRematch(BrainMatchEntity source) {
		BrainMatchEntity rematch = new BrainMatchEntity();
		rematch.setInviteCode(generateInviteCode());
		rematch.setStatus(ACTIVE);
		rematch.setMode(source.getMode());
		rematch.setPuzzleType(resolvePuzzleType(source.getMode()).name());
		rematch.setWhitePlayerId(source.getBlackPlayerId());
		rematch.setWhitePlayerName(source.getBlackPlayerName());
		rematch.setBlackPlayerId(source.getWhitePlayerId());
		rematch.setBlackPlayerName(source.getWhitePlayerName());
		start(rematch);
		return rematch;
	}

	private BrainRoundPuzzleType resolvePuzzleType(BrainMatchMode mode) {
		if (mode == null || mode == BrainMatchMode.RANDOM) {
			BrainRoundPuzzleType[] values = BrainRoundPuzzleType.values();
			return values[RANDOM.nextInt(values.length)];
		}
		return BrainRoundPuzzleType.valueOf(mode.name());
	}

	private BrainMatchEntity loadActive(String matchId) {
		BrainMatchEntity match = repository.findByIdForUpdate(matchId)
				.orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "BRAIN_MATCH_NOT_FOUND", "Brain match not found."));
		if (!ACTIVE.equals(match.getStatus())) {
			throw new ApiException(HttpStatus.CONFLICT, "BRAIN_MATCH_NOT_ACTIVE", "Brain match is not active.");
		}
		return match;
	}

	private void requirePuzzleType(BrainMatchEntity match, BrainRoundPuzzleType expected) {
		if (!expected.name().equals(match.getPuzzleType())) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "WRONG_BRAIN_MATCH_MODE", "This request does not match the brain game type.");
		}
	}

	private String requirePlayer(BrainMatchEntity match, String playerId) {
		if (playerId != null && playerId.equals(match.getWhitePlayerId())) return "WHITE";
		if (playerId != null && playerId.equals(match.getBlackPlayerId())) return "BLACK";
		throw new ApiException(HttpStatus.FORBIDDEN, "PLAYER_NOT_IN_BRAIN_MATCH", "Player is not part of this brain match.");
	}

	private boolean isExpired(BrainMatchEntity match) {
		return match.getExpiresAt() != null && !Instant.now().isBefore(match.getExpiresAt());
	}

	private int allMask(BrainMatchEntity match) {
		return (1 << match.getTotalQuestions()) - 1;
	}

	private boolean bothAnswered(BrainMatchEntity match) {
		int all = allMask(match);
		return (match.getWhiteAnsweredMask() & all) == all && (match.getBlackAnsweredMask() & all) == all;
	}

	private boolean answered(String side, BrainMatchEntity match) {
		return (answeredMask(match, side) & allMask(match)) == allMask(match);
	}

	private int answeredMask(BrainMatchEntity match, String side) {
		return "WHITE".equals(side) ? match.getWhiteAnsweredMask() : match.getBlackAnsweredMask();
	}

	private void setAnsweredMask(BrainMatchEntity match, String side, int value) {
		if ("WHITE".equals(side)) match.setWhiteAnsweredMask(value); else match.setBlackAnsweredMask(value);
	}

	private int score(BrainMatchEntity match, String side) {
		return "WHITE".equals(side) ? match.getWhiteScore() : match.getBlackScore();
	}

	private void setScore(BrainMatchEntity match, String side, int value) {
		if ("WHITE".equals(side)) match.setWhiteScore(value); else match.setBlackScore(value);
	}

	private void writePuzzles(BrainMatchEntity match, List<String> expressions, List<Integer> answers) {
		try {
			match.setPuzzleExpressions(objectMapper.writeValueAsString(expressions.toArray(String[]::new)));
			match.setPuzzleAnswers(objectMapper.writeValueAsString(answers.toArray(Integer[]::new)));
			match.setTotalQuestions(expressions.size());
		} catch (JacksonException e) {
			throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "BRAIN_MATCH_SERIALIZE_ERROR", "Failed to create brain match puzzles.");
		}
	}

	private List<String> parseExpressions(String json) {
		try {
			return Arrays.asList(objectMapper.readValue(json, String[].class));
		} catch (JacksonException e) {
			return List.of();
		}
	}

	private List<Integer> parseAnswers(String json) {
		try {
			return Arrays.asList(objectMapper.readValue(json, Integer[].class));
		} catch (JacksonException e) {
			return List.of();
		}
	}

	private MemoryPuzzleService.MemoryState parseMemoryState(String json) {
		try {
			return objectMapper.readValue(json, MemoryPuzzleService.MemoryState.class);
		} catch (JacksonException e) {
			throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "MEMORY_STATE_PARSE_ERROR", "Failed to parse memory state.");
		}
	}

	private String writeMemoryState(MemoryPuzzleService.MemoryState state) {
		try {
			return objectMapper.writeValueAsString(state);
		} catch (JacksonException e) {
			throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "MEMORY_STATE_WRITE_ERROR", "Failed to save memory state.");
		}
	}

	private String writePublicMemoryBoard(MemoryPuzzleService.MemoryState state) {
		try {
			return objectMapper.writeValueAsString(new String[] { memoryPuzzleService.publicBoardJson(state) });
		} catch (JacksonException e) {
			throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "MEMORY_BOARD_WRITE_ERROR", "Failed to save memory board.");
		}
	}

	private BrainMatchResponse toResponse(BrainMatchEntity match) {
		return new BrainMatchResponse(
				match.getId(),
				match.getInviteCode(),
				match.getStatus(),
				match.getMode(),
				match.getPuzzleType(),
				new PlayerResponse(match.getWhitePlayerId(), match.getWhitePlayerName(), "WHITE", 0, 0, false, false, 0, false, null),
				match.getBlackPlayerId() == null ? null : new PlayerResponse(match.getBlackPlayerId(), match.getBlackPlayerName(), "BLACK", 0, 0, false, false, 0, false, null),
				match.getWhiteScore(),
				match.getBlackScore(),
				match.getTotalQuestions(),
				parseExpressions(match.getPuzzleExpressions()),
				nextUnanswered(match.getWhiteAnsweredMask(), match.getTotalQuestions()),
				nextUnanswered(match.getBlackAnsweredMask(), match.getTotalQuestions()),
				match.getWinnerPlayerId(),
				match.getRematchRequestedByPlayerId(),
				match.getRematchMatchId(),
				match.getStartedAt(),
				match.getExpiresAt(),
				match.getCompletedAt());
	}

	private int nextUnanswered(int mask, int total) {
		for (int i = 0; i < total; i++) {
			if ((mask & (1 << i)) == 0) return i;
		}
		return total;
	}

	private String generateInviteCode() {
		for (int attempt = 0; attempt < 10; attempt++) {
			StringBuilder builder = new StringBuilder();
			for (int i = 0; i < 6; i++) {
				builder.append(INVITE_ALPHABET.charAt(RANDOM.nextInt(INVITE_ALPHABET.length())));
			}
			String code = builder.toString();
			if (!repository.existsByInviteCode(code)) return code;
		}
		return UUID.randomUUID().toString().substring(0, 6).toUpperCase(Locale.ROOT);
	}

	private String playerIdOrNew(String playerId) {
		return playerId == null || playerId.isBlank() ? "player_" + UUID.randomUUID() : playerId.trim();
	}

	private String playerNameOrDefault(String playerName, String fallback) {
		return playerName == null || playerName.isBlank() ? fallback : playerName.trim();
	}
}
