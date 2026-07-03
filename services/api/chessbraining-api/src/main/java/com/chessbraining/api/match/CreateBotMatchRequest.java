package com.chessbraining.api.match;

public record CreateBotMatchRequest(
		String playerId,
		String playerName,
		BotDifficulty difficulty,
		String preferredSide,
		Integer timeControlSeconds,
		Integer brainRoundIntervalMoves) {
}
