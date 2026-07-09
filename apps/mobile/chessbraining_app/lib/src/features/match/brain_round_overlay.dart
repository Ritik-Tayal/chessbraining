import 'dart:async';
import 'dart:math';

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

class _BrainRoundOverlayState extends State<BrainRoundOverlay> {
  Timer? timer;
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

  @override
  void initState() {
    super.initState();
    widget.controller.loadCurrentBrainRound();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      final round = widget.controller.brainRound;
      if (round != null && _remainingSeconds(round) == 0) {
        setState(() => finished = true);
        timer?.cancel();
        if (scoreSubmitted) {
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
    final answeredCount = round?.isDotConnect == true
        ? dotConnectSolvedCount
        : answersByQuestion.length;
    final displayedScore =
        scoreSubmitted ? max(score, serverScore) : answeredCount;
    final scoreLabel = scoreSubmitted ? 'SCORE' : 'DONE';
    final scoreValue = scoreSubmitted
        ? '$displayedScore'
        : '$answeredCount/${round?.totalQuestions ?? 0}';
    final deadlinePassed = round != null && secondsLeft == 0;
    final roundTitle =
        round?.isDotConnect == true ? 'DOT CONNECT' : 'MENTAL MATH';

    return Positioned.fill(
      child: Material(
        color: const Color(0xfffff8f1),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 720;
              return Padding(
                padding: EdgeInsets.all(compact ? 10 : 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _BrainHeader(
                          title: roundTitle,
                          scoreLabel: scoreLabel,
                          scoreValue: scoreValue,
                          secondsLeft: secondsLeft,
                          compact: compact,
                        ),
                        SizedBox(height: compact ? 10 : 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            minHeight: compact ? 8 : 10,
                            value: progress,
                            backgroundColor: const Color(0xffe9e1d7),
                            color: secondsLeft <= 5
                                ? const Color(0xffba1a1a)
                                : const Color(0xff78583f),
                          ),
                        ),
                        SizedBox(height: compact ? 10 : 16),
                        Expanded(
                          flex: compact ? 5 : 6,
                          child: round?.isDotConnect == true
                              ? DotConnectPuzzleWidget(
                                  puzzles: puzzles,
                                  enabled: _inputEnabled,
                                  onPuzzleSolved: _onDotConnectSolved,
                                )
                              : _PuzzleCard(
                                  puzzle: currentPuzzle,
                                  answer: answer,
                                  finished: finished,
                                  scoreSubmitted: scoreSubmitted,
                                  submitting: submitting,
                                  questionIndex: questionIndex,
                                  totalQuestions: round?.totalQuestions ?? 0,
                                  compact: compact,
                                ),
                        ),
                        SizedBox(height: compact ? 10 : 14),
                        if (round?.isDotConnect != true)
                          Expanded(
                            flex: compact ? 5 : 4,
                            child: _NumberPad(
                              enabled: _inputEnabled,
                              onAppend: _append,
                              onBackspace: _backspace,
                              onSubmit: _inputEnabled && answer.isNotEmpty
                                  ? _submit
                                  : null,
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
                              color: Color(0xffba1a1a),
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
    );
  }

  bool get _inputEnabled {
    final round = widget.controller.brainRound;
    return round != null &&
        !finished &&
        !submitting &&
        !scoreSubmitted &&
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

    final round = widget.controller.brainRound;
    if (round != null && dotConnectSolvedCount >= round.totalQuestions) {
      setState(() => finished = true);
      unawaited(_submitDotConnectPaths());
    }
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
      final result = await widget.controller.submitDotConnectPath(
        puzzleIndex: entry.key,
        path: entry.value,
      );
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
}

class _BrainHeader extends StatelessWidget {
  const _BrainHeader({
    required this.title,
    required this.scoreLabel,
    required this.scoreValue,
    required this.secondsLeft,
    required this.compact,
  });

  final String title;
  final String scoreLabel;
  final String scoreValue;
  final int secondsLeft;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.close, color: Color(0xff170f0a), size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xff170f0a),
              fontSize: compact ? 22 : 28,
              fontWeight: FontWeight.w900,
              fontFamily: 'Playfair Display',
            ),
          ),
        ),
        _StatPill(label: scoreLabel, value: scoreValue),
        const SizedBox(width: 8),
        _StatPill(label: 'TIME', value: '${secondsLeft}s'),
      ],
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
  });

  final String puzzle;
  final String answer;
  final bool finished;
  final bool scoreSubmitted;
  final bool submitting;
  final int questionIndex;
  final int totalQuestions;
  final bool compact;

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
        border: Border.all(color: const Color(0xffd1c4bd)),
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
            style: const TextStyle(
              color: Color(0xff78583f),
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
  });

  final bool enabled;
  final ValueChanged<String> onAppend;
  final VoidCallback onBackspace;
  final VoidCallback? onSubmit;

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
                  onPressed: enabled ? onBackspace : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KeyButton(
                  label: '0',
                  onPressed: enabled ? () => onAppend('0') : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KeyButton(
                  icon: Icons.check_circle_outline,
                  filled: true,
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

class _BrainFooter extends StatelessWidget {
  const _BrainFooter({
    required this.whitePoints,
    required this.blackPoints,
    required this.secondsLeft,
    required this.deadlinePassed,
    required this.submitting,
    required this.scoreSubmitted,
    required this.onComplete,
  });

  final int whitePoints;
  final int blackPoints;
  final int secondsLeft;
  final bool deadlinePassed;
  final bool submitting;
  final bool scoreSubmitted;
  final Future<void> Function() onComplete;

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
              backgroundColor: const Color(0xff2d241e),
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
    required this.onPressed,
  });

  final String? label;
  final IconData? icon;
  final Color? color;
  final bool filled;
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
              backgroundColor: const Color(0xff2d241e),
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
              side: const BorderSide(color: Color(0xffd1c4bd)),
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
