package com.chessbraining.api.match;

import java.time.Instant;
import java.util.List;

public record BrainRoundResponse(
		String roundId,
		int roundNumber,
		String status,
		List<String> puzzles,
		int totalQuestions,
		int whiteCorrectCount,
		int blackCorrectCount,
		int nextWhiteQuestionIndex,
		int nextBlackQuestionIndex,
		String winnerPlayerId,
		Instant startedAt,
		Instant expiresAt,
		Instant completedAt) {
}
