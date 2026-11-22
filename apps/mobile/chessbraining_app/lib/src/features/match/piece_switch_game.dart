import 'dart:async';
import 'dart:convert';
import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../../services/sound_service.dart';
import 'match_controller.dart';

class PieceSwitchGame extends StatefulWidget {
  const PieceSwitchGame(
      {super.key,
      this.socketFactory,
      required this.controller,
      required this.roundId,
      required this.puzzles,
      required this.view,
      required this.side,
      required this.arena});
  final MatchController controller;
  final String roundId;
  final List<String> puzzles;
  final Map<String, dynamic> view;
  final String side;
  final bool arena;
  final StompClient Function(StompConfig config)? socketFactory;
  @override
  State<PieceSwitchGame> createState() => _PieceSwitchGameState();
}

class _PieceSwitchGameState extends State<PieceSwitchGame> {
  static final _drafts = <String, List<Map<String, dynamic>>>{};
  static const _colors = [
    Color(0xff75b9ed),
    Color(0xfff5ad67),
    Color(0xffef98c0)
  ];
  static const _names = ['Blue', 'Orange', 'Pink'];
  static const _pieces = ['Pawn', 'Knight', 'Rook'];
  late List<Map<String, dynamic>> _questions;
  late List<Map<String, dynamic>> _answers;
  late Map<String, dynamic> _view;
  final _clock = Stopwatch();
  final _focus = FocusNode();
  late int _anchor;
  int _anchorElapsed = 0;
  int _lockUntil = 0;
  int _feedback = 0;
  int _opponent = 0;
  int _lastFinal = -1000;
  int _acknowledgedCount = -1;
  int _lastSnapshot = 0;
  bool _ready = false;
  bool _busy = false;
  bool _offline = false;
  bool _completed = false;
  Timer? _frame;
  Timer? _network;
  StompClient? _socket;
  int get _now => _anchor + _clock.elapsedMilliseconds - _anchorElapsed;
  int get _startsAt => (_view['startsAt'] as num).toInt();
  int get _remaining => ((_startsAt + 45000 - _now + 999) ~/ 1000).clamp(0, 45);
  String get _draftKey => '${widget.roundId}:${widget.controller.playerId}';
  int _solution(Map<String, dynamic> q) => q['rule'] == 'COLOR'
      ? q['color'] as int
      : q['rule'] == 'PIECE'
          ? q['piece'] as int
          : (q['count'] as int) - 1;
  int get _score => _answers.fold(
      0,
      (sum, a) =>
          sum +
          (_solution(_questions[a['questionIndex'] as int]) == a['chosenButton']
              ? 1
              : -1));

  @override
  void initState() {
    super.initState();
    _questions = widget.puzzles
        .map((p) => jsonDecode(p) as Map<String, dynamic>)
        .toList();
    _answers = _drafts.putIfAbsent(_draftKey, () => []);
    _view = widget.view;
    _anchor = (_view['serverNow'] as num).toInt();
    _clock.start();
    _frame = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      if (_remaining == 0 &&
          _clock.elapsedMilliseconds - _lastFinal > 900 &&
          _ready &&
          !_completed) {
        _lastFinal = _clock.elapsedMilliseconds;
        unawaited(_send(finalSubmission: true));
      }
      setState(() {});
    });
    _network = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (_busy || _completed) return;
      if (_ready &&
          _remaining > 0 &&
          _acknowledgedCount == _answers.length &&
          _clock.elapsedMilliseconds - _lastSnapshot < 2500) {
        return;
      }
      _busy = true;
      unawaited(_send().whenComplete(() => _busy = false));
    });
    unawaited(_send());
    final base = Uri.parse(widget.controller.apiBaseUrl);
    final config = StompConfig(
      url: base
          .replace(
              scheme: base.scheme == 'https' ? 'wss' : 'ws',
              path: '/ws',
              query: '')
          .toString(),
      onConnect: (_) => _socket?.subscribe(
          destination: '/topic/piece-switch/${widget.roundId}',
          callback: (frame) {
            if (frame.body != null && mounted) {
              try {
                _merge(jsonDecode(frame.body!) as Map<String, dynamic>);
              } on FormatException {
                /* HTTP snapshots recover invalid frames. */
              }
            }
          }),
      onWebSocketError: (_) {},
      reconnectDelay: const Duration(seconds: 2),
    );
    _socket = widget.socketFactory?.call(config) ?? StompClient(config: config);
    _socket!.activate();
  }

  void _merge(Map<String, dynamic> response) {
    final incoming = response['pieceSwitch'] as Map<String, dynamic>?;
    if (incoming == null ||
        (incoming['revision'] as num) < (_view['revision'] as num)) {
      return;
    }
    setState(() {
      _view = incoming;
      _opponent = (widget.side == 'WHITE'
                  ? response['blackScore'] ?? response['blackCorrectCount']
                  : response['whiteScore'] ?? response['whiteCorrectCount'])
              as int? ??
          0;
      _completed = response['status'] == 'COMPLETED';
      if (_completed) _drafts.remove(_draftKey);
    });
  }

  Future<void> _send({bool finalSubmission = false}) async {
    final readyRequest = !_ready;
    final sent = _clock.elapsedMilliseconds;
    final sentCount = _answers.length;
    try {
      final response = await widget.controller.sendPieceSwitch(
          arena: widget.arena,
          roundId: widget.roundId,
          ready: readyRequest,
          answers: List.of(_answers),
          finished: finalSubmission || _remaining == 0);
      if (!mounted) return;
      if (readyRequest) {
        final timing = response['pieceSwitch'] as Map;
        final serverNow = (timing['serverNow'] as num).toInt();
        final processing = serverNow -
            ((timing['serverReceivedAt'] as num?)?.toInt() ?? serverNow);
        _anchor = serverNow +
            (_clock.elapsedMilliseconds - sent - processing).clamp(0, 10000) ~/
                2;
        _anchorElapsed = _clock.elapsedMilliseconds;
      }
      _ready = true;
      _acknowledgedCount = sentCount;
      _lastSnapshot = _clock.elapsedMilliseconds;
      _offline = false;
      _merge(response);
    } catch (_) {
      if (mounted) setState(() => _offline = true);
    }
  }

  void _choose(int choice) {
    if (_now < _startsAt ||
        _remaining == 0 ||
        _completed ||
        _clock.elapsedMilliseconds < _lockUntil ||
        _answers.length >= _questions.length) {
      return;
    }
    final correct = _solution(_questions[_answers.length]) == choice;
    setState(() {
      _answers.add({
        'questionIndex': _answers.length,
        'chosenButton': choice,
        'elapsedMs': _now - _startsAt
      });
      _feedback = correct ? 1 : -1;
      _lockUntil = _clock.elapsedMilliseconds + (correct ? 150 : 600);
    });
    unawaited(SoundService.instance.unlock());
    unawaited(SoundService.instance
        .play(correct ? GameSound.notify : GameSound.error));
  }

  Widget _piece(int kind, bool dark, double size) => SizedBox.square(
      dimension: size,
      child: switch ((kind, dark)) {
        (0, false) => WhitePawn(),
        (0, true) => BlackPawn(),
        (1, false) => WhiteKnight(),
        (1, true) => BlackKnight(),
        (2, false) => WhiteRook(),
        _ => BlackRook(),
      });

  @override
  Widget build(BuildContext context) {
    final started = _now >= _startsAt;
    final question = _answers.length < _questions.length
        ? _questions[_answers.length]
        : null;
    final waiting = !started || _remaining == 0 || question == null;
    final feedback = _clock.elapsedMilliseconds < _lockUntil ? _feedback : 0;
    return Focus(
        autofocus: true,
        focusNode: _focus,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final keys = [
            LogicalKeyboardKey.digit1,
            LogicalKeyboardKey.digit2,
            LogicalKeyboardKey.digit3
          ];
          final numpad = [
            LogicalKeyboardKey.numpad1,
            LogicalKeyboardKey.numpad2,
            LogicalKeyboardKey.numpad3
          ];
          final index = keys.indexOf(event.logicalKey);
          final number = index < 0 ? numpad.indexOf(event.logicalKey) : index;
          if (number < 0) return KeyEventResult.ignored;
          _choose(number);
          return KeyEventResult.handled;
        },
        child: Container(
          color: const Color(0xff1c2920),
          padding: const EdgeInsets.all(16),
          child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  const Icon(Icons.shuffle, color: Color(0xffb7e28c)),
                  const SizedBox(width: 10),
                  const Expanded(
                      child: Text('Piece Switch',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold))),
                  IconButton(
                      tooltip: 'Piece Switch rules',
                      icon: const Icon(Icons.help_outline, color: Colors.white),
                      onPressed: () => showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                                  title: const Text('One card. Three rules.'),
                                  content: const Text(
                                      'Match COLOR, PIECE, or COUNT. The buttons never change.\n\nThree blue knights? COLOR is 1, PIECE is 2, COUNT is 3.\n\nCorrect +1. Wrong −1 and a short pause. Most points in 45 seconds wins.'),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Got it'))
                                  ])))
                ]),
                const SizedBox(height: 12),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                          child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text('You  $_score',
                                  style: const TextStyle(fontSize: 21)))),
                      Expanded(
                          child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                  started
                                      ? '${_remaining}s'
                                      : '${((_startsAt - _now + 999) ~/ 1000).clamp(0, 20)}s',
                                  style: const TextStyle(fontSize: 24)))),
                      Expanded(
                          child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text('Rival  $_opponent',
                                  style: const TextStyle(fontSize: 21))))
                    ]),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                    value: _remaining / 45,
                    color: const Color(0xffb7e28c),
                    backgroundColor: Colors.white12),
                SizedBox(
                    height: 230,
                    child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 120),
                        child: waiting
                            ? Center(
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                    const Icon(Icons.shuffle,
                                        size: 44, color: Colors.white),
                                    const SizedBox(height: 16),
                                    Text(
                                        started
                                            ? 'Confirming both scores…'
                                            : 'Get ready',
                                        style: const TextStyle(fontSize: 24))
                                  ]))
                            : Column(
                                key: ValueKey(_answers.length),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    Text('MATCH THE ${question['rule']}',
                                        style: const TextStyle(
                                            fontSize: 25,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xffd5efaf))),
                                    const SizedBox(height: 16),
                                    Container(
                                        height: 125,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                            color: _colors[
                                                question['color'] as int],
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: List.generate(
                                                      question['count'] as int,
                                                      (_) => _piece(
                                                          question['piece']
                                                              as int,
                                                          question['dark']
                                                              as bool,
                                                          64))),
                                              Text(
                                                  _names[
                                                      question['color'] as int],
                                                  style: const TextStyle(
                                                      color: Color(0xff17232c),
                                                      fontWeight:
                                                          FontWeight.bold))
                                            ]))
                                  ]))),
                SizedBox(
                    height: 24,
                    child: Text(
                        feedback == 1
                            ? '+1'
                            : feedback == -1
                                ? '−1'
                                : '',
                        style: TextStyle(
                            fontSize: 19,
                            color: feedback == -1
                                ? Colors.redAccent
                                : const Color(0xffb7e28c)))),
                Row(
                    children: List.generate(
                        3,
                        (i) => Expanded(
                            child: Padding(
                                padding:
                                    EdgeInsets.only(right: i == 2 ? 0 : 10),
                                child: Semantics(
                                    label:
                                        '${_names[i]}, ${_pieces[i]}, ${i + 1}',
                                    button: true,
                                    child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12),
                                            minimumSize: const Size(48, 112),
                                            side: BorderSide(
                                                color: _colors[i], width: 2),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8))),
                                        onPressed: waiting || feedback == -1
                                            ? null
                                            : () {
                                                _focus.requestFocus();
                                                _choose(i);
                                              },
                                        child: Column(children: [
                                          Container(
                                              height: 6,
                                              width: 32,
                                              color: _colors[i]),
                                          Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                _piece(i, false, 40),
                                                Text('${i + 1}',
                                                    style: const TextStyle(
                                                        fontSize: 27,
                                                        color: Colors.white))
                                              ]),
                                          Text('${_names[i]} · ${_pieces[i]}',
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white))
                                        ]))))))),
                if (_offline)
                  const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Reconnecting. Answers saved on this device.',
                          style: TextStyle(color: Colors.amber, fontSize: 12))),
              ])),
        ));
  }

  @override
  void dispose() {
    _frame?.cancel();
    _network?.cancel();
    _socket?.deactivate();
    _focus.dispose();
    _clock.stop();
    super.dispose();
  }
}
