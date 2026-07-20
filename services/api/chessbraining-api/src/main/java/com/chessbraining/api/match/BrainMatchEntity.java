package com.chessbraining.api.match;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Lob;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;

@Entity
@Table(name = "brain_matches")
public class BrainMatchEntity {

	@Id
	@Column(length = 36)
	private String id;

	@Column(nullable = false, unique = true, length = 12)
	private String inviteCode;

	@Column(nullable = false, length = 32)
	private String status;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 32)
	private BrainMatchMode mode;

	@Column(nullable = false, length = 32)
	private String puzzleType;

	@Column(nullable = false, length = 64)
	private String whitePlayerId;

	@Column(nullable = false, length = 80)
	private String whitePlayerName;

	@Column(length = 64)
	private String blackPlayerId;

	@Column(length = 80)
	private String blackPlayerName;

	@Column(length = 64)
	private String winnerPlayerId;

	@Column(length = 64)
	private String rematchRequestedByPlayerId;

	@Column(length = 36)
	private String rematchMatchId;

	@Lob
	@Column(nullable = false)
	private String puzzleExpressions;

	@Lob
	@Column(nullable = false)
	private String puzzleAnswers;

	@Column(nullable = false)
	private int totalQuestions;

	@Column(nullable = false)
	private int whiteScore;

	@Column(nullable = false)
	private int blackScore;

	@Column(nullable = false)
	private int whiteAnsweredMask;

	@Column(nullable = false)
	private int blackAnsweredMask;

	@Column(nullable = false)
	private Instant createdAt;

	@Column(nullable = false)
	private Instant updatedAt;

	private Instant startedAt;
	private Instant expiresAt;
	private Instant completedAt;

	@PrePersist
	void prePersist() {
		if (id == null) {
			id = UUID.randomUUID().toString();
		}
		Instant now = Instant.now();
		createdAt = now;
		updatedAt = now;
	}

	@PreUpdate
	void preUpdate() {
		updatedAt = Instant.now();
	}

	public String getId() { return id; }
	public void setId(String id) { this.id = id; }
	public String getInviteCode() { return inviteCode; }
	public void setInviteCode(String inviteCode) { this.inviteCode = inviteCode; }
	public String getStatus() { return status; }
	public void setStatus(String status) { this.status = status; }
	public BrainMatchMode getMode() { return mode; }
	public void setMode(BrainMatchMode mode) { this.mode = mode; }
	public String getPuzzleType() { return puzzleType; }
	public void setPuzzleType(String puzzleType) { this.puzzleType = puzzleType; }
	public String getWhitePlayerId() { return whitePlayerId; }
	public void setWhitePlayerId(String whitePlayerId) { this.whitePlayerId = whitePlayerId; }
	public String getWhitePlayerName() { return whitePlayerName; }
	public void setWhitePlayerName(String whitePlayerName) { this.whitePlayerName = whitePlayerName; }
	public String getBlackPlayerId() { return blackPlayerId; }
	public void setBlackPlayerId(String blackPlayerId) { this.blackPlayerId = blackPlayerId; }
	public String getBlackPlayerName() { return blackPlayerName; }
	public void setBlackPlayerName(String blackPlayerName) { this.blackPlayerName = blackPlayerName; }
	public String getWinnerPlayerId() { return winnerPlayerId; }
	public void setWinnerPlayerId(String winnerPlayerId) { this.winnerPlayerId = winnerPlayerId; }
	public String getRematchRequestedByPlayerId() { return rematchRequestedByPlayerId; }
	public void setRematchRequestedByPlayerId(String rematchRequestedByPlayerId) { this.rematchRequestedByPlayerId = rematchRequestedByPlayerId; }
	public String getRematchMatchId() { return rematchMatchId; }
	public void setRematchMatchId(String rematchMatchId) { this.rematchMatchId = rematchMatchId; }
	public String getPuzzleExpressions() { return puzzleExpressions; }
	public void setPuzzleExpressions(String puzzleExpressions) { this.puzzleExpressions = puzzleExpressions; }
	public String getPuzzleAnswers() { return puzzleAnswers; }
	public void setPuzzleAnswers(String puzzleAnswers) { this.puzzleAnswers = puzzleAnswers; }
	public int getTotalQuestions() { return totalQuestions; }
	public void setTotalQuestions(int totalQuestions) { this.totalQuestions = totalQuestions; }
	public int getWhiteScore() { return whiteScore; }
	public void setWhiteScore(int whiteScore) { this.whiteScore = whiteScore; }
	public int getBlackScore() { return blackScore; }
	public void setBlackScore(int blackScore) { this.blackScore = blackScore; }
	public int getWhiteAnsweredMask() { return whiteAnsweredMask; }
	public void setWhiteAnsweredMask(int whiteAnsweredMask) { this.whiteAnsweredMask = whiteAnsweredMask; }
	public int getBlackAnsweredMask() { return blackAnsweredMask; }
	public void setBlackAnsweredMask(int blackAnsweredMask) { this.blackAnsweredMask = blackAnsweredMask; }
	public Instant getCreatedAt() { return createdAt; }
	public Instant getUpdatedAt() { return updatedAt; }
	public Instant getStartedAt() { return startedAt; }
	public void setStartedAt(Instant startedAt) { this.startedAt = startedAt; }
	public Instant getExpiresAt() { return expiresAt; }
	public void setExpiresAt(Instant expiresAt) { this.expiresAt = expiresAt; }
	public Instant getCompletedAt() { return completedAt; }
	public void setCompletedAt(Instant completedAt) { this.completedAt = completedAt; }
}
