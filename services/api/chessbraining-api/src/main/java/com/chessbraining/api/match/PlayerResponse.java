package com.chessbraining.api.match;

public record PlayerResponse(
		String playerId,
		String playerName,
		String side,
		int brainPoints,
		int clockMs) {
}
