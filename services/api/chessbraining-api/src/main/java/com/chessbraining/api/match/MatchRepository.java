package com.chessbraining.api.match;

import java.time.Instant;
import java.util.Optional;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface MatchRepository extends JpaRepository<MatchEntity, String> {

	Optional<MatchEntity> findByInviteCode(String inviteCode);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("select m from MatchEntity m where m.id = :id")
	Optional<MatchEntity> findByIdForUpdate(@Param("id") String id);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("select m from MatchEntity m where m.inviteCode = :inviteCode")
	Optional<MatchEntity> findByInviteCodeForUpdate(@Param("inviteCode") String inviteCode);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	Optional<MatchEntity> findFirstByStatusAndMatchmakingModeAndWhitePlayerIdAndCreatedAtAfterOrderByCreatedAtAsc(
			MatchStatus status,
			MatchmakingMode matchmakingMode,
			String whitePlayerId,
			Instant createdAt);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	Optional<MatchEntity> findFirstByStatusAndMatchmakingModeAndWhitePlayerIdNotAndCreatedAtAfterOrderByCreatedAtAsc(
			MatchStatus status,
			MatchmakingMode matchmakingMode,
			String whitePlayerId,
			Instant createdAt);

	boolean existsByInviteCode(String inviteCode);
}
