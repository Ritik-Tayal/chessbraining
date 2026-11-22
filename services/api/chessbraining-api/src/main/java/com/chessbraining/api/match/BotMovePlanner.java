package com.chessbraining.api.match;

import java.util.*;
import com.chessbraining.api.chess.*;
import com.chessbraining.api.common.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/** Stockfish evaluates chess; this bounded outer search models our nonstandard turn actions. */
@Service
public class BotMovePlanner {
    private final StockfishEngine engine;
    private final ChessService chess;

    public BotMovePlanner(StockfishEngine engine, ChessService chess) {
        this.engine = engine;
        this.chess = chess;
    }

    public record Plan(LegalMoveResponse move, PowerupType powerup, String targetSquare) { }

    public Plan choose(MatchResponse match, PlayerResponse bot) {
        var difficulty = bot.botDifficulty() == null ? BotDifficulty.NORMAL : bot.botDifficulty();
        var moves = allowedMoves(match.fen(), bot.side(), bot.extraMoveArmed());
        if (moves.isEmpty()) return null;
        int searchMs = (int) Math.min(difficulty.searchMillis(), Math.max(30, bot.clockMs() / 30));
        var baseline = engine.analyze(match.fen(), difficulty, searchMs, moves, 1);
        if (baseline.isEmpty()) {
            if (engine.required()) throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE,
                    "BOT_ENGINE_UNAVAILABLE", "The chess engine is recovering. Please wait.");
            return null;
        }
        var best = baseline.getFirst();
        Plan plan = new Plan(find(moves, best.move()), null, null);
        int bestValue = best.scoreCp();
        // Preserve forced mates and avoid expensive variant searches on a nearly exhausted clock.
        if (bestValue > 90000 || bot.clockMs() < 10000 || difficulty == BotDifficulty.EASY) return plan;

        boolean nextStartsBrain = match.brainRoundIntervalMoves() > 0 &&
                (match.plyCount() + 1) % (match.brainRoundIntervalMoves() * 2) == 0;
        boolean activeExtra = bot.extraMoveArmed() || bot.extraMoveActive() ||
                match.white().extraMoveActive() || (match.black() != null && match.black().extraMoveActive());
        if (!activeExtra && !nextStartsBrain && bot.brainPoints() >= PowerupType.EXTRA_MOVE.cost() &&
                !chess.isSideInCheck(match.fen(), bot.side())) {
            var quiet = allowedMoves(match.fen(), bot.side(), true);
            var openings = engine.analyze(match.fen(), BotDifficulty.EXPERT, 100, quiet, 3);
            for (var opening : openings) {
                var first = find(quiet, opening.move());
                var moved = chess.applyMove(match.fen(), command(first), bot.side());
                String continuation = chess.withSideToMove(moved.fen(), bot.side());
                var followup = engine.analyze(continuation, difficulty, 100,
                        chess.legalMoves(continuation), 1);
                if (!followup.isEmpty()) {
                    int value = followup.getFirst().scoreCp() - PowerupType.EXTRA_MOVE.cost() * 35;
                    if (value > bestValue) {
                        bestValue = value;
                        plan = new Plan(first, PowerupType.EXTRA_MOVE, null);
                    }
                }
            }
        }
        if (!activeExtra && bot.revivablePawns() > 0 && bot.brainPoints() >= PowerupType.REVIVE_PAWN.cost()) {
            // Inspect all legal placements, then spend engine time on the eight most promising ranks/files.
            var placements = new ArrayList<Map.Entry<String, String>>();
            for (int rank = 2; rank <= 7; rank++) for (char file = 'a'; file <= 'h'; file++) {
                String square = "" + file + rank;
                try {
                    String revived = chess.revivePawn(match.fen(), bot.side(), square);
                    placements.add(Map.entry(square, chess.withSideToMove(revived, opposite(bot.side()))));
                } catch (ApiException ignored) { }
            }
            placements.sort(Comparator.comparingDouble((Map.Entry<String, String> e) ->
                    placementPriority(e.getKey(), bot.side())).reversed());
            for (var placement : placements.stream().limit(8).toList()) {
                var replies = chess.legalMoves(placement.getValue());
                if (replies.isEmpty()) continue;
                var evaluated = engine.analyze(placement.getValue(), BotDifficulty.EXPERT, 60, replies, 1);
                if (!evaluated.isEmpty()) {
                    // Opponent moves next: invert their evaluation, not their turn.
                    int value = -evaluated.getFirst().scoreCp() - PowerupType.REVIVE_PAWN.cost() * 35;
                    if (value > bestValue) {
                        bestValue = value;
                        plan = new Plan(null, PowerupType.REVIVE_PAWN, placement.getKey());
                    }
                }
            }
        }
        return plan;
    }

    List<LegalMoveResponse> allowedMoves(String fen, String side, boolean firstExtraMove) {
        var legal = chess.legalMoves(fen);
        if (!firstExtraMove) return legal;
        return legal.stream().filter(move -> {
            var result = chess.applyMove(fen, command(move), side);
            return !result.check() && !result.checkmate() && !result.stalemate() && !result.draw();
        }).toList();
    }

    private double placementPriority(String square, String side) {
        int rank = square.charAt(1) - '0';
        return (side.equals("WHITE") ? rank : 9 - rank) * 10 - Math.abs(square.charAt(0) - 'd');
    }

    private LegalMoveResponse find(List<LegalMoveResponse> legal, String uci) {
        return legal.stream().filter(m -> StockfishEngine.uci(m).equals(uci)).findFirst().orElseThrow();
    }

    private ChessMove command(LegalMoveResponse move) { return new ChessMove(move.from(), move.to(), move.promotion()); }
    private String opposite(String side) { return "WHITE".equals(side) ? "BLACK" : "WHITE"; }
}
