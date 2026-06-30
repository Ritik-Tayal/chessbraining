import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:flutter/material.dart';

import 'fen.dart';
import 'match_controller.dart';

class ChessBoard extends StatelessWidget {
  const ChessBoard({
    required this.controller,
    super.key,
  });

  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    final match = controller.match;
    if (match == null) {
      return const SizedBox.shrink();
    }

    final board = parseFenBoard(match.fen);
    final isBlackPerspective = controller.me?.side == 'BLACK';
    final files = isBlackPerspective
        ? const ['h', 'g', 'f', 'e', 'd', 'c', 'b', 'a']
        : const ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    final ranks = isBlackPerspective
        ? const [1, 2, 3, 4, 5, 6, 7, 8]
        : const [8, 7, 6, 5, 4, 3, 2, 1];
    final lastMove = match.moves.isEmpty ? null : match.moves.last;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xff201f1f),
        border: Border.all(color: const Color(0xff3c4a42)),
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
          ),
          itemCount: 64,
          itemBuilder: (context, index) {
            final fileIndex = index % 8;
            final rankIndex = index ~/ 8;
            final square = '${files[fileIndex]}${ranks[rankIndex]}';
            final piece = board[square];
            final isLight = (fileIndex + rankIndex).isEven;
            final isSelected = controller.selectedSquare == square;
            final isTarget = controller.isLegalTarget(square);
            final isPowerupTarget = controller.isPowerupTarget(square);
            final isLastMove =
                lastMove?.from == square || lastMove?.to == square;

            return _BoardSquare(
              square: square,
              piece: piece,
              isLight: isLight,
              isSelected: isSelected,
              isTarget: isTarget,
              isPowerupTarget: isPowerupTarget,
              isLastMove: isLastMove,
              onTap: () => controller.selectSquare(square),
            );
          },
        ),
      ),
    );
  }
}

class _BoardSquare extends StatelessWidget {
  const _BoardSquare({
    required this.square,
    required this.piece,
    required this.isLight,
    required this.isSelected,
    required this.isTarget,
    required this.isPowerupTarget,
    required this.isLastMove,
    required this.onTap,
  });

  final String square;
  final String? piece;
  final bool isLight;
  final bool isSelected;
  final bool isTarget;
  final bool isPowerupTarget;
  final bool isLastMove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final base = isLight ? const Color(0xff262626) : const Color(0xff121212);
    final pieceValue = piece;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: const Color(0xff10b981).withValues(alpha: 0.14),
        highlightColor: const Color(0xff10b981).withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _squareColor(base),
            border: Border.all(color: _borderColor(), width: _borderWidth()),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 4,
                top: 4,
                child: Text(
                  square,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.28),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isTarget || isPowerupTarget)
                Center(
                  child: Container(
                    width: isPowerupTarget ? 24 : 16,
                    height: isPowerupTarget ? 24 : 16,
                    decoration: BoxDecoration(
                      color: (isPowerupTarget
                              ? const Color(0xfff59e0b)
                              : const Color(0xff3b82f6))
                          .withValues(alpha: 0.32),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isPowerupTarget
                            ? const Color(0xfff59e0b)
                            : const Color(0xff3b82f6),
                      ),
                    ),
                  ),
                ),
              if (pieceValue != null)
                Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.biggest.shortestSide * 0.72;
                      return _PieceVector(piece: pieceValue, size: size);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _squareColor(Color base) {
    if (isSelected) {
      return const Color(0xff073b2c);
    }
    if (isLastMove) {
      return Color.lerp(base, const Color(0xff3b82f6), 0.22)!;
    }
    if (isPowerupTarget) {
      return Color.lerp(base, const Color(0xfff59e0b), 0.18)!;
    }
    return base;
  }

  Color _borderColor() {
    if (isSelected) {
      return const Color(0xff10b981);
    }
    if (isTarget) {
      return const Color(0xff3b82f6);
    }
    if (isPowerupTarget) {
      return const Color(0xfff59e0b);
    }
    if (isLastMove) {
      return const Color(0xff3b82f6).withValues(alpha: 0.65);
    }
    return Colors.transparent;
  }

  double _borderWidth() {
    if (isSelected || isTarget || isPowerupTarget) {
      return 2;
    }
    if (isLastMove) {
      return 1;
    }
    return 0;
  }
}

class _PieceVector extends StatelessWidget {
  const _PieceVector({
    required this.piece,
    required this.size,
  });

  final String piece;
  final double size;

  @override
  Widget build(BuildContext context) {
    final white = isWhitePiece(piece);
    final fill = white ? const Color(0xff10b981) : const Color(0xff6f7772);
    final stroke = white ? const Color(0xff06261c) : const Color(0xff2a2a2a);

    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: white
            ? [
                BoxShadow(
                  color: const Color(0xff10b981).withValues(alpha: 0.22),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      child: _pieceWidget(piece, size, fill, stroke),
    );
  }

  Widget _pieceWidget(String value, double size, Color fill, Color stroke) {
    return switch (value) {
      'P' => WhitePawn(size: size, fillColor: fill, strokeColor: stroke),
      'N' => WhiteKnight(size: size, fillColor: fill, strokeColor: stroke),
      'B' => WhiteBishop(size: size, fillColor: fill, strokeColor: stroke),
      'R' => WhiteRook(size: size, fillColor: fill, strokeColor: stroke),
      'Q' => WhiteQueen(size: size, fillColor: fill, strokeColor: stroke),
      'K' => WhiteKing(size: size, fillColor: fill, strokeColor: stroke),
      'p' => BlackPawn(size: size, fillColor: fill, strokeColor: stroke),
      'n' => BlackKnight(size: size, fillColor: fill, strokeColor: stroke),
      'b' => BlackBishop(size: size, fillColor: fill, strokeColor: stroke),
      'r' => BlackRook(size: size, fillColor: fill, strokeColor: stroke),
      'q' => BlackQueen(size: size, fillColor: fill, strokeColor: stroke),
      'k' => BlackKing(size: size, fillColor: fill, strokeColor: stroke),
      _ => const SizedBox.shrink(),
    };
  }
}
