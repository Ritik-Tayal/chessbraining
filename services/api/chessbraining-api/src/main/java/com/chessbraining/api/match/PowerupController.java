package com.chessbraining.api.match;

import com.chessbraining.api.websocket.MatchRealtimeService;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/matches/{matchId}/powerups")
public class PowerupController {

	private final PowerupService powerupService;
	private final MatchRealtimeService realtimeService;

	public PowerupController(PowerupService powerupService, MatchRealtimeService realtimeService) {
		this.powerupService = powerupService;
		this.realtimeService = realtimeService;
	}

	@PostMapping
	public MatchResponse applyPowerup(
			@PathVariable String matchId,
			@RequestBody ApplyPowerupRequest request) {
		MatchResponse response = powerupService.applyPowerup(matchId, request);
		realtimeService.publishMatchState(response);
		return response;
	}
}
