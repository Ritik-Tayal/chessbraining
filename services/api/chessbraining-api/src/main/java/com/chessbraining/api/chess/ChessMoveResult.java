package com.chessbraining.api.chess;

public record ChessMoveResult(
		String fen,
		String sideToMove,
		boolean check,
		boolean checkmate,
		boolean stalemate,
		boolean draw) {
}
