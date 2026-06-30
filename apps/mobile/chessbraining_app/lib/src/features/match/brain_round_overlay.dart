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
    final currentPuzzle =
        puzzles.isEmpty ? 'Loading puzzle...' : puzzles[safeIndex];
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
        color: const Color(0xff0a0a0c).withValues(alpha: 0.97),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.psychology, color: Color(0xff00daf3)),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'CHESS BRAINING',
                            style: TextStyle(
                              color: Color(0xff00daf3),
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _StatPill(label: 'SCORE', value: '$displayedScore'),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xffb600f8).withValues(alpha: 0.22),
                          border: Border.all(color: const Color(0xffb600f8)),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Text(
                          'BRAIN ROUND ACTIVE',
                          style: TextStyle(
                            color: Color(0xffebb2ff),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 12,
                        value: progress,
                        backgroundColor: const Color(0xff353437),
                        color: secondsLeft <= 5
                            ? const Color(0xffffb4ab)
                            : const Color(0xff00daf3),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text(
                          'TIME REMAINING',
                          style: TextStyle(
                            color: Color(0xff849396),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${secondsLeft}s',
                          style: const TextStyle(
                            color: Color(0xffc3f5ff),
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: const Color(0xff131315),
                        border: Border.all(
                          color: wrong
                              ? const Color(0xffffb4ab)
                              : const Color(0xff353437),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'SOLVE FOR MAX BOOST',
                            style: TextStyle(
                              color: Color(0xff849396),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            currentPuzzle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Container(
                            height: 58,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                    color: Color(0xff849396), width: 2),
                              ),
                            ),
                            child: Text(
                              answer,
                              style: const TextStyle(
                                color: Color(0xffc3f5ff),
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                              ),
                            ),
                          ),
                          if (wrong) ...[
                            const SizedBox(height: 14),
                            const Text(
                              'Not scored',
                              style: TextStyle(
                                color: Color(0xffffb4ab),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.45,
                        children: [
                          for (final value in [
                            '1',
                            '2',
                            '3',
                            '4',
                            '5',
                            '6',
                            '7',
                            '8',
                            '9'
                          ])
                            _KeyButton(
                                label: value,
                                onPressed: _inputEnabled
                                    ? () => _append(value)
                                    : null),
                          _KeyButton(
                            icon: Icons.backspace_outlined,
                            color: const Color(0xffffb4ab),
                            onPressed: _inputEnabled ? _backspace : null,
                          ),
                          _KeyButton(
                              label: '0',
                              onPressed:
                                  _inputEnabled ? () => _append('0') : null),
                          _KeyButton(
                            icon: Icons.check_circle_outline,
                            filled: true,
                            onPressed: _inputEnabled && answer.isNotEmpty
                                ? _submit
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (widget.controller.error != null) ...[
                      Text(
                        widget.controller.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xffffb4ab),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        _StatPill(
                            label: 'WHITE BP',
                            value: '${match.white.brainPoints}'),
                        const SizedBox(width: 12),
                        _StatPill(
                            label: 'BLACK BP',
                            value: '${match.black?.brainPoints ?? 0}'),
                        const Spacer(),
                        FilledButton(
                          onPressed: submitting || !deadlinePassed
                              ? null
                              : () => widget.controller.completeBrainRound(),
                          child: Text(deadlinePassed
                              ? 'Complete Round'
                              : 'Locked ${secondsLeft}s'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          )
        : Icon(icon, size: 30);

    return filled
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffc3f5ff),
              foregroundColor: const Color(0xff001f24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: child,
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: color ?? Colors.white,
              side: const BorderSide(color: Color(0xff353437)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xff131315),
        border: Border.all(color: const Color(0xff3b494c)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xff849396),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xff00e38b),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
