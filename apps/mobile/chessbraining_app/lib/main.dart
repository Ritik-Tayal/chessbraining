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
        colorScheme: const ColorScheme.light(
          primary: Color(0xff170f0a),
          secondary: Color(0xff78583f),
          surface: Color(0xfffff8f1),
          error: Color(0xffba1a1a),
          onPrimary: Color(0xffffffff),
          onSecondary: Color(0xffffffff),
          onSurface: Color(0xff1e1b15),
        ),
        scaffoldBackgroundColor: const Color(0xfffff8f1),
        textTheme: GoogleFonts.manropeTextTheme(
          ThemeData.light().textTheme,
        ).copyWith(
          displayLarge: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w800,
          ),
          displayMedium: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w800,
          ),
          headlineLarge: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w800,
          ),
          headlineMedium: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
          ),
          titleLarge: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
          ),
        ),
        useMaterial3: true,
      ),
      home: MatchScreen(controller: controller),
    );
  }
}
