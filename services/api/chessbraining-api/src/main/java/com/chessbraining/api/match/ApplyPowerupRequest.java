package com.chessbraining.api.match;

public record ApplyPowerupRequest(
		String playerId,
		PowerupType type,
		String targetSquare) {
}
