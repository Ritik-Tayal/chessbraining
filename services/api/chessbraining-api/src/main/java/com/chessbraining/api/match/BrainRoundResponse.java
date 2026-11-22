package com.chessbraining.api.match;

import java.time.Instant;
import java.util.List;

public record BrainRoundResponse(
		String roundId,
		int roundNumber,
		String status,
		String puzzleType,
		List<String> puzzles,
		int totalQuestions,
		int whiteCorrectCount,
		int blackCorrectCount,
		int nextWhiteQuestionIndex,
		int nextBlackQuestionIndex,
		String winnerPlayerId,
		Instant startedAt,
		Instant expiresAt,
		Instant completedAt,
		List<Integer> solutions,
		PieceSwitchEngine.View pieceSwitch) {
	public BrainRoundResponse progress() {
		return progress(System.currentTimeMillis());
	}
	public BrainRoundResponse progress(long receivedAt) {
		return new BrainRoundResponse(roundId, roundNumber, status, puzzleType, List.of(), totalQuestions,
				whiteCorrectCount, blackCorrectCount, nextWhiteQuestionIndex, nextBlackQuestionIndex,
				winnerPlayerId, startedAt, expiresAt, completedAt, List.of(), pieceSwitch == null ? null : pieceSwitch.timed(receivedAt));
	}
}
