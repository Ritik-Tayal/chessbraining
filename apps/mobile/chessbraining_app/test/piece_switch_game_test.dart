import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chessbraining_app/src/api/chessbraining_api.dart';
import 'package:chessbraining_app/src/api/match_socket_client.dart';
import 'package:chessbraining_app/src/features/match/match_controller.dart';
import 'package:chessbraining_app/src/features/match/piece_switch_game.dart';
import 'package:chessbraining_app/src/session/guest_session.dart';
import 'package:chessbraining_app/src/services/sound_service.dart';

class _Socket extends StompClient {
  _Socket(StompConfig config) : super(config: config);
  @override
  void activate() {}
  @override
  void deactivate() {}
}

class _Controller extends MatchController {
  _Controller(this.view)
      : super(
            api: ChessbrainingApi(),
            guestSession: const GuestSession(
                playerId: 'switch-test', playerName: 'Player'),
            socketFactory: (
                    {required apiBaseUrl,
                    required matchId,
                    required onMatch,
                    required onConnectionChanged}) =>
                MatchSocketClient(
                    apiBaseUrl: apiBaseUrl,
                    matchId: matchId,
                    onMatch: onMatch,
                    onConnectionChanged: onConnectionChanged));
  final Map<String, dynamic> view;
  @override
  Future<Map<String, dynamic>> sendPieceSwitch(
          {required bool arena,
          required String roundId,
          required bool ready,
          required List<Map<String, dynamic>> answers,
          required bool finished}) async =>
      {
        'pieceSwitch': view,
        'status': 'ACTIVE',
        'whiteScore': 0,
        'blackScore': 0,
      };
}

void main() {
  for (final keyboard in [false, true]) {
    testWidgets(
        'Piece Switch ${keyboard ? 'keyboard' : 'touch'} input scores locally with large mobile controls',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SoundService.instance.setEnabled(false);
      final now = DateTime.now().millisecondsSinceEpoch;
      final view = <String, dynamic>{
        'serverNow': now,
        'startsAt': now - 1000,
        'readyDeadline': now - 1000,
        'revision': 0,
        'whiteReady': true,
        'blackReady': true
      };
      final controller = _Controller(view);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Center(
                  child: PieceSwitchGame(
                      socketFactory: _Socket.new,
                      controller: controller,
                      roundId: 'test-$keyboard',
                      puzzles: List.generate(
                          4,
                          (_) => jsonEncode({
                                'rule': 'COLOR',
                                'color': 0,
                                'piece': 1,
                                'count': 3,
                                'dark': false,
                                'layout': 0
                              })),
                      view: view,
                      side: 'WHITE',
                      arena: true)))));
      await tester.pump();
      expect(find.byType(OutlinedButton), findsNWidgets(3));
      for (final element in find.byType(OutlinedButton).evaluate()) {
        final size = tester.getSize(find.byWidget(element.widget));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      if (keyboard) {
        await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      } else {
        await tester.tap(find.byType(OutlinedButton).first);
      }
      await tester.pump();
      expect(find.text('You  1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
}
