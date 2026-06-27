package com.chessbraining.api.match;

public record CreateMatchRequest(
		String playerId,
		String playerName,
		Integer timeControlSeconds,
		Integer brainRoundIntervalMoves) {
}
