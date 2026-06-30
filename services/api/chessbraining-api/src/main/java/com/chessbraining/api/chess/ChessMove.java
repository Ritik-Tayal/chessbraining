package com.chessbraining.api.chess;

public record ChessMove(
		String from,
		String to,
		String promotion) {
}
