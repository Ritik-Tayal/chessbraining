package com.chessbraining.api.match;

import java.time.Instant;

public record BrainRoundResultResponse(
		String roundId,
		int roundNumber,
		int whiteCorrectCount,
		int blackCorrectCount,
		String winnerPlayerId,
		int awardedBrainPoints,
		Instant completedAt) {
}
