package com.chessbraining.api.match;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;

@Entity
@Table(name = "brain_rounds")
public class BrainRoundEntity {

	@Id
	@Column(length = 36)
	private String id;

	@Column(nullable = false, length = 36)
	private String matchId;

	@Column(nullable = false)
	private int roundNumber;

	@Column(nullable = false, length = 32)
	private String status;

	@Column(length = 64)
	private String winnerPlayerId;

	private Integer whiteScore;
	private Integer blackScore;

	@Column(nullable = false)
	private Instant startedAt;

	private Instant completedAt;

	@PrePersist
	void prePersist() {
		if (id == null) {
			id = UUID.randomUUID().toString();
		}
		startedAt = Instant.now();
	}

	public String getId() {
		return id;
	}

	public void setId(String id) {
		this.id = id;
	}

	public String getMatchId() {
		return matchId;
	}

	public void setMatchId(String matchId) {
		this.matchId = matchId;
	}

	public int getRoundNumber() {
		return roundNumber;
	}

	public void setRoundNumber(int roundNumber) {
		this.roundNumber = roundNumber;
	}

	public String getStatus() {
		return status;
	}

	public void setStatus(String status) {
		this.status = status;
	}

	public String getWinnerPlayerId() {
		return winnerPlayerId;
	}

	public void setWinnerPlayerId(String winnerPlayerId) {
		this.winnerPlayerId = winnerPlayerId;
	}

	public Integer getWhiteScore() {
		return whiteScore;
	}

	public void setWhiteScore(Integer whiteScore) {
		this.whiteScore = whiteScore;
	}

	public Integer getBlackScore() {
		return blackScore;
	}

	public void setBlackScore(Integer blackScore) {
		this.blackScore = blackScore;
	}

	public Instant getStartedAt() {
		return startedAt;
	}

	public void setStartedAt(Instant startedAt) {
		this.startedAt = startedAt;
	}

	public Instant getCompletedAt() {
		return completedAt;
	}

	public void setCompletedAt(Instant completedAt) {
		this.completedAt = completedAt;
	}
}
