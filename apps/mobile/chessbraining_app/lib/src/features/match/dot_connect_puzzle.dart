import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/match_models.dart';
import '../../services/sound_service.dart';

class DotConnectPuzzleWidget extends StatefulWidget {
  const DotConnectPuzzleWidget({
    required this.puzzles,
    required this.onPuzzleSolved,
    required this.enabled,
    super.key,
  });

  final List<String> puzzles;
  final void Function(int puzzleIndex, bool correct, List<List<int>> path) onPuzzleSolved;
  final bool enabled;

  @override
  State<DotConnectPuzzleWidget> createState() => _DotConnectPuzzleWidgetState();
}

class _DotConnectPuzzleWidgetState extends State<DotConnectPuzzleWidget> {
  int currentPuzzleIndex = 0;
  List<List<int>> currentPath = [];
  Set<String> pathCells = {};
  int solvedCount = 0;
  bool submitted = false;

  DotConnectPuzzle? get currentPuzzle {
    if (currentPuzzleIndex >= widget.puzzles.length) return null;
    try {
      final json = jsonDecode(widget.puzzles[currentPuzzleIndex]) as Map<String, dynamic>;
      return DotConnectPuzzle.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final puzzle = currentPuzzle;
    if (puzzle == null || submitted) {
      return Center(
        child: Text(
          submitted ? 'SOLVED $solvedCount / ${widget.puzzles.length}' : 'Loading...',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    return Column(
      children: [
        _PuzzleHeader(
          puzzleIndex: currentPuzzleIndex,
          totalPuzzles: widget.puzzles.length,
          solvedCount: solvedCount,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: _DotConnectGrid(
                puzzle: puzzle,
                currentPath: currentPath,
                pathCells: pathCells,
                onCellTap: widget.enabled ? _onCellTap : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _DotConnectControls(
          onReset: widget.enabled ? _resetPath : null,
          onUndo: widget.enabled && currentPath.isNotEmpty ? _undoLast : null,
        ),
      ],
    );
  }

  void _onCellTap(int row, int col) {
    if (submitted) return;

    final key = '$row,$col';

    if (currentPath.isNotEmpty) {
      final last = currentPath.last;
      final lastKey = '${last[0]},${last[1]}';

      if (key == lastKey) {
        _undoLast();
        return;
      }

      final rowDiff = (last[0] - row).abs();
      final colDiff = (last[1] - col).abs();
      if (rowDiff + colDiff != 1) {
        return;
      }

      if (pathCells.contains(key)) {
        return;
      }
    }

    setState(() {
      currentPath.add([row, col]);
      pathCells.add(key);
    });

    SoundService.instance.playMove();
    _checkIfSolved();
  }

  void _resetPath() {
    setState(() {
      currentPath = [];
      pathCells = {};
    });
  }

  void _undoLast() {
    if (currentPath.isEmpty) return;
    final last = currentPath.removeLast();
    pathCells.remove('${last[0]},${last[1]}');
    setState(() {});
  }

  void _checkIfSolved() {
    final puzzle = currentPuzzle;
    if (puzzle == null) return;

    bool allDotsVisited = true;
    for (final dot in puzzle.dots) {
      if (!pathCells.contains('${dot[0]},${dot[1]}')) {
        allDotsVisited = false;
        break;
      }
    }

    if (allDotsVisited && currentPath.length >= 2) {
      solvedCount++;
      widget.onPuzzleSolved(currentPuzzleIndex, true, List<List<int>>.from(currentPath));

      SoundService.instance.playNotify();

      if (currentPuzzleIndex < widget.puzzles.length - 1) {
        setState(() {
          currentPuzzleIndex++;
          currentPath = [];
          pathCells = {};
        });
      } else {
        setState(() => submitted = true);
      }
    }
  }
}

class _PuzzleHeader extends StatelessWidget {
  const _PuzzleHeader({
    required this.puzzleIndex,
    required this.totalPuzzles,
    required this.solvedCount,
  });

  final int puzzleIndex;
  final int totalPuzzles;
  final int solvedCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'PUZZLE ${puzzleIndex + 1} / $totalPuzzles',
          style: const TextStyle(
            color: Color(0xff94a3b8),
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xff121720),
            border: Border.all(color: const Color(0xff303844)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'SOLVED $solvedCount',
            style: const TextStyle(
              color: Color(0xff81fbb8),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _DotConnectGrid extends StatelessWidget {
  const _DotConnectGrid({
    required this.puzzle,
    required this.currentPath,
    required this.pathCells,
    required this.onCellTap,
  });

  final DotConnectPuzzle puzzle;
  final List<List<int>> currentPath;
  final Set<String> pathCells;
  final void Function(int row, int col)? onCellTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = min(
          constraints.maxWidth / puzzle.cols,
          constraints.maxHeight / puzzle.rows,
        );
        final totalWidth = cellSize * puzzle.cols;
        final totalHeight = cellSize * puzzle.rows;

        return Center(
          child: SizedBox(
            width: totalWidth,
            height: totalHeight,
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(totalWidth, totalHeight),
                  painter: _GridPainter(
                    puzzle: puzzle,
                    cellSize: cellSize,
                    currentPath: currentPath,
                    pathCells: pathCells,
                  ),
                ),
                ...[
                  for (int row = 0; row < puzzle.rows; row++)
                    for (int col = 0; col < puzzle.cols; col++)
                      Positioned(
                        left: col * cellSize,
                        top: row * cellSize,
                        width: cellSize,
                        height: cellSize,
                        child: GestureDetector(
                          onTap: onCellTap != null ? () => onCellTap!(row, col) : null,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xff303844),
                                width: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.puzzle,
    required this.cellSize,
    required this.currentPath,
    required this.pathCells,
  });

  final DotConnectPuzzle puzzle;
  final double cellSize;
  final List<List<int>> currentPath;
  final Set<String> pathCells;

  @override
  void paint(Canvas canvas, Size size) {
    _drawPath(canvas);
    _drawDots(canvas);
  }

  void _drawPath(Canvas canvas) {
    if (currentPath.length < 2) return;

    final paint = Paint()
      ..color = const Color(0xff4fcbff)
      ..strokeWidth = cellSize * 0.25
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final first = currentPath[0];
    path.moveTo(
      first[1] * cellSize + cellSize / 2,
      first[0] * cellSize + cellSize / 2,
    );

    for (int i = 1; i < currentPath.length; i++) {
      final cell = currentPath[i];
      path.lineTo(
        cell[1] * cellSize + cellSize / 2,
        cell[0] * cellSize + cellSize / 2,
      );
    }

    canvas.drawPath(path, paint);
  }

  void _drawDots(Canvas canvas) {
    final dotPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < puzzle.dots.length; i++) {
      final dot = puzzle.dots[i];
      final cx = dot[1] * cellSize + cellSize / 2;
      final cy = dot[0] * cellSize + cellSize / 2;
      final radius = cellSize * 0.22;

      final isStart = i == 0;
      final isEnd = i == puzzle.dots.length - 1;

      if (isStart) {
        dotPaint.color = const Color(0xff81fbb8);
      } else if (isEnd) {
        dotPaint.color = const Color(0xffff8a80);
      } else {
        dotPaint.color = const Color(0xff4fcbff);
      }

      canvas.drawCircle(Offset(cx, cy), radius, dotPaint);

      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(cx, cy), radius, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.currentPath != currentPath ||
        oldDelegate.pathCells != pathCells;
  }
}

class _DotConnectControls extends StatelessWidget {
  const _DotConnectControls({
    required this.onReset,
    required this.onUndo,
  });

  final VoidCallback? onReset;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: onUndo,
          icon: const Icon(Icons.undo, size: 18),
          label: const Text('UNDO'),
          style: OutlinedButton.styleFrom(
            foregroundColor: onUndo != null ? Colors.white : const Color(0xff555555),
            side: const BorderSide(color: Color(0xff303844)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('RESET'),
          style: OutlinedButton.styleFrom(
            foregroundColor: onReset != null ? const Color(0xffff8a80) : const Color(0xff555555),
            side: const BorderSide(color: Color(0xff303844)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}
