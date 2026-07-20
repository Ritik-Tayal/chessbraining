package com.chessbraining.api.profile;

import java.time.Instant;
import java.util.List;

public record GuestProfileResponse(
		String playerId,
		String playerName,
		int rating,
		int gamesPlayed,
		int activeMatches,
		int wins,
		int losses,
		int draws,
		Instant createdAt,
		Instant updatedAt,
		List<MatchHistoryResponse> recentMatches) {
}
