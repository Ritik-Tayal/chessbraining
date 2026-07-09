package com.chessbraining.api.match;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Lob;
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

	@Column(nullable = false, length = 32)
	private String puzzleType;

	@Column(length = 64)
	private String winnerPlayerId;

	private Integer whiteScore;
	private Integer blackScore;

	@Lob
	@Column(nullable = false)
	private String puzzleExpressions;

	@Lob
	@Column(nullable = false)
	private String puzzleAnswers;

	@Column(nullable = false)
	private int totalQuestions;

	@Column(nullable = false)
	private int whiteCorrectCount;

	@Column(nullable = false)
	private int blackCorrectCount;

	@Column
	private int whiteAnsweredMask;

	@Column
	private int blackAnsweredMask;

	@Column(nullable = false)
	private Instant startedAt;

	@Column
	private Instant expiresAt;

	private Instant completedAt;

	@PrePersist
	void prePersist() {
		if (id == null) {
			id = UUID.randomUUID().toString();
		}
		if (startedAt == null) {
			startedAt = Instant.now();
		}
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

	public String getPuzzleType() {
		return puzzleType;
	}

	public void setPuzzleType(String puzzleType) {
		this.puzzleType = puzzleType;
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

	public String getPuzzleExpressions() {
		return puzzleExpressions;
	}

	public void setPuzzleExpressions(String puzzleExpressions) {
		this.puzzleExpressions = puzzleExpressions;
	}

	public String getPuzzleAnswers() {
		return puzzleAnswers;
	}

	public void setPuzzleAnswers(String puzzleAnswers) {
		this.puzzleAnswers = puzzleAnswers;
	}

	public int getTotalQuestions() {
		return totalQuestions;
	}

	public void setTotalQuestions(int totalQuestions) {
		this.totalQuestions = totalQuestions;
	}

	public int getWhiteCorrectCount() {
		return whiteCorrectCount;
	}

	public void setWhiteCorrectCount(int whiteCorrectCount) {
		this.whiteCorrectCount = whiteCorrectCount;
	}

	public int getBlackCorrectCount() {
		return blackCorrectCount;
	}

	public void setBlackCorrectCount(int blackCorrectCount) {
		this.blackCorrectCount = blackCorrectCount;
	}

	public int getWhiteAnsweredMask() {
		return whiteAnsweredMask;
	}

	public void setWhiteAnsweredMask(int whiteAnsweredMask) {
		this.whiteAnsweredMask = whiteAnsweredMask;
	}

	public int getBlackAnsweredMask() {
		return blackAnsweredMask;
	}

	public void setBlackAnsweredMask(int blackAnsweredMask) {
		this.blackAnsweredMask = blackAnsweredMask;
	}

	public Instant getStartedAt() {
		return startedAt;
	}

	public void setStartedAt(Instant startedAt) {
		this.startedAt = startedAt;
	}

	public Instant getExpiresAt() {
		if (expiresAt == null && startedAt != null) {
			return startedAt.plusSeconds(30);
		}
		return expiresAt;
	}

	public void setExpiresAt(Instant expiresAt) {
		this.expiresAt = expiresAt;
	}

	public Instant getCompletedAt() {
		return completedAt;
	}

	public void setCompletedAt(Instant completedAt) {
		this.completedAt = completedAt;
	}
}
