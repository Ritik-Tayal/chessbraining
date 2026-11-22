package com.chessbraining.api.match;

import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import com.chessbraining.api.common.ApiException;
import org.springframework.http.HttpStatus;
import tools.jackson.databind.ObjectMapper;

/** Shared rules and append-only scoring, independent of the match transport. */
public final class PieceSwitchEngine {
    public static final int DURATION_MS = 45_000;
    public static final int GRACE_MS = 3_000;
    public static final int QUESTION_COUNT = 243;
    private static final SecureRandom RANDOM = new SecureRandom();
    private PieceSwitchEngine() {}

    public record Question(String rule, int color, int piece, int count, boolean dark, int layout) {
        public int solution() { return switch (rule) { case "COLOR" -> color; case "PIECE" -> piece; default -> count - 1; }; }
    }
    public record Answer(int questionIndex, int chosenButton, long elapsedMs) {}
    public record Submission(String playerId, String roundId, List<Answer> answers, boolean finished) {}
    public record PlayerLog(boolean ready, boolean finished, List<Answer> answers) {}
    public record State(long readyDeadline, long startsAt, long revision, PlayerLog white, PlayerLog black) {}
    public record View(long serverNow, long startsAt, long readyDeadline, long revision,
                       boolean whiteReady, boolean blackReady, int whiteAcknowledged, int blackAcknowledged,
                       boolean whiteFinished, boolean blackFinished, long serverReceivedAt) {
        public View timed(long receivedAt) {
            return new View(System.currentTimeMillis(), startsAt, readyDeadline, revision, whiteReady, blackReady,
                    whiteAcknowledged, blackAcknowledged, whiteFinished, blackFinished, receivedAt);
        }
    }

    public static List<Question> questions() {
        List<Question> result = new ArrayList<>();
        var seen = new java.util.HashSet<Question>();
        // Balance rules and answer positions without repeating an exact visual question.
        for (int block = 0; block < 3; block++) {
            List<Question> pool = new ArrayList<>();
            for (String rule : List.of("COLOR", "PIECE", "COUNT"))
                for (int c = 0; c < 3; c++) for (int p = 0; p < 3; p++) for (int n = 1; n <= 3; n++)
                    {
                        int variant = RANDOM.nextInt(6);
                        for (int attempt = 0; attempt < 6; attempt++) {
                            int visual = (variant + attempt) % 6;
                            Question question = new Question(rule, c, p, n, visual >= 3, visual % 3);
                            if (seen.add(question)) { pool.add(question); break; }
                        }
                    }
            Collections.shuffle(pool, RANDOM);
            while (!pool.isEmpty()) {
                Question previous = result.isEmpty() ? null : result.getLast();
                int selected = 0;
                for (int i = 0; i < pool.size(); i++) {
                    Question q = pool.get(i);
                    boolean repeatCard = previous != null && q.color == previous.color && q.piece == previous.piece && q.count == previous.count;
                    boolean longRun = result.size() >= 2 && previous.rule.equals(q.rule) && result.get(result.size()-2).rule.equals(q.rule);
                    if (!repeatCard && !longRun) { selected = i; break; }
                }
                result.add(pool.remove(selected));
            }
        }
        return List.copyOf(result);
    }

    public static State initial(long now) {
        return new State(now + 20_000, 0, 0, new PlayerLog(false, false, List.of()), new PlayerLog(false, false, List.of()));
    }
    public static State ready(State s, String side, long now) {
        PlayerLog p = player(s, side);
        if (p.ready) return s;
        PlayerLog next = new PlayerLog(true, p.finished, p.answers);
        State updated = replace(s, side, next);
        long start = updated.white.ready && updated.black.ready ? Math.min(now + 3_000, s.readyDeadline) : s.startsAt;
        return new State(s.readyDeadline, start, updated.revision, updated.white, updated.black);
    }
    public static long start(State s) { return s.startsAt == 0 ? s.readyDeadline : s.startsAt; }
    public static long end(State s) { return start(s) + DURATION_MS; }
    public static boolean settled(State s, long now) {
        return now >= end(s) + GRACE_MS || (now >= end(s) && s.white.finished && s.black.finished);
    }
    public static PlayerLog player(State s, String side) { return "WHITE".equals(side) ? s.white : s.black; }
    public static State submit(State s, String side, List<Question> questions, Submission request, long now) {
        if (request == null || request.answers == null || request.answers.size() > questions.size()) invalid("Invalid answer batch.");
        PlayerLog p = player(s, side);
        if (now >= end(s) + GRACE_MS) return s;
        List<Answer> batch = request.answers;
        if (batch.stream().anyMatch(java.util.Objects::isNull)) invalid("An answer entry is required.");
        if (batch.size() < p.answers.size()) {
            for (int i=0; i<batch.size(); i++) if (!batch.get(i).equals(p.answers.get(i))) invalid("An accepted answer cannot change.");
            return s; // An older in-flight snapshot must not undo a newer one.
        }
        for (int i=0; i<p.answers.size(); i++) if (!p.answers.get(i).equals(batch.get(i))) invalid("An accepted answer cannot change.");
        if (p.finished) { if (batch.size() != p.answers.size()) invalid("Your round has finished."); return s; }
        if (batch.size() == p.answers.size() && !request.finished) return s;
        // The immutable prefix was already validated; only the appended tail needs timing checks.
        long minimum = 0;
        if (!p.answers.isEmpty()) {
            Answer last = p.answers.getLast();
            minimum = last.elapsedMs + (last.chosenButton == questions.get(last.questionIndex).solution() ? 150 : 600);
        }
        for (int i=p.answers.size(); i<batch.size(); i++) {
            Answer a = batch.get(i);
            if (a == null || a.questionIndex != i || a.chosenButton < 0 || a.chosenButton > 2 || a.elapsedMs < minimum
                    || a.elapsedMs >= DURATION_MS || a.elapsedMs > now - start(s) + 100) invalid("Invalid answer order or timing.");
            minimum = a.elapsedMs + (a.chosenButton == questions.get(i).solution() ? 150 : 600);
        }
        if (request.finished && now < end(s) && batch.size() < questions.size()) invalid("The timer is still running.");
        return replace(s, side, new PlayerLog(p.ready, request.finished, List.copyOf(batch)));
    }
    public static int score(State s, String side, List<Question> questions) {
        return player(s, side).answers.stream().mapToInt(a -> a.chosenButton == questions.get(a.questionIndex).solution() ? 1 : -1).sum();
    }
    private static State replace(State s, String side, PlayerLog p) {
        return new State(s.readyDeadline, s.startsAt, s.revision + 1, "WHITE".equals(side) ? p : s.white, "BLACK".equals(side) ? p : s.black);
    }
    public static View view(State s) {
        return new View(System.currentTimeMillis(), start(s), s.readyDeadline, s.revision, s.white.ready, s.black.ready,
                s.white.answers.size(), s.black.answers.size(), s.white.finished, s.black.finished, System.currentTimeMillis());
    }
    public static State read(ObjectMapper mapper, String json) { return mapper.readValue(json, State.class); }
    public static List<Question> readQuestions(ObjectMapper mapper, String json) {
        return List.of(mapper.readValue(json, String[].class)).stream().map(q -> mapper.readValue(q, Question.class)).toList();
    }
    public static String writeQuestions(ObjectMapper mapper, List<Question> questions) {
        return mapper.writeValueAsString(questions.stream().map(mapper::writeValueAsString).toList());
    }
    private static void invalid(String message) { throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_PIECE_SWITCH_SUBMISSION", message); }
}
