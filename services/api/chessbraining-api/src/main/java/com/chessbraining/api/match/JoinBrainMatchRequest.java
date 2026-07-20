package com.chessbraining.api.match;

public record JoinBrainMatchRequest(
		String inviteCode,
		String playerId,
		String playerName) {
}
