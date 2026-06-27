package com.chessbraining.api.match;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;

@Entity
@Table(
		name = "match_moves",
		uniqueConstraints = @UniqueConstraint(
				name = "uk_match_moves_match_ply",
				columnNames = {"matchId", "plyNumber"}))
public class MatchMoveEntity {

	@Id
	@Column(length = 36)
	private String id;

	@Column(nullable = false, length = 36)
	private String matchId;

	@Column(nullable = false)
	private int plyNumber;

	@Column(nullable = false, length = 64)
	private String playerId;

	@Column(nullable = false, length = 8)
	private String side;

	@Column(nullable = false, length = 2)
	private String fromSquare;

	@Column(nullable = false, length = 2)
	private String toSquare;

	@Column(length = 8)
	private String promotion;

	@Column(nullable = false, length = 512)
	private String fenBefore;

	@Column(nullable = false, length = 512)
	private String fenAfter;

	@Column(nullable = false)
	private Instant createdAt;

	@PrePersist
	void prePersist() {
		if (id == null) {
			id = UUID.randomUUID().toString();
		}
		createdAt = Instant.now();
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

	public int getPlyNumber() {
		return plyNumber;
	}

	public void setPlyNumber(int plyNumber) {
		this.plyNumber = plyNumber;
	}

	public String getPlayerId() {
		return playerId;
	}

	public void setPlayerId(String playerId) {
		this.playerId = playerId;
	}

	public String getSide() {
		return side;
	}

	public void setSide(String side) {
		this.side = side;
	}

	public String getFromSquare() {
		return fromSquare;
	}

	public void setFromSquare(String fromSquare) {
		this.fromSquare = fromSquare;
	}

	public String getToSquare() {
		return toSquare;
	}

	public void setToSquare(String toSquare) {
		this.toSquare = toSquare;
	}

	public String getPromotion() {
		return promotion;
	}

	public void setPromotion(String promotion) {
		this.promotion = promotion;
	}

	public String getFenBefore() {
		return fenBefore;
	}

	public void setFenBefore(String fenBefore) {
		this.fenBefore = fenBefore;
	}

	public String getFenAfter() {
		return fenAfter;
	}

	public void setFenAfter(String fenAfter) {
		this.fenAfter = fenAfter;
	}

	public Instant getCreatedAt() {
		return createdAt;
	}

	public void setCreatedAt(Instant createdAt) {
		this.createdAt = createdAt;
	}
}
