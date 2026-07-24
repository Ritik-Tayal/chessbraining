import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:flutter/material.dart';

import 'fen.dart';
import 'match_controller.dart';

class ChessBoard extends StatefulWidget {
  const ChessBoard({
    required this.controller,
    super.key,
  });

  final MatchController controller;

  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

class _ChessBoardState extends State<ChessBoard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _moveController;
  BoardMoveAnimation? _activeMove;
  int? _seenMoveAnimationId;
  String? _draggedFromSquare;
  String? _draggedPiece;

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 170),
    );
    _syncMoveAnimation();
  }

  @override
  void didUpdateWidget(covariant ChessBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMoveAnimation();
  }

  @override
  void dispose() {
    _moveController.dispose();
    super.dispose();
  }

  void _syncMoveAnimation() {
    final move = widget.controller.boardMoveAnimation;
    if (move == null || move.id == _seenMoveAnimationId) {
      return;
    }
    _seenMoveAnimationId = move.id;
    _activeMove = move;
    _moveController
      ..stop()
      ..forward(from: 0).whenComplete(() {
        if (!mounted) {
          return;
        }
        setState(() => _activeMove = null);
      });
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.controller.match;
    if (match == null) {
      return const SizedBox.shrink();
    }

    final board = parseFenBoard(widget.controller.boardFen ?? match.fen);
    final isBlackPerspective = widget.controller.me?.side == 'BLACK';
    final files = isBlackPerspective
        ? const ['h', 'g', 'f', 'e', 'd', 'c', 'b', 'a']
        : const ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    final ranks = isBlackPerspective
        ? const [1, 2, 3, 4, 5, 6, 7, 8]
        : const [8, 7, 6, 5, 4, 3, 2, 1];
    final lastMove = widget.controller.boardLastMove;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff2d241e),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xff170f0a), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(
           builder: (context, constraints) {
            final squareSize = constraints.biggest.shortestSide / 8;
            final children = <Widget>[];
            for (var index = 0; index < 64; index++) {
              final fileIndex = index % 8;
              final rankIndex = index ~/ 8;
              final square = '${files[fileIndex]}${ranks[rankIndex]}';
              final isLight = (fileIndex + rankIndex).isEven;
              final isSelected = widget.controller.selectedSquare == square;
              final isTarget = widget.controller.isLegalTarget(square);
              final isPowerupTarget = widget.controller.isPowerupTarget(square);
              final isLastMove =
                  lastMove?.from == square || lastMove?.to == square;

              children.add(
                Positioned(
                  left: fileIndex * squareSize,
                  top: rankIndex * squareSize,
                  width: squareSize,
                  height: squareSize,
                  child: DragTarget<String>(
                    onWillAcceptWithDetails: (details) {
                      final from = _draggedFromSquare;
                      return from != null &&
                          from != square &&
                          widget.controller.canMove &&
                          widget.controller.legalMoves
                              .any((m) => m.from == from && m.to == square);
                    },
                    onAcceptWithDetails: (details) {
                      final from = _draggedFromSquare;
                      if (from == null) {
                        return;
                      }
                      widget.controller.selectSquare(from);
                      widget.controller.selectSquare(square);
                    },
                    builder: (context, candidateData, rejectedData) {
                      final isDragTarget = candidateData.isNotEmpty &&
                          _draggedFromSquare != null &&
                          widget.controller.legalMoves
                              .any((m) =>
                                  m.from == _draggedFromSquare &&
                                  m.to == square);
                      return _BoardSquare(
                        square: square,
                        isLight: isLight,
                        isSelected: isSelected,
                        isTarget: isTarget || isDragTarget,
                        isPowerupTarget: isPowerupTarget,
                        isLastMove: isLastMove,
                        onTap: () => widget.controller.selectSquare(square),
                      );
                    },
                  ),
                ),
              );
            }

            final activeMove =
                widget.controller.isReviewingMove ? null : _activeMove;
            for (final entry in board.entries) {
              if (activeMove != null && entry.key == activeMove.to) {
                continue;
              }
              if (_draggedFromSquare == entry.key) {
                continue;
              }
              final offset = _squareOffset(
                entry.key,
                files,
                ranks,
                squareSize,
              );
              final pieceWidget = IgnorePointer(
                child: Center(
                  child: _PieceVector(
                    piece: entry.value,
                    size: squareSize * 0.82,
                  ),
                ),
              );
              children.add(
                Positioned(
                  left: offset.dx,
                  top: offset.dy,
                  width: squareSize,
                  height: squareSize,
                  child: _draggablePiece(
                    square: entry.key,
                    piece: entry.value,
                    size: squareSize * 0.82,
                    child: pieceWidget,
                  ),
                ),
              );
            }

            if (activeMove != null) {
              children.add(
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _moveController,
                      builder: (context, child) {
                        final from = _squareOffset(
                          activeMove.from,
                          files,
                          ranks,
                          squareSize,
                        );
                        final to = _squareOffset(
                          activeMove.to,
                          files,
                          ranks,
                          squareSize,
                        );
                        final progress = Curves.easeOutCubic
                            .transform(_moveController.value);
                        final offset = Offset.lerp(from, to, progress)!;
                        return Transform.translate(
                          offset: offset,
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: SizedBox(
                              width: squareSize,
                              height: squareSize,
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: Center(
                        child: _PieceVector(
                          piece: activeMove.piece,
                          size: squareSize * 0.82,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            return Stack(children: children);
          },
        ),
      ),
    );
  }

  Offset _squareOffset(
    String square,
    List<String> files,
    List<int> ranks,
    double squareSize,
  ) {
    final fileIndex = files.indexOf(square[0]);
    final rankIndex = ranks.indexOf(int.parse(square.substring(1)));
    return Offset(fileIndex * squareSize, rankIndex * squareSize);
  }

  Widget _draggablePiece({
    required String square,
    required String piece,
    required double size,
    required Widget child,
  }) {
    final canDrag = widget.controller.canMove &&
        isWhitePiece(piece) ==
            (widget.controller.me?.side == 'WHITE');
    if (!canDrag) {
      return child;
    }
    return LongPressDraggable<String>(
      data: square,
      dragAnchorStrategy: (_, __, ___) => Offset(size / 2, size / 2),
      onDragStarted: () {
        setState(() {
          _draggedFromSquare = square;
          _draggedPiece = piece;
        });
      },
      onDragEnd: (_) {
        setState(() {
          _draggedFromSquare = null;
          _draggedPiece = null;
        });
      },
      feedback: Transform.scale(
        scale: 1.12,
        child: _PieceVector(
          piece: piece,
          size: size,
        ),
      ),
      childWhenDragging: const SizedBox.shrink(),
      child: child,
    );
  }
}

class _BoardSquare extends StatelessWidget {
  const _BoardSquare({
    required this.square,
    required this.isLight,
    required this.isSelected,
    required this.isTarget,
    required this.isPowerupTarget,
    required this.isLastMove,
    required this.onTap,
  });

  final String square;
  final bool isLight;
  final bool isSelected;
  final bool isTarget;
  final bool isPowerupTarget;
  final bool isLastMove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final base = isLight ? const Color(0xfff5ede2) : const Color(0xff8c6a50);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: const Color(0xfffdd2b2).withValues(alpha: 0.28),
        highlightColor: const Color(0xfffdd2b2).withValues(alpha: 0.18),
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
                    color: isLight
                        ? const Color(0xff8c6a50).withValues(alpha: 0.62)
                        : const Color(0xfff5ede2).withValues(alpha: 0.62),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
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
                              ? const Color(0xff78583f)
                              : const Color(0xff2d241e))
                          .withValues(alpha: 0.32),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isPowerupTarget
                            ? const Color(0xff78583f)
                            : const Color(0xff2d241e),
                      ),
                    ),
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
      return const Color(0xfffdd2b2);
    }
    if (isLastMove) {
      return Color.lerp(base, const Color(0xfffdd2b2), 0.55)!;
    }
    if (isPowerupTarget) {
      return Color.lerp(base, const Color(0xfff8dec1), 0.45)!;
    }
    return base;
  }

  Color _borderColor() {
    if (isSelected) {
      return const Color(0xff170f0a);
    }
    if (isTarget) {
      return const Color(0xff2d241e);
    }
    if (isPowerupTarget) {
      return const Color(0xff78583f);
    }
    if (isLastMove) {
      return const Color(0xfffdd2b2).withValues(alpha: 0.95);
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
    final fill = white ? const Color(0xfffffbf4) : const Color(0xff2d241e);
    final stroke = white ? const Color(0xffa69076) : const Color(0xff170f0a);

    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: white
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
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
