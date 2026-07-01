package com.chessbraining.api.match;

public enum PowerupType {
	CLOCK_BOOST_30(1, 30_000),
	EXTRA_MOVE(4, 0),
	REVIVE_PAWN(3, 0);

	private final int cost;
	private final int clockBonusMs;

	PowerupType(int cost, int clockBonusMs) {
		this.cost = cost;
		this.clockBonusMs = clockBonusMs;
	}

	public int cost() {
		return cost;
	}

	public int clockBonusMs() {
		return clockBonusMs;
	}
}
