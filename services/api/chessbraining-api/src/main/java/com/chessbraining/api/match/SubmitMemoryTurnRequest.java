package com.chessbraining.api.match;

public record SubmitMemoryTurnRequest(
		String playerId,
		int firstIndex,
		int secondIndex) {
}
