import 'dart:async';
import 'dart:math';

import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:flutter/material.dart';

import '../../models/match_models.dart';
import '../../services/sound_service.dart';
import 'dot_connect_puzzle.dart';
import 'match_controller.dart';

class BrainRoundOverlay extends StatefulWidget {
  const BrainRoundOverlay({
    required this.controller,
    super.key,
  });

  final MatchController controller;

  @override
  State<BrainRoundOverlay> createState() => _BrainRoundOverlayState();
}

class _BrainRoundInfo {
  const _BrainRoundInfo({
    required this.title,
    required this.subtitle,
    required this.instruction,
    required this.icon,
    required this.accent,
    required this.deep,
  });

  final String title;
  final String subtitle;
  final String instruction;
  final IconData icon;
  final Color accent;
  final Color deep;

  static _BrainRoundInfo fromRound(BrainRoundModel? round) {
    if (round?.isMemory == true) {
      return const _BrainRoundInfo(
        title: 'Memory Match',
        subtitle: 'Find more chess-piece pairs before time runs out.',
        instruction:
            'Flip two cards. A match scores a pair and keeps the turn; a miss passes the turn.',
        icon: Icons.grid_view_rounded,
        accent: Color(0xff7c5cff),
        deep: Color(0xff22143d),
      );
    }
    if (round?.isDotConnect == true) {
      return const _BrainRoundInfo(
        title: 'Dot Connect',
        subtitle: 'Draw paths through every glowing dot.',
        instruction:
            'Tap adjacent cells to build a path. Visit every dot, then solve the next board.',
        icon: Icons.route_rounded,
        accent: Color(0xff0f9f7a),
        deep: Color(0xff0d3029),
      );
    }
    return const _BrainRoundInfo(
      title: 'Math Sprint',
      subtitle: 'Answer fast. Every correct answer adds to your score.',
      instruction:
          'Use the keypad, submit, and keep moving. Your answers are scored together.',
      icon: Icons.calculate_rounded,
      accent: Color(0xffb56b2d),
      deep: Color(0xff351c0d),
    );
  }
}

class _BrainRoundOverlayState extends State<BrainRoundOverlay> {
  Timer? timer;
  DateTime? _lastNullReload;
  final Map<int, int> answersByQuestion = {};
  String answer = '';
  int questionIndex = 0;
  int score = 0;
  bool finished = false;
  bool scoreSubmitted = false;
  bool submitting = false;

  int dotConnectSolvedCount = 0;
  final Map<int, List<List<int>>> dotConnectPaths = {};
  final Map<int, bool> dotConnectResults = {};
  final Set<int> dotConnectSubmitted = {};
  final Set<int> dotConnectPending = {};
  final List<int> memorySelection = [];

  @override
  void initState() {
    super.initState();
    widget.controller.loadCurrentBrainRound();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      final round = widget.controller.brainRound;
      if (round == null) {
        // Round data failed to load; retry periodically so the overlay can
        // self-heal once the server expires/completes the round.
        final now = DateTime.now();
        if (_lastNullReload == null ||
            now.difference(_lastNullReload!) > const Duration(seconds: 3)) {
          _lastNullReload = now;
          unawaited(widget.controller.loadCurrentBrainRound());
        }
        setState(() {});
        return;
      }
      if (_remainingSeconds(round) == 0) {
        setState(() => finished = true);
        timer?.cancel();
        if (round.isMemory) {
          unawaited(widget.controller.completeBrainRound());
        } else if (scoreSubmitted) {
          unawaited(widget.controller.completeBrainRound());
        } else if (round.isDotConnect) {
          unawaited(_submitDotConnectPaths());
        } else {
          unawaited(_submitAnswers());
        }
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.controller.match!;
    final round = widget.controller.brainRound;
    final puzzles = round?.puzzles ?? const <String>[];
    final serverScore = match.white.playerId == widget.controller.playerId
        ? round?.whiteCorrectCount ?? 0
        : round?.blackCorrectCount ?? 0;
    if (round != null &&
        answersByQuestion.isEmpty &&
        widget.controller.nextBrainQuestionIndex >= round.totalQuestions) {
      questionIndex = round.totalQuestions;
      finished = true;
      scoreSubmitted = true;
      score = serverScore;
    }
    final safeIndex =
        puzzles.isEmpty ? 0 : min(questionIndex, puzzles.length - 1);
    final currentPuzzle = puzzles.isEmpty ? 'Loading...' : puzzles[safeIndex];
    final secondsLeft = round == null ? 30 : _remainingSeconds(round);
    final totalSeconds = round == null ? 30 : _durationSeconds(round);
    final progress = totalSeconds == 0 ? 0.0 : secondsLeft / totalSeconds;
    final answeredCount = round?.isMemory == true
        ? serverScore
        : round?.isDotConnect == true
            ? dotConnectSolvedCount
            : answersByQuestion.length;
    final displayedScore =
        scoreSubmitted ? max(score, serverScore) : answeredCount;
    final scoreLabel = scoreSubmitted ? 'SCORE' : 'DONE';
    final scoreValue = scoreSubmitted
        ? '$displayedScore'
        : '$answeredCount/${round?.totalQuestions ?? 0}';
    final deadlinePassed = round != null && secondsLeft == 0;
    final info = _BrainRoundInfo.fromRound(round);

    return Positioned.fill(
      child: Material(
        color: info.deep,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                info.deep,
                const Color(0xff170f0a),
                const Color(0xfffff8f1),
              ],
              stops: const [0, 0.42, 1],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 720;
                return Padding(
                  padding: EdgeInsets.all(compact ? 10 : 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _BrainHeader(
                            info: info,
                            scoreLabel: scoreLabel,
                            scoreValue: scoreValue,
                            secondsLeft: secondsLeft,
                            compact: compact,
                          ),
                          SizedBox(height: compact ? 10 : 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: compact ? 8 : 10,
                              value: progress,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.14),
                              color: secondsLeft <= 5
                                  ? const Color(0xffff6b6b)
                                  : info.accent,
                            ),
                          ),
                          SizedBox(height: compact ? 10 : 14),
                          _BrainInstruction(info: info, compact: compact),
                          SizedBox(height: compact ? 10 : 14),
                          Expanded(
                            flex: compact ? 5 : 6,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeOutCubic,
                              child: round?.isMemory == true
                                  ? _MemoryBoard(
                                      key: const ValueKey('memory'),
                                      round: round!,
                                      playerSide: widget.controller.me?.side,
                                      selected: memorySelection,
                                      enabled: _inputEnabled,
                                      submitting: submitting,
                                      onCardTap: _onMemoryCardTap,
                                    )
                                  : round?.isDotConnect == true
                                      ? _DotConnectArena(
                                          key: const ValueKey('dot-connect'),
                                          puzzles: puzzles,
                                          enabled: _inputEnabled,
                                          onPuzzleSolved: _onDotConnectSolved,
                                        )
                                      : _PuzzleCard(
                                          key: ValueKey('math-$questionIndex'),
                                          puzzle: currentPuzzle,
                                          answer: answer,
                                          finished: finished,
                                          scoreSubmitted: scoreSubmitted,
                                          submitting: submitting,
                                          questionIndex: questionIndex,
                                          totalQuestions:
                                              round?.totalQuestions ?? 0,
                                          compact: compact,
                                          accent: info.accent,
                                        ),
                            ),
                          ),
                          SizedBox(height: compact ? 10 : 14),
                          if (round?.isDotConnect != true &&
                              round?.isMemory != true)
                            Expanded(
                              flex: compact ? 5 : 4,
                              child: _NumberPad(
                                enabled: _inputEnabled,
                                onAppend: _append,
                                onBackspace: _backspace,
                                onSubmit: _inputEnabled && answer.isNotEmpty
                                    ? _submit
                                    : null,
                                accent: info.accent,
                              ),
                            ),
                          SizedBox(height: compact ? 8 : 12),
                          if (widget.controller.error != null) ...[
                            Text(
                              widget.controller.error!,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xffff6b6b),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          _BrainFooter(
                            whitePoints: match.white.brainPoints,
                            blackPoints: match.black?.brainPoints ?? 0,
                            secondsLeft: secondsLeft,
                            deadlinePassed: deadlinePassed,
                            submitting: submitting,
                            scoreSubmitted: scoreSubmitted,
                            onComplete: _handleComplete,
                            accent: info.accent,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  bool get _inputEnabled {
    final round = widget.controller.brainRound;
    return round != null &&
        !finished &&
        !submitting &&
        !scoreSubmitted &&
        (!round.isMemory ||
            round.memoryBoard?.turnSide == widget.controller.me?.side) &&
        _remainingSeconds(round) > 0;
  }

  int _remainingSeconds(BrainRoundModel round) {
    final remainingMs =
        round.expiresAt.difference(DateTime.now().toUtc()).inMilliseconds;
    if (remainingMs <= 0) {
      return 0;
    }
    return (remainingMs + 999) ~/ 1000;
  }

  int _durationSeconds(BrainRoundModel round) {
    final durationMs =
        round.expiresAt.difference(round.startedAt).inMilliseconds;
    if (durationMs <= 0) {
      return 0;
    }
    return (durationMs + 999) ~/ 1000;
  }

  void _append(String value) {
    if (answer.length >= 5) {
      return;
    }
    setState(() => answer += value);
  }

  void _backspace() {
    if (answer.isEmpty) {
      return;
    }
    setState(() => answer = answer.substring(0, answer.length - 1));
  }

  Future<void> _submit() async {
    final parsed = int.tryParse(answer);
    final round = widget.controller.brainRound;
    if (parsed == null || round == null) {
      return;
    }

    final nextIndex = questionIndex + 1;
    setState(() {
      answersByQuestion[questionIndex] = parsed;
      answer = '';
      questionIndex = min(nextIndex, round.totalQuestions);
      finished = nextIndex >= round.totalQuestions;
    });

    SoundService.instance.playNotify();

    if (nextIndex >= round.totalQuestions) {
      unawaited(_submitAnswers());
    }
  }

  Future<void> _submitAnswers() async {
    final round = widget.controller.brainRound;
    if (round == null || scoreSubmitted || submitting) {
      return;
    }

    setState(() => submitting = true);
    final result = await widget.controller.submitBrainRoundAnswers(
      Map<int, int>.from(answersByQuestion),
    );
    if (!mounted) {
      return;
    }
    if (result == null) {
      setState(() => submitting = false);
      return;
    }

    setState(() {
      score = result.playerCorrectCount;
      questionIndex = round.totalQuestions;
      finished = true;
      scoreSubmitted = true;
      submitting = false;
    });
    SoundService.instance.playBrainRoundEnd();
    if (result.roundCompleted) {
      timer?.cancel();
    }
  }

  Future<void> _handleComplete() async {
    if (widget.controller.brainRound?.isMemory == true) {
      await widget.controller.completeBrainRound();
      return;
    }
    if (!scoreSubmitted) {
      if (widget.controller.brainRound?.isDotConnect == true) {
        await _submitDotConnectPaths();
      } else {
        await _submitAnswers();
      }
      return;
    }
    await widget.controller.completeBrainRound();
  }

  void _onDotConnectSolved(
      int puzzleIndex, bool correct, List<List<int>> path) {
    setState(() {
      dotConnectSolvedCount++;
      dotConnectPaths[puzzleIndex] = path;
      dotConnectResults[puzzleIndex] = correct;
    });
    unawaited(_submitDotConnectPathNow(puzzleIndex, path));

    final round = widget.controller.brainRound;
    if (round != null && dotConnectSolvedCount >= round.totalQuestions) {
      setState(() => finished = true);
      unawaited(widget.controller.refresh());
    }
  }

  Future<void> _submitDotConnectPathNow(
    int puzzleIndex,
    List<List<int>> path,
  ) async {
    if (dotConnectSubmitted.contains(puzzleIndex)) {
      return;
    }
    if (dotConnectPending.contains(puzzleIndex)) {
      return;
    }
    dotConnectPending.add(puzzleIndex);
    final result = await widget.controller.submitDotConnectPath(
      puzzleIndex: puzzleIndex,
      path: path,
    );
    dotConnectPending.remove(puzzleIndex);
    if (result != null) {
      dotConnectSubmitted.add(puzzleIndex);
    }
    if (!mounted || result == null) {
      return;
    }
    setState(() {
      score = result.playerCorrectCount;
    });
  }

  Future<void> _submitDotConnectPaths() async {
    final round = widget.controller.brainRound;
    if (round == null || scoreSubmitted || submitting) {
      return;
    }

    setState(() => submitting = true);
    int totalCorrect = 0;
    final deadlinePassed = _remainingSeconds(round) == 0;

    for (final entry in dotConnectPaths.entries) {
      if (dotConnectSubmitted.contains(entry.key) ||
          dotConnectPending.contains(entry.key)) {
        if (dotConnectResults[entry.key] == true) {
          totalCorrect++;
        }
        continue;
      }
      final result = await widget.controller.submitDotConnectPath(
        puzzleIndex: entry.key,
        path: entry.value,
      );
      dotConnectSubmitted.add(entry.key);
      if (result != null && result.correct) {
        totalCorrect++;
      }
    }

    if (!mounted) return;

    setState(() {
      score = totalCorrect;
      finished = true;
      scoreSubmitted = true;
      submitting = false;
    });
    SoundService.instance.playBrainRoundEnd();
    if (deadlinePassed) {
      await widget.controller.completeBrainRound();
    } else {
      unawaited(widget.controller.refresh());
    }
  }

  void _onMemoryCardTap(int index) {
    final round = widget.controller.brainRound;
    final board = round?.memoryBoard;
    if (round == null || board == null || !_inputEnabled) {
      return;
    }
    final card = board.cards.firstWhere((item) => item.index == index);
    if (card.matched || memorySelection.contains(index)) {
      return;
    }
    setState(() => memorySelection.add(index));
    if (memorySelection.length == 2) {
      final first = memorySelection[0];
      final second = memorySelection[1];
      unawaited(_submitMemoryTurn(first, second));
    }
  }

  Future<void> _submitMemoryTurn(int firstIndex, int secondIndex) async {
    setState(() => submitting = true);
    final result = await widget.controller.submitMemoryTurn(
      firstIndex: firstIndex,
      secondIndex: secondIndex,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      submitting = false;
      memorySelection.clear();
      if (result?.isCompleted == true) {
        finished = true;
      }
    });
    if (result?.isCompleted == true) {
      SoundService.instance.playBrainRoundEnd();
      timer?.cancel();
    } else {
      SoundService.instance.playNotify();
    }
  }
}

class _BrainHeader extends StatelessWidget {
  const _BrainHeader({
    required this.info,
    required this.scoreLabel,
    required this.scoreValue,
    required this.secondsLeft,
    required this.compact,
  });

  final _BrainRoundInfo info;
  final String scoreLabel;
  final String scoreValue;
  final int secondsLeft;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: compact ? 42 : 50,
          height: compact ? 42 : 50,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            border: Border.all(color: info.accent),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(info.icon, color: info.accent, size: compact ? 22 : 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info.title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 22 : 30,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Playfair Display',
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 3),
                Text(
                  info.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        _StatPill(label: scoreLabel, value: scoreValue),
        const SizedBox(width: 8),
        _StatPill(label: 'TIME', value: '${secondsLeft}s'),
      ],
    );
  }
}

class _BrainInstruction extends StatelessWidget {
  const _BrainInstruction({
    required this.info,
    required this.compact,
  });

  final _BrainRoundInfo info;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 9 : 11,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        border: Border.all(color: info.accent.withValues(alpha: 0.62)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.tips_and_updates, color: info.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              info.instruction,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PuzzleCard extends StatelessWidget {
  const _PuzzleCard({
    required this.puzzle,
    required this.answer,
    required this.finished,
    required this.scoreSubmitted,
    required this.submitting,
    required this.questionIndex,
    required this.totalQuestions,
    required this.compact,
    required this.accent,
    super.key,
  });

  final String puzzle;
  final String answer;
  final bool finished;
  final bool scoreSubmitted;
  final bool submitting;
  final int questionIndex;
  final int totalQuestions;
  final bool compact;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final questionLabel = totalQuestions == 0
        ? 'Loading'
        : 'Question ${min(questionIndex + 1, totalQuestions)} / $totalQuestions';
    final title = finished ? 'Answers locked' : questionLabel.toUpperCase();
    final mainText = submitting
        ? 'SUBMITTING SCORE'
        : scoreSubmitted
            ? 'WAIT FOR OPPONENT'
            : finished
                ? 'ANSWERS LOCKED'
                : puzzle;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: EdgeInsets.all(compact ? 18 : 30),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.4),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff2d241e).withValues(alpha: 0.1),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          SizedBox(height: compact ? 10 : 18),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              mainText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xff170f0a),
                fontSize: compact ? 38 : 48,
                fontWeight: FontWeight.w900,
                fontFamily: 'Playfair Display',
              ),
            ),
          ),
          SizedBox(height: compact ? 10 : 18),
          Container(
            height: compact ? 48 : 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xfffff8f1),
              border: Border.all(color: const Color(0xffe9e1d7)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              answer.isEmpty ? '|' : answer,
              style: TextStyle(
                color: const Color(0xff170f0a),
                fontSize: compact ? 28 : 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberPad extends StatelessWidget {
  const _NumberPad({
    required this.enabled,
    required this.onAppend,
    required this.onBackspace,
    required this.onSubmit,
    required this.accent,
  });

  final bool enabled;
  final ValueChanged<String> onAppend;
  final VoidCallback onBackspace;
  final VoidCallback? onSubmit;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    return Column(
      children: [
        for (final row in rows) ...[
          Expanded(
            child: Row(
              children: [
                for (final value in row) ...[
                  Expanded(
                    child: _KeyButton(
                      label: value,
                      accent: accent,
                      onPressed: enabled ? () => onAppend(value) : null,
                    ),
                  ),
                  if (value != row.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _KeyButton(
                  icon: Icons.backspace_outlined,
                  color: const Color(0xffba1a1a),
                  accent: accent,
                  onPressed: enabled ? onBackspace : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KeyButton(
                  label: '0',
                  accent: accent,
                  onPressed: enabled ? () => onAppend('0') : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KeyButton(
                  icon: Icons.check_circle_outline,
                  filled: true,
                  accent: accent,
                  onPressed: onSubmit,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemoryBoard extends StatelessWidget {
  const _MemoryBoard({
    super.key,
    required this.round,
    required this.playerSide,
    required this.selected,
    required this.enabled,
    required this.submitting,
    required this.onCardTap,
  });

  final BrainRoundModel round;
  final String? playerSide;
  final List<int> selected;
  final bool enabled;
  final bool submitting;
  final ValueChanged<int> onCardTap;

  @override
  Widget build(BuildContext context) {
    final board = round.memoryBoard;
    if (board == null || board.cards.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xff78583f)),
      );
    }
    final myTurn = board.turnSide == playerSide;
    final status = submitting
        ? 'LOCKING TURN'
        : myTurn
            ? 'YOUR TURN'
            : '${board.turnSide} THINKING';
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MemoryScoreTile(
                label: 'WHITE PAIRS',
                value: round.whiteCorrectCount,
                active: board.turnSide == 'WHITE',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MemoryScoreTile(
                label: 'BLACK PAIRS',
                value: round.blackCorrectCount,
                active: board.turnSide == 'BLACK',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          status,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xff78583f),
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.86,
            ),
            itemCount: board.cards.length,
            itemBuilder: (context, index) {
              final card = board.cards[index];
              final isSelected = selected.contains(card.index);
              return _MemoryCard(
                card: card,
                selected: isSelected,
                enabled: enabled && !card.matched,
                onTap: () => onCardTap(card.index),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DotConnectArena extends StatelessWidget {
  const _DotConnectArena({
    super.key,
    required this.puzzles,
    required this.enabled,
    required this.onPuzzleSolved,
  });

  final List<String> puzzles;
  final bool enabled;
  final void Function(int puzzleIndex, bool correct, List<List<int>> path)
      onPuzzleSolved;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        border: Border.all(color: const Color(0xff0f9f7a), width: 1.4),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff0f9f7a).withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: DotConnectPuzzleWidget(
        puzzles: puzzles,
        enabled: enabled,
        onPuzzleSolved: onPuzzleSolved,
      ),
    );
  }
}

class _MemoryScoreTile extends StatelessWidget {
  const _MemoryScoreTile({
    required this.label,
    required this.value,
    required this.active,
  });

  final String label;
  final int value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: active ? const Color(0xff2d241e) : const Color(0xfffbf2e7),
        border: Border.all(color: const Color(0xffd1c4bd)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color:
                    active ? const Color(0xfffff8f1) : const Color(0xff78583f),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              color: active ? const Color(0xfffff8f1) : const Color(0xff170f0a),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.card,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final MemoryCardModel card;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final faceUp = card.matched || selected || (serverRevealVisible && card.revealed);
    return AnimatedScale(
      scale: selected ? 0.96 : 1,
      duration: const Duration(milliseconds: 120),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: card.matched
                  ? const Color(0xffd6ead5)
                  : faceUp
                      ? Colors.white
                      : const Color(0xff2d241e),
              border: Border.all(
                color: selected
                    ? const Color(0xffb56b2d)
                    : card.matched
                        ? const Color(0xff5f8f5a)
                        : const Color(0xffd1c4bd),
                width: selected ? 3 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xff2d241e).withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: faceUp
                  ? _MemoryPiece(piece: card.piece)
                  : Icon(
                      Icons.psychology_alt,
                      color: const Color(0xfffff8f1).withValues(alpha: 0.72),
                      size: 30,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MemoryPiece extends StatelessWidget {
  const _MemoryPiece({required this.piece});

  final String? piece;

  @override
  Widget build(BuildContext context) {
    const fill = Color(0xfffffbf4);
    const stroke = Color(0xff170f0a);
    const size = 46.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xfff5ede2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: switch (piece) {
          'PAWN' => WhitePawn(size: size, fillColor: fill, strokeColor: stroke),
          'KNIGHT' =>
            WhiteKnight(size: size, fillColor: fill, strokeColor: stroke),
          'BISHOP' =>
            WhiteBishop(size: size, fillColor: fill, strokeColor: stroke),
          'ROOK' => WhiteRook(size: size, fillColor: fill, strokeColor: stroke),
          'QUEEN' =>
            WhiteQueen(size: size, fillColor: fill, strokeColor: stroke),
          'KING' => WhiteKing(size: size, fillColor: fill, strokeColor: stroke),
          _ => const Icon(Icons.help_outline, color: stroke, size: 34),
        },
      ),
    );
  }
}

class _BrainFooter extends StatelessWidget {
  const _BrainFooter({
    required this.whitePoints,
    required this.blackPoints,
    required this.secondsLeft,
    required this.deadlinePassed,
    required this.submitting,
    required this.scoreSubmitted,
    required this.onComplete,
    required this.accent,
  });

  final int whitePoints;
  final int blackPoints;
  final int secondsLeft;
  final bool deadlinePassed;
  final bool submitting;
  final bool scoreSubmitted;
  final Future<void> Function() onComplete;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final buttonLabel = submitting
        ? 'SUBMITTING'
        : deadlinePassed
            ? scoreSubmitted
                ? 'SYNC'
                : 'SUBMIT'
            : '${secondsLeft}s';
    return Row(
      children: [
        _StatPill(label: 'WHITE BP', value: '$whitePoints'),
        const SizedBox(width: 8),
        _StatPill(label: 'BLACK BP', value: '$blackPoints'),
        const Spacer(),
        SizedBox(
          height: 44,
          child: FilledButton.icon(
            onPressed: submitting || !deadlinePassed
                ? null
                : () => unawaited(onComplete()),
            icon: Icon(deadlinePassed ? Icons.done_all : Icons.lock_clock),
            label: Text(buttonLabel),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: const Color(0xfffff8f1),
              disabledBackgroundColor: const Color(0xffe9e1d7),
              disabledForegroundColor: const Color(0xff7f756f),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    this.label,
    this.icon,
    this.color,
    this.filled = false,
    required this.accent,
    required this.onPressed,
  });

  final String? label;
  final IconData? icon;
  final Color? color;
  final bool filled;
  final Color accent;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(
            label!,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          )
        : Icon(icon, size: 26);

    return filled
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: const Color(0xfffff8f1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: child,
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: color ?? const Color(0xff170f0a),
              backgroundColor: const Color(0xfffbf2e7),
              side: BorderSide(color: accent.withValues(alpha: 0.34)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: child,
          );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xfffbf2e7),
        border: Border.all(color: const Color(0xffd1c4bd)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xff7f756f),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xff170f0a),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}


