import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/match_models.dart';
import 'brain_round_overlay.dart';
import 'chess_board.dart';
import 'match_controller.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({
    required this.controller,
    super.key,
  });

  final MatchController controller;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  final apiUrlController = TextEditingController(
    text: 'http://localhost:8080/api/v1',
  );
  final playerNameController = TextEditingController(text: 'Neo Master');
  final inviteController = TextEditingController();
  Timer? clockTicker;
  DateTime? lastClockExpiryRefreshDeadline;

  @override
  void initState() {
    super.initState();
    clockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _refreshExpiredClock();
        setState(() {});
      }
    });
  }

  void _refreshExpiredClock() {
    final current = widget.controller.match;
    final deadline = current?.clockDeadlineAt;
    if (current?.isChessPhase != true || deadline == null) {
      return;
    }
    if (DateTime.now().toUtc().isBefore(deadline)) {
      return;
    }
    if (lastClockExpiryRefreshDeadline == deadline) {
      return;
    }
    lastClockExpiryRefreshDeadline = deadline;
    unawaited(widget.controller.refresh());
  }

  @override
  void dispose() {
    clockTicker?.cancel();
    apiUrlController.dispose();
    playerNameController.dispose();
    inviteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              const _BackgroundGrid(),
              SafeArea(
                child: Column(
                  children: [
                    _TopBar(controller: controller),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1280),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final wide = constraints.maxWidth >= 980;
                                return wide
                                    ? _DesktopLayout(
                                        controller: controller,
                                        apiUrlController: apiUrlController,
                                        playerNameController: playerNameController,
                                        inviteController: inviteController,
                                      )
                                    : _MobileLayout(
                                        controller: controller,
                                        apiUrlController: apiUrlController,
                                        playerNameController: playerNameController,
                                        inviteController: inviteController,
                                      );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _PowerToolbar(controller: controller),
              if (controller.match?.isBrainRound == true)
                BrainRoundOverlay(controller: controller),
            ],
          ),
        );
      },
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.controller,
    required this.apiUrlController,
    required this.playerNameController,
    required this.inviteController,
  });

  final MatchController controller;
  final TextEditingController apiUrlController;
  final TextEditingController playerNameController;
  final TextEditingController inviteController;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _LeftRail(
            controller: controller,
            apiUrlController: apiUrlController,
            playerNameController: playerNameController,
            inviteController: inviteController,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 5,
          child: _BoardColumn(controller: controller),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 3,
          child: _RightRail(controller: controller),
        ),
      ],
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.controller,
    required this.apiUrlController,
    required this.playerNameController,
    required this.inviteController,
  });

  final MatchController controller;
  final TextEditingController apiUrlController;
  final TextEditingController playerNameController;
  final TextEditingController inviteController;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _LobbyPanel(
          controller: controller,
          apiUrlController: apiUrlController,
          playerNameController: playerNameController,
          inviteController: inviteController,
        ),
        const SizedBox(height: 16),
        _BrainProgress(controller: controller),
        const SizedBox(height: 16),
        _PlayerCard(controller: controller, top: true),
        const SizedBox(height: 16),
        _BoardColumn(controller: controller),
        const SizedBox(height: 16),
        _MoveLog(controller: controller),
        const SizedBox(height: 16),
        _PlayerCard(controller: controller, top: false),
      ],
    );
  }
}

class _LeftRail extends StatelessWidget {
  const _LeftRail({
    required this.controller,
    required this.apiUrlController,
    required this.playerNameController,
    required this.inviteController,
  });

  final MatchController controller;
  final TextEditingController apiUrlController;
  final TextEditingController playerNameController;
  final TextEditingController inviteController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _LobbyPanel(
          controller: controller,
          apiUrlController: apiUrlController,
          playerNameController: playerNameController,
          inviteController: inviteController,
        ),
        const SizedBox(height: 16),
        _PlayerCard(controller: controller, top: true),
      ],
    );
  }
}

class _RightRail extends StatelessWidget {
  const _RightRail({required this.controller});

  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MoveLog(controller: controller),
        const SizedBox(height: 16),
        _EvaluationPanel(controller: controller),
        const SizedBox(height: 16),
        _PlayerCard(controller: controller, top: false),
      ],
    );
  }
}

class _BoardColumn extends StatelessWidget {
  const _BoardColumn({required this.controller});

  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    final match = controller.match;
    return Column(
      children: [
        _BrainProgress(controller: controller),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: match == null
              ? const _EmptyBoard()
              : ChessBoard(controller: controller),
        ),
        const SizedBox(height: 14),
        _TurnStrip(controller: controller),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});

  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    final match = controller.match;
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.menu, color: AppColors.primary),
          const SizedBox(width: 16),
          const Text(
            'CHESS BRAINING',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),
          _LiveChip(connected: controller.realtimeConnected),
          const SizedBox(width: 12),
          Text(
            match?.phase ?? 'LOBBY',
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _LobbyPanel extends StatelessWidget {
  const _LobbyPanel({
    required this.controller,
    required this.apiUrlController,
    required this.playerNameController,
    required this.inviteController,
  });

  final MatchController controller;
  final TextEditingController apiUrlController;
  final TextEditingController playerNameController;
  final TextEditingController inviteController;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'COMMAND CENTER',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TechField(
            controller: playerNameController,
            label: 'CALLSIGN',
            onChanged: controller.updatePlayerName,
          ),
          const SizedBox(height: 12),
          _TechField(
            controller: apiUrlController,
            label: 'API ENDPOINT',
            onChanged: controller.updateApiBaseUrl,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'CREATE',
                  icon: Icons.add,
                  onPressed: controller.loading ? null : controller.createMatch,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: 'QUICKPLAY',
                  icon: Icons.bolt,
                  secondary: true,
                  onPressed: controller.loading ? null : controller.quickplay,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TechField(
                  controller: inviteController,
                  label: 'INVITE CODE',
                  onChanged: (_) {},
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                tooltip: 'Join match',
                onPressed: controller.loading
                    ? null
                    : () => controller.joinMatch(inviteController.text),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.login),
              ),
            ],
          ),
          if (controller.error != null) ...[
            const SizedBox(height: 12),
            Text(
              controller.error!,
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BrainProgress extends StatelessWidget {
  const _BrainProgress({required this.controller});

  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    final match = controller.match;
    final interval = maxInt(1, match?.brainRoundIntervalMoves ?? 5) * 2;
    final ply = match?.plyCount ?? 0;
    final progress = match?.isBrainRound == true ? interval : ply % interval;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'BRAIN ROUND IN',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
            const Spacer(),
            Text(
              match?.isBrainRound == true ? 'ACTIVE' : '$progress / $interval',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < interval; i++)
              Expanded(
                child: Container(
                  height: 12,
                  margin: EdgeInsets.only(right: i == interval - 1 ? 0 : 4),
                  color: i < progress
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.controller,
    required this.top,
  });

  final MatchController controller;
  final bool top;

  @override
  Widget build(BuildContext context) {
    final match = controller.match;
    final player = top ? match?.black : match?.white;
    final fallback = top ? 'WAITING_OPPONENT' : controller.playerName.toUpperCase();
    final accent = top ? AppColors.primary : AppColors.secondary;
    final isTurn = match?.sideToMove == player?.side;
    final clockMs = _displayClockMs(match, player, isTurn);

    return _Panel(
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              border: Border.all(color: accent, width: 1.5),
              color: AppColors.surfaceHigh,
            ),
            child: Icon(top ? Icons.smart_toy : Icons.person, color: accent, size: 34),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  (player?.playerName ?? fallback).toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Text(
                player?.side ?? (top ? 'BLACK' : 'WHITE'),
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: (clockMs / 300000).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: AppColors.background,
            color: clockMs <= 30000 ? const Color(0xffffb4ab) : AppColors.primary,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MiniMetric(label: 'CLOCK', value: _formatClock(clockMs)),
              _MiniMetric(label: 'BRAIN POINTS', value: '${player?.brainPoints ?? 0}'),
            ],
          ),
        ],
      ),
    );
  }

  int _displayClockMs(MatchModel? match, PlayerModel? player, bool isTurn) {
    if (player == null) {
      return 0;
    }
    final deadline = match?.clockDeadlineAt;
    if (match?.isChessPhase == true && isTurn && deadline != null) {
      final remaining = deadline.difference(DateTime.now().toUtc()).inMilliseconds;
      return maxInt(0, remaining);
    }
    return player.clockMs;
  }

  String _formatClock(int clockMs) {
    final totalSeconds = (clockMs / 1000).ceil();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _MoveLog extends StatelessWidget {
  const _MoveLog({required this.controller});

  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    final moves = controller.match?.moves ?? const [];
    return _Panel(
      title: 'MOVE LOG',
      child: SizedBox(
        height: 280,
        child: moves.isEmpty
            ? const Center(
                child: Text('NO MOVES RECORDED', style: TextStyle(color: AppColors.muted)),
              )
            : ListView.separated(
                itemCount: moves.length,
                separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 1),
                itemBuilder: (context, index) {
                  final move = moves[index];
                  final accent = move.side == 'WHITE' ? AppColors.text : AppColors.primary;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${move.plyNumber}.',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${move.from}-${move.to}',
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          move.side,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _EvaluationPanel extends StatelessWidget {
  const _EvaluationPanel({required this.controller});

  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    final match = controller.match;
    final whitePoints = match?.white.brainPoints ?? 0;
    final blackPoints = match?.black?.brainPoints ?? 0;
    return _Panel(
      title: 'NEURAL EVALUATION',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: maxInt(1, whitePoints + 1),
                child: Container(height: 4, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: maxInt(1, blackPoints + 1),
                child: Container(height: 4, color: AppColors.secondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            match == null
                ? 'AWAITING MATCH DATA'
                : '${match.white.playerName.toUpperCase()} $whitePoints BP | ${match.black?.playerName.toUpperCase() ?? 'WAITING'} $blackPoints BP',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TurnStrip extends StatelessWidget {
  const _TurnStrip({required this.controller});

  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    final match = controller.match;
    if (match == null) {
      return const SizedBox.shrink();
    }
    final text = match.isCompleted
        ? match.resultReason ?? 'COMPLETED'
        : controller.canMove
            ? 'YOUR MOVE'
            : match.isWaiting
                ? 'WAITING FOR OPPONENT'
                : '${match.sideToMove} TO MOVE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          SelectableText(
            'INVITE ${match.inviteCode}',
            style: const TextStyle(color: AppColors.text),
          ),
        ],
      ),
    );
  }
}

class _PowerToolbar extends StatelessWidget {
  const _PowerToolbar({required this.controller});

  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    final match = controller.match;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: 78,
        decoration: const BoxDecoration(
          color: AppColors.surfaceLow,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _PowerButton(label: 'UNDO', icon: Icons.undo, enabled: false),
                _PowerButton(
                  label: 'SPAWN',
                  icon: Icons.bolt,
                  enabled: false,
                  primary: true,
                ),
                _PowerButton(
                  label: '+30 SEC',
                  icon: Icons.more_time,
                  enabled: controller.canUseClockBoost,
                  onPressed: controller.applyClockBoost,
                ),
                _PowerButton(
                  label: match?.isBrainRound == true ? 'BRAIN' : 'ANALYZE',
                  icon: Icons.psychology,
                  enabled: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PowerButton extends StatelessWidget {
  const _PowerButton({
    required this.label,
    required this.icon,
    required this.enabled,
    this.onPressed,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final foreground = enabled
        ? primary
            ? AppColors.background
            : AppColors.secondary
        : AppColors.muted;
    final background = primary && enabled ? AppColors.primary : Colors.transparent;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: enabled ? 1 : 0.42,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: background,
            border: Border.all(color: primary && enabled ? AppColors.primary : AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.title,
  });

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

class _TechField extends StatelessWidget {
  const _TechField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: AppColors.muted,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
        filled: true,
        fillColor: AppColors.background,
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.secondary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    return secondary
        ? OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.secondary,
              side: const BorderSide(color: AppColors.secondary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          )
        : FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: connected ? AppColors.primary : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        connected ? 'LIVE' : 'OFFLINE',
        style: TextStyle(
          color: connected ? AppColors.background : AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.grid_4x4, color: AppColors.primary, size: 52),
              SizedBox(height: 16),
              Text(
                'CREATE OR JOIN A MATCH',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackgroundGrid extends StatelessWidget {
  const _BackgroundGrid();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        backgroundBlendMode: BlendMode.screen,
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.1,
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.background,
          ],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class AppColors {
  static const background = Color(0xff0a0a0a);
  static const surfaceLow = Color(0xff111111);
  static const surface = Color(0xff171717);
  static const surfaceHigh = Color(0xff262626);
  static const border = Color(0xff3c4a42);
  static const primary = Color(0xff10b981);
  static const secondary = Color(0xff3b82f6);
  static const text = Color(0xffe5e2e1);
  static const muted = Color(0xff86948a);
  static const error = Color(0xffffb4ab);
}

int maxInt(int a, int b) => a > b ? a : b;
