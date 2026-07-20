package com.chessbraining.api.match;

import java.util.Optional;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface BrainMatchRepository extends JpaRepository<BrainMatchEntity, String> {

	Optional<BrainMatchEntity> findByInviteCode(String inviteCode);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("select b from BrainMatchEntity b where b.id = :id")
	Optional<BrainMatchEntity> findByIdForUpdate(@Param("id") String id);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("select b from BrainMatchEntity b where b.inviteCode = :inviteCode")
	Optional<BrainMatchEntity> findByInviteCodeForUpdate(@Param("inviteCode") String inviteCode);

	boolean existsByInviteCode(String inviteCode);
}
