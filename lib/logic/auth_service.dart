import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_logger.dart';
import 'experimental_api_client.dart';

/// Persisted auth state: tokens + basic user profile.
class AuthUser {
  final String id;
  final String username;
  final String email;
  final int elo;

  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
    required this.elo,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      elo: (json['elo'] as num?)?.toInt() ?? 1200,
    );
  }
}

/// Manages authentication state: login, register, token refresh, logout.
/// Persists tokens in SharedPreferences (secure storage recommended for prod).
class AuthService extends ChangeNotifier {
  final ExperimentalApiClient _api;

  AuthService(this._api);

  // ── State ──────────────────────────────────────────────────────────────────
  AuthUser? _user;
  String? _accessToken;
  String? _refreshToken;
  bool _busy = false;
  String? _lastError;

  AuthUser? get user => _user;
  bool get isLoggedIn => _user != null && _accessToken != null;
  bool get busy => _busy;
  String? get lastError => _lastError;
  String? get accessToken => _accessToken;

  Future<String?> ensureValidAccessToken({int minValiditySeconds = 30}) async {
    final token = _accessToken;
    if (token == null || token.isEmpty) return null;

    final remainingSeconds = _jwtRemainingSeconds(token);
    if (remainingSeconds == null) {
      DevLogger.instance.log(
        DevLogCategory.http,
        'Access token expiry check skipped: unable to parse JWT exp',
      );
      return token;
    }

    if (remainingSeconds > minValiditySeconds) {
      DevLogger.instance.log(
        DevLogCategory.http,
        'Access token valid for ${remainingSeconds}s',
      );
      return token;
    }

    DevLogger.instance.log(
      DevLogCategory.http,
      'Access token expiring/expired (${remainingSeconds}s) -> refreshing',
    );
    final refreshed = await refreshTokens();
    if (!refreshed || _accessToken == null || _accessToken!.isEmpty) {
      return null;
    }

    final refreshedRemaining = _jwtRemainingSeconds(_accessToken!);
    DevLogger.instance.log(
      DevLogCategory.http,
      'Access token refreshed${refreshedRemaining != null ? ' | validFor=${refreshedRemaining}s' : ''}',
    );
    return _accessToken;
  }

  // ── SharedPreferences keys ─────────────────────────────────────────────────
  static const _kAccessToken = 'auth_access_token';
  static const _kRefreshToken = 'auth_refresh_token';
  static const _kUserId = 'auth_user_id';
  static const _kUsername = 'auth_username';
  static const _kEmail = 'auth_email';
  static const _kElo = 'auth_elo';

  // ── Init: restore session from disk ────────────────────────────────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_kAccessToken);
    _refreshToken = prefs.getString(_kRefreshToken);
    final userId = prefs.getString(_kUserId);

    if (_accessToken != null && userId != null && userId.isNotEmpty) {
      _user = AuthUser(
        id: userId,
        username: prefs.getString(_kUsername) ?? '',
        email: prefs.getString(_kEmail) ?? '',
        elo: prefs.getInt(_kElo) ?? 1200,
      );
      _api.accessToken = _accessToken;
      DevLogger.instance.log(
        DevLogCategory.http,
        'Auth restored: ${_user!.username} (ELO ${_user!.elo})',
      );
    }
    notifyListeners();
  }

  // ── Register ────────────────────────────────────────────────────────────────
  Future<bool> register({
    required String email,
    required String password,
    required String username,
  }) async {
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      final json = await _api.postJsonPublic('/api/auth/register', body: {
        'email': email,
        'password': password,
        'username': username,
      });
      await _handleAuthResponse(json);
      DevLogger.instance.log(DevLogCategory.http, 'Register OK: $username');
      return true;
    } on ApiException catch (e) {
      _lastError = e.message;
      DevLogger.instance.log(DevLogCategory.http, 'Register FAIL: $e');
      return false;
    } catch (e) {
      _lastError = e.toString();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  // ── Login ───────────────────────────────────────────────────────────────────
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      final json = await _api.postJsonPublic('/api/auth/login', body: {
        'email': email,
        'password': password,
      });
      await _handleAuthResponse(json);
      DevLogger.instance.log(
        DevLogCategory.http,
        'Login OK: ${_user?.username}',
      );
      return true;
    } on ApiException catch (e) {
      _lastError = e.message;
      DevLogger.instance.log(DevLogCategory.http, 'Login FAIL: $e');
      return false;
    } catch (e) {
      _lastError = e.toString();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  // ── Refresh token ──────────────────────────────────────────────────────────
  Future<bool> refreshTokens() async {
    if (_refreshToken == null) return false;
    try {
      final json = await _api.postJsonPublic('/api/auth/refresh', body: {
        'refreshToken': _refreshToken,
      });
      _accessToken = json['accessToken'] as String?;
      _refreshToken = json['refreshToken'] as String?;
      _api.accessToken = _accessToken;
      await _persistTokens();
      DevLogger.instance.log(DevLogCategory.http, 'Token refresh OK');
      return true;
    } catch (e) {
      DevLogger.instance.log(DevLogCategory.http, 'Token refresh FAIL: $e');
      // If refresh fails, clear auth state
      await logout();
      return false;
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    if (_refreshToken != null) {
      try {
        await _api.postJsonPublic('/api/auth/logout', body: {
          'refreshToken': _refreshToken,
        });
      } catch (_) {
        // Best-effort — server may be unreachable
      }
    }
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    _api.accessToken = null;
    await _clearPersistedAuth();
    DevLogger.instance.log(DevLogCategory.http, 'Logged out');
    notifyListeners();
  }

  // ── Fetch fresh profile ────────────────────────────────────────────────────
  Future<void> fetchProfile() async {
    if (!isLoggedIn) return;
    try {
      final json = await _api.getJsonAuth('/api/users/me');
      _user = AuthUser(
        id: json['id'] as String? ?? _user!.id,
        username: json['username'] as String? ?? _user!.username,
        email: _user!.email, // GET /users/me doesn't return email
        elo: (json['elo'] as num?)?.toInt() ?? _user!.elo,
      );
      await _persistUser();
      notifyListeners();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        // Try refresh
        final ok = await refreshTokens();
        if (ok) await fetchProfile();
      }
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────
  Future<void> _handleAuthResponse(Map<String, dynamic> json) async {
    _accessToken = json['accessToken'] as String?;
    _refreshToken = json['refreshToken'] as String?;
    final userJson = json['user'] as Map<String, dynamic>?;
    if (userJson != null) {
      _user = AuthUser.fromJson(userJson);
    }
    _api.accessToken = _accessToken;
    await _persistTokens();
    await _persistUser();
  }

  Future<void> _persistTokens() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) {
      await prefs.setString(_kAccessToken, _accessToken!);
    } else {
      await prefs.remove(_kAccessToken);
    }
    if (_refreshToken != null) {
      await prefs.setString(_kRefreshToken, _refreshToken!);
    } else {
      await prefs.remove(_kRefreshToken);
    }
  }

  Future<void> _persistUser() async {
    if (_user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId, _user!.id);
    await prefs.setString(_kUsername, _user!.username);
    await prefs.setString(_kEmail, _user!.email);
    await prefs.setInt(_kElo, _user!.elo);
  }

  Future<void> _clearPersistedAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kRefreshToken);
    await prefs.remove(_kUserId);
    await prefs.remove(_kUsername);
    await prefs.remove(_kEmail);
    await prefs.remove(_kElo);
  }

  static int? _jwtRemainingSeconds(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;

      final decoded = _decodeBase64Url(parts[1]);
      final expIndex = decoded.indexOf('"exp":');
      if (expIndex < 0) return null;

      final start = expIndex + 6;
      var end = start;
      while (end < decoded.length) {
        final code = decoded.codeUnitAt(end);
        if (code < 48 || code > 57) break;
        end++;
      }
      if (end <= start) return null;

      final expSeconds = int.tryParse(decoded.substring(start, end));
      if (expSeconds == null) return null;

      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return expSeconds - nowSeconds;
    } catch (_) {
      return null;
    }
  }

  static String _decodeBase64Url(String input) {
    var normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    final remainder = normalized.length % 4;
    if (remainder > 0) {
      normalized =
          normalized.padRight(normalized.length + (4 - remainder), '=');
    }

    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final bytes = <int>[];

    for (var index = 0; index < normalized.length; index += 4) {
      final c1 = chars.indexOf(normalized[index]);
      final c2 = chars.indexOf(normalized[index + 1]);
      final c3 = normalized[index + 2] == '='
          ? -1
          : chars.indexOf(normalized[index + 2]);
      final c4 = normalized[index + 3] == '='
          ? -1
          : chars.indexOf(normalized[index + 3]);

      if (c1 < 0 ||
          c2 < 0 ||
          (c3 < 0 && normalized[index + 2] != '=') ||
          (c4 < 0 && normalized[index + 3] != '=')) {
        return '{}';
      }

      final b1 = (c1 << 2) | (c2 >> 4);
      bytes.add(b1 & 0xFF);

      if (c3 >= 0) {
        final b2 = ((c2 & 0x0F) << 4) | (c3 >> 2);
        bytes.add(b2 & 0xFF);
      }

      if (c4 >= 0 && c3 >= 0) {
        final b3 = ((c3 & 0x03) << 6) | c4;
        bytes.add(b3 & 0xFF);
      }
    }

    return String.fromCharCodes(bytes);
  }
}
