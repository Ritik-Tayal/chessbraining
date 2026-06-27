package com.chessbraining.api.match;

import java.time.Instant;
import java.util.Arrays;
import java.util.List;

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
	private final ClockService clockService;
	private final ObjectMapper objectMapper;

	public BrainRoundService(
			BrainRoundRepository brainRoundRepository,
			MatchRepository matchRepository,
			MathPuzzleService mathPuzzleService,
			ClockService clockService,
			ObjectMapper objectMapper) {
		this.brainRoundRepository = brainRoundRepository;
		this.matchRepository = matchRepository;
		this.mathPuzzleService = mathPuzzleService;
		this.clockService = clockService;
		this.objectMapper = objectMapper;
	}

	@Transactional(readOnly = true)
	public BrainRoundResponse getCurrentRound(String matchId) {
		BrainRoundEntity round = loadActiveRound(matchId);
		List<String> puzzles = parseExpressions(round.getPuzzleExpressions());
		return toResponse(round, puzzles);
	}

	@Transactional
	public AnswerResultResponse submitAnswer(String matchId, SubmitAnswerRequest request) {
		if (request == null) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "ANSWER_REQUIRED", "Answer request is required.");
		}

		BrainRoundEntity round = loadActiveRound(matchId);
		MatchEntity match = loadMatch(matchId);
		List<Integer> answers = parseAnswers(round.getPuzzleAnswers());

		if (request.questionIndex() < 0 || request.questionIndex() >= answers.size()) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_QUESTION_INDEX",
					"Question index is out of range.");
		}

		boolean correct = mathPuzzleService.validateAnswer(answers, request.questionIndex(), request.answer());

		boolean isWhite = requirePlayerInMatch(match, request.playerId()).equals("WHITE");
		if (isWhite) {
			if (correct) {
				round.setWhiteCorrectCount(round.getWhiteCorrectCount() + 1);
			}
		} else {
			if (correct) {
				round.setBlackCorrectCount(round.getBlackCorrectCount() + 1);
			}
		}
		brainRoundRepository.save(round);

		int playerCorrectCount = isWhite ? round.getWhiteCorrectCount() : round.getBlackCorrectCount();
		return new AnswerResultResponse(
				correct,
				answers.get(request.questionIndex()),
				playerCorrectCount,
				round.getTotalQuestions());
	}

	@Transactional
	public BrainRoundResponse completeRound(String matchId) {
		BrainRoundEntity round = loadActiveRound(matchId);
		MatchEntity match = loadMatch(matchId);
		if (match.getPhase() != MatchPhase.BRAIN_ROUND) {
			throw new ApiException(HttpStatus.CONFLICT, "NOT_IN_BRAIN_ROUND", "Match is not in a brain round.");
		}

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

	private MatchEntity loadMatch(String matchId) {
		return matchRepository.findById(matchId)
				.orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "MATCH_NOT_FOUND", "Match not found."));
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

	private BrainRoundResponse toResponse(BrainRoundEntity round, List<String> puzzles) {
		return new BrainRoundResponse(
				round.getId(),
				round.getRoundNumber(),
				round.getStatus(),
				puzzles,
				round.getTotalQuestions(),
				round.getWhiteCorrectCount(),
				round.getBlackCorrectCount(),
				round.getWinnerPlayerId(),
				round.getStartedAt(),
				round.getCompletedAt());
	}
}
