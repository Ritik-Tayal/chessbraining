package com.chessbraining.api.match;

import java.util.Optional;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;

public interface BrainRoundRepository extends JpaRepository<BrainRoundEntity, String> {

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	Optional<BrainRoundEntity> findFirstByMatchIdAndStatusOrderByRoundNumberDesc(String matchId, String status);

	Optional<BrainRoundEntity> findFirstByMatchIdAndStatusOrderByStartedAtDesc(String matchId, String status);
}
