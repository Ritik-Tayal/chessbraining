package com.chessbraining.api.profile;

import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/players")
public class GuestProfileController {

	private final GuestProfileService profileService;

	public GuestProfileController(GuestProfileService profileService) {
		this.profileService = profileService;
	}

	@GetMapping("/{playerId}/profile")
	public GuestProfileResponse getProfile(@PathVariable String playerId) {
		return profileService.getProfile(playerId);
	}

	@PutMapping("/{playerId}/profile")
	public GuestProfileResponse updateProfile(
			@PathVariable String playerId,
			@RequestBody(required = false) UpdateGuestProfileRequest request) {
		return profileService.upsertProfile(playerId, request);
	}

	@DeleteMapping("/{playerId}/profile")
	public DeleteGuestProfileResponse deleteProfile(@PathVariable String playerId) {
		return profileService.deleteProfile(playerId);
	}
}
