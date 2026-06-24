package com.chessbraining.api.match;

public record CompleteBrainRoundRequest(
		String winnerPlayerId,
		Integer whiteScore,
		Integer blackScore) {
}
