import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../models/match_models.dart';

class MatchSocketClient {
  MatchSocketClient({
    required this.apiBaseUrl,
    required this.matchId,
    required this.onMatch,
    required this.onConnectionChanged,
  });

  final String apiBaseUrl;
  final String matchId;
  final void Function(MatchModel match) onMatch;
  final void Function(bool connected) onConnectionChanged;

  StompClient? _client;

  void connect() {
    disconnect();
    _client = StompClient(
      config: StompConfig(
        url: _webSocketUrl(apiBaseUrl),
        onConnect: _onConnect,
        onDisconnect: (_) => onConnectionChanged(false),
        onWebSocketError: (_) => onConnectionChanged(false),
        reconnectDelay: const Duration(seconds: 2),
      ),
    )..activate();
  }

  void disconnect() {
    _client?.deactivate();
    _client = null;
    onConnectionChanged(false);
  }

  void _onConnect(StompFrame frame) {
    onConnectionChanged(true);
    _client?.subscribe(
      destination: '/topic/matches/$matchId',
      callback: (frame) {
        final body = frame.body;
        if (body == null || body.isEmpty) {
          return;
        }
        final json = jsonDecode(body) as Map<String, dynamic>;
        final matchJson = json['match'] as Map<String, dynamic>;
        onMatch(MatchModel.fromJson(matchJson));
      },
    );
  }

  String _webSocketUrl(String baseUrl) {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: '/ws',
    ).toString();
  }
}
