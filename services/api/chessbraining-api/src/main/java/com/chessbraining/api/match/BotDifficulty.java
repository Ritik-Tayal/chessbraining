package com.chessbraining.api.match;

public enum BotDifficulty {
	EASY(0.38, 0.12, 0.18, 1100, 2200),
	NORMAL(0.55, 0.10, 0.42, 800, 1600),
	HARD(0.70, 0.08, 0.68, 500, 1200),
	EXPERT(0.84, 0.06, 0.88, 300, 900);

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
}
