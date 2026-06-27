package com.chessbraining.api.match;

public record AnswerResultResponse(
		boolean correct,
		int correctAnswer,
		int playerCorrectCount,
		int totalQuestions) {
}
