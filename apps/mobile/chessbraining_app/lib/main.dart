import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'src/api/chessbraining_api.dart';
import 'src/api/match_socket_client.dart';
import 'src/features/match/match_controller.dart';
import 'src/features/match/match_screen.dart';
import 'src/services/sound_service.dart';
import 'src/session/guest_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final guestSession = await GuestSession.load();
  runApp(ChessBrainingApp(guestSession: guestSession));
}

class ChessBrainingApp extends StatefulWidget {
  const ChessBrainingApp({
    required this.guestSession,
    super.key,
  });

  final GuestSession guestSession;

  @override
  State<ChessBrainingApp> createState() => _ChessBrainingAppState();
}

class _ChessBrainingAppState extends State<ChessBrainingApp> {
  late final MatchController controller;

  @override
  void initState() {
    super.initState();
    controller = MatchController(
      api: ChessbrainingApi(),
      socketFactory: MatchSocketClient.new,
      guestSession: widget.guestSession,
    );
    SoundService.instance.setVolume(0.6);
  }

  @override
  void dispose() {
    controller.dispose();
    SoundService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ChessBraining',
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xff10b981),
          secondary: Color(0xff3b82f6),
          surface: Color(0xff171717),
          error: Color(0xffffb4ab),
        ),
        scaffoldBackgroundColor: const Color(0xff0a0a0a),
        textTheme: GoogleFonts.getTextTheme(
          'Geist',
          ThemeData.dark().textTheme,
        ),
        useMaterial3: true,
      ),
      home: MatchScreen(controller: controller),
    );
  }
}
