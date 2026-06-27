package com.chessbraining.api.match;

import java.time.Duration;
import java.time.Instant;

import org.springframework.stereotype.Service;

@Service
public class ClockService {

	/**
	 * Start the clock for white when the match begins (both players joined).
	 * White moves first, so white's clock starts ticking.
	 */
	public void startClocks(MatchEntity match) {
		match.setClockDeadlineAt(Instant.now().plusMillis(match.getWhiteClockMs()));
	}

	/**
	 * Tick the active player's clock after a move is submitted.
	 * Saves the remaining time for the player who just moved,
	 * then starts the opponent's clock.
	 * Returns the winner player ID if the active player timed out, or null.
	 */
	public String tickAfterMove(MatchEntity match) {
		if (match.getClockDeadlineAt() == null) {
			return null;
		}

		Instant now = Instant.now();
		long remainingMs = Duration.between(now, match.getClockDeadlineAt()).toMillis();

		// The player who just moved is the opposite of current sideToMove
		// (sideToMove was already flipped by chessService.applyMove)
		boolean justMovedIsWhite = !"WHITE".equals(match.getSideToMove());

		if (justMovedIsWhite) {
			match.setWhiteClockMs(Math.max(0, (int) remainingMs));
			if (remainingMs <= 0) {
				match.setClockDeadlineAt(null);
				return match.getBlackPlayerId();
			}
			match.setClockDeadlineAt(Instant.now().plusMillis(match.getBlackClockMs()));
		} else {
			match.setBlackClockMs(Math.max(0, (int) remainingMs));
			if (remainingMs <= 0) {
				match.setClockDeadlineAt(null);
				return match.getWhitePlayerId();
			}
			match.setClockDeadlineAt(Instant.now().plusMillis(match.getWhiteClockMs()));
		}

		return null;
	}

	/**
	 * Check if the active player has already timed out (for GET /match checks).
	 * Returns the winner player ID if timed out, or null otherwise.
	 */
	public String checkTimeout(MatchEntity match) {
		if (match.getClockDeadlineAt() == null) {
			return null;
		}

		Instant now = Instant.now();
		if (!now.isAfter(match.getClockDeadlineAt())) {
			return null;
		}

		// The active player (sideToMove) has timed out
		boolean whiteTimedOut = "WHITE".equals(match.getSideToMove());
		match.setClockDeadlineAt(null);

		if (whiteTimedOut) {
			match.setWhiteClockMs(0);
			return match.getBlackPlayerId();
		} else {
			match.setBlackClockMs(0);
			return match.getWhitePlayerId();
		}
	}

	/**
	 * Pause clocks when entering a brain round. Saves remaining time for the active player.
	 */
	public void pauseForBrainRound(MatchEntity match) {
		if (match.getClockDeadlineAt() == null) {
			return;
		}

		Instant now = Instant.now();
		long remainingMs = Duration.between(now, match.getClockDeadlineAt()).toMillis();

		boolean whiteIsActive = "WHITE".equals(match.getSideToMove());
		if (whiteIsActive) {
			match.setWhiteClockMs(Math.max(0, (int) remainingMs));
		} else {
			match.setBlackClockMs(Math.max(0, (int) remainingMs));
		}

		match.setClockDeadlineAt(null);
	}

	/**
	 * Resume clocks after a brain round ends. Starts the clock for the current side to move.
	 */
	public void resumeAfterBrainRound(MatchEntity match) {
		if ("WHITE".equals(match.getSideToMove())) {
			match.setClockDeadlineAt(Instant.now().plusMillis(match.getWhiteClockMs()));
		} else {
			match.setClockDeadlineAt(Instant.now().plusMillis(match.getBlackClockMs()));
		}
	}
}
