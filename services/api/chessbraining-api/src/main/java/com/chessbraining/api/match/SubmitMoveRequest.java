package com.chessbraining.api.match;

public record SubmitMoveRequest(
		String playerId,
		String from,
		String to,
		String promotion) {
}
