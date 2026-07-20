package com.chessbraining.api.profile;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import com.chessbraining.api.match.MatchEntity;
import com.chessbraining.api.match.MatchRepository;
import com.chessbraining.api.match.MatchStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class GuestProfileService {

	private static final int BASE_RATING = 1000;
	private static final int WIN_DELTA = 18;
	private static final int LOSS_DELTA = -14;
	private static final int DRAW_DELTA = 2;

	private final GuestProfileRepository profileRepository;
	private final MatchRepository matchRepository;

	public GuestProfileService(GuestProfileRepository profileRepository, MatchRepository matchRepository) {
		this.profileRepository = profileRepository;
		this.matchRepository = matchRepository;
	}

	@Transactional(readOnly = true)
	public GuestProfileResponse getProfile(String playerId) {
		return buildProfile(playerId, profileRepository.findById(playerId).orElse(null));
	}

	@Transactional
	public GuestProfileResponse upsertProfile(String playerId, UpdateGuestProfileRequest request) {
		GuestProfileEntity profile = profileRepository.findById(playerId).orElseGet(() -> {
			GuestProfileEntity created = new GuestProfileEntity();
			created.setPlayerId(playerId);
			return created;
		});
		profile.setPlayerName(cleanName(request == null ? null : request.playerName(), defaultName(playerId)));
		GuestProfileEntity saved = profileRepository.save(profile);
		return buildProfile(playerId, saved);
	}

	@Transactional
	public DeleteGuestProfileResponse deleteProfile(String playerId) {
		boolean exists = profileRepository.existsById(playerId);
		if (exists) {
			profileRepository.deleteById(playerId);
		}
		return new DeleteGuestProfileResponse(playerId, exists);
	}

	private GuestProfileResponse buildProfile(String playerId, GuestProfileEntity profile) {
		List<MatchEntity> allMatches = matchRepository
				.findByWhitePlayerIdOrBlackPlayerIdOrderByCreatedAtAsc(playerId, playerId);
		int rating = BASE_RATING;
		int wins = 0;
		int losses = 0;
		int draws = 0;
		int activeMatches = 0;
		Map<String, RatingSnapshot> ratings = new HashMap<>();

		for (MatchEntity match : allMatches) {
			String result = resultFor(playerId, match);
			int delta = switch (result) {
				case "WIN" -> WIN_DELTA;
				case "LOSS" -> LOSS_DELTA;
				case "DRAW" -> DRAW_DELTA;
				default -> 0;
			};
			if (match.getStatus() == MatchStatus.COMPLETED) {
				if ("WIN".equals(result)) {
					wins++;
				} else if ("LOSS".equals(result)) {
					losses++;
				} else {
					draws++;
				}
				rating = Math.max(100, rating + delta);
			} else {
				activeMatches++;
			}
			ratings.put(match.getId(), new RatingSnapshot(delta, rating));
		}

		List<MatchHistoryResponse> history = new ArrayList<>();
		for (MatchEntity match : matchRepository
				.findTop20ByWhitePlayerIdOrBlackPlayerIdOrderByCreatedAtDesc(playerId, playerId)) {
			RatingSnapshot snapshot = ratings.getOrDefault(match.getId(), new RatingSnapshot(0, rating));
			history.add(toHistory(playerId, match, snapshot));
		}

		return new GuestProfileResponse(
				playerId,
				profile == null ? defaultName(playerId) : profile.getPlayerName(),
				rating,
				wins + losses + draws,
				activeMatches,
				wins,
				losses,
				draws,
				profile == null ? null : profile.getCreatedAt(),
				profile == null ? null : profile.getUpdatedAt(),
				history);
	}

	private MatchHistoryResponse toHistory(String playerId, MatchEntity match, RatingSnapshot rating) {
		boolean playerIsWhite = playerId.equals(match.getWhitePlayerId());
		String opponentName = playerIsWhite ? match.getBlackPlayerName() : match.getWhitePlayerName();
		boolean opponentBot = playerIsWhite ? match.isBlackBot() : match.isWhiteBot();
		Object difficulty = playerIsWhite ? match.getBlackBotDifficulty() : match.getWhiteBotDifficulty();
		Instant playedAt = match.getCompletedAt() == null ? match.getCreatedAt() : match.getCompletedAt();
		return new MatchHistoryResponse(
				match.getId(),
				match.getInviteCode(),
				opponentName == null ? "Waiting player" : opponentName,
				opponentBot,
				difficulty == null ? null : difficulty.toString(),
				resultFor(playerId, match),
				match.getResultReason(),
				rating.change(),
				rating.after(),
				match.getPlyCount(),
				match.getBrainRoundCount(),
				playedAt);
	}

	private String resultFor(String playerId, MatchEntity match) {
		if (match.getStatus() != MatchStatus.COMPLETED) {
			return match.getStatus().name();
		}
		if (match.getWinnerPlayerId() == null || match.getWinnerPlayerId().isBlank()) {
			return "DRAW";
		}
		return playerId.equals(match.getWinnerPlayerId()) ? "WIN" : "LOSS";
	}

	private String cleanName(String value, String fallback) {
		if (value == null || value.isBlank()) {
			return fallback;
		}
		return value.trim().substring(0, Math.min(value.trim().length(), 80));
	}

	private String defaultName(String playerId) {
		if (playerId == null || playerId.isBlank()) {
			return "Guest Player";
		}
		String suffix = playerId.length() <= 4 ? playerId : playerId.substring(playerId.length() - 4);
		return "Guest " + suffix.toUpperCase(Locale.ROOT);
	}

	private record RatingSnapshot(int change, int after) {
	}
}
