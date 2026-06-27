package com.chessbraining.api.match;

public record SubmitAnswerRequest(
		String playerId,
		int questionIndex,
		int answer) {
}
