package com.chessbraining.api.match;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

public interface MatchMoveRepository extends JpaRepository<MatchMoveEntity, String> {

	List<MatchMoveEntity> findByMatchIdOrderByPlyNumberAsc(String matchId);
}
