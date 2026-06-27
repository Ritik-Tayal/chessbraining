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

	@Transactional
	public AnswerResultResponse submitAnswer(String matchId, SubmitAnswerRequest request) {
		if (request == null) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "ANSWER_REQUIRED", "Answer request is required.");
		}

		BrainRoundEntity round = loadActiveRound(matchId);
		MatchEntity match = loadMatchForUpdate(matchId);
		List<Integer> answers = parseAnswers(round.getPuzzleAnswers());
		requireActiveBrainRoundMatch(match);
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
	public BrainRoundResponse completeRound(String matchId) {
		BrainRoundEntity round = loadActiveRound(matchId);
		MatchEntity match = loadMatchForUpdate(matchId);
		requireActiveBrainRoundMatch(match);
		if (!isExpired(round) && !bothPlayersAnsweredAll(round)) {
			throw new ApiException(HttpStatus.CONFLICT, "BRAIN_ROUND_STILL_ACTIVE",
					"Brain round can only complete after the deadline or after both players answer all questions.");
		}

		return completeActiveRound(round, match);
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
		int allAnsweredMask = (1 << round.getTotalQuestions()) - 1;
		return (round.getWhiteAnsweredMask() & allAnsweredMask) == allAnsweredMask &&
				(round.getBlackAnsweredMask() & allAnsweredMask) == allAnsweredMask;
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
