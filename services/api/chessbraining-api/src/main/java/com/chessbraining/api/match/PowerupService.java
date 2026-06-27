package com.chessbraining.api.match;

import java.time.Duration;

import com.chessbraining.api.common.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PowerupService {

	private final MatchRepository matchRepository;
	private final MatchService matchService;

	public PowerupService(MatchRepository matchRepository, MatchService matchService) {
		this.matchRepository = matchRepository;
		this.matchService = matchService;
	}

	@Transactional
	public MatchResponse applyPowerup(String matchId, ApplyPowerupRequest request) {
		if (request == null || request.type() == null) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "POWERUP_REQUIRED", "Powerup request is required.");
		}
		if (request.playerId() == null || request.playerId().isBlank()) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "PLAYER_ID_REQUIRED", "Player id is required.");
		}

		// Reuse match timeout enforcement before spending points.
		matchService.getMatch(matchId);

		MatchEntity match = matchRepository.findByIdForUpdate(matchId)
				.orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "MATCH_NOT_FOUND", "Match not found."));
		if (match.getStatus() != MatchStatus.ACTIVE || match.getPhase() != MatchPhase.CHESS_PHASE) {
			throw new ApiException(HttpStatus.CONFLICT, "POWERUP_NOT_AVAILABLE",
					"Powerups can only be used during an active chess phase.");
		}

		String side = requirePlayerInMatch(match, request.playerId());
		spendBrainPoints(match, side, request.type().cost());
		applyClockBoost(match, side, request.type().clockBonusMs());

		matchRepository.save(match);
		return matchService.getMatch(matchId);
	}

	private String requirePlayerInMatch(MatchEntity match, String playerId) {
		if (playerId.equals(match.getWhitePlayerId())) {
			return "WHITE";
		}
		if (playerId.equals(match.getBlackPlayerId())) {
			return "BLACK";
		}
		throw new ApiException(HttpStatus.FORBIDDEN, "PLAYER_NOT_IN_MATCH", "Player is not part of this match.");
	}

	private void spendBrainPoints(MatchEntity match, String side, int cost) {
		if ("WHITE".equals(side)) {
			if (match.getWhiteBrainPoints() < cost) {
				throw new ApiException(HttpStatus.CONFLICT, "INSUFFICIENT_BRAIN_POINTS",
						"White does not have enough Brain Points.");
			}
			match.setWhiteBrainPoints(match.getWhiteBrainPoints() - cost);
			return;
		}

		if (match.getBlackBrainPoints() < cost) {
			throw new ApiException(HttpStatus.CONFLICT, "INSUFFICIENT_BRAIN_POINTS",
					"Black does not have enough Brain Points.");
		}
		match.setBlackBrainPoints(match.getBlackBrainPoints() - cost);
	}

	private void applyClockBoost(MatchEntity match, String side, int bonusMs) {
		if ("WHITE".equals(side)) {
			match.setWhiteClockMs(match.getWhiteClockMs() + bonusMs);
		} else {
			match.setBlackClockMs(match.getBlackClockMs() + bonusMs);
		}

		if (side.equals(match.getSideToMove()) && match.getClockDeadlineAt() != null) {
			match.setClockDeadlineAt(match.getClockDeadlineAt().plus(Duration.ofMillis(bonusMs)));
		}
	}
}
