package com.chessbraining.api;

import com.chessbraining.api.match.PieceSwitchEngine;
import com.chessbraining.api.match.PieceSwitchEngine.*;
import com.chessbraining.api.common.ApiException;
import java.util.List;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class PieceSwitchEngineTests {
    private final List<Question> questions = List.of(
        new Question("COLOR", 0, 1, 3, false, 0),
        new Question("PIECE", 0, 1, 3, false, 0),
        new Question("COUNT", 0, 1, 3, false, 0));
    private State started() {
        return PieceSwitchEngine.ready(PieceSwitchEngine.ready(PieceSwitchEngine.initial(0), "WHITE", 0), "BLACK", 0);
    }
    private Submission batch(List<Answer> events) { return new Submission("player", "round", events, false); }
    @Test void fixedButtonsHaveDifferentAnswersForSameCard() {
        assertEquals(List.of(0,1,2), questions.stream().map(Question::solution).toList());
    }
    @Test void bothPlayersShareCountdownAndReadinessIsIdempotent() {
        var one = PieceSwitchEngine.ready(PieceSwitchEngine.initial(0), "WHITE", 500);
        assertEquals(20_000, PieceSwitchEngine.start(one));
        var two = PieceSwitchEngine.ready(one, "BLACK", 1000);
        assertEquals(4000, PieceSwitchEngine.start(two));
        assertEquals(two, PieceSwitchEngine.ready(two, "BLACK", 1500));
        assertEquals(49_000, PieceSwitchEngine.end(two));
    }
    @Test void duplicateAndOlderSnapshotsCannotChangeScore() {
        var answers = List.of(new Answer(0,0,200), new Answer(1,0,500));
        var state = PieceSwitchEngine.submit(started(), "WHITE", questions, batch(answers), 4000);
        assertEquals(0, PieceSwitchEngine.score(state, "WHITE", questions));
        assertEquals(state, PieceSwitchEngine.submit(state, "WHITE", questions, batch(answers), 4500));
        assertEquals(state, PieceSwitchEngine.submit(state, "WHITE", questions, batch(answers.subList(0,1)), 4500));
        assertThrows(ApiException.class, () -> PieceSwitchEngine.submit(state, "WHITE", questions, batch(List.of(new Answer(0,1,200))), 4500));
    }
    @Test void wrongAnswersCanProduceNegativeScoresAndEnforceCooldown() {
        var first = List.of(new Answer(0,1,100));
        var state = PieceSwitchEngine.submit(started(), "WHITE", questions, batch(first), 4000);
        assertEquals(-1, PieceSwitchEngine.score(state, "WHITE", questions));
        assertThrows(ApiException.class, () -> PieceSwitchEngine.submit(state, "WHITE", questions, batch(List.of(first.getFirst(),new Answer(1,1,200))), 4000));
    }
    @Test void futureOutOfOrderEarlyFinalAndLateEventsAreRejectedOrIgnored() {
        assertThrows(ApiException.class, () -> PieceSwitchEngine.submit(started(), "WHITE", questions, batch(List.of(new Answer(1,0,100))), 4000));
        assertThrows(ApiException.class, () -> PieceSwitchEngine.submit(started(), "WHITE", questions, batch(List.of(new Answer(0,0,2000))), 4000));
        assertThrows(ApiException.class, () -> PieceSwitchEngine.submit(started(), "WHITE", questions, new Submission("p","r",List.of(),true), 4000));
        assertEquals(started(), PieceSwitchEngine.submit(started(), "WHITE", questions, batch(List.of(new Answer(0,0,100))), 52_000));
        assertFalse(PieceSwitchEngine.settled(started(), 50_999));
        assertTrue(PieceSwitchEngine.settled(started(), 51_000));
    }
    @Test void questionSetsAreBalancedVariedAndSerializeWithoutLosingState() {
        var set = PieceSwitchEngine.questions();
        assertEquals(243, set.size());
        assertEquals(243, set.stream().distinct().count());
        for (int block=0;block<3;block++) {
            var slice = set.subList(block*81, (block+1)*81);
            assertEquals(81, slice.stream().map(q -> q.rule()+q.color()+q.piece()+q.count()).distinct().count());
            for (int button=0;button<3;button++) { final int b=button; assertEquals(27, slice.stream().filter(q -> q.solution()==b).count()); }
        }
        var mapper = new tools.jackson.databind.ObjectMapper();
        assertEquals(set, PieceSwitchEngine.readQuestions(mapper, PieceSwitchEngine.writeQuestions(mapper,set)));
        assertEquals(started(), PieceSwitchEngine.read(mapper, mapper.writeValueAsString(started())));
        assertNotEquals(set, PieceSwitchEngine.questions());
    }
}
