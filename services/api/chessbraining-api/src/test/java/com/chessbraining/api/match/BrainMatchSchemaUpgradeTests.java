package com.chessbraining.api.match;

import java.sql.DriverManager;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

class BrainMatchSchemaUpgradeTests {
    @Test
    void upgradesExistingPostgresConstraintWithoutLosingRowsAndIsRepeatable() throws Exception {
        String url = System.getenv("SCHEMA_TEST_JDBC_URL");
        assumeTrue(url != null, "Set SCHEMA_TEST_JDBC_URL to run the PostgreSQL upgrade regression.");
        try (var connection = DriverManager.getConnection(url,
                System.getenv("SCHEMA_TEST_DB_USER"), System.getenv("SCHEMA_TEST_DB_PASSWORD"));
                var statement = connection.createStatement()) {
            String schema = "upgrade_test_" + UUID.randomUUID().toString().replace("-", "");
            statement.execute("CREATE SCHEMA " + schema);
            connection.setSchema(schema);
            try {
                statement.execute("CREATE TABLE brain_matches (mode varchar(32) NOT NULL CONSTRAINT brain_matches_mode_check CHECK (mode IN ('RANDOM','MENTAL_MATH','DOT_CONNECT','MEMORY')))");
                statement.execute("INSERT INTO brain_matches VALUES ('MEMORY')");
                assertThrows(java.sql.SQLException.class, () -> statement.execute("INSERT INTO brain_matches VALUES ('PIECE_SWITCH')"));
                BrainMatchSchemaUpgrade.upgrade(connection);
                BrainMatchSchemaUpgrade.upgrade(connection);
                statement.execute("INSERT INTO brain_matches VALUES ('PIECE_SWITCH')");
                try (var rows = statement.executeQuery("SELECT count(*) FROM brain_matches")) {
                    assertTrue(rows.next());
                    assertEquals(2, rows.getInt(1));
                }
                assertThrows(java.sql.SQLException.class, () -> statement.execute("INSERT INTO brain_matches VALUES ('INVALID')"));
            } finally {
                statement.execute("DROP SCHEMA " + schema + " CASCADE");
            }
        }
    }
}
