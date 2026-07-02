package com.chessbraining.api.match;

import com.chessbraining.api.websocket.MatchRealtimeService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/matches/{matchId}/brain-rounds")
public class BrainRoundController {

	private final BrainRoundService brainRoundService;
	private final MatchService matchService;
	private final MatchRealtimeService realtimeService;

	public BrainRoundController(
			BrainRoundService brainRoundService,
			MatchService matchService,
			MatchRealtimeService realtimeService) {
		this.brainRoundService = brainRoundService;
		this.matchService = matchService;
		this.realtimeService = realtimeService;
	}

	@GetMapping("/current")
	public BrainRoundResponse getCurrentRound(@PathVariable String matchId) {
		BrainRoundResponse response = brainRoundService.getCurrentRound(matchId);
		publishIfRoundFinished(matchId);
		return response;
	}

	@GetMapping("/latest-result")
	public BrainRoundResponse getLatestResult(@PathVariable String matchId) {
		return brainRoundService.getLatestResult(matchId);
	}

	@PostMapping("/current/answers")
	public AnswerResultResponse submitAnswer(
			@PathVariable String matchId,
			@RequestBody SubmitAnswerRequest request) {
		AnswerResultResponse response = brainRoundService.submitAnswer(matchId, request);
		publishIfRoundFinished(matchId);
		return response;
	}

	@PostMapping("/current/submissions")
	public BrainRoundSubmissionResponse submitAnswers(
			@PathVariable String matchId,
			@RequestBody SubmitAnswerBatchRequest request) {
		BrainRoundSubmissionResponse response = brainRoundService.submitAnswerBatch(matchId, request);
		publishIfRoundFinished(matchId);
		return response;
	}

	@PostMapping("/current/complete")
	public BrainRoundResponse completeRound(@PathVariable String matchId) {
		BrainRoundResponse response = brainRoundService.completeRound(matchId);
		publishIfRoundFinished(matchId);
		return response;
	}

	private void publishIfRoundFinished(String matchId) {
		MatchResponse match = matchService.getMatch(matchId);
		if (match.phase() != MatchPhase.BRAIN_ROUND) {
			realtimeService.publishMatchState(match);
		}
	}
}
