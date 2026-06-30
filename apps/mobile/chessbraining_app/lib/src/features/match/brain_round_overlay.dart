import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/match_models.dart';
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
  String answer = '';
  int questionIndex = 0;
  int score = 0;
  bool finished = false;
  bool wrong = false;
  bool submitting = false;

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
    if (round != null &&
        widget.controller.nextBrainQuestionIndex > questionIndex) {
      questionIndex =
          min(widget.controller.nextBrainQuestionIndex, round.totalQuestions);
      finished = questionIndex >= round.totalQuestions;
    }
    final safeIndex =
        puzzles.isEmpty ? 0 : min(questionIndex, puzzles.length - 1);
    final currentPuzzle = puzzles.isEmpty ? 'Loading...' : puzzles[safeIndex];
    final secondsLeft = round == null ? 30 : _remainingSeconds(round);
    final totalSeconds = round == null ? 30 : _durationSeconds(round);
    final progress = totalSeconds == 0 ? 0.0 : secondsLeft / totalSeconds;
    final serverScore = match.white.playerId == widget.controller.playerId
        ? round?.whiteCorrectCount ?? 0
        : round?.blackCorrectCount ?? 0;
    final displayedScore = max(score, serverScore);
    final deadlinePassed = round != null && secondsLeft == 0;

    return Positioned.fill(
      child: Material(
        color: const Color(0xff07090d).withValues(alpha: 0.98),
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
                          score: displayedScore,
                          secondsLeft: secondsLeft,
                          compact: compact,
                        ),
                        SizedBox(height: compact ? 10 : 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            minHeight: compact ? 8 : 10,
                            value: progress,
                            backgroundColor: const Color(0xff252b34),
                            color: secondsLeft <= 5
                                ? const Color(0xffff8a80)
                                : const Color(0xff4fcbff),
                          ),
                        ),
                        SizedBox(height: compact ? 10 : 16),
                        Expanded(
                          flex: compact ? 5 : 6,
                          child: _PuzzleCard(
                            puzzle: currentPuzzle,
                            answer: answer,
                            wrong: wrong,
                            finished: finished,
                            questionIndex: questionIndex,
                            totalQuestions: round?.totalQuestions ?? 0,
                            compact: compact,
                          ),
                        ),
                        SizedBox(height: compact ? 10 : 14),
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
                              color: Color(0xffff8a80),
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
                          onComplete: () =>
                              widget.controller.completeBrainRound(),
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

    setState(() => submitting = true);
    final result = await widget.controller.submitBrainRoundAnswer(
      questionIndex: questionIndex,
      answer: parsed,
    );
    if (!mounted) {
      return;
    }
    if (result == null) {
      setState(() => submitting = false);
      return;
    }

    final nextIndex = questionIndex + 1;
    setState(() {
      answer = '';
      submitting = false;
      wrong = !result.correct;
      score = result.playerCorrectCount;
      questionIndex = min(nextIndex, max(0, result.totalQuestions - 1));
      if (nextIndex >= result.totalQuestions) {
        finished = true;
      }
    });
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() => wrong = false);
      }
    });
  }
}

class _BrainHeader extends StatelessWidget {
  const _BrainHeader({
    required this.score,
    required this.secondsLeft,
    required this.compact,
  });

  final int score;
  final int secondsLeft;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.psychology, color: Color(0xff4fcbff)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'BRAIN ROUND',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xff4fcbff),
              fontSize: compact ? 22 : 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        _StatPill(label: 'SCORE', value: '$score'),
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
    required this.wrong,
    required this.finished,
    required this.questionIndex,
    required this.totalQuestions,
    required this.compact,
  });

  final String puzzle;
  final String answer;
  final bool wrong;
  final bool finished;
  final int questionIndex;
  final int totalQuestions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final questionLabel = totalQuestions == 0
        ? 'Loading'
        : 'Question ${min(questionIndex + 1, totalQuestions)} / $totalQuestions';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: EdgeInsets.all(compact ? 14 : 22),
      decoration: BoxDecoration(
        color: const Color(0xff121720),
        border: Border.all(
          color: wrong ? const Color(0xffff8a80) : const Color(0xff303844),
          width: wrong ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            finished ? 'All answers submitted' : questionLabel.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xff94a3b8),
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: compact ? 10 : 18),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              finished ? 'WAIT FOR TIMER' : puzzle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 38 : 48,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(height: compact ? 10 : 18),
          Container(
            height: compact ? 48 : 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xff07090d),
              border: Border.all(color: const Color(0xff303844)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              answer.isEmpty ? ' ' : answer,
              style: TextStyle(
                color: const Color(0xffb9f7ff),
                fontSize: compact ? 28 : 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
          ),
          if (wrong) ...[
            const SizedBox(height: 8),
            const Text(
              'Not scored',
              style: TextStyle(
                color: Color(0xffff8a80),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
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
                  color: const Color(0xffff8a80),
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
    required this.onComplete,
  });

  final int whitePoints;
  final int blackPoints;
  final int secondsLeft;
  final bool deadlinePassed;
  final bool submitting;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatPill(label: 'WHITE BP', value: '$whitePoints'),
        const SizedBox(width: 8),
        _StatPill(label: 'BLACK BP', value: '$blackPoints'),
        const Spacer(),
        SizedBox(
          height: 44,
          child: FilledButton.icon(
            onPressed: submitting || !deadlinePassed ? null : onComplete,
            icon: Icon(deadlinePassed ? Icons.done_all : Icons.lock_clock),
            label: Text(deadlinePassed ? 'COMPLETE' : '${secondsLeft}s'),
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
              backgroundColor: const Color(0xff4fcbff),
              foregroundColor: const Color(0xff06131a),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: child,
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: color ?? Colors.white,
              side: const BorderSide(color: Color(0xff303844)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
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
        color: const Color(0xff121720),
        border: Border.all(color: const Color(0xff303844)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xff94a3b8),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xff81fbb8),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
