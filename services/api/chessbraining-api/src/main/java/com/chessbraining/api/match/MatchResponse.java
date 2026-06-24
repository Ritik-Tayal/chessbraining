package com.chessbraining.api.match;

import java.time.Instant;
import java.util.List;

public record MatchResponse(
		String matchId,
		String inviteCode,
		MatchStatus status,
		MatchPhase phase,
		String fen,
		String sideToMove,
		int plyCount,
		int brainRoundIntervalMoves,
		int brainRoundCount,
		PlayerResponse white,
		PlayerResponse black,
		String winnerPlayerId,
		String resultReason,
		List<MoveResponse> moves,
		Instant createdAt,
		Instant updatedAt) {
}
