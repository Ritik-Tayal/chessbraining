package com.chessbraining.api.match;

import java.time.Instant;

public record MoveResponse(
		int plyNumber,
		String playerId,
		String side,
		String from,
		String to,
		String promotion,
		String fenBefore,
		String fenAfter,
		Instant createdAt) {
}
