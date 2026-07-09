package com.chessbraining.api.match;

import java.util.List;

public record SubmitPathRequest(
		String playerId,
		int puzzleIndex,
		List<List<Integer>> path) {
}
