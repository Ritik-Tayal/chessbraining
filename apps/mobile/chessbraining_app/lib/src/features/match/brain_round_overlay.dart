import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

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
  static const totalSeconds = 20;
  final random = Random();

  Timer? timer;
  late _Problem problem;
  String answer = '';
  int secondsLeft = totalSeconds;
  int score = 0;
  bool finished = false;
  bool wrong = false;

  @override
  void initState() {
    super.initState();
    problem = _Problem.random(random);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        secondsLeft = max(0, secondsLeft - 1);
        if (secondsLeft == 0) {
          finished = true;
          timer?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = secondsLeft / totalSeconds;
    final match = widget.controller.match!;

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
                        _StatPill(label: 'SCORE', value: '$score'),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xffb600f8).withValues(alpha: 0.22),
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
                            problem.label,
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
                                bottom: BorderSide(color: Color(0xff849396), width: 2),
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
                          for (final value in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
                            _KeyButton(label: value, onPressed: finished ? null : () => _append(value)),
                          _KeyButton(
                            icon: Icons.backspace_outlined,
                            color: const Color(0xffffb4ab),
                            onPressed: finished ? null : _backspace,
                          ),
                          _KeyButton(label: '0', onPressed: finished ? null : () => _append('0')),
                          _KeyButton(
                            icon: Icons.check_circle_outline,
                            filled: true,
                            onPressed: finished ? null : _submit,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _StatPill(label: 'WHITE BP', value: '${match.white.brainPoints}'),
                        const SizedBox(width: 12),
                        _StatPill(label: 'BLACK BP', value: '${match.black?.brainPoints ?? 0}'),
                        const Spacer(),
                        FilledButton(
                          onPressed: score == 0 && !finished
                              ? null
                              : () => widget.controller.claimBrainRoundWin(score),
                          child: Text(finished ? 'Claim Round' : 'Claim $score'),
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

  void _submit() {
    final parsed = int.tryParse(answer);
    if (parsed == problem.answer) {
      setState(() {
        score += 1;
        answer = '';
        problem = _Problem.random(random);
        wrong = false;
        if (score >= 5) {
          finished = true;
          timer?.cancel();
        }
      });
      return;
    }

    setState(() {
      answer = '';
      wrong = true;
    });
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() => wrong = false);
      }
    });
  }
}

class _Problem {
  const _Problem(this.label, this.answer);

  final String label;
  final int answer;

  factory _Problem.random(Random random) {
    final a = random.nextInt(18) + 7;
    final b = random.nextInt(8) + 2;
    final c = random.nextInt(35) + 6;
    final plus = random.nextBool();
    return _Problem(
      plus ? '$a x $b + $c' : '$a x $b - $c',
      plus ? a * b + c : a * b - c,
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
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          )
        : Icon(icon, size: 30);

    return filled
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffc3f5ff),
              foregroundColor: const Color(0xff001f24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: child,
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: color ?? Colors.white,
              side: const BorderSide(color: Color(0xff353437)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
