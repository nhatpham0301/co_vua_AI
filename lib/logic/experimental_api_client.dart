import 'dart:convert';
import 'dart:io';

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
    final json = await _postJson(
      '/api/games/$gameId/moves',
      requiresAuth: true,
      body: {
        'from': from,
        'to': to,
        'promotion': promotion,
      },
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

  Future<Map<String, dynamic>> _getJson(
    String path, {
    bool requiresAuth = false,
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: queryParams,
    );

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      if (requiresAuth && accessToken != null && accessToken!.isNotEmpty) {
        request.headers
            .set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      }

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      return _parseResponse(response.statusCode, responseBody);
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
      return _parseResponse(response.statusCode, responseBody);
    } finally {
      client.close(force: true);
    }
  }

  Future<List<Map<String, dynamic>>> _getListJson(
    String path, {
    bool requiresAuth = false,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      if (requiresAuth && accessToken != null && accessToken!.isNotEmpty) {
        request.headers
            .set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      }

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      return _parseListResponse(response.statusCode, responseBody);
    } finally {
      client.close(force: true);
    }
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
