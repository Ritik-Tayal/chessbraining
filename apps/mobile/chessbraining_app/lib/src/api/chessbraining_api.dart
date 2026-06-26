import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/match_models.dart';

class ChessbrainingApi {
  ChessbrainingApi({
    this.baseUrl = 'http://localhost:8080/api/v1',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  ChessbrainingApi copyWithBaseUrl(String value) {
    return ChessbrainingApi(baseUrl: value.trim(), client: _client);
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalizedBase$path').replace(queryParameters: query);
  }

  Future<MatchModel> createMatch({
    required String playerId,
    required String playerName,
    int timeControlSeconds = 300,
    int brainRoundIntervalMoves = 5,
  }) {
    return _postMatch('/matches', {
      'playerId': playerId,
      'playerName': playerName,
      'timeControlSeconds': timeControlSeconds,
      'brainRoundIntervalMoves': brainRoundIntervalMoves,
    });
  }

  Future<MatchModel> quickplay({
    required String playerId,
    required String playerName,
  }) {
    return _postMatch('/matches/quickplay', {
      'playerId': playerId,
      'playerName': playerName,
    });
  }

  Future<MatchModel> joinMatch({
    required String inviteCode,
    required String playerId,
    required String playerName,
  }) {
    return _postMatch('/matches/join', {
      'inviteCode': inviteCode,
      'playerId': playerId,
      'playerName': playerName,
    });
  }

  Future<MatchModel> getMatch(String matchId) async {
    final response = await _client.get(_uri('/matches/$matchId'));
    return _decodeMatch(response);
  }

  Future<List<LegalMoveModel>> legalMoves({
    required String matchId,
    required String playerId,
  }) async {
    final response = await _client.get(
      _uri('/matches/$matchId/legal-moves', {'playerId': playerId}),
    );
    final body = _decodeResponse(response);
    return (body as List<dynamic>)
        .map((item) => LegalMoveModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<MatchModel> submitMove({
    required String matchId,
    required String playerId,
    required String from,
    required String to,
    String? promotion,
  }) {
    return _postMatch('/matches/$matchId/moves', {
      'playerId': playerId,
      'from': from,
      'to': to,
      'promotion': promotion,
    });
  }

  Future<MatchModel> completeBrainRound({
    required String matchId,
    String? winnerPlayerId,
    int? whiteScore,
    int? blackScore,
  }) {
    return _postMatch('/matches/$matchId/brain-rounds/complete', {
      'winnerPlayerId': winnerPlayerId,
      'whiteScore': whiteScore,
      'blackScore': blackScore,
    });
  }

  Future<MatchModel> resign({
    required String matchId,
    required String playerId,
  }) {
    return _postMatch('/matches/$matchId/resign', {
      'playerId': playerId,
    });
  }

  Future<MatchModel> _postMatch(String path, Map<String, Object?> body) async {
    final response = await _client.post(
      _uri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decodeMatch(response);
  }

  MatchModel _decodeMatch(http.Response response) {
    final body = _decodeResponse(response);
    return MatchModel.fromJson(body as Map<String, dynamic>);
  }

  Object? _decodeResponse(http.Response response) {
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    if (decoded is Map<String, dynamic>) {
      throw ApiException(
        decoded['code']?.toString() ?? 'API_ERROR',
        decoded['message']?.toString() ?? 'Request failed',
      );
    }
    throw ApiException('API_ERROR', 'Request failed with ${response.statusCode}');
  }
}

class ApiException implements Exception {
  ApiException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}
