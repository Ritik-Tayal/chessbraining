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
		Instant completedAt,
		List<Integer> solutions,
		PieceSwitchEngine.View pieceSwitch) {
	public BrainMatchResponse progress() {
		return progress(System.currentTimeMillis());
	}
	public BrainMatchResponse progress(long receivedAt) {
		return new BrainMatchResponse(matchId, inviteCode, status, mode, puzzleType, white, black, whiteScore,
				blackScore, totalQuestions, List.of(), nextWhiteQuestionIndex, nextBlackQuestionIndex,
				winnerPlayerId, rematchRequestedByPlayerId, rematchMatchId, startedAt, expiresAt, completedAt, List.of(), pieceSwitch == null ? null : pieceSwitch.timed(receivedAt));
	}
}
