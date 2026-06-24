package com.chessbraining.api.chess;

import java.util.List;
import java.util.Locale;

import com.chessbraining.api.common.ApiException;
import com.github.bhlangonijr.chesslib.Board;
import com.github.bhlangonijr.chesslib.Piece;
import com.github.bhlangonijr.chesslib.Side;
import com.github.bhlangonijr.chesslib.Square;
import com.github.bhlangonijr.chesslib.move.Move;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

@Service
public class ChessService {

	public static final String STARTING_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

	public ChessMoveResult applyMove(String fen, ChessMove command, String expectedSide) {
		Board board = loadBoard(fen);

		if (!board.getSideToMove().name().equals(expectedSide)) {
			throw new ApiException(HttpStatus.CONFLICT, "NOT_SIDE_TO_MOVE",
					"It is " + board.getSideToMove().name() + " to move.");
		}

		Move move = toChessLibMove(command, board.getSideToMove());
		if (!board.legalMoves().contains(move)) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "ILLEGAL_MOVE",
					"Move " + command.from() + command.to() + " is not legal from the current position.");
		}

		board.doMove(move);
		return new ChessMoveResult(
				board.getFen(),
				board.getSideToMove().name(),
				board.isKingAttacked(),
				board.isMated(),
				board.isStaleMate(),
				board.isDraw());
	}

	public List<LegalMoveResponse> legalMoves(String fen) {
		Board board = loadBoard(fen);
		return board.legalMoves().stream()
				.map(move -> new LegalMoveResponse(
						toApiSquare(move.getFrom()),
						toApiSquare(move.getTo()),
						toApiPromotion(move.getPromotion())))
				.toList();
	}

	private Board loadBoard(String fen) {
		Board board = new Board();
		board.loadFromFen(fen);
		return board;
	}

	private Move toChessLibMove(ChessMove command, Side sideToMove) {
		Square from = toSquare(command.from(), "from");
		Square to = toSquare(command.to(), "to");
		Piece promotion = toPromotion(command.promotion(), sideToMove);
		if (promotion == Piece.NONE) {
			return new Move(from, to);
		}
		return new Move(from, to, promotion);
	}

	private Square toSquare(String value, String fieldName) {
		if (value == null || !value.matches("^[a-hA-H][1-8]$")) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_SQUARE",
					"Invalid " + fieldName + " square.");
		}
		return Square.valueOf(value.toUpperCase(Locale.ROOT));
	}

	private Piece toPromotion(String value, Side sideToMove) {
		if (value == null || value.isBlank()) {
			return Piece.NONE;
		}

		String normalized = value.trim().toUpperCase(Locale.ROOT);
		String pieceName = switch (normalized) {
			case "Q", "QUEEN" -> "QUEEN";
			case "R", "ROOK" -> "ROOK";
			case "B", "BISHOP" -> "BISHOP";
			case "N", "KNIGHT" -> "KNIGHT";
			default -> throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_PROMOTION",
					"Promotion must be one of Q, R, B, or N.");
		};

		return Piece.valueOf(sideToMove.name() + "_" + pieceName);
	}

	private String toApiSquare(Square square) {
		return square.name().toLowerCase(Locale.ROOT);
	}

	private String toApiPromotion(Piece piece) {
		if (piece == null || piece == Piece.NONE) {
			return null;
		}

		String name = piece.name();
		if (name.endsWith("_QUEEN")) {
			return "q";
		}
		if (name.endsWith("_ROOK")) {
			return "r";
		}
		if (name.endsWith("_BISHOP")) {
			return "b";
		}
		if (name.endsWith("_KNIGHT")) {
			return "n";
		}
		return null;
	}
}
