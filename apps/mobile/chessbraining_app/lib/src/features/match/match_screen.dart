import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/match_models.dart';
import 'brain_round_overlay.dart';
import 'chess_board.dart';
import 'match_controller.dart';

enum _ScreenPage { command, play }

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
  final playerNameController = TextEditingController();
  final inviteController = TextEditingController();
  Timer? clockTicker;
  DateTime? lastClockExpiryRefreshDeadline;
  _ScreenPage selectedPage = _ScreenPage.command;
  String? activeMatchId;
  String? dismissedCelebrationMatchId;

  @override
  void initState() {
    super.initState();
    playerNameController.text = widget.controller.playerName;
    activeMatchId = widget.controller.match?.matchId;
    if (activeMatchId != null) {
      selectedPage = _ScreenPage.play;
    }
    widget.controller.addListener(_handleControllerChanged);
    clockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _refreshExpiredClock();
        setState(() {});
      }
    });
  }

  void _handleControllerChanged() {
    final matchId = widget.controller.match?.matchId;
    if (matchId != null && matchId != activeMatchId) {
      activeMatchId = matchId;
      dismissedCelebrationMatchId = null;
      if (mounted && selectedPage != _ScreenPage.play) {
        setState(() => selectedPage = _ScreenPage.play);
      }
    }
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
    widget.controller.removeListener(_handleControllerChanged);
    clockTicker?.cancel();
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
        final match = controller.match;
        final page = match == null ? _ScreenPage.command : selectedPage;
        final showPowerBar = page == _ScreenPage.play &&
            match != null &&
            !match.isWaiting &&
            !match.isCompleted;
        final showCelebration = page == _ScreenPage.play &&
            match?.isCompleted == true &&
            dismissedCelebrationMatchId != match!.matchId;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              const _BackgroundGrid(),
              SafeArea(
                child: Column(
                  children: [
                    _TopBar(
                      controller: controller,
                      selectedPage: page,
                      onCommand: () =>
                          setState(() => selectedPage = _ScreenPage.command),
                      onPlay: match == null
                          ? null
                          : () =>
                              setState(() => selectedPage = _ScreenPage.play),
                    ),
                    Expanded(
                      child: page == _ScreenPage.command
                          ? _CommandPage(
                              controller: controller,
                              playerNameController: playerNameController,
                              inviteController: inviteController,
                              onResume: match == null
                                  ? null
                                  : () => setState(
                                        () => selectedPage = _ScreenPage.play,
                                      ),
                            )
                          : _GameplayPage(controller: controller),
                    ),
                  ],
                ),
              ),
              if (showPowerBar) _PowerToolbar(controller: controller),
              if (controller.match?.isBrainRound == true)
                BrainRoundOverlay(controller: controller),
              if (showCelebration)
                _EndGameResult(
                  match: match,
                  playerId: controller.playerId,
                  onReview: () => setState(
                    () => dismissedCelebrationMatchId = match.matchId,
                  ),
                  onCommand: () => setState(() {
                    dismissedCelebrationMatchId = match.matchId;
                    selectedPage = _ScreenPage.command;
                  }),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.selectedPage,
    required this.onCommand,
    required this.onPlay,
  });

  final MatchController controller;
  final _ScreenPage selectedPage;
  final VoidCallback onCommand;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final match = controller.match;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.65)),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.menu, color: AppColors.primary, size: 26),
          const SizedBox(width: 10),
          const Flexible(
            child: Text(
              'CHESS BRAINING',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                fontFamily: 'Playfair Display',
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (match != null)
            _PageSwitch(
              selectedPage: selectedPage,
              onCommand: onCommand,
              onPlay: onPlay,
            ),
          const Spacer(),
          if (MediaQuery.sizeOf(context).width >= 560) ...[
            Text(
              match?.phase ?? 'HOME',
              style: const TextStyle(
                color: AppColors.quiet,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 12),
          ],
          _LiveChip(connected: controller.realtimeConnected),
        ],
      ),
    );
  }
}

class _PageSwitch extends StatelessWidget {
  const _PageSwitch({
    required this.selectedPage,
    required this.onCommand,
    required this.onPlay,
  });

  final _ScreenPage selectedPage;
  final VoidCallback onCommand;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SwitchTab(
            icon: Icons.home_outlined,
            label: 'HOME',
            selected: selectedPage == _ScreenPage.command,
            onPressed: onCommand,
          ),
          _SwitchTab(
            icon: Icons.sports_esports,
            label: 'PLAY',
            selected: selectedPage == _ScreenPage.play,
            onPressed: onPlay,
          ),
        ],
      ),
    );
  }
}

class _SwitchTab extends StatelessWidget {
  const _SwitchTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 620;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 32,
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppColors.background : AppColors.muted,
            ),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.background : AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CommandPage extends StatelessWidget {
  const _CommandPage({
    required this.controller,
    required this.playerNameController,
    required this.inviteController,
    required this.onResume,
  });

  final MatchController controller;
  final TextEditingController playerNameController;
  final TextEditingController inviteController;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: _HomeMainPanel(this)),
                          const SizedBox(width: 18),
                          Expanded(
                            flex: 4,
                            child: _HomeSidePanel(this),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _HomeMainPanel(this),
                          const SizedBox(height: 16),
                          _HomeSidePanel(this),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HomeMainPanel extends StatelessWidget {
  const _HomeMainPanel(this.page);

  final _CommandPage page;

  @override
  Widget build(BuildContext context) {
    final controller = page.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HomeHero(controller: controller),
        const SizedBox(height: 16),
        _Panel(
          title: 'PROFILE',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      border: Border.all(color: AppColors.primary),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TechField(
                      controller: page.playerNameController,
                      label: 'DISPLAY NAME',
                      icon: Icons.edit,
                      onChanged: controller.updatePlayerName,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'PLAY',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 620;
                  final cards = [
                    _PlayModeCard(
                      title: 'Instant Play',
                      description: 'Find a waiting player or create a table.',
                      icon: Icons.flash_on,
                      color: AppColors.primary,
                      onPressed:
                          controller.loading ? null : controller.quickplay,
                    ),
                    _PlayModeCard(
                      title: 'Create Match',
                      description: 'Open a private invite for a friend.',
                      icon: Icons.add_circle_outline,
                      color: AppColors.secondary,
                      onPressed:
                          controller.loading ? null : controller.createMatch,
                    ),
                  ];
                  if (stacked) {
                    return Column(
                      children: [
                        for (final card in cards) ...[
                          card,
                          if (card != cards.last) const SizedBox(height: 10),
                        ],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      for (final card in cards) ...[
                        Expanded(child: card),
                        if (card != cards.last) const SizedBox(width: 10),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              _JoinMatchRow(
                controller: controller,
                inviteController: page.inviteController,
              ),
              if (controller.loading) ...[
                const SizedBox(height: 18),
                const LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: AppColors.surfaceHigh,
                  color: AppColors.primary,
                ),
              ],
              if (controller.error != null) ...[
                const SizedBox(height: 14),
                _ErrorBanner(message: controller.error!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeSidePanel extends StatelessWidget {
  const _HomeSidePanel(this.page);

  final _CommandPage page;

  @override
  Widget build(BuildContext context) {
    final controller = page.controller;
    final match = controller.match;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Panel(
          title: match == null ? 'HOW IT WORKS' : 'ACTIVE MATCH',
          child: match == null
              ? const _RulesSnapshot()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SessionRow(label: 'STATUS', value: match.status),
                    _SessionRow(label: 'PHASE', value: match.phase),
                    _SessionRow(
                      label: 'INVITE',
                      value: match.inviteCode,
                      selectable: true,
                    ),
                    _SessionRow(label: 'MOVE', value: match.sideToMove),
                    const SizedBox(height: 16),
                    _ActionButton(
                      label: 'RESUME GAME',
                      icon: Icons.play_arrow,
                      onPressed: page.onResume,
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        const _PowerupGuide(),
      ],
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({required this.controller});

  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 680;
    return Container(
      padding: EdgeInsets.all(compact ? 18 : 22),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        border: Border.all(color: AppColors.primary),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -26,
            top: -28,
            child: Icon(
              Icons.castle,
              size: compact ? 118 : 156,
              color: AppColors.background.withValues(alpha: 0.07),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: compact ? 28 : 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chess Braining',
                  style: TextStyle(
                    color: AppColors.background,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Playfair Display',
                    height: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Play chess, win brain rounds, spend Brain Points on tactical powerups.',
                  style: TextStyle(
                    color: AppColors.background.withValues(alpha: 0.78),
                    fontSize: compact ? 14 : 16,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _TinyStat(icon: Icons.timer, value: '5 min'),
                    _TinyStat(icon: Icons.calculate, value: 'Math rounds'),
                    _TinyStat(icon: Icons.bolt, value: 'Powerups'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayModeCard extends StatelessWidget {
  const _PlayModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final primaryCard = title == 'Instant Play';
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: onPressed == null ? 0.55 : 1,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: primaryCard
                ? AppColors.primaryContainer
                : AppColors.surfaceHigh.withValues(alpha: 0.7),
            border: Border.all(
              color: primaryCard
                  ? AppColors.primary
                  : AppColors.strongBorder.withValues(alpha: 0.55),
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color:
                      primaryCard ? AppColors.background : AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color:
                            primaryCard ? AppColors.background : AppColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Playfair Display',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        color: primaryCard
                            ? AppColors.background.withValues(alpha: 0.72)
                            : AppColors.muted,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward,
                color: primaryCard ? AppColors.background : AppColors.secondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinMatchRow extends StatelessWidget {
  const _JoinMatchRow({
    required this.controller,
    required this.inviteController,
  });

  final MatchController controller;
  final TextEditingController inviteController;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final input = _TechField(
          controller: inviteController,
          label: 'INVITE CODE',
          icon: Icons.key,
          onChanged: (_) {},
        );
        final button = _ActionButton(
          label: 'JOIN MATCH',
          icon: Icons.login,
          secondary: true,
          onPressed: controller.loading
              ? null
              : () => controller.joinMatch(inviteController.text),
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              input,
              const SizedBox(height: 10),
              button,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: input),
            const SizedBox(width: 10),
            SizedBox(width: 172, child: button),
          ],
        );
      },
    );
  }
}

class _RulesSnapshot extends StatelessWidget {
  const _RulesSnapshot();

  @override
  Widget build(BuildContext context) {
    const rows = [
      (Icons.grid_4x4, 'Chess is normal until a brain round starts.'),
      (Icons.calculate, 'Answer fast math puzzles between chess phases.'),
      (Icons.toll, 'Earn Brain Points from brain-round results.'),
      (Icons.bolt, 'Spend points during your chess turn.'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows) ...[
          _RuleLine(icon: row.$1, text: row.$2),
          if (row != rows.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _RuleLine extends StatelessWidget {
  const _RuleLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _PowerupGuide extends StatelessWidget {
  const _PowerupGuide();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'POWERUPS',
      child: SizedBox(
        height: 230,
        child: PageView(
          padEnds: false,
          children: const [
            _PowerupSlide(
              icon: Icons.more_time,
              name: 'Clock Boost',
              cost: '1 BP',
              color: AppColors.primary,
              description: 'Add 30 seconds to your clock during chess phase.',
              detail:
                  'Use it any time during active play when you have at least 1 Brain Point.',
            ),
            _PowerupSlide(
              icon: Icons.replay,
              name: 'Revive Pawn',
              cost: '3 BP',
              color: AppColors.warning,
              description: 'Return one captured pawn to an empty square.',
              detail:
                  'Choose an empty square from ranks 2 through 7. Placement uses your turn.',
            ),
            _PowerupSlide(
              icon: Icons.double_arrow,
              name: 'Extra Move',
              cost: '4 BP',
              color: AppColors.secondary,
              description: 'Arm one extra turn after your next legal move.',
              detail:
                  'Only works on your turn, outside check, and not on a brain-round trigger move.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PowerupSlide extends StatelessWidget {
  const _PowerupSlide({
    required this.icon,
    required this.name,
    required this.cost,
    required this.color,
    required this.description,
    required this.detail,
  });

  final IconData icon;
  final String name;
  final String cost;
  final Color color;
  final String description;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceBright,
          border: Border.all(color: color.withValues(alpha: 0.48)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Playfair Display',
                    ),
                  ),
                ),
                _StatusTag(label: cost, color: color),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              description,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              detail,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameplayPage extends StatelessWidget {
  const _GameplayPage({required this.controller});

  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1080;
        final availableBoardHeight = constraints.maxHeight - 18 - 106;
        final desktopBoardMax = math.max(
          360.0,
          math.min(760.0, availableBoardHeight - 180),
        );
        return wide
            ? Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 106),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 8,
                      child: _BoardColumn(
                        controller: controller,
                        maxBoardSize: desktopBoardMax,
                      ),
                    ),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: 350,
                      child: _GameInfoRail(controller: controller),
                    ),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 104),
                children: [
                  _BoardColumn(controller: controller),
                  const SizedBox(height: 14),
                  _GameInfoRail(controller: controller),
                ],
              );
      },
    );
  }
}

class _BoardColumn extends StatelessWidget {
  const _BoardColumn({
    required this.controller,
    this.maxBoardSize,
  });

  final MatchController controller;
  final double? maxBoardSize;

  @override
  Widget build(BuildContext context) {
    final match = controller.match;
    final me = controller.me;
    final opponent = _opponent(match, me);
    final width = MediaQuery.sizeOf(context).width;
    final boardMax =
        maxBoardSize ?? (width >= 1080 ? 760.0 : math.min(width - 24, 620.0));

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: boardMax),
        child: Column(
          children: [
            _PlayerBar(
              controller: controller,
              player: opponent,
              fallbackName:
                  match?.black == null ? 'Waiting opponent' : 'Opponent',
              alignRight: true,
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: match == null
                  ? const _EmptyBoard()
                  : _BoardFrame(controller: controller),
            ),
            const SizedBox(height: 10),
            _PlayerBar(
              controller: controller,
              player: me ?? match?.white,
              fallbackName: controller.playerName,
              alignRight: false,
            ),
            const SizedBox(height: 12),
            _TurnStrip(controller: controller),
          ],
        ),
      ),
    );
  }

  PlayerModel? _opponent(MatchModel? match, PlayerModel? me) {
    if (match == null || me == null) {
      return match?.black;
    }
    return me.side == 'WHITE' ? match.black : match.white;
  }
}

class _BoardFrame extends StatelessWidget {
  const _BoardFrame({required this.controller});

  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ChessBoard(controller: controller),
      ),
    );
  }
}

class _PlayerBar extends StatelessWidget {
  const _PlayerBar({
    required this.controller,
    required this.player,
    required this.fallbackName,
    required this.alignRight,
  });

  final MatchController controller;
  final PlayerModel? player;
  final String fallbackName;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final match = controller.match;
    final isTurn = player != null && match?.sideToMove == player!.side;
    final clockMs = _displayClockMs(match, player, isTurn);
    final accent = isTurn ? AppColors.secondary : AppColors.quiet;
    final dark = player?.playerId == controller.playerId;

    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: dark ? AppColors.primaryContainer : AppColors.surfaceLow,
        border: Border.all(
          color: isTurn
              ? AppColors.secondary
              : AppColors.strongBorder.withValues(alpha: 0.25),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        textDirection: alignRight ? TextDirection.rtl : TextDirection.ltr,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: dark ? AppColors.surface : AppColors.surfaceBright,
              border: Border.all(color: accent),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Icon(
              player?.side == 'BLACK' ? Icons.person_4 : Icons.person,
              color: accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: alignRight
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Row(
                  textDirection:
                      alignRight ? TextDirection.rtl : TextDirection.ltr,
                  children: [
                    Flexible(
                      child: Text(
                        (player?.playerName ?? fallbackName).toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: dark ? AppColors.background : AppColors.text,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isTurn)
                      const _StatusTag(
                        label: 'TURN',
                        color: AppColors.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment:
                      alignRight ? WrapAlignment.end : WrapAlignment.start,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _TinyStat(icon: Icons.timer, value: _formatClock(clockMs)),
                    _TinyStat(
                      icon: Icons.psychology,
                      value: '${player?.brainPoints ?? 0} BP',
                    ),
                    if (player?.extraMoveArmed == true)
                      const _StatusTag(
                        label: 'EXTRA ARMED',
                        color: AppColors.secondary,
                      ),
                    if (player?.extraMoveActive == true)
                      const _StatusTag(
                        label: 'EXTRA TURN',
                        color: AppColors.primary,
                      ),
                    if ((player?.revivablePawns ?? 0) > 0)
                      _StatusTag(
                        label: '${player!.revivablePawns} PAWN LOST',
                        color: AppColors.warning,
                      ),
                  ],
                ),
              ],
            ),
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
      final remaining =
          deadline.difference(DateTime.now().toUtc()).inMilliseconds;
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

class _GameInfoRail extends StatelessWidget {
  const _GameInfoRail({required this.controller});

  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InvitePanel(controller: controller),
        const SizedBox(height: 14),
        _BrainProgress(controller: controller),
        const SizedBox(height: 14),
        _MoveLog(controller: controller),
        const SizedBox(height: 14),
        _EvaluationPanel(controller: controller),
        if (controller.error != null) ...[
          const SizedBox(height: 14),
          _ErrorBanner(message: controller.error!),
        ],
      ],
    );
  }
}

class _InvitePanel extends StatelessWidget {
  const _InvitePanel({required this.controller});

  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    final match = controller.match;
    if (match == null) {
      return const SizedBox.shrink();
    }
    return _Panel(
      title: 'MATCH',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'INVITE CODE',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                SelectableText(
                  match.inviteCode,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          _LiveChip(connected: controller.realtimeConnected),
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

    return _Panel(
      title: 'BRAIN ROUND',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                match?.isBrainRound == true ? 'ACTIVE' : 'NEXT CHECKPOINT',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                '$progress / $interval',
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: interval == 0 ? 0 : progress / interval,
              minHeight: 12,
              backgroundColor: AppColors.surfaceHigh,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoveLog extends StatelessWidget {
  const _MoveLog({required this.controller});

  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    final moves = controller.match?.moves ?? const [];
    return _Panel(
      title: 'MOVES',
      child: SizedBox(
        height: 230,
        child: moves.isEmpty
            ? const Center(
                child: Text(
                  'No moves yet',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : ListView.separated(
                itemCount: moves.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: AppColors.border, height: 1),
                itemBuilder: (context, index) {
                  final move = moves[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          child: Text(
                            '${move.plyNumber}.',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${move.from}-${move.to}',
                            style: const TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          move.side,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
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
      title: 'BRAIN POINTS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PointRow(
            label: match?.white.playerName ?? 'White',
            points: whitePoints,
            color: AppColors.primary,
          ),
          const SizedBox(height: 10),
          _PointRow(
            label: match?.black?.playerName ?? 'Black',
            points: blackPoints,
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow({
    required this.label,
    required this.points,
    required this.color,
  });

  final String label;
  final int points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            '$points BP',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
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
    final text = controller.isRevivePawnTargeting
        ? 'Choose an empty square for revived pawn'
        : match.isCompleted
            ? match.resultReason ?? 'Completed'
            : controller.canMove
                ? 'Your move'
                : match.isWaiting
                    ? 'Waiting for opponent'
                    : '${match.sideToMove} to move';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceBright,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            controller.canMove
                ? Icons.radio_button_checked
                : Icons.info_outline,
            color: controller.canMove ? AppColors.secondary : AppColors.quiet,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SelectableText(
            match.inviteCode,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
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
    final targeting = controller.isRevivePawnTargeting;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          height: 98,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 18,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _PowerButton(
                    label: 'EXTRA',
                    icon: Icons.double_arrow,
                    enabled: controller.canArmExtraMove,
                    primary: controller.me?.extraMoveArmed == true,
                    onPressed: controller.armExtraMove,
                  ),
                  const SizedBox(width: 10),
                  _PowerButton(
                    label: targeting ? 'CANCEL' : 'REVIVE',
                    icon: targeting ? Icons.close : Icons.replay,
                    enabled: targeting || controller.canRevivePawn,
                    primary: targeting,
                    onPressed: targeting
                        ? controller.cancelPowerupTargeting
                        : controller.startRevivePawnTargeting,
                  ),
                  const SizedBox(width: 10),
                  _PowerButton(
                    label: '+30 SEC',
                    icon: Icons.more_time,
                    enabled: controller.canUseClockBoost,
                    onPressed: controller.applyClockBoost,
                  ),
                  const SizedBox(width: 10),
                  _PowerButton(
                    label: 'RESIGN',
                    icon: Icons.flag,
                    enabled: controller.match?.isChessPhase == true ||
                        controller.match?.isBrainRound == true,
                    onPressed: controller.resign,
                  ),
                ],
              ),
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
            ? Colors.white
            : AppColors.primary
        : AppColors.quiet;
    final background = primary && enabled
        ? AppColors.secondary
        : enabled
            ? AppColors.surfaceLow
            : AppColors.surfaceHigh;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 96,
          height: 68,
          decoration: BoxDecoration(
            color: background,
            border: Border.all(
              color: primary && enabled
                  ? AppColors.secondary
                  : AppColors.strongBorder.withValues(alpha: 0.32),
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EndGameResult extends StatefulWidget {
  const _EndGameResult({
    required this.match,
    required this.playerId,
    required this.onReview,
    required this.onCommand,
  });

  final MatchModel match;
  final String playerId;
  final VoidCallback onReview;
  final VoidCallback onCommand;

  @override
  State<_EndGameResult> createState() => _EndGameResultState();
}

class _EndGameResultState extends State<_EndGameResult>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late List<_ConfettiParticle> particles;
  late _GameResult result;

  @override
  void initState() {
    super.initState();
    result = _calculateResult();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..forward();
    if (result == _GameResult.win) {
      particles = _makeParticles(widget.match.matchId.hashCode);
    }
  }

  @override
  void didUpdateWidget(covariant _EndGameResult oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.matchId != widget.match.matchId) {
      result = _calculateResult();
      if (result == _GameResult.win) {
        particles = _makeParticles(widget.match.matchId.hashCode);
      }
      controller.forward(from: 0);
    }
  }

  _GameResult _calculateResult() {
    if (widget.match.isDraw) {
      return _GameResult.draw;
    }
    return widget.match.winnerPlayerId == widget.playerId
        ? _GameResult.win
        : _GameResult.loss;
  }

  List<_ConfettiParticle> _makeParticles(int seed) {
    final random = math.Random(seed);
    const colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.warning,
      Color(0xfff472b6),
      Color(0xfff8fafc),
    ];
    return List.generate(90, (index) {
      return _ConfettiParticle(
        x: random.nextDouble(),
        y: -random.nextDouble(),
        drift: random.nextDouble() * 0.7 - 0.35,
        size: 5 + random.nextDouble() * 7,
        speed: 0.55 + random.nextDouble() * 0.9,
        rotation: random.nextDouble() * math.pi,
        color: colors[index % colors.length],
      );
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (result) {
      _GameResult.win => _EndGameCelebration(
          match: widget.match,
          playerId: widget.playerId,
          onReview: widget.onReview,
          onCommand: widget.onCommand,
          controller: controller,
          particles: particles,
        ),
      _GameResult.loss => _EndGameDefeat(
          match: widget.match,
          playerId: widget.playerId,
          onReview: widget.onReview,
          onCommand: widget.onCommand,
        ),
      _GameResult.draw => _EndGameDraw(
          match: widget.match,
          playerId: widget.playerId,
          onReview: widget.onReview,
          onCommand: widget.onCommand,
        ),
    };
  }
}

enum _GameResult { win, loss, draw }

class _EndGameCelebration extends StatelessWidget {
  const _EndGameCelebration({
    required this.match,
    required this.playerId,
    required this.onReview,
    required this.onCommand,
    required this.controller,
    required this.particles,
  });

  final MatchModel match;
  final String playerId;
  final VoidCallback onReview;
  final VoidCallback onCommand;
  final AnimationController controller;
  final List<_ConfettiParticle> particles;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          IgnorePointer(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ConfettiPainter(
                    particles: particles,
                    progress: Curves.easeOut.transform(controller.value),
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
          _buildCelebrationCard(context),
        ],
      ),
    );
  }

  Widget _buildCelebrationCard(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBright,
                  border: Border.all(color: AppColors.border, width: 1.5),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      blurRadius: 34,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondary.withValues(alpha: 0.22),
                            blurRadius: 26,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        color: AppColors.surfaceHigh,
                        size: 58,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'YOU WON',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontFamily: 'Playfair Display',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _resultReason(),
                      style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.replay, size: 18),
                            label: const Text('REVIEW'),
                            onPressed: onReview,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.home, size: 18),
                            label: const Text('HOME'),
                            onPressed: onCommand,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryContainer,
                              foregroundColor: AppColors.background,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
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

  String _resultReason() {
    final reason = match.resultReason;
    if (reason != null && reason.isNotEmpty) {
      return reason;
    }
    return match.winnerPlayerId == playerId ? 'Checkmate' : 'Game over';
  }
}

class _EndGameDefeat extends StatelessWidget {
  const _EndGameDefeat({
    required this.match,
    required this.playerId,
    required this.onReview,
    required this.onCommand,
  });

  final MatchModel match;
  final String playerId;
  final VoidCallback onReview;
  final VoidCallback onCommand;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          // Subtle dimming overlay
          Container(
            color: AppColors.primary.withValues(alpha: 0.38),
          ),
          _buildDefeatCard(context),
        ],
      ),
    );
  }

  Widget _buildDefeatCard(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBright,
                  border: Border.all(color: AppColors.warning, width: 1.5),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      blurRadius: 34,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sentiment_very_dissatisfied,
                        color: AppColors.warning, size: 58),
                    const SizedBox(height: 12),
                    Text(
                      'DEFEAT',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontFamily: 'Playfair Display',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _resultReason(),
                      style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.replay, size: 18),
                            label: const Text('REVIEW'),
                            onPressed: onReview,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.warning,
                              side: const BorderSide(color: AppColors.warning),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.home, size: 18),
                            label: const Text('HOME'),
                            onPressed: onCommand,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryContainer,
                              foregroundColor: AppColors.background,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
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

  String _resultReason() {
    final reason = match.resultReason;
    if (reason != null && reason.isNotEmpty) {
      return reason;
    }
    return match.winnerPlayerId == playerId ? 'Checkmate' : 'Game over';
  }
}

class _EndGameDraw extends StatelessWidget {
  const _EndGameDraw({
    required this.match,
    required this.playerId,
    required this.onReview,
    required this.onCommand,
  });

  final MatchModel match;
  final String playerId;
  final VoidCallback onReview;
  final VoidCallback onCommand;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          // Subtle overlay
          Container(
            color: AppColors.primary.withValues(alpha: 0.38),
          ),
          _buildDrawCard(context),
        ],
      ),
    );
  }

  Widget _buildDrawCard(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBright,
                  border: Border.all(color: AppColors.secondary, width: 1.5),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      blurRadius: 34,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.handshake,
                        color: AppColors.secondary, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'DRAW',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontFamily: 'Playfair Display',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _resultReason(),
                      style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.replay, size: 18),
                            label: const Text('REVIEW'),
                            onPressed: onReview,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.secondary,
                              side:
                                  const BorderSide(color: AppColors.secondary),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.home, size: 18),
                            label: const Text('HOME'),
                            onPressed: onCommand,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryContainer,
                              foregroundColor: AppColors.background,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
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

  String _resultReason() {
    final reason = match.resultReason;
    if (reason != null && reason.isNotEmpty) {
      return reason;
    }
    return 'Stalemate / Insufficient material';
  }
}

class _ConfettiParticle {
  const _ConfettiParticle({
    required this.x,
    required this.y,
    required this.drift,
    required this.size,
    required this.speed,
    required this.rotation,
    required this.color,
  });

  final double x;
  final double y;
  final double drift;
  final double size;
  final double speed;
  final double rotation;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({
    required this.particles,
    required this.progress,
  });

  final List<_ConfettiParticle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final particle in particles) {
      final x = (particle.x + particle.drift * progress) * size.width;
      final y = (particle.y + particle.speed * progress) * size.height;
      if (y < -20 || y > size.height + 20) {
        continue;
      }
      paint.color = particle.color.withValues(alpha: 1 - progress * 0.25);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(particle.rotation + progress * math.pi * 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: particle.size,
            height: particle.size * 0.55,
          ),
          const Radius.circular(1),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.particles != particles;
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
        color: AppColors.surface.withValues(alpha: 0.92),
        border:
            Border.all(color: AppColors.strongBorder.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 2.2,
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: AppColors.border.withValues(alpha: 0.7), height: 1),
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
    required this.icon,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style:
          const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.secondary),
        labelText: label,
        labelStyle: const TextStyle(
          color: AppColors.quiet,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
        filled: true,
        fillColor: AppColors.surfaceBright,
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.primary),
          borderRadius: BorderRadius.circular(8),
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
    return SizedBox(
      height: 48,
      child: secondary
          ? OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondary,
                side: const BorderSide(color: AppColors.secondary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            )
          : FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: AppColors.background,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final valueStyle = const TextStyle(
      color: AppColors.text,
      fontWeight: FontWeight.w900,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: selectable
                ? SelectableText(value, style: valueStyle)
                : Text(value,
                    style: valueStyle, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _TinyStat extends StatelessWidget {
  const _TinyStat({
    required this.icon,
    required this.value,
  });

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.secondary),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
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
        color: connected ? AppColors.secondary : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        connected ? 'LIVE' : 'SYNC',
        style: TextStyle(
          color: connected ? Colors.white : AppColors.quiet,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.error),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.error,
          fontWeight: FontWeight.w800,
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
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            'Create or join a match',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
            ),
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
    return CustomPaint(
      painter: const _ParchmentPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _ParchmentPainter extends CustomPainter {
  const _ParchmentPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.background,
          AppColors.surfaceLow,
          AppColors.background,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    final squarePaint = Paint();
    const cell = 56.0;
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        final even = ((x / cell).floor() + (y / cell).floor()).isEven;
        squarePaint.color = (even ? AppColors.secondary : AppColors.primary)
            .withValues(alpha: 0.018);
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), squarePaint);
      }
    }

    final fleckPaint = Paint()
      ..color = AppColors.strongBorder.withValues(alpha: 0.035);
    final width = math.max(1, size.width.toInt());
    final height = math.max(1, size.height.toInt());
    for (var i = 0; i < 180; i++) {
      final dx = (i * 37 % width).toDouble();
      final dy = (i * 61 % height).toDouble();
      canvas.drawCircle(Offset(dx, dy), i.isEven ? 0.8 : 0.45, fleckPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AppColors {
  static const background = Color(0xfffff8f1);
  static const surfaceLow = Color(0xfffbf2e7);
  static const surface = Color(0xfff5ede2);
  static const surfaceHigh = Color(0xffe9e1d7);
  static const surfaceBright = Color(0xffffffff);
  static const border = Color(0xffd1c4bd);
  static const strongBorder = Color(0xff8c6a50);
  static const primary = Color(0xff170f0a);
  static const primaryContainer = Color(0xff2d241e);
  static const secondary = Color(0xff78583f);
  static const secondaryContainer = Color(0xfffdd2b2);
  static const warning = Color(0xffa69076);
  static const text = Color(0xff1e1b15);
  static const muted = Color(0xff4e4540);
  static const quiet = Color(0xff7f756f);
  static const error = Color(0xffba1a1a);
}

int maxInt(int a, int b) => a > b ? a : b;
