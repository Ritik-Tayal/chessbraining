package com.chessbraining.api.match;

import com.fasterxml.jackson.annotation.JsonCreator;

public enum BotDifficulty {
	EASY(0.55, 0.24, 0.12, 1100, 2200),
	NORMAL(0.70, 0.16, 0.35, 800, 1600),
	HARD(0.84, 0.09, 0.68, 500, 1200),
	EXPERT(0.96, 0.03, 0.90, 220, 850);

	private final double brainMean;
	private final double brainSpread;
	private final double tacticalBias;
	private final int minThinkMs;
	private final int maxThinkMs;

	BotDifficulty(double brainMean, double brainSpread, double tacticalBias, int minThinkMs, int maxThinkMs) {
		this.brainMean = brainMean;
		this.brainSpread = brainSpread;
		this.tacticalBias = tacticalBias;
		this.minThinkMs = minThinkMs;
		this.maxThinkMs = maxThinkMs;
	}

	public double brainMean() {
		return brainMean;
	}

	public double brainSpread() {
		return brainSpread;
	}

	public double tacticalBias() {
		return tacticalBias;
	}

	public int minThinkMs() {
		return minThinkMs;
	}

	public int maxThinkMs() {
		return maxThinkMs;
	}

	@JsonCreator
	public static BotDifficulty parse(String value) {
		if (value == null || value.isBlank()) {
			return NORMAL;
		}
		for (BotDifficulty difficulty : values()) {
			if (difficulty.name().equalsIgnoreCase(value.trim())) {
				return difficulty;
			}
		}
		throw new IllegalArgumentException("UNKNOWN_BOT_DIFFICULTY");
	}
}

