package com.chessbraining.api.match;

public record BrainRoundSubmissionResponse(
		int playerCorrectCount,
		int playerAnsweredCount,
		int totalQuestions,
		boolean roundCompleted) {
}
