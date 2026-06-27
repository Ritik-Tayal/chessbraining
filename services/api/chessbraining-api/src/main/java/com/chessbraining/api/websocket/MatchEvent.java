package com.chessbraining.api.websocket;

import com.chessbraining.api.match.MatchResponse;

public record MatchEvent(
		String type,
		MatchResponse match) {
}
