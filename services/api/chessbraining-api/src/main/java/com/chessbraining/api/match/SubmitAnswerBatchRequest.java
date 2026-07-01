package com.chessbraining.api.match;

import java.util.List;

public record SubmitAnswerBatchRequest(
		String playerId,
		List<SubmittedAnswer> answers) {

	public record SubmittedAnswer(
			int questionIndex,
			int answer) {
	}
}
