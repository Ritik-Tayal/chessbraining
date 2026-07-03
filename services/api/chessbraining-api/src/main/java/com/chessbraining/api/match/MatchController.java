package com.chessbraining.api.match;

import java.util.List;
import java.util.Map;

import com.chessbraining.api.chess.LegalMoveResponse;
import com.chessbraining.api.websocket.MatchRealtimeService;
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
	private final MatchRealtimeService realtimeService;

	public MatchController(MatchService matchService, MatchRealtimeService realtimeService) {
		this.matchService = matchService;
		this.realtimeService = realtimeService;
	}

	@PostMapping
	public MatchResponse createMatch(@RequestBody(required = false) CreateMatchRequest request) {
		MatchResponse response = matchService.createMatch(request);
		realtimeService.publishMatchState(response);
		return response;
	}

	@PostMapping("/quickplay")
	public MatchResponse quickplay(@RequestBody(required = false) CreateMatchRequest request) {
		MatchResponse response = matchService.quickplay(request);
		realtimeService.publishMatchState(response);
		return response;
	}

	@PostMapping("/join")
	public MatchResponse joinMatch(@RequestBody JoinMatchRequest request) {
		MatchResponse response = matchService.joinMatch(request);
		realtimeService.publishMatchState(response);
		return response;
	}

	@GetMapping("/{matchId}")
	public MatchResponse getMatch(@PathVariable String matchId) {
		MatchResponse response = matchService.getMatch(matchId);
		if (response.status() == MatchStatus.COMPLETED) {
			realtimeService.publishMatchState(response);
		}
		return response;
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
		MatchResponse response = matchService.submitMove(matchId, request);
		realtimeService.publishMatchState(response);
		return response;
	}

	@PostMapping("/{matchId}/resign")
	public MatchResponse resign(
			@PathVariable String matchId,
			@RequestBody Map<String, String> request) {
		MatchResponse response = matchService.resign(matchId, request.get("playerId"));
		realtimeService.publishMatchState(response);
		return response;
	}

	@PostMapping("/{matchId}/rematch")
	public MatchResponse rematch(
			@PathVariable String matchId,
			@RequestBody Map<String, String> request) {
		MatchResponse response = matchService.requestRematch(matchId, request.get("playerId"));
		realtimeService.publishMatchState(response);
		return response;
	}
}
