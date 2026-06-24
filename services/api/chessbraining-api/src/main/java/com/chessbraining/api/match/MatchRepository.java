package com.chessbraining.api.match;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

public interface MatchRepository extends JpaRepository<MatchEntity, String> {

	Optional<MatchEntity> findByInviteCode(String inviteCode);

	Optional<MatchEntity> findFirstByStatusOrderByCreatedAtAsc(MatchStatus status);

	boolean existsByInviteCode(String inviteCode);
}
