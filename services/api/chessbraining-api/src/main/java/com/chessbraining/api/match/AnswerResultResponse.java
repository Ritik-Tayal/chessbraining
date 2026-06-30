package com.chessbraining.api.match;

public record AnswerResultResponse(
		boolean correct,
		int playerCorrectCount,
		int totalQuestions) {
}
