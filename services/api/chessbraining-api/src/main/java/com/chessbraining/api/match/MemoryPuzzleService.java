package com.chessbraining.api.match;

import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import com.chessbraining.api.common.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

@Service
public class MemoryPuzzleService {

	private static final int CARD_COUNT = 12;
	private static final int PAIR_COUNT = 6;
	private static final SecureRandom RANDOM = new SecureRandom();
	private static final List<String> PIECES = List.of("PAWN", "KNIGHT", "BISHOP", "ROOK", "QUEEN", "KING");

	public MemoryState newGame() {
		List<String> cards = new ArrayList<>();
		for (String piece : PIECES) {
			cards.add(piece);
			cards.add(piece);
		}
		Collections.shuffle(cards, RANDOM);
		return new MemoryState(cards, 0, "WHITE", List.of(), false, null);
	}

	public TurnResult playTurn(MemoryState state, String side, int firstIndex, int secondIndex) {
		if (!state.turnSide().equals(side)) {
			throw new ApiException(HttpStatus.CONFLICT, "NOT_YOUR_MEMORY_TURN",
					"It is not this player's memory turn.");
		}
		if (state.pendingFirstIndex() == null && secondIndex < 0) {
			validatePlayableCard(state, firstIndex);
			MemoryState nextState = new MemoryState(
					state.cards(),
					state.matchedMask(),
					state.turnSide(),
					List.of(firstIndex),
					false,
					firstIndex);
			return new TurnResult(nextState, false, false);
		}

		int resolvedFirstIndex = state.pendingFirstIndex() == null ? firstIndex : state.pendingFirstIndex();
		int resolvedSecondIndex = secondIndex;
		if (resolvedSecondIndex == resolvedFirstIndex && state.pendingFirstIndex() != null) {
			resolvedSecondIndex = firstIndex;
		}
		validateIndex(resolvedFirstIndex);
		validateIndex(resolvedSecondIndex);
		if (resolvedFirstIndex == resolvedSecondIndex) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "DUPLICATE_MEMORY_CARD",
					"Choose two different cards.");
		}
		validatePlayableCard(state, resolvedFirstIndex);
		validatePlayableCard(state, resolvedSecondIndex);

		boolean matched = state.cards().get(resolvedFirstIndex).equals(state.cards().get(resolvedSecondIndex));
		int matchedMask = state.matchedMask();
		String nextTurnSide = state.turnSide();
		if (matched) {
			matchedMask |= (1 << resolvedFirstIndex);
			matchedMask |= (1 << resolvedSecondIndex);
		} else {
			nextTurnSide = "WHITE".equals(side) ? "BLACK" : "WHITE";
		}

		MemoryState nextState = new MemoryState(
				state.cards(),
				matchedMask,
				nextTurnSide,
				List.of(resolvedFirstIndex, resolvedSecondIndex),
				matched,
				null);
		return new TurnResult(nextState, matched, allMatched(nextState));
	}

	public String publicBoardJson(MemoryState state) {
		StringBuilder builder = new StringBuilder();
		builder.append("{\"turnSide\":\"").append(state.turnSide()).append("\",");
		builder.append("\"lastMatched\":").append(state.lastMatched()).append(',');
		builder.append("\"lastFlipped\":").append(indexArray(state.lastFlipped())).append(',');
		builder.append("\"pendingFirstIndex\":");
		if (state.pendingFirstIndex() == null) {
			builder.append("null");
		} else {
			builder.append(state.pendingFirstIndex());
		}
		builder.append(',');
		builder.append("\"cards\":[");
		for (int i = 0; i < CARD_COUNT; i++) {
			if (i > 0) {
				builder.append(',');
			}
			boolean matched = isMatched(state, i);
			boolean revealed = matched ||
					(state.pendingFirstIndex() != null && state.pendingFirstIndex() == i);
			builder.append("{\"index\":").append(i)
					.append(",\"matched\":").append(matched)
					.append(",\"revealed\":").append(revealed)
					.append(",\"piece\":");
			if (revealed) {
				builder.append('\"').append(state.cards().get(i)).append('\"');
			} else {
				builder.append("null");
			}
			builder.append('}');
		}
		builder.append("]}");
		return builder.toString();
	}

	public boolean allMatched(MemoryState state) {
		return state.matchedMask() == ((1 << CARD_COUNT) - 1);
	}

	public int pairCount() {
		return PAIR_COUNT;
	}

	private void validateIndex(int index) {
		if (index < 0 || index >= CARD_COUNT) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_MEMORY_CARD",
					"Memory card index is out of range.");
		}
	}

	private void validatePlayableCard(MemoryState state, int index) {
		validateIndex(index);
		if (isMatched(state, index)) {
			throw new ApiException(HttpStatus.CONFLICT, "MEMORY_CARD_ALREADY_MATCHED",
					"One of these cards has already been matched.");
		}
	}

	private boolean isMatched(MemoryState state, int index) {
		return (state.matchedMask() & (1 << index)) != 0;
	}

	private String indexArray(List<Integer> indexes) {
		StringBuilder builder = new StringBuilder("[");
		for (int i = 0; i < indexes.size(); i++) {
			if (i > 0) {
				builder.append(',');
			}
			builder.append(indexes.get(i));
		}
		return builder.append(']').toString();
	}

	public record MemoryState(
			List<String> cards,
			int matchedMask,
			String turnSide,
			List<Integer> lastFlipped,
			boolean lastMatched,
			Integer pendingFirstIndex) {
	}

	public record TurnResult(
			MemoryState state,
			boolean matched,
			boolean completed) {
	}
}
