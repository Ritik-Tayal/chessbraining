package com.chessbraining.api.match;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;

@Entity
@Table(name = "matches")
public class MatchEntity {

	@Id
	@Column(length = 36)
	private String id;

	@Column(nullable = false, unique = true, length = 12)
	private String inviteCode;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 32)
	private MatchStatus status;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 32)
	private MatchPhase phase;

	@Enumerated(EnumType.STRING)
	@Column(length = 16)
	private MatchmakingMode matchmakingMode;

	@Column(nullable = false, length = 512)
	private String fen;

	@Column(nullable = false, length = 8)
	private String sideToMove;

	@Column(nullable = false, length = 64)
	private String whitePlayerId;

	@Column(nullable = false, length = 80)
	private String whitePlayerName;

	@Column(length = 64)
	private String blackPlayerId;

	@Column(length = 80)
	private String blackPlayerName;

	@Column
	private Boolean whiteBot = false;

	@Column
	private Boolean blackBot = false;

	@Enumerated(EnumType.STRING)
	@Column(length = 16)
	private BotDifficulty whiteBotDifficulty;

	@Enumerated(EnumType.STRING)
	@Column(length = 16)
	private BotDifficulty blackBotDifficulty;

	@Column(nullable = false)
	private int timeControlSeconds;

	@Column(nullable = false)
	private int whiteClockMs;

	@Column(nullable = false)
	private int blackClockMs;

	@Column(nullable = false)
	private int brainRoundIntervalMoves;

	@Column(nullable = false)
	private int plyCount;

	@Column(nullable = false)
	private int brainRoundCount;

	@Column(nullable = false)
	private int whiteBrainPoints;

	@Column(nullable = false)
	private int blackBrainPoints;

	@Column(nullable = false)
	private boolean whiteExtraMoveArmed;

	@Column(nullable = false)
	private boolean blackExtraMoveArmed;

	@Column(nullable = false)
	private boolean whiteExtraMoveActive;

	@Column(nullable = false)
	private boolean blackExtraMoveActive;

	@Column(length = 64)
	private String winnerPlayerId;

	@Column(length = 64)
	private String resultReason;

	@Column(length = 64)
	private String rematchRequestedByPlayerId;

	@Column(length = 36)
	private String rematchMatchId;

	@Column(nullable = false)
	private Instant createdAt;

	@Column(nullable = false)
	private Instant updatedAt;

	private Instant startedAt;
	private Instant completedAt;

	@Column(nullable = true)
	private Instant clockDeadlineAt;

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

	public String getId() {
		return id;
	}

	public void setId(String id) {
		this.id = id;
	}

	public String getInviteCode() {
		return inviteCode;
	}

	public void setInviteCode(String inviteCode) {
		this.inviteCode = inviteCode;
	}

	public MatchStatus getStatus() {
		return status;
	}

	public void setStatus(MatchStatus status) {
		this.status = status;
	}

	public MatchPhase getPhase() {
		return phase;
	}

	public void setPhase(MatchPhase phase) {
		this.phase = phase;
	}

	public MatchmakingMode getMatchmakingMode() {
		return matchmakingMode;
	}

	public void setMatchmakingMode(MatchmakingMode matchmakingMode) {
		this.matchmakingMode = matchmakingMode;
	}

	public String getFen() {
		return fen;
	}

	public void setFen(String fen) {
		this.fen = fen;
	}

	public String getSideToMove() {
		return sideToMove;
	}

	public void setSideToMove(String sideToMove) {
		this.sideToMove = sideToMove;
	}

	public String getWhitePlayerId() {
		return whitePlayerId;
	}

	public void setWhitePlayerId(String whitePlayerId) {
		this.whitePlayerId = whitePlayerId;
	}

	public String getWhitePlayerName() {
		return whitePlayerName;
	}

	public void setWhitePlayerName(String whitePlayerName) {
		this.whitePlayerName = whitePlayerName;
	}

	public String getBlackPlayerId() {
		return blackPlayerId;
	}

	public void setBlackPlayerId(String blackPlayerId) {
		this.blackPlayerId = blackPlayerId;
	}

	public String getBlackPlayerName() {
		return blackPlayerName;
	}

	public void setBlackPlayerName(String blackPlayerName) {
		this.blackPlayerName = blackPlayerName;
	}

	public boolean isWhiteBot() {
		return Boolean.TRUE.equals(whiteBot);
	}

	public void setWhiteBot(boolean whiteBot) {
		this.whiteBot = whiteBot;
	}

	public boolean isBlackBot() {
		return Boolean.TRUE.equals(blackBot);
	}

	public void setBlackBot(boolean blackBot) {
		this.blackBot = blackBot;
	}

	public BotDifficulty getWhiteBotDifficulty() {
		return whiteBotDifficulty;
	}

	public void setWhiteBotDifficulty(BotDifficulty whiteBotDifficulty) {
		this.whiteBotDifficulty = whiteBotDifficulty;
	}

	public BotDifficulty getBlackBotDifficulty() {
		return blackBotDifficulty;
	}

	public void setBlackBotDifficulty(BotDifficulty blackBotDifficulty) {
		this.blackBotDifficulty = blackBotDifficulty;
	}

	public int getTimeControlSeconds() {
		return timeControlSeconds;
	}

	public void setTimeControlSeconds(int timeControlSeconds) {
		this.timeControlSeconds = timeControlSeconds;
	}

	public int getWhiteClockMs() {
		return whiteClockMs;
	}

	public void setWhiteClockMs(int whiteClockMs) {
		this.whiteClockMs = whiteClockMs;
	}

	public int getBlackClockMs() {
		return blackClockMs;
	}

	public void setBlackClockMs(int blackClockMs) {
		this.blackClockMs = blackClockMs;
	}

	public int getBrainRoundIntervalMoves() {
		return brainRoundIntervalMoves;
	}

	public void setBrainRoundIntervalMoves(int brainRoundIntervalMoves) {
		this.brainRoundIntervalMoves = brainRoundIntervalMoves;
	}

	public int getPlyCount() {
		return plyCount;
	}

	public void setPlyCount(int plyCount) {
		this.plyCount = plyCount;
	}

	public int getBrainRoundCount() {
		return brainRoundCount;
	}

	public void setBrainRoundCount(int brainRoundCount) {
		this.brainRoundCount = brainRoundCount;
	}

	public int getWhiteBrainPoints() {
		return whiteBrainPoints;
	}

	public void setWhiteBrainPoints(int whiteBrainPoints) {
		this.whiteBrainPoints = whiteBrainPoints;
	}

	public int getBlackBrainPoints() {
		return blackBrainPoints;
	}

	public void setBlackBrainPoints(int blackBrainPoints) {
		this.blackBrainPoints = blackBrainPoints;
	}

	public boolean isWhiteExtraMoveArmed() {
		return whiteExtraMoveArmed;
	}

	public void setWhiteExtraMoveArmed(boolean whiteExtraMoveArmed) {
		this.whiteExtraMoveArmed = whiteExtraMoveArmed;
	}

	public boolean isBlackExtraMoveArmed() {
		return blackExtraMoveArmed;
	}

	public void setBlackExtraMoveArmed(boolean blackExtraMoveArmed) {
		this.blackExtraMoveArmed = blackExtraMoveArmed;
	}

	public boolean isWhiteExtraMoveActive() {
		return whiteExtraMoveActive;
	}

	public void setWhiteExtraMoveActive(boolean whiteExtraMoveActive) {
		this.whiteExtraMoveActive = whiteExtraMoveActive;
	}

	public boolean isBlackExtraMoveActive() {
		return blackExtraMoveActive;
	}

	public void setBlackExtraMoveActive(boolean blackExtraMoveActive) {
		this.blackExtraMoveActive = blackExtraMoveActive;
	}

	public String getWinnerPlayerId() {
		return winnerPlayerId;
	}

	public void setWinnerPlayerId(String winnerPlayerId) {
		this.winnerPlayerId = winnerPlayerId;
	}

	public String getResultReason() {
		return resultReason;
	}

	public void setResultReason(String resultReason) {
		this.resultReason = resultReason;
	}

	public String getRematchRequestedByPlayerId() {
		return rematchRequestedByPlayerId;
	}

	public void setRematchRequestedByPlayerId(String rematchRequestedByPlayerId) {
		this.rematchRequestedByPlayerId = rematchRequestedByPlayerId;
	}

	public String getRematchMatchId() {
		return rematchMatchId;
	}

	public void setRematchMatchId(String rematchMatchId) {
		this.rematchMatchId = rematchMatchId;
	}

	public Instant getCreatedAt() {
		return createdAt;
	}

	public void setCreatedAt(Instant createdAt) {
		this.createdAt = createdAt;
	}

	public Instant getUpdatedAt() {
		return updatedAt;
	}

	public void setUpdatedAt(Instant updatedAt) {
		this.updatedAt = updatedAt;
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

	public Instant getClockDeadlineAt() {
		return clockDeadlineAt;
	}

	public void setClockDeadlineAt(Instant clockDeadlineAt) {
		this.clockDeadlineAt = clockDeadlineAt;
	}
}
