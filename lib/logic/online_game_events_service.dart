import 'package:socket_io_client/socket_io_client.dart' as io;

import 'dev_logger.dart';

class OnlineGameEventsService {
  static const List<String> _serverEvents = [
    'game:state',
    'game:move:ok',
    'game:move:invalid',
    'game:draw:offered',
    'game:clock',
    'game:end',
    'game:player:disconnected',
    'game:player:reconnected',
    'match:found',
    'match:timeout',
    'spectator:count',
    'error',
  ];

  io.Socket? _socket;
  String? _activeGameId;

  bool get isConnected => _socket?.connected ?? false;
  String? get activeGameId => _activeGameId;

  Future<void> startTracking({
    required String socketBaseUrl,
    required String gameId,
    required String accessToken,
  }) async {
    await stopTracking();

    final base = _normalizeBaseUrl(socketBaseUrl);
    final uri = '$base/live';
    final authPreview = _maskToken(accessToken);
    final authHeader = 'Bearer $accessToken';
    final jwtDiag = _jwtDiagnostics(accessToken);
    var retriedWithBearer = false;

    DevLogger.instance.log(
      DevLogCategory.http,
      '[SOCKET] startTracking | uri=$uri | gameId=$gameId | auth=$authPreview | $jwtDiag',
    );

    void connectSocket({required bool useBearerTokenField}) {
      final tokenField = useBearerTokenField ? authHeader : accessToken;
      final mode = useBearerTokenField ? 'bearer' : 'raw';

      final socket = io.io(
        uri,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .setAuth({
              'token': tokenField,
              'accessToken': accessToken,
            })
            .setQuery({
              'token': tokenField,
              'accessToken': accessToken,
            })
            .setExtraHeaders({
              'Authorization': authHeader,
              'x-access-token': accessToken,
            })
            .setPath('/socket.io')
            .disableAutoConnect()
            .build(),
      );

      DevLogger.instance.log(
        DevLogCategory.http,
        '[SOCKET] Token format | mode=$mode | len=${accessToken.length} | starts=${accessToken.substring(0, 20)}... | tokenField=$tokenField',
      );

      _socket = socket;
      _activeGameId = gameId;

      DevLogger.instance.log(
        DevLogCategory.http,
        '[SOCKET] Socket created | mode=$mode | transports=websocket,polling | path=/socket.io | auth=payload+query+headers | autoConnect=false | gameId=$gameId',
      );

      socket.onConnect((_) {
        DevLogger.instance.log(
          DevLogCategory.http,
          '[SOCKET] connected | mode=$mode | id=${socket.id ?? '-'} | gameId=$gameId',
        );
        _emitWithLog(socket, 'game:join', {'gameId': gameId}, gameId: gameId);
      });

      socket.onConnectError((error) {
        final preview = _safePreview(error);
        DevLogger.instance.log(
          DevLogCategory.http,
          '[SOCKET] connect_error | mode=$mode | gameId=$gameId | $preview',
        );

        if (!useBearerTokenField &&
            !retriedWithBearer &&
            _looksInvalidToken(preview)) {
          retriedWithBearer = true;
          DevLogger.instance.log(
            DevLogCategory.http,
            '[SOCKET] retry connect with Bearer token format | gameId=$gameId',
          );
          socket.dispose();
          connectSocket(useBearerTokenField: true);
        }
      });

      socket.onError((error) {
        DevLogger.instance.log(
          DevLogCategory.http,
          '[SOCKET] error(callback) | mode=$mode | gameId=$gameId | ${_safePreview(error)}',
        );
      });

      socket.onDisconnect((reason) {
        DevLogger.instance.log(
          DevLogCategory.http,
          '[SOCKET] disconnected | mode=$mode | gameId=$gameId | reason=${_safePreview(reason)}',
        );
      });

      _bindGameEvents(socket, gameId);
      DevLogger.instance.log(
        DevLogCategory.http,
        '[SOCKET] connect() called | mode=$mode | gameId=$gameId',
      );
      socket.connect();
    }

    connectSocket(useBearerTokenField: false);
  }

  Future<void> stopTracking() async {
    final socket = _socket;
    final gameId = _activeGameId;

    if (socket != null) {
      if (socket.connected && gameId != null && gameId.isNotEmpty) {
        _emitWithLog(socket, 'game:leave', {'gameId': gameId}, gameId: gameId);
      } else {
        DevLogger.instance.log(
          DevLogCategory.http,
          '[SOCKET] stopTracking without connected room | gameId=${gameId ?? '-'} | connected=${socket.connected}',
        );
      }
      socket.dispose();
      DevLogger.instance.log(
        DevLogCategory.http,
        '[SOCKET] disposed | gameId=${gameId ?? '-'}',
      );
    }

    _socket = null;
    _activeGameId = null;
  }

  void _bindGameEvents(io.Socket socket, String gameId) {
    DevLogger.instance.log(
      DevLogCategory.http,
      '[SOCKET] binding listeners | gameId=$gameId | events=${_serverEvents.join(', ')}',
    );

    for (final eventName in _serverEvents) {
      _bindLoggedEvent(socket, eventName, gameId);
    }
  }

  void _bindLoggedEvent(io.Socket socket, String eventName, String gameId) {
    final category = _categoryForEvent(eventName);
    socket.on(eventName, (data) {
      DevLogger.instance.log(
        category,
        '[SOCKET][$eventName] gameId=$gameId | connected=${socket.connected} | payload=${_safePreview(data)}',
      );
    });
  }

  void _emitWithLog(
    io.Socket socket,
    String eventName,
    Map<String, dynamic> payload, {
    String? gameId,
  }) {
    DevLogger.instance.log(
      DevLogCategory.http,
      '[SOCKET][emit] event=$eventName | gameId=${gameId ?? payload['gameId'] ?? '-'} | connected=${socket.connected} | payload=${_safePreview(payload)}',
    );
    socket.emit(eventName, payload);
  }

  static DevLogCategory _categoryForEvent(String eventName) {
    if (eventName == 'error' || eventName.startsWith('match:')) {
      return DevLogCategory.http;
    }
    return DevLogCategory.game;
  }

  static String _maskToken(String token) {
    if (token.length <= 12) return 'present(len=${token.length})';
    return '${token.substring(0, 6)}...${token.substring(token.length - 4)}';
  }

  static String _jwtDiagnostics(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return 'jwt=invalid_format';
      final payload = parts[1];
      final decoded = _decodeBase64Url(payload);
      final expIndex = decoded.indexOf('"exp":');
      if (expIndex < 0) return 'jwt=exp_missing';

      final start = expIndex + 6;
      var end = start;
      while (end < decoded.length) {
        final c = decoded.codeUnitAt(end);
        if (c < 48 || c > 57) break;
        end++;
      }
      if (end <= start) return 'jwt=exp_parse_failed';

      final expSeconds = int.tryParse(decoded.substring(start, end));
      if (expSeconds == null) return 'jwt=exp_parse_failed';

      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final remaining = expSeconds - nowSeconds;
      if (remaining < 0) return 'jwt=expired(${remaining.abs()}s_ago)';
      return 'jwt=valid(${remaining}s_left)';
    } catch (_) {
      return 'jwt=diag_failed';
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

    for (var i = 0; i < normalized.length; i += 4) {
      final c1 = chars.indexOf(normalized[i]);
      final c2 = chars.indexOf(normalized[i + 1]);
      final c3 =
          normalized[i + 2] == '=' ? -1 : chars.indexOf(normalized[i + 2]);
      final c4 =
          normalized[i + 3] == '=' ? -1 : chars.indexOf(normalized[i + 3]);
      if (c1 < 0 ||
          c2 < 0 ||
          (c3 < 0 && normalized[i + 2] != '=') ||
          (c4 < 0 && normalized[i + 3] != '=')) {
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

  static bool _looksInvalidToken(String errorPreview) {
    final text = errorPreview.toLowerCase();
    return text.contains('invalid token') || text.contains('invalid_token');
  }

  static Future<void> debugSocketAuth({
    required String socketBaseUrl,
    required String accessToken,
    required String gameId,
  }) async {
    final base = _normalizeBaseUrl(socketBaseUrl);
    final uri = '$base/live';
    final jwtDiag = _jwtDiagnostics(accessToken);

    DevLogger.instance.log(
      DevLogCategory.http,
      '[SOCKET_DEBUG] Attempting minimal query-only auth | uri=$uri | gameId=$gameId | $jwtDiag',
    );

    try {
      final socket = io.io(
        uri,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .setQuery({'token': accessToken})
            .setPath('/socket.io')
            .disableAutoConnect()
            .build(),
      );

      var connectAttempts = 0;
      socket.onConnect((_) {
        DevLogger.instance.log(
          DevLogCategory.http,
          '[SOCKET_DEBUG] SUCCESS connected | uri=$uri | gameId=$gameId',
        );
        socket.dispose();
      });

      socket.onConnectError((error) {
        connectAttempts++;
        DevLogger.instance.log(
          DevLogCategory.http,
          '[SOCKET_DEBUG] connect_error attempt=$connectAttempts | uri=$uri | gameId=$gameId | error=${_safePreview(error)}',
        );
        if (connectAttempts > 2) socket.dispose();
      });

      socket.onError((error) {
        DevLogger.instance.log(
          DevLogCategory.http,
          '[SOCKET_DEBUG] error | uri=$uri | gameId=$gameId | error=${_safePreview(error)}',
        );
      });

      socket.connect();
      await Future.delayed(const Duration(seconds: 3));
    } catch (e) {
      DevLogger.instance.log(
        DevLogCategory.http,
        '[SOCKET_DEBUG] exception | uri=$uri | gameId=$gameId | error=$e',
      );
    }
  }

  static String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'https://giaitri.cloud';
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  static String _safePreview(dynamic data) {
    final text = data?.toString() ?? 'null';
    if (text.length <= 220) return text;
    return '${text.substring(0, 220)}...';
  }
}
