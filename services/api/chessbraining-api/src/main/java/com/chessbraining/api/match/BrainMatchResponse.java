package com.chessbraining.api.match;

import java.time.Instant;
import java.util.List;

public record BrainMatchResponse(
		String matchId,
		String inviteCode,
		String status,
		BrainMatchMode mode,
		String puzzleType,
		PlayerResponse white,
		PlayerResponse black,
		int whiteScore,
		int blackScore,
		int totalQuestions,
		List<String> puzzles,
		int nextWhiteQuestionIndex,
		int nextBlackQuestionIndex,
		String winnerPlayerId,
		String rematchRequestedByPlayerId,
		String rematchMatchId,
		Instant startedAt,
		Instant expiresAt,
		Instant completedAt) {
}
