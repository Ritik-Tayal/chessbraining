package com.chessbraining.api.match;

public record CreateBrainMatchRequest(
		String playerId,
		String playerName,
		BrainMatchMode mode) {
}
