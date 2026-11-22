package com.chessbraining.api.match;

import java.sql.Connection;
import javax.sql.DataSource;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.context.annotation.DependsOn;
import org.springframework.stereotype.Component;

/** Additive compatibility upgrade for databases created before Piece Switch. */
@Component
@DependsOn("entityManagerFactory")
public class BrainMatchSchemaUpgrade implements InitializingBean {

    private static final Logger log = LoggerFactory.getLogger(BrainMatchSchemaUpgrade.class);

    private final DataSource dataSource;

    public BrainMatchSchemaUpgrade(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    @Override
    public void afterPropertiesSet() throws Exception {
        try (Connection connection = dataSource.getConnection()) {
            if (!"PostgreSQL".equals(connection.getMetaData().getDatabaseProductName())) return;
            upgrade(connection);
        }
    }

    static void upgrade(Connection connection) throws java.sql.SQLException {
        boolean autoCommit = connection.getAutoCommit();
        connection.setAutoCommit(false);
        try (var statement = connection.createStatement()) {
            statement.execute("SET LOCAL lock_timeout = '10s'");
            // Serialize concurrent instance startups; DDL replacement is atomic.
            statement.execute("SELECT pg_advisory_xact_lock(7291843201)");
            try (var result = statement.executeQuery("""
                    SELECT pg_get_constraintdef(oid) FROM pg_constraint
                    WHERE conrelid = to_regclass('brain_matches')
                      AND conname = 'brain_matches_mode_check'
                    """)) {
                if (!result.next() || result.getString(1).contains("PIECE_SWITCH")) {
                    connection.commit();
                    return;
                }
            }
            statement.execute("ALTER TABLE brain_matches DROP CONSTRAINT brain_matches_mode_check");
            statement.execute("""
                    ALTER TABLE brain_matches ADD CONSTRAINT brain_matches_mode_check
                    CHECK (mode IN ('RANDOM', 'MENTAL_MATH', 'DOT_CONNECT', 'MEMORY', 'PIECE_SWITCH'))
                    """);
            connection.commit();
            log.info("Upgraded brain_matches mode constraint to support Piece Switch");
        } catch (java.sql.SQLException exception) {
            connection.rollback();
            throw exception;
        } finally {
            connection.setAutoCommit(autoCommit);
        }
    }
}
