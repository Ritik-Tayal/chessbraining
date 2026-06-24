package com.chessbraining.api.match;

public record JoinMatchRequest(
		String inviteCode,
		String playerId,
		String playerName) {
}
