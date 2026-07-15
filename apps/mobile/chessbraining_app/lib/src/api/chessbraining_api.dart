import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/match_models.dart';

class ChessbrainingApi {
  static const defaultBaseUrl = String.fromEnvironment(
    'CHESSBRAINING_API_BASE_URL',
    defaultValue: 'http://localhost:8080/api/v1',
  );

  ChessbrainingApi({
    this.baseUrl = defaultBaseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  static const _requestTimeout = Duration(seconds: 75);

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

  Future<MatchModel> createBotMatch({
    required String playerId,
    required String playerName,
    required String difficulty,
    String preferredSide = 'WHITE',
    int timeControlSeconds = 300,
    int brainRoundIntervalMoves = 5,
  }) {
    return _postMatch('/matches/bot', {
      'playerId': playerId,
      'playerName': playerName,
      'difficulty': difficulty,
      'preferredSide': preferredSide,
      'timeControlSeconds': timeControlSeconds,
      'brainRoundIntervalMoves': brainRoundIntervalMoves,
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
    final response = await _withTimeout(_client.get(_uri('/matches/$matchId')));
    return _decodeMatch(response);
  }

  Future<List<LegalMoveModel>> legalMoves({
    required String matchId,
    required String playerId,
  }) async {
    final response = await _withTimeout(
      _client
          .get(_uri('/matches/$matchId/legal-moves', {'playerId': playerId})),
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

  Future<BrainRoundModel> getCurrentBrainRound(String matchId) async {
    final response = await _withTimeout(
      _client.get(_uri('/matches/$matchId/brain-rounds/current')),
    );
    final body = _decodeResponse(response);
    return BrainRoundModel.fromJson(body as Map<String, dynamic>);
  }

  Future<AnswerResultModel> submitBrainRoundAnswer({
    required String matchId,
    required String playerId,
    required int questionIndex,
    required int answer,
  }) async {
    final response = await _withTimeout(
      _client.post(
        _uri('/matches/$matchId/brain-rounds/current/answers'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'playerId': playerId,
          'questionIndex': questionIndex,
          'answer': answer,
        }),
      ),
    );
    final body = _decodeResponse(response);
    return AnswerResultModel.fromJson(body as Map<String, dynamic>);
  }

  Future<BrainRoundSubmissionModel> submitBrainRoundAnswers({
    required String matchId,
    required String playerId,
    required Map<int, int> answers,
  }) async {
    final orderedAnswers = answers.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    final response = await _withTimeout(
      _client.post(
        _uri('/matches/$matchId/brain-rounds/current/submissions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'playerId': playerId,
          'answers': [
            for (final answer in orderedAnswers)
              {
                'questionIndex': answer.key,
                'answer': answer.value,
              },
          ],
        }),
      ),
    );
    final body = _decodeResponse(response);
    return BrainRoundSubmissionModel.fromJson(body as Map<String, dynamic>);
  }

  Future<BrainRoundModel> completeBrainRound({
    required String matchId,
  }) async {
    final response = await _withTimeout(
      _client.post(_uri('/matches/$matchId/brain-rounds/current/complete')),
    );
    final body = _decodeResponse(response);
    return BrainRoundModel.fromJson(body as Map<String, dynamic>);
  }

  Future<AnswerResultModel> submitDotConnectPath({
    required String matchId,
    required String playerId,
    required int puzzleIndex,
    required List<List<int>> path,
  }) async {
    final response = await _withTimeout(
      _client.post(
        _uri('/matches/$matchId/brain-rounds/current/paths'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'playerId': playerId,
          'puzzleIndex': puzzleIndex,
          'path': path,
        }),
      ),
    );
    final body = _decodeResponse(response);
    return AnswerResultModel.fromJson(body as Map<String, dynamic>);
  }

  Future<BrainRoundModel> submitMemoryTurn({
    required String matchId,
    required String playerId,
    required int firstIndex,
    required int secondIndex,
  }) async {
    final response = await _withTimeout(
      _client.post(
        _uri('/matches/$matchId/brain-rounds/current/memory-turns'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'playerId': playerId,
          'firstIndex': firstIndex,
          'secondIndex': secondIndex,
        }),
      ),
    );
    final body = _decodeResponse(response);
    return BrainRoundModel.fromJson(body as Map<String, dynamic>);
  }

  Future<MatchModel> applyPowerup({
    required String matchId,
    required String playerId,
    required String type,
    String? targetSquare,
  }) {
    return _postMatch('/matches/$matchId/powerups', {
      'playerId': playerId,
      'type': type,
      'targetSquare': targetSquare,
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

  Future<MatchModel> requestRematch({
    required String matchId,
    required String playerId,
  }) {
    return _postMatch('/matches/$matchId/rematch', {
      'playerId': playerId,
    });
  }

  Future<MatchModel> _postMatch(String path, Map<String, Object?> body) async {
    final response = await _withTimeout(
      _client.post(
        _uri(path),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );
    return _decodeMatch(response);
  }

  Future<T> _withTimeout<T>(Future<T> request) {
    return request.timeout(
      _requestTimeout,
      onTimeout: () {
        throw ApiException(
          'REQUEST_TIMEOUT',
          'The server is taking longer than expected. If this is the first request after inactivity, wait a moment and try again.',
        );
      },
    );
  }

  MatchModel _decodeMatch(http.Response response) {
    final body = _decodeResponse(response);
    return MatchModel.fromJson(body as Map<String, dynamic>);
  }

  Object? _decodeResponse(http.Response response) {
    final decoded =
        response.body.isEmpty ? null : _tryDecodeJson(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    if (decoded is Map<String, dynamic>) {
      throw ApiException(
        decoded['code']?.toString() ?? 'API_ERROR',
        decoded['message']?.toString() ?? 'Request failed',
      );
    }
    throw ApiException(
        'API_ERROR', 'Request failed with ${response.statusCode}');
  }

  Object? _tryDecodeJson(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }
}

class ApiException implements Exception {
  ApiException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}
