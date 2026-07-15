package com.chessbraining.api.match;

import java.time.Instant;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import com.chessbraining.api.common.ApiException;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.ObjectMapper;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class BrainRoundService {

	private static final String BRAIN_ROUND_ACTIVE = "ACTIVE";
	private static final String BRAIN_ROUND_COMPLETED = "COMPLETED";
	private static final int WINNER_BRAIN_POINTS = 2;
	private static final int TIE_BRAIN_POINTS = 1;

	private final BrainRoundRepository brainRoundRepository;
	private final MatchRepository matchRepository;
	private final MathPuzzleService mathPuzzleService;
	private final DotConnectPuzzleService dotConnectPuzzleService;
	private final MemoryPuzzleService memoryPuzzleService;
	private final ClockService clockService;
	private final ObjectMapper objectMapper;

	public BrainRoundService(
			BrainRoundRepository brainRoundRepository,
			MatchRepository matchRepository,
			MathPuzzleService mathPuzzleService,
			DotConnectPuzzleService dotConnectPuzzleService,
			MemoryPuzzleService memoryPuzzleService,
			ClockService clockService,
			ObjectMapper objectMapper) {
		this.brainRoundRepository = brainRoundRepository;
		this.matchRepository = matchRepository;
		this.mathPuzzleService = mathPuzzleService;
		this.dotConnectPuzzleService = dotConnectPuzzleService;
		this.memoryPuzzleService = memoryPuzzleService;
		this.clockService = clockService;
		this.objectMapper = objectMapper;
	}

	@Transactional
	public BrainRoundResponse getCurrentRound(String matchId) {
		BrainRoundEntity round = loadActiveRound(matchId);
		MatchEntity match = loadMatchForUpdate(matchId);
		requireActiveBrainRoundMatch(match);
		if (isExpired(round)) {
			return completeActiveRound(round, match);
		}
		List<String> puzzles = parseExpressions(round.getPuzzleExpressions());
		return toResponse(round, puzzles);
	}

	@Transactional(readOnly = true)
	public BrainRoundResponse getLatestResult(String matchId) {
		BrainRoundEntity round = brainRoundRepository
				.findFirstByMatchIdAndStatusOrderByRoundNumberDesc(matchId, BRAIN_ROUND_COMPLETED)
				.orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "BRAIN_ROUND_RESULT_NOT_FOUND",
						"No completed brain round found."));
		List<String> puzzles = parseExpressions(round.getPuzzleExpressions());
		return toResponse(round, puzzles);
	}

	@Transactional
	public AnswerResultResponse submitAnswer(String matchId, SubmitAnswerRequest request) {
		if (request == null) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "ANSWER_REQUIRED", "Answer request is required.");
		}

		BrainRoundEntity round = loadActiveRound(matchId);
		MatchEntity match = loadMatchForUpdate(matchId);
		requireActiveBrainRoundMatch(match);
		requirePuzzleType(round, BrainRoundPuzzleType.MENTAL_MATH, "NOT_MENTAL_MATH_ROUND",
				"This brain round is not a mental math puzzle.");
		List<Integer> answers = parseAnswers(round.getPuzzleAnswers());
		String side = requirePlayerInMatch(match, request.playerId());
		boolean isWhite = side.equals("WHITE");
		if (isExpired(round)) {
			completeActiveRound(round, match);
			int playerCorrectCount = isWhite ? round.getWhiteCorrectCount() : round.getBlackCorrectCount();
			return new AnswerResultResponse(false, playerCorrectCount, round.getTotalQuestions());
		}

		if (request.questionIndex() < 0 || request.questionIndex() >= answers.size()) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_QUESTION_INDEX",
					"Question index is out of range.");
		}

		boolean correct = mathPuzzleService.validateAnswer(answers, request.questionIndex(), request.answer());

		int questionMask = 1 << request.questionIndex();
		if (isWhite) {
			if ((round.getWhiteAnsweredMask() & questionMask) != 0) {
				throw new ApiException(HttpStatus.CONFLICT, "QUESTION_ALREADY_ANSWERED",
						"This question was already answered by this player.");
			}
			round.setWhiteAnsweredMask(round.getWhiteAnsweredMask() | questionMask);
			if (correct) {
				round.setWhiteCorrectCount(round.getWhiteCorrectCount() + 1);
			}
		} else {
			if ((round.getBlackAnsweredMask() & questionMask) != 0) {
				throw new ApiException(HttpStatus.CONFLICT, "QUESTION_ALREADY_ANSWERED",
						"This question was already answered by this player.");
			}
			round.setBlackAnsweredMask(round.getBlackAnsweredMask() | questionMask);
			if (correct) {
				round.setBlackCorrectCount(round.getBlackCorrectCount() + 1);
			}
		}
		brainRoundRepository.save(round);
		if (bothPlayersAnsweredAll(round)) {
			completeActiveRound(round, match);
		}

		int playerCorrectCount = isWhite ? round.getWhiteCorrectCount() : round.getBlackCorrectCount();
		return new AnswerResultResponse(
				correct,
				playerCorrectCount,
				round.getTotalQuestions());
	}

	@Transactional
	public BrainRoundSubmissionResponse submitAnswerBatch(String matchId, SubmitAnswerBatchRequest request) {
		if (request == null) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "ANSWER_REQUIRED", "Answer submission is required.");
		}

		BrainRoundEntity round = loadActiveRound(matchId);
		MatchEntity match = loadMatchForUpdate(matchId);
		requireActiveBrainRoundMatch(match);
		requirePuzzleType(round, BrainRoundPuzzleType.MENTAL_MATH, "NOT_MENTAL_MATH_ROUND",
				"This brain round is not a mental math puzzle.");
		List<Integer> answers = parseAnswers(round.getPuzzleAnswers());
		String side = requirePlayerInMatch(match, request.playerId());
		boolean isWhite = side.equals("WHITE");
		int allAnsweredMask = allAnsweredMask(round);
		int currentAnsweredMask = isWhite ? round.getWhiteAnsweredMask() : round.getBlackAnsweredMask();

		if (currentAnsweredMask != 0) {
			boolean roundCompleted = false;
			if (isExpired(round)) {
				completeActiveRound(round, match);
				roundCompleted = true;
			}
			return new BrainRoundSubmissionResponse(
					isWhite ? round.getWhiteCorrectCount() : round.getBlackCorrectCount(),
					Integer.bitCount(currentAnsweredMask & allAnsweredMask),
					round.getTotalQuestions(),
					roundCompleted);
		}

		List<SubmitAnswerBatchRequest.SubmittedAnswer> submittedAnswers = request.answers();
		if (submittedAnswers == null) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "ANSWERS_REQUIRED", "Answers are required.");
		}
		if (submittedAnswers.size() > round.getTotalQuestions()) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "TOO_MANY_ANSWERS",
					"Answer submission has more answers than the current brain round.");
		}

		int answeredMask = 0;
		int correctCount = 0;
		Set<Integer> submittedQuestionIndexes = new HashSet<>();
		for (SubmitAnswerBatchRequest.SubmittedAnswer submittedAnswer : submittedAnswers) {
			if (submittedAnswer == null) {
				throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_ANSWER", "Answer entry is required.");
			}
			int questionIndex = submittedAnswer.questionIndex();
			if (questionIndex < 0 || questionIndex >= answers.size()) {
				throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_QUESTION_INDEX",
						"Question index is out of range.");
			}
			if (!submittedQuestionIndexes.add(questionIndex)) {
				throw new ApiException(HttpStatus.BAD_REQUEST, "DUPLICATE_QUESTION_INDEX",
						"Question index appears more than once in the submission.");
			}

			answeredMask |= 1 << questionIndex;
			if (mathPuzzleService.validateAnswer(answers, questionIndex, submittedAnswer.answer())) {
				correctCount++;
			}
		}

		if (isWhite) {
			round.setWhiteAnsweredMask(allAnsweredMask);
			round.setWhiteCorrectCount(correctCount);
		} else {
			round.setBlackAnsweredMask(allAnsweredMask);
			round.setBlackCorrectCount(correctCount);
		}

		boolean shouldCompleteRound = bothPlayersAnsweredAll(round) || isExpired(round);
		if (shouldCompleteRound) {
			completeActiveRound(round, match);
		} else {
			brainRoundRepository.save(round);
		}

		return new BrainRoundSubmissionResponse(
				correctCount,
				Integer.bitCount(answeredMask & allAnsweredMask),
				round.getTotalQuestions(),
				shouldCompleteRound);
	}

	@Transactional
	public BrainRoundResponse completeRound(String matchId) {
		BrainRoundEntity round = loadActiveRound(matchId);
		MatchEntity match = loadMatchForUpdate(matchId);
		requireActiveBrainRoundMatch(match);
		if (!isExpired(round) && !isRoundFullySolved(round)) {
			throw new ApiException(HttpStatus.CONFLICT, "BRAIN_ROUND_STILL_ACTIVE",
					"Brain round can only complete after the deadline or after both players answer all questions.");
		}

		return completeActiveRound(round, match);
	}

	@Transactional
	public AnswerResultResponse submitPath(String matchId, SubmitPathRequest request) {
		if (request == null) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "PATH_REQUIRED", "Path request is required.");
		}

		BrainRoundEntity round = loadActiveRound(matchId);
		MatchEntity match = loadMatchForUpdate(matchId);
		requireActiveBrainRoundMatch(match);
		String side = requirePlayerInMatch(match, request.playerId());
		boolean isWhite = side.equals("WHITE");

		if (isExpired(round)) {
			completeActiveRound(round, match);
			int playerCorrectCount = isWhite ? round.getWhiteCorrectCount() : round.getBlackCorrectCount();
			return new AnswerResultResponse(false, playerCorrectCount, round.getTotalQuestions());
		}

		requirePuzzleType(round, BrainRoundPuzzleType.DOT_CONNECT, "NOT_DOT_CONNECT_ROUND",
				"This brain round is not a dot-connect puzzle.");

		List<String> puzzles = parseExpressions(round.getPuzzleExpressions());
		if (request.puzzleIndex() < 0 || request.puzzleIndex() >= puzzles.size()) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_PUZZLE_INDEX",
					"Puzzle index is out of range.");
		}

		int questionMask = 1 << request.puzzleIndex();
		if (isWhite) {
			if ((round.getWhiteAnsweredMask() & questionMask) != 0) {
				throw new ApiException(HttpStatus.CONFLICT, "PUZZLE_ALREADY_ANSWERED",
						"This puzzle was already answered by this player.");
			}
		} else {
			if ((round.getBlackAnsweredMask() & questionMask) != 0) {
				throw new ApiException(HttpStatus.CONFLICT, "PUZZLE_ALREADY_ANSWERED",
						"This puzzle was already answered by this player.");
			}
		}

		String puzzleJson = puzzles.get(request.puzzleIndex());
		boolean correct = dotConnectPuzzleService.validatePath(puzzleJson, request.path());

		if (isWhite) {
			round.setWhiteAnsweredMask(round.getWhiteAnsweredMask() | questionMask);
			if (correct) {
				round.setWhiteCorrectCount(round.getWhiteCorrectCount() + 1);
			}
		} else {
			round.setBlackAnsweredMask(round.getBlackAnsweredMask() | questionMask);
			if (correct) {
				round.setBlackCorrectCount(round.getBlackCorrectCount() + 1);
			}
		}
		brainRoundRepository.save(round);

		if (bothPlayersAnsweredAll(round)) {
			completeActiveRound(round, match);
		}

		int playerCorrectCount = isWhite ? round.getWhiteCorrectCount() : round.getBlackCorrectCount();
		return new AnswerResultResponse(
				correct,
				playerCorrectCount,
				round.getTotalQuestions());
	}

	@Transactional
	public BrainRoundResponse submitMemoryTurn(String matchId, SubmitMemoryTurnRequest request) {
		if (request == null) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "MEMORY_TURN_REQUIRED", "Memory turn request is required.");
		}

		BrainRoundEntity round = loadActiveRound(matchId);
		MatchEntity match = loadMatchForUpdate(matchId);
		requireActiveBrainRoundMatch(match);
		String side = requirePlayerInMatch(match, request.playerId());

		if (isExpired(round)) {
			return completeActiveRound(round, match);
		}

		requirePuzzleType(round, BrainRoundPuzzleType.MEMORY, "NOT_MEMORY_ROUND",
				"This brain round is not a memory puzzle.");

		MemoryPuzzleService.MemoryState state = parseMemoryState(round.getPuzzleAnswers());
		MemoryPuzzleService.TurnResult result = memoryPuzzleService.playTurn(
				state,
				side,
				request.firstIndex(),
				request.secondIndex());
		if (result.matched()) {
			if ("WHITE".equals(side)) {
				round.setWhiteCorrectCount(round.getWhiteCorrectCount() + 1);
			} else {
				round.setBlackCorrectCount(round.getBlackCorrectCount() + 1);
			}
		}

		round.setPuzzleAnswers(writeMemoryState(result.state()));
		round.setPuzzleExpressions(writePublicMemoryBoard(result.state()));
		if (result.completed()) {
			return completeActiveRound(round, match);
		}
		brainRoundRepository.save(round);
		return toResponse(round, parseExpressions(round.getPuzzleExpressions()));
	}

	private BrainRoundResponse completeActiveRound(BrainRoundEntity round, MatchEntity match) {
		int whiteScore = round.getWhiteCorrectCount();
		int blackScore = round.getBlackCorrectCount();

		round.setWhiteScore(whiteScore);
		round.setBlackScore(blackScore);

		if (whiteScore > blackScore) {
			round.setWinnerPlayerId(match.getWhitePlayerId());
			match.setWhiteBrainPoints(match.getWhiteBrainPoints() + WINNER_BRAIN_POINTS);
		} else if (blackScore > whiteScore) {
			round.setWinnerPlayerId(match.getBlackPlayerId());
			match.setBlackBrainPoints(match.getBlackBrainPoints() + WINNER_BRAIN_POINTS);
		} else {
			round.setWinnerPlayerId(null);
			match.setWhiteBrainPoints(match.getWhiteBrainPoints() + TIE_BRAIN_POINTS);
			match.setBlackBrainPoints(match.getBlackBrainPoints() + TIE_BRAIN_POINTS);
		}

		round.setStatus(BRAIN_ROUND_COMPLETED);
		round.setCompletedAt(Instant.now());
		brainRoundRepository.save(round);

		match.setPhase(MatchPhase.CHESS_PHASE);
		clockService.resumeAfterBrainRound(match);
		matchRepository.save(match);

		List<String> puzzles = parseExpressions(round.getPuzzleExpressions());
		return toResponse(round, puzzles);
	}

	private BrainRoundEntity loadActiveRound(String matchId) {
		return brainRoundRepository
				.findFirstByMatchIdAndStatusOrderByRoundNumberDesc(matchId, BRAIN_ROUND_ACTIVE)
				.orElseThrow(() -> new ApiException(HttpStatus.CONFLICT, "BRAIN_ROUND_NOT_FOUND",
						"No active brain round found."));
	}

	private MatchEntity loadMatchForUpdate(String matchId) {
		return matchRepository.findByIdForUpdate(matchId)
				.orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "MATCH_NOT_FOUND", "Match not found."));
	}

	private void requireActiveBrainRoundMatch(MatchEntity match) {
		if (match.getStatus() != MatchStatus.ACTIVE || match.getPhase() != MatchPhase.BRAIN_ROUND) {
			throw new ApiException(HttpStatus.CONFLICT, "NOT_IN_BRAIN_ROUND", "Match is not in a brain round.");
		}
	}

	private void requirePuzzleType(
			BrainRoundEntity round,
			BrainRoundPuzzleType expectedType,
			String errorCode,
			String message) {
		if (!expectedType.name().equals(round.getPuzzleType())) {
			throw new ApiException(HttpStatus.BAD_REQUEST, errorCode, message);
		}
	}

	private String requirePlayerInMatch(MatchEntity match, String playerId) {
		if (playerId != null && playerId.equals(match.getWhitePlayerId())) {
			return "WHITE";
		}
		if (playerId != null && playerId.equals(match.getBlackPlayerId())) {
			return "BLACK";
		}
		throw new ApiException(HttpStatus.FORBIDDEN, "PLAYER_NOT_IN_MATCH", "Player is not part of this match.");
	}

	private boolean isExpired(BrainRoundEntity round) {
		return round.getExpiresAt() != null && !Instant.now().isBefore(round.getExpiresAt());
	}

	private boolean bothPlayersAnsweredAll(BrainRoundEntity round) {
		int allAnsweredMask = allAnsweredMask(round);
		return (round.getWhiteAnsweredMask() & allAnsweredMask) == allAnsweredMask &&
				(round.getBlackAnsweredMask() & allAnsweredMask) == allAnsweredMask;
	}

	private boolean isRoundFullySolved(BrainRoundEntity round) {
		if (BrainRoundPuzzleType.MEMORY.name().equals(round.getPuzzleType())) {
			return memoryPuzzleService.allMatched(parseMemoryState(round.getPuzzleAnswers()));
		}
		return bothPlayersAnsweredAll(round);
	}

	private int allAnsweredMask(BrainRoundEntity round) {
		return (1 << round.getTotalQuestions()) - 1;
	}

	private List<String> parseExpressions(String json) {
		try {
			return Arrays.asList(objectMapper.readValue(json, String[].class));
		} catch (JacksonException e) {
			throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "PUZZLE_PARSE_ERROR",
					"Failed to parse puzzle data.");
		}
	}

	private List<Integer> parseAnswers(String json) {
		try {
			return Arrays.asList(objectMapper.readValue(json, Integer[].class));
		} catch (JacksonException e) {
			throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "ANSWER_PARSE_ERROR",
					"Failed to parse answer data.");
		}
	}

	private MemoryPuzzleService.MemoryState parseMemoryState(String json) {
		try {
			return objectMapper.readValue(json, MemoryPuzzleService.MemoryState.class);
		} catch (JacksonException e) {
			throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "MEMORY_STATE_PARSE_ERROR",
					"Failed to parse memory board data.");
		}
	}

	private String writeMemoryState(MemoryPuzzleService.MemoryState state) {
		try {
			return objectMapper.writeValueAsString(state);
		} catch (JacksonException e) {
			throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "MEMORY_STATE_WRITE_ERROR",
					"Failed to save memory board data.");
		}
	}

	private String writePublicMemoryBoard(MemoryPuzzleService.MemoryState state) {
		try {
			return objectMapper.writeValueAsString(new String[] { memoryPuzzleService.publicBoardJson(state) });
		} catch (JacksonException e) {
			throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "MEMORY_BOARD_WRITE_ERROR",
					"Failed to save memory board view.");
		}
	}

	private BrainRoundResponse toResponse(BrainRoundEntity round, List<String> puzzles) {
		return new BrainRoundResponse(
				round.getId(),
				round.getRoundNumber(),
				round.getStatus(),
				round.getPuzzleType(),
				puzzles,
				round.getTotalQuestions(),
				round.getWhiteCorrectCount(),
				round.getBlackCorrectCount(),
				nextUnansweredIndex(round.getWhiteAnsweredMask(), round.getTotalQuestions()),
				nextUnansweredIndex(round.getBlackAnsweredMask(), round.getTotalQuestions()),
				round.getWinnerPlayerId(),
				round.getStartedAt(),
				round.getExpiresAt(),
				round.getCompletedAt());
	}

	private int nextUnansweredIndex(int answeredMask, int totalQuestions) {
		for (int i = 0; i < totalQuestions; i++) {
			if ((answeredMask & (1 << i)) == 0) {
				return i;
			}
		}
		return totalQuestions;
	}
}
