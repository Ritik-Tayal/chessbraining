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
		return brainRoundService.getCurrentRound(matchId);
	}

	@PostMapping("/current/answers")
	public AnswerResultResponse submitAnswer(
			@PathVariable String matchId,
			@RequestBody SubmitAnswerRequest request) {
		return brainRoundService.submitAnswer(matchId, request);
	}

	@PostMapping("/current/complete")
	public BrainRoundResponse completeRound(@PathVariable String matchId) {
		BrainRoundResponse response = brainRoundService.completeRound(matchId);
		realtimeService.publishMatchState(matchService.getMatch(matchId));
		return response;
	}
}
