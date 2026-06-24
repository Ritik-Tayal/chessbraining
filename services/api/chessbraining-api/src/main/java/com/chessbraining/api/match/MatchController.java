package com.chessbraining.api.match;

import java.util.List;
import java.util.Map;

import com.chessbraining.api.chess.LegalMoveResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/matches")
public class MatchController {

	private final MatchService matchService;

	public MatchController(MatchService matchService) {
		this.matchService = matchService;
	}

	@PostMapping
	public MatchResponse createMatch(@RequestBody(required = false) CreateMatchRequest request) {
		return matchService.createMatch(request);
	}

	@PostMapping("/quickplay")
	public MatchResponse quickplay(@RequestBody(required = false) CreateMatchRequest request) {
		return matchService.quickplay(request);
	}

	@PostMapping("/join")
	public MatchResponse joinMatch(@RequestBody JoinMatchRequest request) {
		return matchService.joinMatch(request);
	}

	@GetMapping("/{matchId}")
	public MatchResponse getMatch(@PathVariable String matchId) {
		return matchService.getMatch(matchId);
	}

	@GetMapping("/{matchId}/legal-moves")
	public List<LegalMoveResponse> legalMoves(
			@PathVariable String matchId,
			@RequestParam String playerId) {
		return matchService.legalMoves(matchId, playerId);
	}

	@PostMapping("/{matchId}/moves")
	public MatchResponse submitMove(
			@PathVariable String matchId,
			@RequestBody SubmitMoveRequest request) {
		return matchService.submitMove(matchId, request);
	}

	@PostMapping("/{matchId}/brain-rounds/complete")
	public MatchResponse completeBrainRound(
			@PathVariable String matchId,
			@RequestBody(required = false) CompleteBrainRoundRequest request) {
		return matchService.completeBrainRound(matchId, request);
	}

	@PostMapping("/{matchId}/resign")
	public MatchResponse resign(
			@PathVariable String matchId,
			@RequestBody Map<String, String> request) {
		return matchService.resign(matchId, request.get("playerId"));
	}
}
