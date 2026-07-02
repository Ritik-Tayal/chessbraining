import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/match_models.dart';
import 'brain_round_overlay.dart';
import 'chess_board.dart';
import 'fen.dart';
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
  final commandScrollController = ScrollController();
  final homeSectionKey = GlobalKey();
  final playSectionKey = GlobalKey();
  final powerupsSectionKey = GlobalKey();
  final profileSectionKey = GlobalKey();
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

  void _scrollToHomeSection(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) {
      return;
    }
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    clockTicker?.cancel();
    commandScrollController.dispose();
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
                    if (page == _ScreenPage.command)
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
                              scrollController: commandScrollController,
                              homeKey: homeSectionKey,
                              playKey: playSectionKey,
                              powerupsKey: powerupsSectionKey,
                              profileKey: profileSectionKey,
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
              if (page == _ScreenPage.command)
                _HomeBottomNav(
                  onHome: () => _scrollToHomeSection(homeSectionKey),
                  onPlay: () => _scrollToHomeSection(playSectionKey),
                  onPowerups: () => _scrollToHomeSection(powerupsSectionKey),
                  onProfile: () => _scrollToHomeSection(profileSectionKey),
                ),
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
          if (selectedPage == _ScreenPage.play &&
              match != null &&
              MediaQuery.sizeOf(context).width >= 560) ...[
            Text(
              match.phase,
              style: const TextStyle(
                color: AppColors.quiet,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 12),
          ],
          if (selectedPage == _ScreenPage.play && match != null)
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
    required this.scrollController,
    required this.homeKey,
    required this.playKey,
    required this.powerupsKey,
    required this.profileKey,
    required this.onResume,
  });

  final MatchController controller;
  final TextEditingController playerNameController;
  final TextEditingController inviteController;
  final ScrollController scrollController;
  final GlobalKey homeKey;
  final GlobalKey playKey;
  final GlobalKey powerupsKey;
  final GlobalKey profileKey;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 108),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KeyedSubtree(
                      key: homeKey,
                      child: _HomeHero(controller: controller),
                    ),
                    const SizedBox(height: 18),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: _HomeMainPanel(
                              page: this,
                              profileKey: profileKey,
                              playKey: playKey,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            flex: 4,
                            child: _HomeSidePanel(
                              page: this,
                              powerupsKey: powerupsKey,
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _HomeMainPanel(
                            page: this,
                            profileKey: profileKey,
                            playKey: playKey,
                          ),
                          const SizedBox(height: 16),
                          _HomeSidePanel(
                            page: this,
                            powerupsKey: powerupsKey,
                          ),
                        ],
                      ),
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
  const _HomeMainPanel({
    required this.page,
    required this.profileKey,
    required this.playKey,
  });

  final _CommandPage page;
  final GlobalKey profileKey;
  final GlobalKey playKey;

  @override
  Widget build(BuildContext context) {
    final controller = page.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyedSubtree(
          key: profileKey,
          child: _Panel(
            title: 'PROFILE',
            child: _GuestProfileCard(
              controller: controller,
              playerNameController: page.playerNameController,
            ),
          ),
        ),
        const SizedBox(height: 16),
        KeyedSubtree(
          key: playKey,
          child: _Panel(
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
                  const _LoadingBanner(),
                ],
                if (controller.error != null) ...[
                  const SizedBox(height: 14),
                  _ErrorBanner(message: controller.error!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeSidePanel extends StatelessWidget {
  const _HomeSidePanel({
    required this.page,
    required this.powerupsKey,
  });

  final _CommandPage page;
  final GlobalKey powerupsKey;

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
        KeyedSubtree(
          key: powerupsKey,
          child: const _PowerupGuide(),
        ),
      ],
    );
  }
}

class _GuestProfileCard extends StatelessWidget {
  const _GuestProfileCard({
    required this.controller,
    required this.playerNameController,
  });

  final MatchController controller;
  final TextEditingController playerNameController;

  @override
  Widget build(BuildContext context) {
    final player = controller.me;
    final brainPoints = player?.brainPoints ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                border: Border.all(color: AppColors.secondary, width: 2),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.18),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: const Icon(
                Icons.person,
                color: AppColors.surfaceHigh,
                size: 34,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.playerName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Playfair Display',
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'GUEST PLAYER • NEW BRAINER',
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: _ProfileStat(label: 'WINS', value: '0')),
            const SizedBox(width: 10),
            const Expanded(child: _ProfileStat(label: 'LOSSES', value: '0')),
            const SizedBox(width: 10),
            Expanded(
              child: _ProfileStat(label: 'BRAIN POINTS', value: '$brainPoints'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _TechField(
          controller: playerNameController,
          label: 'DISPLAY NAME',
          icon: Icons.edit,
          onChanged: controller.updatePlayerName,
        ),
      ],
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh.withValues(alpha: 0.55),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.75)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.quiet,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              fontFamily: 'Playfair Display',
            ),
          ),
        ],
      ),
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
            right: compact ? -28 : -10,
            bottom: compact ? -26 : -18,
            child: IgnorePointer(
              child: SizedBox(
                width: compact ? 142 : 230,
                height: compact ? 142 : 190,
                child: const _HeroBrainBoardVisual(),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: compact ? 6 : 190),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COMPETITIVE ARENA',
                  style: TextStyle(
                    color: AppColors.secondaryContainer.withValues(alpha: 0.78),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Chess Braining',
                  style: TextStyle(
                    color: AppColors.background,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Playfair Display',
                    height: 0.98,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Chess + brain battles + powerups.',
                  style: TextStyle(
                    color: AppColors.background.withValues(alpha: 0.86),
                    fontSize: compact ? 17 : 20,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _HeroAction(
                      label: 'PLAY NOW',
                      icon: Icons.arrow_forward,
                      primary: true,
                      onPressed:
                          controller.loading ? null : controller.quickplay,
                    ),
                    _HeroAction(
                      label: 'CREATE PRIVATE MATCH',
                      icon: Icons.add,
                      onPressed:
                          controller.loading ? null : controller.createMatch,
                    ),
                  ],
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

class _HeroBrainBoardVisual extends StatelessWidget {
  const _HeroBrainBoardVisual();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _HeroBrainBoardPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _HeroBrainBoardPainter extends CustomPainter {
  const _HeroBrainBoardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final boardSize = size.shortestSide * 0.58;
    final boardOrigin =
        Offset(size.width - boardSize - 8, size.height - boardSize - 6);
    final light = Paint()..color = AppColors.background.withValues(alpha: 0.18);
    final dark = Paint()..color = AppColors.secondary.withValues(alpha: 0.22);
    final cell = boardSize / 4;
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 4; col++) {
        final paint = (row + col).isEven ? light : dark;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              boardOrigin.dx + col * cell,
              boardOrigin.dy + row * cell,
              cell,
              cell,
            ),
            const Radius.circular(4),
          ),
          paint,
        );
      }
    }

    final nodePaint = Paint()
      ..color = AppColors.secondaryContainer.withValues(alpha: 0.56)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = AppColors.secondaryContainer.withValues(alpha: 0.32)
      ..strokeWidth = 2;
    final nodes = [
      Offset(size.width * 0.18, size.height * 0.28),
      Offset(size.width * 0.38, size.height * 0.16),
      Offset(size.width * 0.54, size.height * 0.32),
      Offset(size.width * 0.35, size.height * 0.48),
      Offset(size.width * 0.62, size.height * 0.55),
    ];
    for (var i = 0; i < nodes.length - 1; i++) {
      canvas.drawLine(nodes[i], nodes[i + 1], linePaint);
    }
    canvas.drawLine(nodes[0], nodes[3], linePaint);
    canvas.drawLine(nodes[2], nodes[4], linePaint);
    for (final node in nodes) {
      canvas.drawCircle(node, 7, nodePaint);
      canvas.drawCircle(
        node,
        12,
        Paint()
          ..color = AppColors.secondaryContainer.withValues(alpha: 0.12)
          ..style = PaintingStyle.fill,
      );
    }

    final piecePaint = Paint()
      ..color = AppColors.background.withValues(alpha: 0.42);
    final center = Offset(
        boardOrigin.dx + boardSize * 0.62, boardOrigin.dy + boardSize * 0.42);
    canvas.drawCircle(center, boardSize * 0.12, piecePaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + boardSize * 0.2),
          width: boardSize * 0.22,
          height: boardSize * 0.28,
        ),
        const Radius.circular(18),
      ),
      piecePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + boardSize * 0.36),
          width: boardSize * 0.44,
          height: boardSize * 0.08,
        ),
        const Radius.circular(6),
      ),
      piecePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final foreground =
        primary ? AppColors.primaryContainer : AppColors.background;
    final background =
        primary ? AppColors.background : Colors.white.withValues(alpha: 0.08);
    return SizedBox(
      height: 46,
      child: primary
          ? FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(label),
              style: FilledButton.styleFrom(
                backgroundColor: background,
                foregroundColor: foreground,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                backgroundColor: background,
                foregroundColor: foreground,
                side: BorderSide(
                  color: AppColors.background.withValues(alpha: 0.34),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceBright,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.key, color: AppColors.secondary, size: 20),
              SizedBox(width: 8),
              Text(
                'JOIN WITH CODE',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: inviteController,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
              LengthLimitingTextInputFormatter(6),
              TextInputFormatter.withFunction((oldValue, newValue) {
                final upper = newValue.text.toUpperCase();
                return newValue.copyWith(
                  text: upper,
                  selection: TextSelection.collapsed(offset: upper.length),
                );
              }),
            ],
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 5,
            ),
            decoration: InputDecoration(
              hintText: 'ABC123',
              hintStyle: TextStyle(
                color: AppColors.quiet.withValues(alpha: 0.42),
                letterSpacing: 5,
              ),
              filled: true,
              fillColor: AppColors.surfaceLow,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide:
                    const BorderSide(color: AppColors.secondary, width: 1.4),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ask your friend for the 6-character invite code.',
            style: TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          _ActionButton(
            label: 'JOIN MATCH',
            icon: Icons.login,
            secondary: true,
            onPressed: controller.loading
                ? null
                : () => controller.joinMatch(inviteController.text),
          ),
        ],
      ),
    );
  }
}

class _RulesSnapshot extends StatelessWidget {
  const _RulesSnapshot();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.grid_4x4, '1', 'Play chess', 'Normal legal chess moves.'),
      (
        Icons.calculate,
        '2',
        'Win brain rounds',
        'Fast math battles pause play.'
      ),
      (Icons.bolt, '3', 'Spend BP', 'Use powerups during chess turns.'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 620;
        final cards = [
          for (final step in steps)
            _RuleStepCard(
              icon: step.$1,
              number: step.$2,
              title: step.$3,
              body: step.$4,
            ),
        ];
        if (horizontal) {
          return Row(
            children: [
              for (final card in cards) ...[
                Expanded(child: card),
                if (card != cards.last) const SizedBox(width: 10),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (final card in cards) ...[
              card,
              if (card != cards.last) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _RuleStepCard extends StatelessWidget {
  const _RuleStepCard({
    required this.icon,
    required this.number,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surfaceBright,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Icon(icon, color: AppColors.secondary, size: 22),
              Positioned(
                right: 4,
                bottom: 3,
                child: Text(
                  number,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Playfair Display',
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
        height: 286,
        child: PageView(
          padEnds: false,
          children: const [
            _PowerupSlide(
              icon: Icons.more_time,
              name: 'Clock Boost',
              cost: '1 BP',
              color: AppColors.primary,
              description: 'Add 30 seconds to your clock during chess phase.',
              timing: 'Any active chess phase',
              detail:
                  'Use it any time during active play when you have at least 1 Brain Point.',
              rule: 'Does not consume your turn.',
            ),
            _PowerupSlide(
              icon: Icons.replay,
              name: 'Revive Pawn',
              cost: '3 BP',
              color: AppColors.warning,
              description: 'Return one captured pawn to an empty square.',
              timing: 'Only on your turn',
              detail:
                  'Choose an empty square from ranks 2 through 7. Placement uses your turn.',
              rule: 'Cannot revive onto occupied or promotion-rank squares.',
            ),
            _PowerupSlide(
              icon: Icons.double_arrow,
              name: 'Extra Move',
              cost: '4 BP',
              color: AppColors.secondary,
              description: 'Arm one extra turn after your next legal move.',
              timing: 'Only before your move',
              detail:
                  'Only works on your turn, outside check, and not on a brain-round trigger move.',
              rule: 'First move cannot give check or finish the game.',
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
    required this.timing,
    required this.detail,
    required this.rule,
  });

  final IconData icon;
  final String name;
  final String cost;
  final Color color;
  final String description;
  final String timing;
  final String detail;
  final String rule;

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
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    border: Border.all(color: color.withValues(alpha: 0.32)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 30),
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
            _PowerupMetaLine(
              icon: Icons.schedule,
              label: timing,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const Spacer(),
            _PowerupMetaLine(
              icon: Icons.gavel,
              label: rule,
              color: AppColors.quiet,
            ),
          ],
        ),
      ),
    );
  }
}

class _PowerupMetaLine extends StatelessWidget {
  const _PowerupMetaLine({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
        ),
      ],
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
            _GameTopStrip(controller: controller),
            const SizedBox(height: 10),
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

class _GameTopStrip extends StatelessWidget {
  const _GameTopStrip({required this.controller});

  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    final match = controller.match;
    if (match == null) {
      return const SizedBox.shrink();
    }
    final turnText = controller.isRevivePawnTargeting
        ? 'Place revived pawn'
        : match.isWaiting
            ? 'Waiting for opponent'
            : controller.canMove
                ? 'Your move'
                : '${match.sideToMove} to move';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceBright.withValues(alpha: 0.9),
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  controller.canMove
                      ? Icons.radio_button_checked
                      : Icons.info_outline,
                  color: controller.canMove
                      ? AppColors.secondary
                      : AppColors.quiet,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    turnText.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.9,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: MediaQuery.sizeOf(context).width < 430 ? 176 : 220,
          child: _BrainRoundToGo(controller: controller),
        ),
      ],
    );
  }
}

class _BrainRoundToGo extends StatelessWidget {
  const _BrainRoundToGo({required this.controller});

  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    final match = controller.match;
    final interval = maxInt(1, match?.brainRoundIntervalMoves ?? 5) * 2;
    final ply = match?.plyCount ?? 0;
    final progress = match?.isBrainRound == true ? interval : ply % interval;
    final movesLeft = maxInt(0, interval - progress);
    final value = interval == 0 ? 0.0 : progress / interval;

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'BRAIN ROUND TO GO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.background,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Text(
                match?.isBrainRound == true ? 'NOW' : '$movesLeft',
                style: const TextStyle(
                  color: AppColors.secondaryContainer,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.background.withValues(alpha: 0.18),
              color: AppColors.secondaryContainer,
            ),
          ),
        ],
      ),
    );
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

class _MoveLog extends StatelessWidget {
  const _MoveLog({required this.controller});

  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    final moves = controller.match?.moves ?? const [];
    final movePairs = _movePairs(moves);
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
            : Column(
                children: [
                  if (controller.isReviewingMove) ...[
                    _HistoryModeBanner(controller: controller),
                    const SizedBox(height: 8),
                  ],
                  Expanded(
                    child: ListView.separated(
                      itemCount: movePairs.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: AppColors.border, height: 1),
                      itemBuilder: (context, index) {
                        final pair = movePairs[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 34,
                                child: Text(
                                  '${pair.number}.',
                                  style:
                                      const TextStyle(color: AppColors.muted),
                                ),
                              ),
                              Expanded(
                                child: _MoveNotationButton(
                                  controller: controller,
                                  move: pair.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _MoveNotationButton(
                                  controller: controller,
                                  move: pair.black,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<_MovePair> _movePairs(List<MoveModel> moves) {
    final pairs = <int, _MovePair>{};
    for (final move in moves) {
      final number = (move.plyNumber + 1) ~/ 2;
      final current = pairs[number] ?? _MovePair(number: number);
      pairs[number] = move.side == 'WHITE' || move.plyNumber.isOdd
          ? current.copyWith(white: move)
          : current.copyWith(black: move);
    }
    return pairs.values.toList()..sort((a, b) => a.number.compareTo(b.number));
  }
}

class _MovePair {
  const _MovePair({
    required this.number,
    this.white,
    this.black,
  });

  final int number;
  final MoveModel? white;
  final MoveModel? black;

  _MovePair copyWith({
    MoveModel? white,
    MoveModel? black,
  }) {
    return _MovePair(
      number: number,
      white: white ?? this.white,
      black: black ?? this.black,
    );
  }
}

class _HistoryModeBanner extends StatelessWidget {
  const _HistoryModeBanner({required this.controller});

  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    final move = controller.reviewMove;
    final label = move == null
        ? 'Viewing history'
        : 'Viewing ${moveNotationFromFen(
            fenBefore: move.fenBefore,
            from: move.from,
            to: move.to,
            promotion: move.promotion,
          )}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.36)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.history, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          TextButton(
            onPressed: controller.returnToLivePosition,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoveNotationButton extends StatelessWidget {
  const _MoveNotationButton({
    required this.controller,
    required this.move,
  });

  final MatchController controller;
  final MoveModel? move;

  @override
  Widget build(BuildContext context) {
    final currentMove = move;
    if (currentMove == null) {
      return const SizedBox(height: 34);
    }

    final selected = controller.reviewMove?.plyNumber == currentMove.plyNumber;
    final notation = moveNotationFromFen(
      fenBefore: currentMove.fenBefore,
      from: currentMove.from,
      to: currentMove.to,
      promotion: currentMove.promotion,
    );

    return Material(
      color: selected
          ? AppColors.primaryContainer.withValues(alpha: 0.24)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => controller.viewMovePosition(currentMove),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 34,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.62)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            notation,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? AppColors.primary : AppColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
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

class _HomeBottomNav extends StatelessWidget {
  const _HomeBottomNav({
    required this.onHome,
    required this.onPlay,
    required this.onPowerups,
    required this.onProfile,
  });

  final VoidCallback onHome;
  final VoidCallback onPlay;
  final VoidCallback onPowerups;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 720) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _HomeNavItem(
                label: 'Home',
                icon: Icons.home_outlined,
                active: true,
                onPressed: onHome,
              ),
              _HomeNavItem(
                label: 'Play',
                icon: Icons.extension_outlined,
                onPressed: onPlay,
              ),
              _HomeNavItem(
                label: 'Power-ups',
                icon: Icons.bolt_outlined,
                onPressed: onPowerups,
              ),
              _HomeNavItem(
                label: 'Profile',
                icon: Icons.person_outline,
                onPressed: onProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeNavItem extends StatelessWidget {
  const _HomeNavItem({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.active = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final foreground =
        active ? Colors.white : AppColors.background.withValues(alpha: 0.62);
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: EdgeInsets.symmetric(
          horizontal: active ? 16 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: active ? AppColors.secondary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: foreground, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBanner extends StatelessWidget {
  const _LoadingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer.withValues(alpha: 0.32),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.32)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.secondary,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Preparing your table...',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
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
