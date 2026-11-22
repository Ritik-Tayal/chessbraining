package com.chessbraining.api.match;

import java.time.Instant;
import java.util.SplittableRandom;

/** A stable per-round performance plan; polling/retries cannot reroll the score. */
final class BotBrainPace {
    private BotBrainPace() { }

    static int target(String roundId, BotDifficulty difficulty, int total) {
        if (total <= 0) return 0;
        var random = new SplittableRandom(roundId.hashCode() * 31L + difficulty.ordinal());
        double rate = difficulty.brainMean() + random.nextDouble(-1, 1) * difficulty.brainSpread();
        return Math.clamp(Math.round(total * rate), 1, total);
    }

    static int due(BrainRoundEntity round, Instant now) {
        long duration = Math.max(1, round.getExpiresAt().toEpochMilli() - round.getStartedAt().toEpochMilli() - 1000);
        long elapsed = Math.max(0, now.toEpochMilli() - round.getStartedAt().toEpochMilli());
        return (int) Math.min(round.getTotalQuestions(), round.getTotalQuestions() * elapsed / duration);
    }

    static boolean correct(int index, int target, int total) {
        return ((index + 1) * target + total - 1) / total > (index * target + total - 1) / total;
    }
}
