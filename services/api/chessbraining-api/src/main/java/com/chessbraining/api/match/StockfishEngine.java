package com.chessbraining.api.match;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.locks.ReentrantLock;
import java.util.regex.Pattern;

import com.chessbraining.api.chess.LegalMoveResponse;
import com.chessbraining.api.common.ApiException;
import jakarta.annotation.PreDestroy;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/** One bounded UCI worker per API instance; engine work never holds a database transaction. */
@Service
public class StockfishEngine {
    private static final Logger LOG = LoggerFactory.getLogger(StockfishEngine.class);
    private static final Pattern SCORE = Pattern.compile("\\bscore (cp|mate) (-?\\d+)");
    private static final Pattern PV = Pattern.compile("\\bpv ([a-h][1-8][a-h][1-8][qrbn]?)");
    private static final String EOF = "<engine-eof>";
    private final String executable;
    private final boolean required;
    private final int hashMb;
    private final ReentrantLock lock = new ReentrantLock(true);
    private Process process;
    private BufferedWriter input;
    private BlockingQueue<String> output;
    private long retryAt;

    public StockfishEngine(@Value("${bot.stockfish.path:stockfish}") String executable,
                           @Value("${bot.stockfish.required:false}") boolean required,
                           @Value("${bot.stockfish.hash-mb:32}") int hashMb) {
        this.executable = executable;
        this.required = required;
        this.hashMb = Math.clamp(hashMb, 16, 128);
    }

    public boolean required() { return required; }

    public void requireAvailable() {
        if (!required) return;
        try {
            if (!lock.tryLock(2, TimeUnit.SECONDS)) throw new IOException("Engine busy");
            try { ensureStarted(); } finally { lock.unlock(); }
        } catch (IOException e) {
            LOG.warn("Stockfish startup unavailable: {}", e.getMessage());
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "BOT_ENGINE_UNAVAILABLE",
                    "The chess engine is temporarily unavailable. Please try again shortly.");
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "BOT_ENGINE_UNAVAILABLE", "Chess engine interrupted.");
        }
    }

    public record Analysis(String move, int scoreCp) { }

    public List<Analysis> analyze(String fen, BotDifficulty difficulty, int millis,
                                  List<LegalMoveResponse> legalMoves, int variations) {
        if (legalMoves.isEmpty()) return List.of();
        if (fen == null || fen.contains("\n") || fen.contains("\r"))
            throw new IllegalArgumentException("Invalid engine position");
        boolean acquired = false;
        try {
            acquired = lock.tryLock(2, TimeUnit.SECONDS);
            if (!acquired) return List.of();
            ensureStarted();
            send("ucinewgame");
            send("setoption name Skill Level value " + (difficulty == BotDifficulty.EASY ? 2 : 20));
            send("setoption name UCI_LimitStrength value " + (difficulty == BotDifficulty.NORMAL || difficulty == BotDifficulty.HARD));
            if (difficulty == BotDifficulty.NORMAL || difficulty == BotDifficulty.HARD)
                send("setoption name UCI_Elo value " + difficulty.targetElo());
            send("setoption name MultiPV value " + Math.clamp(variations, 1, 4));
            send("isready");
            await("readyok", 3000);
            send("position fen " + engineFen(fen));
            String roots = String.join(" ", legalMoves.stream().map(StockfishEngine::uci).toList());
            send("go movetime " + Math.clamp(millis, 30, 2000) + " searchmoves " + roots);
            long deadline = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(millis + 2000L);
            Map<String, Integer> scores = new LinkedHashMap<>();
            while (true) {
                String line = read(deadline);
                if (line.startsWith("bestmove ")) {
                    String best = line.split("\\s+")[1];
                    if (legalMoves.stream().noneMatch(m -> uci(m).equals(best)))
                        throw new IOException("Engine returned a move outside legal roots");
                    List<Analysis> result = new ArrayList<>();
                    result.add(new Analysis(best, scores.getOrDefault(best, 0)));
                    scores.entrySet().stream().filter(e -> !e.getKey().equals(best))
                            .sorted(Map.Entry.<String, Integer>comparingByValue().reversed())
                            .filter(e -> legalMoves.stream().anyMatch(m -> uci(m).equals(e.getKey())))
                            .limit(Math.max(0, variations - 1))
                            .forEach(e -> result.add(new Analysis(e.getKey(), e.getValue())));
                    return result;
                }
                var score = SCORE.matcher(line);
                var pv = PV.matcher(line);
                if (score.find() && pv.find()) {
                    int value = Integer.parseInt(score.group(2));
                    if (score.group(1).equals("mate")) value = Integer.signum(value) * (100000 - Math.min(999, Math.abs(value)));
                    scores.put(pv.group(1), value);
                }
            }
        } catch (IOException | RuntimeException e) {
            if (acquired) {
                LOG.warn("Stockfish search unavailable: {}", e.getMessage());
                stop();
                retryAt = System.currentTimeMillis() + 2000;
            }
            return List.of();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            if (acquired) stop();
            return List.of();
        } finally {
            if (acquired) lock.unlock();
        }
    }

    public static String uci(LegalMoveResponse move) {
        return move.from() + move.to() + (move.promotion() == null ? "" : move.promotion().toLowerCase(Locale.ROOT));
    }

    private String engineFen(String fen) {
        String[] fields = fen.split("\\s+");
        if (fields.length != 6) throw new IllegalArgumentException("Expected six FEN fields");
        // A retained extra turn can leave an en-passant square belonging to the other side.
        if (!fields[3].equals("-") && !fields[3].endsWith(fields[1].equals("w") ? "6" : "3"))
            fields[3] = "-";
        return String.join(" ", fields);
    }

    private void ensureStarted() throws IOException, InterruptedException {
        if (process != null && process.isAlive()) return;
        if (System.currentTimeMillis() < retryAt) throw new IOException("Engine restarting");
        process = new ProcessBuilder(executable).redirectErrorStream(true).start();
        input = process.outputWriter(StandardCharsets.UTF_8);
        var queue = new ArrayBlockingQueue<String>(2048);
        output = queue;
        Process running = process;
        // Process pipes block in native I/O on JDK 21; isolate them from virtual-thread carriers.
        Thread.ofPlatform().daemon(true).name("stockfish-output").start(() -> {
            try (var reader = running.inputReader(StandardCharsets.UTF_8)) {
                String line;
                while ((line = reader.readLine()) != null) {
                    if (!queue.offer(line)) { running.destroyForcibly(); break; }
                }
            } catch (IOException ignored) {
                // EOF below wakes a pending search on process failure.
            } finally { queue.offer(EOF); }
        });
        try {
            send("uci");
            await("uciok", 10000);
            send("setoption name Threads value 1");
            send("setoption name Hash value " + hashMb);
            send("isready");
            await("readyok", 10000);
            LOG.info("Stockfish UCI worker ready (1 thread, {} MiB hash)", hashMb);
        } catch (IOException | InterruptedException e) { stop(); throw e; }
    }

    private void send(String command) throws IOException {
        input.write(command);
        input.newLine();
        input.flush();
    }

    private void await(String expected, int timeoutMs) throws IOException, InterruptedException {
        long deadline = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(timeoutMs);
        try {
            while (!read(deadline).equals(expected)) { }
        } catch (IOException e) {
            throw new IOException("Waiting for " + expected + ": " + e.getMessage(), e);
        }
    }

    private String read(long deadline) throws IOException, InterruptedException {
        long remaining = deadline - System.nanoTime();
        String line = remaining <= 0 ? null : output.poll(remaining, TimeUnit.NANOSECONDS);
        if (line == null || line.equals(EOF)) throw new IOException("Engine timed out or exited");
        return line;
    }

    private void stop() {
        if (process != null) process.destroyForcibly();
        process = null;
        input = null;
    }

    @PreDestroy
    public void close() {
        lock.lock();
        try { stop(); } finally { lock.unlock(); }
    }
}
