package com.chessbraining.api.match;

import java.util.Optional;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.transaction.annotation.Transactional;

public interface BrainRoundRepository extends JpaRepository<BrainRoundEntity, String> {

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	Optional<BrainRoundEntity> findFirstByMatchIdAndStatusOrderByRoundNumberDesc(String matchId, String status);

	@Transactional(readOnly = true)
	Optional<BrainRoundEntity> findTopByMatchIdAndStatusOrderByRoundNumberDesc(String matchId, String status);

	// PostgreSQL eagerly reads @Lob fields through its transactional large-object API.
	@Transactional(readOnly = true)
	Optional<BrainRoundEntity> findFirstByMatchIdAndStatusOrderByStartedAtDesc(String matchId, String status);
}
