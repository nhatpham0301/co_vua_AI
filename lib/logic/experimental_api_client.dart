import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../model/api_models.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() {
    if (statusCode == null) return message;
    return 'HTTP $statusCode: $message';
  }
}

class ExperimentalApiClient {
  ExperimentalApiClient({required String baseUrl, this.accessToken})
      : _baseUrl = _normalizeBaseUrl(baseUrl);

  String _baseUrl;
  String? accessToken;

  String get baseUrl => _baseUrl;

  void setBaseUrl(String value) {
    _baseUrl = _normalizeBaseUrl(value);
  }

  Future<HomeOverview> fetchHomeOverview() async {
    final json = await _getJson('/api/home/overview', requiresAuth: false);
    return HomeOverview.fromJson(json);
  }

  Future<LiveMatchesResponse> fetchHomeLiveMatches({
    int limit = 10,
    bool includeBots = true,
  }) async {
    final params = {
      'limit': '$limit',
      'includeBots': includeBots ? 'true' : 'false',
    };
    final json = await _getJson(
      '/api/home/live-matches',
      requiresAuth: false,
      queryParams: params,
    );
    return LiveMatchesResponse.fromJson(json);
  }

  Future<QuickPlayResult> quickPlay({
    String timeControl = 'blitz_5',
    String preferredSide = 'random',
    bool fallbackToAi = true,
    int fallbackTimeoutSec = 60,
    String difficulty = 'medium',
  }) async {
    final json = await _postJson(
      '/api/home/quick-play',
      requiresAuth: true,
      body: {
        'timeControl': timeControl,
        'preferredSide': preferredSide,
        'fallbackToAi': fallbackToAi,
        'fallbackTimeoutSec': fallbackTimeoutSec,
        'difficulty': difficulty,
      },
    );
    return QuickPlayResult.fromJson(json);
  }

  Future<MonetizationConfig> fetchMonetizationConfig() async {
    final json = await _getJson(
      '/api/monetization/config',
      requiresAuth: true,
    );
    return MonetizationConfig.fromJson(json);
  }

  Future<OnlineGameSnapshot> fetchGameSnapshot(String gameId) async {
    final json = await _getJson('/api/games/$gameId', requiresAuth: false);
    return OnlineGameSnapshot.fromJson(json);
  }

  Future<List<OnlineMoveRecord>> fetchGameMoves(String gameId) async {
    final json =
        await _getListJson('/api/games/$gameId/moves', requiresAuth: false);
    return json.map(OnlineMoveRecord.fromJson).toList();
  }

  Future<OnlineMoveSubmitResult> submitGameMove({
    required String gameId,
    required String from,
    required String to,
    String? promotion,
  }) async {
    final body = <String, dynamic>{
      'from': from,
      'to': to,
      if (promotion != null) 'promotion': promotion,
    };
    final json = await _postJson(
      '/api/games/$gameId/moves',
      requiresAuth: true,
      body: body,
    );
    return OnlineMoveSubmitResult.fromJson(json);
  }

  Future<OnlineGameSnapshot> resignGame(String gameId) async {
    final json = await _postJson(
      '/api/games/$gameId/resign',
      requiresAuth: true,
      body: const {},
    );
    return OnlineGameSnapshot.fromJson(json);
  }

  Future<Map<String, dynamic>> offerDraw(String gameId) async {
    return _postJson(
      '/api/games/$gameId/draw/offer',
      requiresAuth: true,
      body: const {},
    );
  }

  Future<Map<String, dynamic>> acceptDraw(String gameId) async {
    return _postJson(
      '/api/games/$gameId/draw/accept',
      requiresAuth: true,
      body: const {},
    );
  }

  Future<Map<String, dynamic>> fetchUserGames({
    required String userId,
    int limit = 20,
    int offset = 0,
  }) {
    return _getJson(
      '/api/users/$userId/games',
      requiresAuth: false,
      queryParams: {
        'limit': '$limit',
        'offset': '$offset',
      },
    );
  }

  Future<Map<String, dynamic>> fetchUserProfile(String userId) async {
    return _getJson(
      '/api/users/$userId',
      requiresAuth: false,
    );
  }

  Future<List<dynamic>> fetchUserEloHistory(String userId) async {
    final json = await _getJson(
      '/api/users/$userId/elo-history',
      requiresAuth: false,
    );
    final data = json['data'] ?? json['eloHistory'] ?? [];
    if (data is List) {
      return data;
    }
    return [];
  }

  // ── Public POST (no Bearer token) ──────────────────────────────────────────
  Future<Map<String, dynamic>> postJsonPublic(
    String path, {
    required Map<String, dynamic> body,
  }) {
    return _postJson(path, body: body, requiresAuth: false);
  }

  // ── Authenticated GET ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getJsonAuth(
    String path, {
    Map<String, String>? queryParams,
  }) {
    return _getJson(path, requiresAuth: true, queryParams: queryParams);
  }

  // ── Recent games (public) ──────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchRecentGames({int limit = 10}) {
    return _getListJson(
      '/api/games',
      requiresAuth: false,
      queryParams: {'limit': '$limit'},
    );
  }

  // ── Create AI game (auth) ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> createAiGame({
    int aiLevel = 3,
    String color = 'black',
    String timeControl = 'blitz_5',
    int moveTimeLimit = 0,
  }) {
    return _postJson('/api/games/vs-ai', requiresAuth: true, body: {
      'aiLevel': aiLevel,
      'color': color,
      'timeControl': timeControl,
      'moveTimeLimit': moveTimeLimit,
    });
  }

  // ── Create PvP game (auth) ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> createPvPGame({
    String timeControl = 'rapid_15',
    bool isRated = true,
    int moveTimeLimit = 60,
  }) {
    return _postJson('/api/games', requiresAuth: true, body: {
      'timeControl': timeControl,
      'isRated': isRated,
      'moveTimeLimit': moveTimeLimit,
    });
  }

  // ── Matchmaking (auth) ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> joinMatchmaking({
    String timeControl = 'blitz_5',
    int moveTimeLimit = 0,
  }) {
    return _postJson('/api/matchmaking/join', requiresAuth: true, body: {
      'timeControl': timeControl,
      'moveTimeLimit': moveTimeLimit,
    });
  }

  Future<Map<String, dynamic>> leaveMatchmaking() {
    return _deleteJson('/api/matchmaking/leave', requiresAuth: true);
  }

  Future<Map<String, dynamic>> getMatchmakingStatus() {
    return _getJson('/api/matchmaking/status', requiresAuth: true);
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    bool requiresAuth = false,
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: queryParams,
    );

    final client = HttpClient();
    final stopwatch = Stopwatch()..start();
    _logRequest(
      method: 'GET',
      uri: uri,
      requiresAuth: requiresAuth,
    );
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      if (requiresAuth && accessToken != null && accessToken!.isNotEmpty) {
        request.headers
            .set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      }

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      _logResponse(
        method: 'GET',
        uri: uri,
        statusCode: response.statusCode,
        elapsedMs: stopwatch.elapsedMilliseconds,
        responseBody: responseBody,
      );
      return _parseResponse(response.statusCode, responseBody);
    } catch (e) {
      _logFailure(
        method: 'GET',
        uri: uri,
        elapsedMs: stopwatch.elapsedMilliseconds,
        error: e,
      );
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String path, {
    required Map<String, dynamic> body,
    bool requiresAuth = false,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');

    final client = HttpClient();
    final stopwatch = Stopwatch()..start();
    _logRequest(
      method: 'POST',
      uri: uri,
      requiresAuth: requiresAuth,
      body: body,
    );
    try {
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      if (requiresAuth && accessToken != null && accessToken!.isNotEmpty) {
        request.headers
            .set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      }
      request.add(utf8.encode(jsonEncode(body)));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      _logResponse(
        method: 'POST',
        uri: uri,
        statusCode: response.statusCode,
        elapsedMs: stopwatch.elapsedMilliseconds,
        responseBody: responseBody,
      );
      return _parseResponse(response.statusCode, responseBody);
    } catch (e) {
      _logFailure(
        method: 'POST',
        uri: uri,
        elapsedMs: stopwatch.elapsedMilliseconds,
        error: e,
      );
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<List<Map<String, dynamic>>> _getListJson(
    String path, {
    bool requiresAuth = false,
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: queryParams,
    );

    final client = HttpClient();
    final stopwatch = Stopwatch()..start();
    _logRequest(
      method: 'GET',
      uri: uri,
      requiresAuth: requiresAuth,
    );
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      if (requiresAuth && accessToken != null && accessToken!.isNotEmpty) {
        request.headers
            .set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      }

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      _logResponse(
        method: 'GET',
        uri: uri,
        statusCode: response.statusCode,
        elapsedMs: stopwatch.elapsedMilliseconds,
        responseBody: responseBody,
      );
      return _parseListResponse(response.statusCode, responseBody);
    } catch (e) {
      _logFailure(
        method: 'GET',
        uri: uri,
        elapsedMs: stopwatch.elapsedMilliseconds,
        error: e,
      );
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _deleteJson(
    String path, {
    bool requiresAuth = false,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');

    final client = HttpClient();
    final stopwatch = Stopwatch()..start();
    _logRequest(
      method: 'DELETE',
      uri: uri,
      requiresAuth: requiresAuth,
    );
    try {
      final request = await client.deleteUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      if (requiresAuth && accessToken != null && accessToken!.isNotEmpty) {
        request.headers
            .set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      }

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      _logResponse(
        method: 'DELETE',
        uri: uri,
        statusCode: response.statusCode,
        elapsedMs: stopwatch.elapsedMilliseconds,
        responseBody: responseBody,
      );
      return _parseResponse(response.statusCode, responseBody);
    } catch (e) {
      _logFailure(
        method: 'DELETE',
        uri: uri,
        elapsedMs: stopwatch.elapsedMilliseconds,
        error: e,
      );
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  void _logRequest({
    required String method,
    required Uri uri,
    required bool requiresAuth,
    Map<String, dynamic>? body,
  }) {
    if (!kDebugMode) return;
    final payload =
        body == null ? '' : ' | body=${jsonEncode(_maskSensitive(body))}';
    debugPrint('[API][REQ] $method $uri | auth=$requiresAuth$payload');
  }

  void _logResponse({
    required String method,
    required Uri uri,
    required int statusCode,
    required int elapsedMs,
    required String responseBody,
  }) {
    if (!kDebugMode) return;
    final preview = responseBody.length <= 220
        ? responseBody
        : '${responseBody.substring(0, 220)}...';
    debugPrint(
      '[API][RES] $method $uri | status=$statusCode | ${elapsedMs}ms | body=$preview',
    );
  }

  void _logFailure({
    required String method,
    required Uri uri,
    required int elapsedMs,
    required Object error,
  }) {
    if (!kDebugMode) return;
    debugPrint('[API][ERR] $method $uri | ${elapsedMs}ms | error=$error');
  }

  Map<String, dynamic> _maskSensitive(Map<String, dynamic> input) {
    final output = <String, dynamic>{};
    for (final entry in input.entries) {
      final key = entry.key.toLowerCase();
      if (key.contains('password') ||
          key.contains('token') ||
          key.contains('authorization')) {
        output[entry.key] = '***';
      } else {
        output[entry.key] = entry.value;
      }
    }
    return output;
  }

  Map<String, dynamic> _parseResponse(int statusCode, String responseBody) {
    Map<String, dynamic> decoded = {};
    if (responseBody.isNotEmpty) {
      final dynamic raw = jsonDecode(responseBody);
      if (raw is Map<String, dynamic>) {
        decoded = raw;
      }
    }

    if (statusCode >= 200 && statusCode < 300) {
      return decoded;
    }

    final error = decoded['error'];
    if (error is Map<String, dynamic>) {
      final message = error['message'] as String? ?? 'Request failed';
      throw ApiException(message, statusCode: statusCode);
    }

    throw ApiException('Request failed', statusCode: statusCode);
  }

  List<Map<String, dynamic>> _parseListResponse(
    int statusCode,
    String responseBody,
  ) {
    if (statusCode < 200 || statusCode >= 300) {
      throw ApiException('Request failed', statusCode: statusCode);
    }

    if (responseBody.isEmpty) return const [];
    final dynamic raw = jsonDecode(responseBody);
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  static String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'http://localhost:3000';
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}
