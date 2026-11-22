package com.chessbraining.api.match;

import java.time.Instant;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import static org.junit.jupiter.api.Assertions.*;

@EnabledIfEnvironmentVariable(named = "SCHEMA_TEST_JDBC_URL", matches = ".+")
@SpringBootTest(properties = {
        "spring.datasource.url=${SCHEMA_TEST_JDBC_URL}",
        "spring.datasource.username=${SCHEMA_TEST_DB_USER}",
        "spring.datasource.password=${SCHEMA_TEST_DB_PASSWORD}",
        "spring.datasource.driver-class-name=org.postgresql.Driver",
        "spring.jpa.database-platform=org.hibernate.dialect.PostgreSQLDialect",
        "spring.jpa.hibernate.ddl-auto=update"
})
@DirtiesContext
class PostgresBrainRoundTests {
    @Autowired MatchService matches;
    @Autowired BrainRoundService rounds;
    @Autowired BrainRoundRepository repository;
    @Autowired MatchRepository matchRepository;
    @Autowired MemoryPuzzleService memory;
    @Autowired tools.jackson.databind.ObjectMapper mapper;
    @Autowired PlatformTransactionManager transactions;

    @Test
    void memorySubmissionAndPollingUseTheSameLockOrder() throws Exception {
        String white = "pg_memory_" + UUID.randomUUID();
        String black = white + "_b";
        var match = matches.createMatch(new CreateMatchRequest(white, "White", 600, 1));
        matches.joinMatch(new JoinMatchRequest(match.inviteCode(), black, "Black"));
        matches.submitMove(match.matchId(), new SubmitMoveRequest(white, "e2", "e4", null));
        matches.submitMove(match.matchId(), new SubmitMoveRequest(black, "e7", "e5", null));
        var round = repository.findFirstByMatchIdAndStatusOrderByStartedAtDesc(match.matchId(), "ACTIVE").orElseThrow();
        var state = memory.newGame();
        round.setPuzzleType("MEMORY");
        round.setTotalQuestions(12);
        round.setPuzzleAnswers(mapper.writeValueAsString(state));
        round.setPuzzleExpressions(mapper.writeValueAsString(new String[] {memory.publicBoardJson(state)}));
        round.setExpiresAt(Instant.now().plusSeconds(120));
        repository.save(round);
        var parentLocked = new CountDownLatch(1);
        var submissionStarted = new CountDownLatch(1);
        try (var executor = Executors.newFixedThreadPool(2)) {
            var poll = executor.submit(() -> new TransactionTemplate(transactions).execute(status -> {
                matchRepository.findByIdForUpdate(match.matchId()).orElseThrow();
                parentLocked.countDown();
                try {
                    assertTrue(submissionStarted.await(5, TimeUnit.SECONDS));
                    // Let the competing request reach its first database lock.
                    Thread.sleep(250);
                } catch (InterruptedException exception) {
                    Thread.currentThread().interrupt();
                    throw new IllegalStateException(exception);
                }
                return rounds.getCurrentRound(match.matchId());
            }));
            var submit = executor.submit(() -> {
                assertTrue(parentLocked.await(5, TimeUnit.SECONDS));
                submissionStarted.countDown();
                return rounds.submitMemoryTurn(match.matchId(), new SubmitMemoryTurnRequest(white, 0, -1));
            });
            assertNotNull(poll.get(10, TimeUnit.SECONDS));
            assertNotNull(submit.get(10, TimeUnit.SECONDS));
        }
    }

    @Test
    void botRepositoryReadsLobsAndCompletedResultsDoNotTakeWriteLocksInReadOnlyTransactions() {
        String white = "pg_white_" + UUID.randomUUID();
        String black = "pg_black_" + UUID.randomUUID();
        var match = matches.createMatch(new CreateMatchRequest(white, "White", 600, 1));
        matches.joinMatch(new JoinMatchRequest(match.inviteCode(), black, "Black"));
        matches.submitMove(match.matchId(), new SubmitMoveRequest(white, "e2", "e4", null));
        matches.submitMove(match.matchId(), new SubmitMoveRequest(black, "e7", "e5", null));
        // This derived finder is also used by background bot workers, with no outer transaction.
        var round = repository.findFirstByMatchIdAndStatusOrderByStartedAtDesc(match.matchId(), "ACTIVE").orElseThrow();
        assertNotNull(round.getPuzzleAnswers());
        assertNotNull(round.getPuzzleExpressions());
        round.setStatus("COMPLETED");
        round.setCompletedAt(Instant.now());
        repository.save(round);
        assertEquals(round.getId(), rounds.getLatestResult(match.matchId()).roundId());
    }
}
