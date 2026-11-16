package com.chessbraining.api.match;

import java.util.List;

public record SubmitAnswerBatchRequest(
		String playerId,
		List<SubmittedAnswer> answers,
		Boolean finalSubmission) {
	public SubmitAnswerBatchRequest(String playerId, List<SubmittedAnswer> answers) {
		this(playerId, answers, true);
	}
	public boolean isFinal() { return !Boolean.FALSE.equals(finalSubmission); }

	public record SubmittedAnswer(
			int questionIndex,
			int answer) {
	}
}
