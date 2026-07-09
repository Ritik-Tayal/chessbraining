package com.chessbraining.api.match;

import java.time.Duration;

import com.chessbraining.api.chess.ChessService;
import com.chessbraining.api.common.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PowerupService {

	private final MatchRepository matchRepository;
	private final MatchService matchService;
	private final ChessService chessService;

	public PowerupService(MatchRepository matchRepository, MatchService matchService, ChessService chessService) {
		this.matchRepository = matchRepository;
		this.matchService = matchService;
		this.chessService = chessService;
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
		switch (request.type()) {
			case CLOCK_BOOST_30 -> {
				spendBrainPoints(match, side, request.type().cost());
				applyClockBoost(match, side, request.type().clockBonusMs());
			}
			case EXTRA_MOVE -> {
				requirePlayerTurn(match, side);
				validateExtraMoveAvailable(match, side);
				spendBrainPoints(match, side, request.type().cost());
				setExtraMoveArmed(match, side, true);
			}
			case REVIVE_PAWN -> {
				requirePlayerTurn(match, side);
				String revivedFen = chessService.revivePawn(match.getFen(), side, request.targetSquare());
				spendBrainPoints(match, side, request.type().cost());
				matchService.completePowerupTurn(match, side, revivedFen);
			}
		}

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

	private void requirePlayerTurn(MatchEntity match, String side) {
		if (!side.equals(match.getSideToMove())) {
			throw new ApiException(HttpStatus.CONFLICT, "POWERUP_NOT_YOUR_TURN",
					"This powerup can only be used on your turn.");
		}
	}

	private void validateExtraMoveAvailable(MatchEntity match, String side) {
		if (match.isWhiteExtraMoveActive() || match.isBlackExtraMoveActive()) {
			throw new ApiException(HttpStatus.CONFLICT, "EXTRA_MOVE_ALREADY_ACTIVE",
					"Finish the active extra move before using another one.");
		}
		if (isExtraMoveArmed(match, side)) {
			throw new ApiException(HttpStatus.CONFLICT, "EXTRA_MOVE_ALREADY_ARMED",
					"Extra move is already armed for this player.");
		}
		if (matchService.nextMoveWouldStartBrainRound(match)) {
			throw new ApiException(HttpStatus.CONFLICT, "EXTRA_MOVE_BLOCKED_BY_BRAIN_ROUND",
					"Extra move cannot be armed on the move that starts a brain round.");
		}
		if (chessService.isSideInCheck(match.getFen(), side)) {
			throw new ApiException(HttpStatus.CONFLICT, "EXTRA_MOVE_BLOCKED_IN_CHECK",
					"Extra move cannot be armed while your king is in check.");
		}
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

	private boolean isExtraMoveArmed(MatchEntity match, String side) {
		return "WHITE".equals(side) ? match.isWhiteExtraMoveArmed() : match.isBlackExtraMoveArmed();
	}

	private void setExtraMoveArmed(MatchEntity match, String side, boolean value) {
		if ("WHITE".equals(side)) {
			match.setWhiteExtraMoveArmed(value);
		} else {
			match.setBlackExtraMoveArmed(value);
		}
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
