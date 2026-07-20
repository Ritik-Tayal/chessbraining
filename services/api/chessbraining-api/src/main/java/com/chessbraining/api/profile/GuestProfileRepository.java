package com.chessbraining.api.profile;

import org.springframework.data.jpa.repository.JpaRepository;

public interface GuestProfileRepository extends JpaRepository<GuestProfileEntity, String> {
}
