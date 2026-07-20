package com.chessbraining.api.profile;

import java.time.Instant;

public record MatchHistoryResponse(
		String matchId,
		String inviteCode,
		String opponentName,
		boolean opponentBot,
		String opponentDifficulty,
		String result,
		String resultReason,
		int ratingChange,
		int ratingAfter,
		int plyCount,
		int brainRoundCount,
		Instant playedAt) {
}
