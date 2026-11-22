package com.chessbraining.api.match;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Random;

/** Bounded, disposable observations of public flips, never a copy of the hidden board. */
final class BotMemoryPlayer {
    private static final int MAX_GAMES = 128;
    private final Map<String, Observation> games = new LinkedHashMap<>(16, .75f, true);

    private static final class Observation {
        final String roundId;
        final Random random;
        final Map<Integer, String> seen = new LinkedHashMap<>();
        long lastAction;
        Observation(String roundId) {
            this.roundId = roundId;
            random = new Random(roundId.hashCode());
        }
    }

    synchronized int choose(String matchId, String roundId, MemoryPuzzleService.MemoryState state,
                            BotDifficulty difficulty, String side, long now) {
        var observation = games.get(matchId);
        if (observation == null || !roundId.equals(observation.roundId)) {
            observation = new Observation(roundId);
            games.put(matchId, observation);
            if (games.size() > MAX_GAMES) games.remove(games.keySet().iterator().next());
        }
        for (int index : state.lastFlipped()) observation.seen.put(index, state.cards().get(index));
        if (state.pendingFirstIndex() != null) {
            int index = state.pendingFirstIndex();
            observation.seen.put(index, state.cards().get(index));
        }
        observation.seen.keySet().removeIf(index -> matched(state, index));
        int capacity = switch (difficulty) { case EASY -> 6; case NORMAL -> 12; case HARD -> 18; case EXPERT -> 24; };
        while (observation.seen.size() > capacity) observation.seen.remove(observation.seen.keySet().iterator().next());
        int delay = switch (difficulty) { case EASY -> 1800; case NORMAL -> 1400; case HARD -> 1000; case EXPERT -> 700; };
        if (!side.equals(state.turnSide()) || now - observation.lastAction < delay ||
                (state.turnExpiresAt() != null && now < state.turnExpiresAt() - 8000 + delay)) return -1;

        var available = new ArrayList<Integer>();
        for (int i = 0; i < state.cards().size(); i++)
            if (!matched(state, i) && !Integer.valueOf(i).equals(state.pendingFirstIndex())) available.add(i);
        if (available.isEmpty()) return -1;
        if (observation.random.nextDouble() < difficulty.brainMean()) {
            for (int first : available) {
                String piece = observation.seen.get(first);
                if (piece == null) continue;
                if (state.pendingFirstIndex() != null) {
                    if (piece.equals(observation.seen.get(state.pendingFirstIndex()))) return first;
                } else {
                    for (int second : available)
                        if (second != first && piece.equals(observation.seen.get(second))) return first;
                }
            }
        }
        var unseen = available.stream().filter(index -> !games.get(matchId).seen.containsKey(index)).toList();
        var choices = unseen.isEmpty() ? available : unseen;
        return choices.get(observation.random.nextInt(choices.size()));
    }

    synchronized void played(String matchId, long now) {
        var observation = games.get(matchId);
        if (observation != null) observation.lastAction = now;
    }

    synchronized void forget(String matchId) { games.remove(matchId); }

    private static boolean matched(MemoryPuzzleService.MemoryState state, int index) {
        return (state.matchedMask() & (1 << index)) != 0;
    }
}
