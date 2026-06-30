package com.chessbraining.api.chess;

public record LegalMoveResponse(
		String from,
		String to,
		String promotion) {
}
