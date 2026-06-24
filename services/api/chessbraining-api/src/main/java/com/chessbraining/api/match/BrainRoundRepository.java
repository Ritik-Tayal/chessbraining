package com.chessbraining.api.match;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

public interface BrainRoundRepository extends JpaRepository<BrainRoundEntity, String> {

	Optional<BrainRoundEntity> findFirstByMatchIdAndStatusOrderByRoundNumberDesc(String matchId, String status);
}
