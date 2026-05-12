import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../logic/ad_service.dart';
import '../logic/app_navigator.dart';
import '../logic/audio_service.dart';
import '../logic/auth_service.dart';
import '../logic/chess_piece.dart';
import '../logic/dev_logger.dart';
import '../logic/experimental_api_client.dart';
import '../logic/game_controller.dart';
import '../logic/game_state_storage.dart';
import '../logic/move_calculation/move_classes/move.dart';
import '../logic/move_calculation/move_classes/move_meta.dart';
import '../logic/move_calculation/move_classes/move_stack_object.dart';
import '../logic/online_game_events_service.dart';
import '../logic/shared_functions.dart';
import '../logic/timer_service.dart';
import 'api_models.dart';
import 'app_themes.dart';
import 'player.dart';
import 'user_preferences.dart';

class AppModel extends ChangeNotifier {
  static String _envApiBaseUrl() {
    final raw = dotenv.env['API_BASE_URL']?.trim();
    if (raw == null || raw.isEmpty) return 'https://giaitri.cloud';
    return raw;
  }

  static String _envSocketBaseUrl() {
    final raw = dotenv.env['SOCKET_BASE_URL']?.trim();
    if (raw == null || raw.isEmpty) return _envApiBaseUrl();
    return raw;
  }

  static bool _envOnlineVsAiLocalFallbackEnabled() {
    final raw =
        dotenv.env['ONLINE_VS_AI_LOCAL_FALLBACK_ENABLED']?.trim().toLowerCase();
    if (raw == null || raw.isEmpty) return true;
    return raw == '1' || raw == 'true' || raw == 'yes' || raw == 'on';
  }

  // ── Game Settings ──
  int playerCount = 1; // Default: offline AI mode
  int aiDifficulty = 3;
  Player selectedSide = Player.player1;
  Player playerSide = Player.player1;

  // ── Services ──
  final UserPreferences prefs = UserPreferences();
  final AudioService audio = AudioService();
  final TimerService timerService = TimerService();
  final AdService adService = AdService.instance;
  final ExperimentalApiClient apiClient =
      ExperimentalApiClient(baseUrl: _envApiBaseUrl());
  final OnlineGameEventsService onlineEvents = OnlineGameEventsService();
  late final AuthService authService = AuthService(apiClient);

  // ── Experimental API State ──
  bool apiBusy = false;
  String? apiLastError;
  HomeOverview? homeOverviewSnapshot;
  LiveMatchesResponse? liveMatchesSnapshot;
  MonetizationConfig? monetizationConfigSnapshot;
  QuickPlayResult? quickPlaySnapshot;
  OnlineGameSnapshot? onlineGameSnapshot;
  List<OnlineMoveRecord> onlineMoveHistory = [];
  OnlineMoveSubmitResult? onlineMoveSubmitSnapshot;
  Map<String, dynamic>? onlineUserGamesSnapshot;

  // ── Delegated Accessors (backward compatibility) ──
  int get timeLimit => timerService.timeLimit;
  int get moveTimeLimit => timerService.moveTimeLimitSeconds;
  String get pieceTheme => prefs.pieceTheme;
  String get themeName => prefs.themeName;
  bool get showMoveHistory => prefs.showMoveHistory;
  bool get allowUndoRedo => prefs.allowUndoRedo;
  bool get soundEnabled => prefs.soundEnabled;
  bool get showHints => prefs.showHints;
  bool get showNotation => prefs.showNotation;
  bool get enableRotation => prefs.enableRotation;
  AppTheme get theme => prefs.theme;
  int get themeIndex => prefs.themeIndex;
  int get pieceThemeIndex => prefs.pieceThemeIndex;
  List<String> get pieceThemes => prefs.pieceThemes;
  Locale? get locale => prefs.locale;
  String get apiBaseUrl => apiClient.baseUrl;
  String get socketBaseUrl => _envSocketBaseUrl();

  /// Maps the user's configured time limit to the closest standard timeControl
  /// string to send to the matchmaking API.
  String get onlineTimeControl {
    final m = prefs.timeLimitMinutes;
    if (m <= 0) return 'rapid_15'; // unlimited → treat as rapid_15
    if (m <= 1) return 'bullet_1';
    if (m <= 3) return 'blitz_3';
    if (m <= 5) return 'blitz_5';
    if (m <= 10) return 'rapid_10';
    if (m <= 15) return 'rapid_15';
    if (m <= 30) return 'classical_30';
    return 'classical_30';
  }

  ValueNotifier<Duration> get player1TimeLeft => timerService.player1TimeLeft;
  set player1TimeLeft(ValueNotifier<Duration> val) =>
      timerService.player1TimeLeft.value = val.value;
  ValueNotifier<Duration> get player2TimeLeft => timerService.player2TimeLeft;
  set player2TimeLeft(ValueNotifier<Duration> val) =>
      timerService.player2TimeLeft.value = val.value;
  ValueNotifier<Duration> get moveTimeLeft => timerService.moveTimeLeft;

  // ── Game State ──
  GameController? gameController;
  bool gameOver = false;
  bool stalemate = false;
  bool promotionRequested = false;
  bool checkAlert = false;
  bool serverCheck = false;
  String? serverCheckMessage;
  int? serverCastlingRookFromTile;
  int? serverCastlingRookToTile;
  DateTime? _serverCastlingVisualUntil;
  bool moveListUpdated = false;
  bool userWon = false;
  bool opponentDisconnected = false;
  String? gameEndReason; // e.g. 'checkmate', 'timeout', 'abandoned', 'resigned'
  Player turn = Player.player1;
  List<MoveMeta> moveMetaList = [];
  List<ChessPieceType> capturedWhite = [];
  List<ChessPieceType> capturedBlack = [];
  bool _sessionStartedOnline = false;
  bool _endGameAdDisplayed = false;
  bool _onlineVsAiLocalFallbackSession = false;
  bool _spectatorMode = false;
  bool _handlingGlobalUnauthorized = false;

  // Track previous server clock values to detect frozen (non-decrementing) server clocks.
  // Used in _syncClocksIfDrifted to avoid resetting local timer from stale server data.
  int? _prevServerWhiteSec;
  int? _prevServerBlackSec;
  Timer? _spectatorAwaitClockTimer;
  DateTime? _lastSocketClockAt;

  // ── Computed Properties ──
  Player get aiTurn => oppositePlayer(playerSide);
  bool get isAIsTurn => playingWithAI && (turn == aiTurn);
  bool get playingWithAI => playerCount == 1;
  bool get isOnlineGameMode => _sessionStartedOnline;
  bool get usePairUndoRedo => playingWithAI && !isOnlineGameMode;
  bool get shouldLockReplayAfterEndAd =>
      isOnlineGameMode && gameOver && _endGameAdDisplayed;
  bool get isSpectatorMode => _spectatorMode;
  bool get enableOnlineVsAiLocalFallback =>
      _envOnlineVsAiLocalFallbackEnabled();
  bool get isOnlineVsAiLocalFallbackSession => _onlineVsAiLocalFallbackSession;
  bool get shouldRunLocalAiInOnlineVsAi =>
      isOnlineGameMode &&
      isOnlineVsAiLocalFallbackSession &&
      enableOnlineVsAiLocalFallback;

  void _logSpectator(
    String message, {
    DevLogCategory category = DevLogCategory.game,
  }) {
    if (!_spectatorMode) return;
    DevLogger.instance.log(category, '[SPECTATOR] $message');
  }

  // ── Online PvP Waiting State ──
  String? currentGameInviteCode;
  bool isWaitingForOpponent = false;
  bool opponentJoined = false;

  /// Profile công khai của đối thủ trong ván online (null nếu chưa fetch hoặc là AI game).
  Map<String, dynamic>? opponentProfile;

  /// Xóa profile đối thủ (gọi khi thoát ván).
  void clearOpponentProfile() {
    opponentProfile = null;
  }

  /// ID của đối thủ trong ván online (null nếu chưa có hoặc là AI game).
  String? get opponentUserId {
    final snap = onlineGameSnapshot;
    if (snap == null) return null;
    final myId = authService.user?.id;
    return _resolveOpponentId(
      myUserId: myId,
      whiteId: snap.whiteId,
      blackId: snap.blackId,
    );
  }

  /// Chuẩn hóa cách xác định opponentId từ whiteId/blackId theo user hiện tại.
  String? _resolveOpponentId({
    required String? myUserId,
    required String? whiteId,
    required String? blackId,
  }) {
    final me = myUserId?.trim() ?? '';
    final white = whiteId?.trim() ?? '';
    final black = blackId?.trim() ?? '';

    if (me.isNotEmpty) {
      if (white == me && black.isNotEmpty) return black;
      if (black == me && white.isNotEmpty) return white;
    }

    if (white.isNotEmpty) return white;
    if (black.isNotEmpty) return black;
    return null;
  }

  /// Đồng bộ snapshot ngay từ response join để UI có đủ whiteId/blackId lập tức.
  void applyJoinGameResponse(Map<String, dynamic> joinedJson) {
    onlineGameSnapshot = OnlineGameSnapshot.fromJson(joinedJson);
    notifyListeners();
  }

  /// Nạp profile public của đối thủ theo game snapshot hiện tại.
  /// Không throw để tránh chặn luồng vào bàn nếu API profile lỗi tạm thời.
  Future<void> hydrateOpponentProfileFromSnapshot() async {
    final snap = onlineGameSnapshot;
    if (snap == null || snap.isAiGame) {
      opponentProfile = null;
      notifyListeners();
      return;
    }

    final opponentId = _resolveOpponentId(
      myUserId: authService.user?.id,
      whiteId: snap.whiteId,
      blackId: snap.blackId,
    );

    if (opponentId == null || opponentId.isEmpty) {
      opponentProfile = null;
      notifyListeners();
      return;
    }

    try {
      final profile = await apiClient.fetchUserProfile(opponentId);
      opponentProfile = profile;
      notifyListeners();
    } catch (e) {
      DevLogger.instance.log(
        DevLogCategory.http,
        '[PROFILE] fetch opponent failed | opponentId=$opponentId | error=$e',
      );
    }
  }

  // Used to prevent AnimatedRotation from sweeping across the screen when first loading the board.
  bool animateBoardRotation = false;

  bool get isBoardInverted {
    // Online PvP: the local player always sits at the bottom.
    // Board is fixed to playerSide, not rotated per turn.
    if (isOnlineGameMode && !shouldRunLocalAiInOnlineVsAi) {
      return playerSide == Player.player2;
    }
    if (playingWithAI) {
      return playerSide == Player.player2;
    } else {
      return enableRotation && turn == Player.player2;
    }
  }

  AppModel() {
    apiClient.onUnauthorized = _handleGlobalUnauthorized;

    // Wire up service callbacks
    prefs.onChanged = () {
      // Re-apply fixed defaults when settings change (only outside game).
      // Time limits are no longer user-configurable; always 15 min / 60 s.
      if (gameController == null) {
        timerService.configure(15, moveTimeLimitSeconds: 60);
      }
      audio.enabled = prefs.soundEnabled;
      apiClient.setBaseUrl(prefs.apiBaseUrl);
      notifyListeners();
    };
    timerService.onExpired = _handleTimerExpired;
    audio.enabled = prefs.soundEnabled;
    authService.addListener(() => notifyListeners());

    prefs.load();
    authService.init();
  }

  Future<void> _handleGlobalUnauthorized(ApiException error) async {
    if (_handlingGlobalUnauthorized) return;
    _handlingGlobalUnauthorized = true;

    DevLogger.instance.log(
      DevLogCategory.http,
      '[AUTH] Global 401 detected -> logout + navigate home',
    );

    try {
      await authService.logout();
    } catch (_) {
      // Best effort: even if logout API fails, still force local reset + navigation.
    }

    exitChessView();
    redirectToHomeOnUnauthorizedOnce();

    Future<void>.delayed(const Duration(milliseconds: 800), () {
      _handlingGlobalUnauthorized = false;
    });
  }

  // ── Game Lifecycle ──

  void newGame({bool notify = true}) {
    gameController?.cancelAIMove();
    timerService.stop();
    GameStateStorage.clearGameState();
    gameOver = false;
    stalemate = false;
    userWon = false;
    promotionRequested = false;
    serverCheck = false;
    serverCheckMessage = null;
    clearServerCastlingVisual(notify: false);
    opponentDisconnected = false;
    gameEndReason = null;
    _endGameAdDisplayed = false;
    _prevServerWhiteSec = null;
    _prevServerBlackSec = null;
    // Preserve online snapshot & opponent profile when entering an online game
    // session – they were fetched right before ChessView was pushed and must
    // survive the newGame() reset that ChessView.initState() calls.
    if (!isOnlineGameMode) {
      onlineGameSnapshot = null;
      opponentProfile = null;
    }
    turn = Player.player1;
    moveMetaList = [];
    capturedWhite = [];
    capturedBlack = [];
    if (!isOnlineGameMode) {
      // Fixed defaults: 15 min total, 60 s per move for all offline/AI games.
      timerService.configure(15, moveTimeLimitSeconds: 60);
    } else {
      // Use server-provided time control when available; fall back to 15 min.
      final serverMinutes = onlineGameSnapshot?.timeLimitMinutes;
      final minutesToUse =
          serverMinutes != null && serverMinutes > 0 ? serverMinutes : 15;
      // Per-move limit default 60s for all game modes.
      timerService.configure(minutesToUse, moveTimeLimitSeconds: 60);
    }
    audio.enabled = prefs.soundEnabled;
    // For online games, playerSide is assigned by the server via game:state.
    // Never override it here — it may have been set already by _handleSocketGameState
    // before newGame() was called, and it will be (re-)set by the event if it
    // arrives later.
    if (!isOnlineGameMode) {
      if (selectedSide == Player.random) {
        playerSide = math.Random.secure().nextInt(2) == 0
            ? Player.player1
            : Player.player2;
      } else {
        playerSide = selectedSide;
      }
      // In a local 2-player game, rotation is always relative to player1 at bottom.
      if (!playingWithAI) {
        playerSide = Player.player1;
      }
    }
    gameController = GameController(this);
    if (isOnlineGameMode) {
      final fen = onlineGameSnapshot?.currentFen;
      final applied = _applyServerFenToBoard(fen, source: 'snapshot');
      if (!applied) {
        _replayOnlineMoveHistoryToBoard();
      }
      _syncTurnFromFen(fen);
    }
    timerService.start(() => turn, () => gameOver);
    // Online PvP: local timer runs for smooth display; server game:clock events
    // sync/correct values every second. Game end is driven by game:end socket event.

    // Trigger AI move if it's AI's turn natively for standard games
    if (isAIsTurn && !gameOver) {
      gameController!.triggerAIMove();
    }

    // Disable animation on load, then enable it after the board is rendered.
    animateBoardRotation = false;
    Future.delayed(Duration(milliseconds: 50), () {
      animateBoardRotation = true;
      notifyListeners();
    });

    if (notify) {
      notifyListeners();
    }
  }

  void exitChessView() {
    // Nếu game chưa kết thúc, đánh dấu cần hiện ad trước ván tiếp theo.
    if (!gameOver) adService.markGameAbandoned();
    gameController?.cancelAIMove();
    timerService.stop();
    GameStateStorage.clearGameState();
    _sessionStartedOnline = false;
    _spectatorMode = false;
    _endGameAdDisplayed = false;
    _onlineVsAiLocalFallbackSession = false;
    opponentDisconnected = false;
    gameEndReason = null;
    _prevServerWhiteSec = null;
    _prevServerBlackSec = null;
    _spectatorAwaitClockTimer?.cancel();
    _spectatorAwaitClockTimer = null;
    _lastSocketClockAt = null;
    opponentProfile = null;
    serverCheck = false;
    serverCheckMessage = null;
    clearServerCastlingVisual(notify: false);
    unawaited(onlineEvents.stopTracking());
    notifyListeners();
  }

  void saveAndExitChessView() {
    // Nếu game chưa kết thúc, đánh dấu cần hiện ad trước ván tiếp theo.
    if (!gameOver) adService.markGameAbandoned();
    saveGameState();
    gameController?.cancelAIMove();
    timerService.stop();
    _sessionStartedOnline = false;
    _spectatorMode = false;
    _endGameAdDisplayed = false;
    _onlineVsAiLocalFallbackSession = false;
    _spectatorAwaitClockTimer?.cancel();
    _spectatorAwaitClockTimer = null;
    _lastSocketClockAt = null;
    opponentProfile = null;
    serverCheck = false;
    serverCheckMessage = null;
    clearServerCastlingVisual(notify: false);
    unawaited(onlineEvents.stopTracking());
    notifyListeners();
  }

  // ── Move State Management ──

  void pushMoveMeta(MoveMeta meta, {bool silent = false}) {
    moveMetaList.add(meta);
    refreshCapturedPieces();
    moveListUpdated = true;
    if (!silent) notifyListeners();
    saveGameState();
  }

  void popMoveMeta({bool silent = false}) {
    moveMetaList.removeLast();
    refreshCapturedPieces();
    moveListUpdated = true;
    if (!silent) notifyListeners();
    saveGameState();
  }

  void endGame({bool silent = false, bool? forceUserWon}) {
    if (gameOver) return;
    gameOver = true;

    if (forceUserWon != null) {
      userWon = forceUserWon;
    } else {
      userWon = audio.didUserWin(
        playingWithAI: playingWithAI,
        playerSide: playerSide,
        turn: turn,
        player1TimeLeft: player1TimeLeft.value,
        player2TimeLeft: player2TimeLeft.value,
      );
    }

    audio.playGameEndSound(stalemate: stalemate, userWon: userWon);

    GameStateStorage.clearGameState();
    unawaited(adService.onGameEnded());
    unawaited(onlineEvents.stopTracking());
    if (!silent) notifyListeners();
  }

  void undoEndGame({bool silent = false}) {
    gameOver = false;
    if (!silent) notifyListeners();
  }

  void _handleTimerExpired() {
    final timedOutPlayer = _resolveTimedOutPlayer();
    if (timedOutPlayer == null) {
      gameEndReason = 'timeout';
      endGame();
      return;
    }

    gameEndReason = 'timeout';
    DevLogger.instance.log(
      DevLogCategory.game,
      '[TIMER] timeout reached for ${timedOutPlayer.name}; ending game immediately',
    );
    endGame(forceUserWon: timedOutPlayer != playerSide);
  }

  Player? _resolveTimedOutPlayer() {
    if (timerService.player1TimeLeft.value <= Duration.zero) {
      return Player.player1;
    }
    if (timerService.player2TimeLeft.value <= Duration.zero) {
      return Player.player2;
    }
    if (timerService.moveTimeLeft.value <= Duration.zero) {
      return turn;
    }
    return null;
  }

  void changeTurn({bool silent = false}) {
    turn = oppositePlayer(turn);
    if (!silent) notifyListeners();
  }

  void requestPromotion() {
    promotionRequested = true;
    notifyListeners();
  }

  void markEndGameAdDisplayed() {
    _endGameAdDisplayed = true;
    notifyListeners();
  }

  Future<void> startOnlineEventTracking(
    String gameId, {
    bool spectatorMode = false,
  }) async {
    final token = await authService.ensureValidAccessToken();
    if (token == null || token.isEmpty) {
      DevLogger.instance.log(
        DevLogCategory.http,
        '[SOCKET] Skip tracking: no valid access token available',
      );
      return;
    }
    _sessionStartedOnline = true;
    _spectatorMode = spectatorMode;
    _logSpectator('start tracking | gameId=$gameId');
    _spectatorAwaitClockTimer?.cancel();
    _spectatorAwaitClockTimer = null;
    _lastSocketClockAt = null;
    _endGameAdDisplayed = false;
    _onlineVsAiLocalFallbackSession = false;
    await onlineEvents.startTracking(
      socketBaseUrl: socketBaseUrl,
      gameId: gameId,
      accessToken: token,
    );
    // Register socket event handlers after tracking starts.
    onlineEvents.onGameState = _handleSocketGameState;
    onlineEvents.onGameMoveOk = _handleSocketGameMoveOk;
    onlineEvents.onGameClock = _handleSocketGameClock;
    onlineEvents.onGameEnd = _handleSocketGameEnd;
    onlineEvents.onPlayerDisconnected = _handleSocketPlayerDisconnected;
    onlineEvents.onPlayerReconnected = _handleSocketPlayerReconnected;
  }

  Future<void> startMatchmakingEventTracking() async {
    final token = await authService.ensureValidAccessToken();
    if (token == null || token.isEmpty) {
      DevLogger.instance.log(
        DevLogCategory.http,
        '[SOCKET] Skip matchmaking tracking: no valid access token available',
      );
      return;
    }
    _sessionStartedOnline = true;
    _spectatorMode = false;
    _endGameAdDisplayed = false;
    _onlineVsAiLocalFallbackSession = false;
    await onlineEvents.startTracking(
      socketBaseUrl: socketBaseUrl,
      accessToken: token,
    );
  }

  /// Handles `game:state` event from socket.
  /// Covers two cases:
  ///   1. Matchmaking: waiting PvP room transitions to `in_progress` when both
  ///      players have joined.
  ///   2. Reconnect / initial join: apply board state, set player colour,
  ///      sync clocks from the `players` and `clocks` payload fields.
  void _handleSocketGameState(Map<String, dynamic> data) {
    final status = data['status'] as String?;
    DevLogger.instance.log(
      DevLogCategory.game,
      '[SOCKET] game:state handler | status=$status | isWaiting=$isWaitingForOpponent | fullPayload=$data',
    );

    // ── Determine which colour this user is playing ──────────────────────────
    final playersObj = data['players'] as Map<String, dynamic>?;
    _logSpectator(
      'game:state received | status=$status | hasPlayers=${playersObj != null} | hasFen=${(data['fen'] as String?)?.isNotEmpty == true} | hasClocks=${data['clocks'] is Map}',
    );
    if (playersObj != null) {
      final myId = authService.user?.id.trim() ?? '';
      final whitePlayer = playersObj['white'] as Map<String, dynamic>?;
      final blackPlayer = playersObj['black'] as Map<String, dynamic>?;
      final whiteId = whitePlayer?['id']?.toString().trim() ?? '';
      final blackId = blackPlayer?['id']?.toString().trim() ?? '';
      if (myId.isNotEmpty) {
        if (whiteId == myId) {
          playerSide = Player.player1; // I am white
          DevLogger.instance.log(DevLogCategory.game,
              '[SOCKET] game:state: I am WHITE | whiteId=$whiteId');
        } else if (blackId == myId) {
          playerSide = Player.player2; // I am black
          DevLogger.instance.log(DevLogCategory.game,
              '[SOCKET] game:state: I am BLACK | blackId=$blackId');
        }
      }
    }

    // ── Sync board + turn from authoritative server state ───────────────────
    final fen = data['fen'] as String?;
    _applyServerFenToBoard(fen, source: 'game:state');
    _syncTurnFromFen(fen);

    // ── Sync check state/message from server ────────────────────────────────
    serverCheck = data['check'] == true;
    serverCheckMessage = data['checkMessage']?.toString();

    // ── Sync clocks (per BE_TIMER.md: initial or latest clocks from server) ──
    final clocks = data['clocks'] as Map<String, dynamic>?;
    if (clocks != null) {
      _syncClocksFromPayload(clocks, source: 'game:state');
      // Reset frozen-clock tracking after a hard sync from game:state.
      _prevServerWhiteSec = null;
      _prevServerBlackSec = null;
      if (_spectatorMode) {
        _spectatorAwaitClockTimer?.cancel();
        _spectatorAwaitClockTimer = null;
      }
    } else {
      _logSpectator(
        'game:state missing clocks -> likely BE payload contract issue',
      );
      if (_spectatorMode) {
        _spectatorAwaitClockTimer?.cancel();
        _spectatorAwaitClockTimer = Timer(const Duration(seconds: 4), () {
          final sinceLastClock = _lastSocketClockAt == null
              ? 'never'
              : '${DateTime.now().difference(_lastSocketClockAt!).inSeconds}s ago';
          _logSpectator(
            '[BE?] no game:clock within 4s after game:state without clocks | lastClock=$sinceLastClock',
          );
        });
      }
      DevLogger.instance.log(
        DevLogCategory.game,
        '[TIMER][game:state] WARNING: no clocks field in payload',
      );
    }

    // ── Waiting-room transition ──────────────────────────────────────────────
    if (isWaitingForOpponent && status == 'in_progress') {
      isWaitingForOpponent = false;
      opponentJoined = true;
      DevLogger.instance.log(
        DevLogCategory.game,
        '[SOCKET] game:state: both players joined, transitioning to in_progress',
      );
      notifyListeners();
      unawaited(hydrateOpponentProfileFromSnapshot());
      return;
    }

    notifyListeners();
  }

  /// Handles `game:move:ok` — broadcast to all players after a valid move.
  /// NOTE: game:move:ok clock values are intentionally NOT applied here.
  /// The server still sends incorrect values for the player who just moved
  /// (clock is bumped UP instead of decremented — BE fix pending).
  /// Timer accuracy is maintained by the local countdown + game:clock drift correction.
  void _handleSocketGameMoveOk(Map<String, dynamic> data) {
    final from = data['from']?.toString();
    final to = data['to']?.toString();
    if (from == null || to == null) {
      _logSpectator(
        'game:move:ok invalid payload (missing from/to) -> likely BE event shape issue | payload=$data',
      );
      return;
    }

    final promotion = data['promotion']?.toString();
    final fen = data['fen']?.toString();
    final castling = data['castling'] as Map<String, dynamic>?;

    final clocks = data['clocks'] as Map<String, dynamic>?;
    if (clocks != null) {
      _syncClocksFromPayload(clocks, source: 'game:move:ok');
    }

    // Determine whose move this was.
    // `turn` field = who plays NEXT. If it's my turn next, the opponent moved.
    final nextTurnRaw = data['turn']?.toString().toLowerCase() ?? '';
    final myColor = playerSide == Player.player1 ? 'white' : 'black';
    final opponentJustMoved = nextTurnRaw == myColor;

    // Update turn from move event (authoritative)
    if (nextTurnRaw == 'white' && turn != Player.player1) {
      turn = Player.player1;
    } else if (nextTurnRaw == 'black' && turn != Player.player2) {
      turn = Player.player2;
    }

    DevLogger.instance.log(
      DevLogCategory.game,
      '[SOCKET] game:move:ok | $from→$to | turn=$nextTurnRaw | myColor=$myColor | opponentMoved=$opponentJustMoved | clocks=$clocks',
    );

    serverCheck = data['check'] == true;
    serverCheckMessage = data['checkMessage']?.toString();

    // Server is authoritative for board state after each move.
    _applyServerFenToBoard(fen, source: 'game:move:ok');

    // Keep latest-move highlight aligned with server payload.
    final controller = gameController;
    if (controller != null &&
        _isAlgebraicSquare(from) &&
        _isAlgebraicSquare(to)) {
      controller.latestMove = Move(
        _algebraicToTile(from),
        _algebraicToTile(to),
        promotionType: _promoStringToPieceType(promotion),
      );
      // Clear selection/move hints since server state has been reapplied.
      controller.selectedPiece = null;
      controller.validMoves = [];
    }

    _logSpectator(
      'game:move:ok | from=$from to=$to nextTurn=$nextTurnRaw hasFen=${fen != null && fen.isNotEmpty} opponentMoved=$opponentJustMoved castling=$castling check=$serverCheck',
    );

    if (castling != null) {
      markServerCastlingVisual(
        rookFrom: castling['rookFrom']?.toString(),
        rookTo: castling['rookTo']?.toString(),
      );
      DevLogger.instance.log(
        DevLogCategory.game,
        '[SOCKET] castling meta | rookFrom=${castling['rookFrom']} rookTo=${castling['rookTo']}',
      );
    } else {
      clearServerCastlingVisual(notify: false);
    }
    notifyListeners();
  }

  bool get hasActiveServerCastlingVisual {
    final until = _serverCastlingVisualUntil;
    if (serverCastlingRookFromTile == null ||
        serverCastlingRookToTile == null) {
      return false;
    }
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  double get serverCastlingVisualProgress {
    final until = _serverCastlingVisualUntil;
    if (until == null) return 0;
    final totalMs = 650;
    final remaining = until.difference(DateTime.now()).inMilliseconds;
    if (remaining <= 0) return 0;
    final elapsed = totalMs - remaining;
    return (elapsed / totalMs).clamp(0.0, 1.0);
  }

  void markServerCastlingVisual({String? rookFrom, String? rookTo}) {
    if (!_isAlgebraicSquare(rookFrom ?? '') ||
        !_isAlgebraicSquare(rookTo ?? '')) {
      return;
    }
    serverCastlingRookFromTile = _algebraicToTile(rookFrom!);
    serverCastlingRookToTile = _algebraicToTile(rookTo!);
    _serverCastlingVisualUntil =
        DateTime.now().add(const Duration(milliseconds: 650));
  }

  void clearServerCastlingVisual({bool notify = true}) {
    serverCastlingRookFromTile = null;
    serverCastlingRookToTile = null;
    _serverCastlingVisualUntil = null;
    if (notify) {
      notifyListeners();
    }
  }

  /// Handles `game:clock` — server clock tick broadcast every second.
  /// Per BE_TIMER.md: sync clocks with drift threshold, update activeColor to keep turn in sync.
  /// Only correct local clock if drifted by more than 2 seconds (prevents oscillation).
  void _handleSocketGameClock(Map<String, dynamic> data) {
    _lastSocketClockAt = DateTime.now();
    if (_spectatorMode) {
      _spectatorAwaitClockTimer?.cancel();
      _spectatorAwaitClockTimer = null;
    }
    final rawWhite = data['white'] as num?;
    final rawBlack = data['black'] as num?;
    if (rawWhite == null || rawBlack == null) {
      _logSpectator(
        'game:clock missing white/black -> likely BE event payload issue | payload=$data',
      );
    }
    // Use truncate (floor) instead of round to avoid 909.996 → 910
    final whiteSec = rawWhite?.truncate();
    final blackSec = rawBlack?.truncate();

    // Sync clocks with drift threshold check
    _syncClocksIfDrifted(whiteSec, blackSec);

    // Sync whose turn it is from server activeColor (authoritative)
    final activeColor = data['activeColor']?.toString();
    bool turnChanged = false;
    if (activeColor == 'white' && turn != Player.player1) {
      turn = Player.player1;
      turnChanged = true;
    } else if (activeColor == 'black' && turn != Player.player2) {
      turn = Player.player2;
      turnChanged = true;
    }

    DevLogger.instance.log(
      DevLogCategory.game,
      '[SOCKET] game:clock | raw white=$rawWhite→$whiteSec | raw black=$rawBlack→$blackSec'
      ' | activeColor=$activeColor | turnChanged=$turnChanged',
    );

    _logSpectator(
      'game:clock | white=$whiteSec black=$blackSec activeColor=$activeColor turnChanged=$turnChanged',
    );

    if (turnChanged) notifyListeners();
  }

  /// Sync timer values from a clocks payload per BE_TIMER.md contract.
  /// BE sends clocks in seconds (e.g. blitz_5 → 300).
  /// Called on game:state, game:move:ok, and game:clock events.
  void _syncClocksFromPayload(Map<String, dynamic> clocks,
      {String source = 'unknown'}) {
    final rawWhite = clocks['white'] as num?;
    final rawBlack = clocks['black'] as num?;
    // Use truncate (floor) instead of round to avoid 909.996 → 910
    final whiteSec = rawWhite?.truncate();
    final blackSec = rawBlack?.truncate();
    DevLogger.instance.log(
      DevLogCategory.game,
      '[TIMER][$source] raw white=$rawWhite → $whiteSec | raw black=$rawBlack → $blackSec'
      ' | local white=${timerService.player1TimeLeft.value.inSeconds}s'
      ' | local black=${timerService.player2TimeLeft.value.inSeconds}s',
    );
    // Always accept server value (source of truth)
    timerService.setServerClocks(
        whiteSeconds: whiteSec, blackSeconds: blackSec, source: source);
  }

  /// Update player clocks only when the server is actively decrementing AND local
  /// has drifted beyond the threshold.
  ///
  /// Key guard: only correct when `serverSec < _prevServerSec` (server is counting down).
  /// If the server sends the same value repeatedly (frozen/buggy), we skip correction so
  /// the local countdown continues uninterrupted.
  static const int _clockDriftThresholdSeconds = 2;
  void _syncClocksIfDrifted(int? whiteSec, int? blackSec) {
    if (whiteSec != null) {
      final prev = _prevServerWhiteSec;
      _prevServerWhiteSec = whiteSec;
      final serverDecrementing = prev != null && whiteSec < prev;
      final localSec = timerService.player1TimeLeft.value.inSeconds;
      final drift = (localSec - whiteSec).abs();
      final corrected =
          serverDecrementing && drift > _clockDriftThresholdSeconds;
      DevLogger.instance.log(
        DevLogCategory.game,
        '[TIMER][DRIFT] white: local=${localSec}s server=${whiteSec}s'
        ' prev=${prev}s decrementing=$serverDecrementing drift=${drift}s'
        ' → ${corrected ? 'CORRECTED' : 'skipped'}',
      );
      if (corrected) {
        timerService.setServerClocks(
            whiteSeconds: whiteSec, source: 'clock:drift');
      }
    }
    if (blackSec != null) {
      final prev = _prevServerBlackSec;
      _prevServerBlackSec = blackSec;
      final serverDecrementing = prev != null && blackSec < prev;
      final localSec = timerService.player2TimeLeft.value.inSeconds;
      final drift = (localSec - blackSec).abs();
      final corrected =
          serverDecrementing && drift > _clockDriftThresholdSeconds;
      DevLogger.instance.log(
        DevLogCategory.game,
        '[TIMER][DRIFT] black: local=${localSec}s server=${blackSec}s'
        ' prev=${prev}s decrementing=$serverDecrementing drift=${drift}s'
        ' → ${corrected ? 'CORRECTED' : 'skipped'}',
      );
      if (corrected) {
        timerService.setServerClocks(
            blackSeconds: blackSec, source: 'clock:drift');
      }
    }
  }

  /// Handles `game:end` event from socket.
  /// Per BE_TIMER.md: stop timer immediately and end game.
  void _handleSocketGameEnd(Map<String, dynamic> data) {
    final status = data['status']?.toString() ?? 'unknown';
    final winner = data['winner']?.toString();
    final reason = data['reason']?.toString();

    DevLogger.instance.log(
      DevLogCategory.game,
      '[SOCKET] game:end handler | status=$status | winner=$winner | reason=$reason',
    );

    _logSpectator('game:end | status=$status winner=$winner reason=$reason');
    _spectatorAwaitClockTimer?.cancel();
    _spectatorAwaitClockTimer = null;

    // Stop timer immediately when game ends
    timerService.stop();

    // Store reason so UI can show contextual message (e.g. "Opponent left")
    gameEndReason = status != 'unknown' ? status : reason;
    // Clear disconnected flag — game is now officially over
    opponentDisconnected = false;

    if (!gameOver) {
      // For online PvP, derive userWon exclusively from the server's winner field.
      // Never fall back to didUserWin() which gives wrong results for online games.
      bool? forceWon;
      if (isOnlineGameMode && !shouldRunLocalAiInOnlineVsAi) {
        final iAmWhite = playerSide == Player.player1;
        // winner can be "white", "black", or null/absent (draw/stalemate)
        if (winner == 'white' || winner == 'black') {
          forceWon = (winner == 'white') == iAmWhite;
        } else {
          // draw or stalemate — nobody wins
          forceWon = false;
          if (status == 'stalemate' || status == 'draw') {
            stalemate = true;
          }
        }
        DevLogger.instance.log(
          DevLogCategory.game,
          '[SOCKET] game:end: winner=$winner iAmWhite=$iAmWhite playerSide=${playerSide.name} → userWon=$forceWon stalemate=$stalemate',
        );
      }
      endGame(forceUserWon: forceWon);
    }
  }

  /// Handles `game:player:disconnected` — fires immediately when opponent's
  /// socket drops. The game may still continue (grace period) before game:end.
  void _handleSocketPlayerDisconnected(Map<String, dynamic> data) {
    final userId = data['userId']?.toString();
    final myId = authService.user?.id;
    final isOpponent = (userId != null && myId != null && userId != myId);
    DevLogger.instance.log(
      DevLogCategory.game,
      '[SOCKET] game:player:disconnected | userId=$userId | isOpponent=$isOpponent',
    );
    if (isOpponent && !gameOver) {
      opponentDisconnected = true;
      notifyListeners();
    }
  }

  /// Handles `game:player:reconnected` — opponent came back, clear disconnect flag.
  void _handleSocketPlayerReconnected(Map<String, dynamic> data) {
    final userId = data['userId']?.toString();
    final myId = authService.user?.id;
    final isOpponent = (userId != null && myId != null && userId != myId);
    DevLogger.instance.log(
      DevLogCategory.game,
      '[SOCKET] game:player:reconnected | userId=$userId | isOpponent=$isOpponent',
    );
    if (isOpponent && opponentDisconnected) {
      opponentDisconnected = false;
      notifyListeners();
    }
  }

  void markOnlineVsAiLocalFallbackSession(bool enabled, {bool notify = false}) {
    _onlineVsAiLocalFallbackSession = enabled;
    if (notify) notifyListeners();
  }

  void setSpectatorMode(bool enabled, {bool notify = false}) {
    _spectatorMode = enabled;
    if (notify) notifyListeners();
  }

  bool _applyServerFenToBoard(String? fen, {String source = 'socket'}) {
    final controller = gameController;
    if (controller == null || fen == null || fen.trim().isEmpty) {
      return false;
    }
    final applied = controller.board.loadFromFen(fen);
    if (!applied) {
      DevLogger.instance.log(
        DevLogCategory.game,
        '[SOCKET] failed to apply FEN from $source | fen=$fen',
      );
      return false;
    }
    controller.snapSprites();
    return true;
  }

  void _syncTurnFromFen(String? fen) {
    if (fen == null || !fen.contains(' ')) return;
    final fenParts = fen.split(' ');
    if (fenParts.length < 2) return;
    turn = fenParts[1] == 'w' ? Player.player1 : Player.player2;
    DevLogger.instance
        .log(DevLogCategory.game, '[SOCKET] game:state: turn=${turn.name}');
  }

  void _replayOnlineMoveHistoryToBoard() {
    final controller = gameController;
    if (controller == null || onlineMoveHistory.isEmpty) {
      _logSpectator(
        'replay skipped | controllerReady=${controller != null} moveCount=${onlineMoveHistory.length}',
      );
      return;
    }

    final sorted = [...onlineMoveHistory]
      ..sort((a, b) => a.moveNumber.compareTo(b.moveNumber));

    turn = Player.player1;
    moveMetaList = [];
    var applied = 0;
    var skipped = 0;

    for (final record in sorted) {
      final from = record.fromSquare.trim();
      final to = record.toSquare.trim();
      if (!_isAlgebraicSquare(from) || !_isAlgebraicSquare(to)) {
        skipped++;
        continue;
      }

      final move = Move(
        _algebraicToTile(from),
        _algebraicToTile(to),
        promotionType: _promoStringToPieceType(record.promotion),
      );
      final meta = controller.board.push(
        move,
        getMeta: true,
        promotionType: move.promotionType,
      );

      if (meta.promotion && record.promotion != null) {
        final promoted = _promoStringToPieceType(record.promotion);
        controller.board.moveStack.last.movedPiece?.type = promoted;
        controller.board.moveStack.last.promotionType = promoted;
        controller.board.addPromotedPiece(controller.board.moveStack.last);
        meta.promotionType = promoted;
      }

      moveMetaList.add(meta);
      controller.latestMove = meta.move;
      turn = oppositePlayer(turn);
      applied++;
    }

    refreshCapturedPieces();
    controller.snapSprites();
    _logSpectator(
      'replay completed | history=${sorted.length} applied=$applied skipped=$skipped latestMove=${controller.latestMove?.from}->${controller.latestMove?.to}',
    );
  }

  bool _isAlgebraicSquare(String value) {
    if (value.length != 2) return false;
    final file = value.codeUnitAt(0);
    final rank = value.codeUnitAt(1);
    return file >= 97 && file <= 104 && rank >= 49 && rank <= 56;
  }

  int _algebraicToTile(String algebraic) {
    final file = algebraic.codeUnitAt(0) - 97;
    final rank = 8 - int.parse(algebraic[1]);
    return rank * 8 + file;
  }

  ChessPieceType _promoStringToPieceType(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'r':
        return ChessPieceType.rook;
      case 'b':
        return ChessPieceType.bishop;
      case 'n':
        return ChessPieceType.knight;
      case 'q':
      default:
        return ChessPieceType.queen;
    }
  }

  // ── Game Options ──

  void setPlayerCount(int? count) {
    if (count != null) {
      playerCount = count;
      notifyListeners();
    }
  }

  /// Derive online AI level (1..10) from player's current ELO.
  /// Used by Start Game timeout fallback to keep bot strength aligned with user skill.
  int onlineAiLevelFromPlayerElo() {
    final elo =
        authService.user?.elo ?? homeOverviewSnapshot?.user?.elo ?? 1200;
    if (elo < 800) return 1;
    if (elo < 900) return 2;
    if (elo < 1000) return 3;
    if (elo < 1100) return 4;
    if (elo < 1200) return 5;
    if (elo < 1300) return 6;
    if (elo < 1450) return 7;
    if (elo < 1600) return 8;
    if (elo < 1800) return 9;
    return 10;
  }

  void setAIDifficulty(int? difficulty) {
    if (difficulty != null) {
      aiDifficulty = difficulty;
      notifyListeners();
    }
  }

  void setPlayerSide(Player? side) {
    if (side != null) {
      selectedSide = side;
      if (side != Player.random) {
        playerSide = side;
      }
      notifyListeners();
    }
  }

  void setTimeLimit(int? minutes) {
    if (minutes != null) {
      prefs.setTimeLimitMinutes(minutes);
      timerService.configure(minutes,
          moveTimeLimitSeconds: prefs.moveTimeLimitSeconds);
      notifyListeners();
    }
  }

  void setMoveTimeLimit(int? seconds) {
    if (seconds != null) {
      prefs.setMoveTimeLimitSeconds(seconds);
      timerService.configure(prefs.timeLimitMinutes,
          moveTimeLimitSeconds: seconds);
      notifyListeners();
    }
  }

  // ── Preference Delegation ──

  void setTheme(int index) => prefs.setTheme(index);
  void setPieceTheme(int index) => prefs.setPieceTheme(index);
  void setShowMoveHistory(bool show) => prefs.setShowMoveHistory(show);
  void setSoundEnabled(bool enabled) {
    prefs.setSoundEnabled(enabled);
    audio.enabled = enabled;
  }

  void setShowHints(bool show) => prefs.setShowHints(show);
  void setShowNotation(bool show) => prefs.setShowNotation(show);
  void setEnableRotation(bool enable) => prefs.setEnableRotation(enable);
  void setAllowUndoRedo(bool allow) => prefs.setAllowUndoRedo(allow);
  void setLocale(String? localeCode) => prefs.setLocale(localeCode);
  Future<void> setApiBaseUrl(String url) async {
    await prefs.setApiBaseUrl(url);
    apiClient.setBaseUrl(url);
    DevLogger.instance.log(
      DevLogCategory.http,
      'API baseUrl updated to ${apiClient.baseUrl}',
    );
    notifyListeners();
  }

  // ── Experimental API Actions ──

  Future<void> fetchHomeOverviewPreview() async {
    apiBusy = true;
    apiLastError = null;
    notifyListeners();
    try {
      homeOverviewSnapshot = await apiClient.fetchHomeOverview();
      DevLogger.instance.log(
        DevLogCategory.http,
        'GET /api/home/overview OK | auth=${homeOverviewSnapshot?.authMode}',
      );
    } catch (e) {
      apiLastError = e.toString();
      DevLogger.instance.log(
        DevLogCategory.http,
        'GET /api/home/overview ERROR | $apiLastError',
      );
    } finally {
      apiBusy = false;
      notifyListeners();
    }
  }

  Future<void> fetchLiveMatchesPreview() async {
    apiBusy = true;
    apiLastError = null;
    notifyListeners();
    try {
      liveMatchesSnapshot = await apiClient.fetchHomeLiveMatches(limit: 10);
      DevLogger.instance.log(
        DevLogCategory.http,
        'GET /api/home/live-matches OK | items=${liveMatchesSnapshot?.items.length ?? 0}',
      );
    } catch (e) {
      apiLastError = e.toString();
      DevLogger.instance.log(
        DevLogCategory.http,
        'GET /api/home/live-matches ERROR | $apiLastError',
      );
    } finally {
      apiBusy = false;
      notifyListeners();
    }
  }

  Future<void> fetchMonetizationConfigPreview() async {
    apiBusy = true;
    apiLastError = null;
    notifyListeners();
    try {
      monetizationConfigSnapshot = await apiClient.fetchMonetizationConfig();
      DevLogger.instance.log(
        DevLogCategory.http,
        'GET /api/monetization/config OK',
      );
    } catch (e) {
      apiLastError = e.toString();
      DevLogger.instance.log(
        DevLogCategory.http,
        'GET /api/monetization/config ERROR | $apiLastError',
      );
    } finally {
      apiBusy = false;
      notifyListeners();
    }
  }

  Future<void> quickPlayPreview() async {
    apiBusy = true;
    apiLastError = null;
    notifyListeners();
    try {
      quickPlaySnapshot = await apiClient.quickPlay();
      DevLogger.instance.log(
        DevLogCategory.http,
        'POST /api/home/quick-play OK | mode=${quickPlaySnapshot?.mode}',
      );
    } catch (e) {
      apiLastError = e.toString();
      DevLogger.instance.log(
        DevLogCategory.http,
        'POST /api/home/quick-play ERROR | $apiLastError',
      );
    } finally {
      apiBusy = false;
      notifyListeners();
    }
  }

  Future<void> fetchOnlineGameSnapshotPreview(String gameId) async {
    apiBusy = true;
    apiLastError = null;
    notifyListeners();
    try {
      onlineGameSnapshot = await apiClient.fetchGameSnapshot(gameId);
      DevLogger.instance.log(
        DevLogCategory.http,
        'GET /api/games/$gameId OK | status=${onlineGameSnapshot?.status}',
      );
    } catch (e) {
      apiLastError = e.toString();
      DevLogger.instance.log(
        DevLogCategory.http,
        'GET /api/games/$gameId ERROR | $apiLastError',
      );
    } finally {
      apiBusy = false;
      notifyListeners();
    }
  }

  Future<void> fetchOnlineGameMovesPreview(String gameId) async {
    apiBusy = true;
    apiLastError = null;
    notifyListeners();
    try {
      onlineMoveHistory = await apiClient.fetchGameMoves(gameId);
      DevLogger.instance.log(
        DevLogCategory.http,
        'GET /api/games/$gameId/moves OK | count=${onlineMoveHistory.length}',
      );
    } catch (e) {
      apiLastError = e.toString();
      DevLogger.instance.log(
        DevLogCategory.http,
        'GET /api/games/$gameId/moves ERROR | $apiLastError',
      );
    } finally {
      apiBusy = false;
      notifyListeners();
    }
  }

  Future<void> submitOnlineMovePreview({
    required String gameId,
    required String from,
    required String to,
    String? promotion,
  }) async {
    apiBusy = true;
    apiLastError = null;
    notifyListeners();
    try {
      onlineMoveSubmitSnapshot = await apiClient.submitGameMove(
        gameId: gameId,
        from: from,
        to: to,
        promotion: promotion,
      );
      DevLogger.instance.log(
        DevLogCategory.http,
        'POST /api/games/$gameId/moves OK | type=${onlineMoveSubmitSnapshot?.type}',
      );
    } catch (e) {
      apiLastError = e.toString();
      DevLogger.instance.log(
        DevLogCategory.http,
        'POST /api/games/$gameId/moves ERROR | $apiLastError',
      );
    } finally {
      apiBusy = false;
      notifyListeners();
    }
  }

  Future<void> fetchUserGamesPreview(String userId) async {
    apiBusy = true;
    apiLastError = null;
    notifyListeners();
    try {
      onlineUserGamesSnapshot = await apiClient.fetchUserGames(userId: userId);
      final games = onlineUserGamesSnapshot?['games'];
      final count = games is List ? games.length : 0;
      DevLogger.instance.log(
        DevLogCategory.http,
        'GET /api/users/$userId/games OK | count=$count',
      );
    } catch (e) {
      apiLastError = e.toString();
      DevLogger.instance.log(
        DevLogCategory.http,
        'GET /api/users/$userId/games ERROR | $apiLastError',
      );
    } finally {
      apiBusy = false;
      notifyListeners();
    }
  }

  // ── Developer Mode ──

  /// Force the game to end with the user winning.
  void devSimulateWin() {
    if (!gameOver) {
      DevLogger.instance.log(DevLogCategory.system, 'DEV: Simulating user WIN');
      gameOver = true;
      userWon = true;
      stalemate = false;
      GameStateStorage.clearGameState();
      unawaited(adService.onGameEnded());
      notifyListeners();
    }
  }

  /// Force the game to end with the user losing.
  void devSimulateLose() {
    if (!gameOver) {
      DevLogger.instance
          .log(DevLogCategory.system, 'DEV: Simulating user LOSE');
      gameOver = true;
      userWon = false;
      stalemate = false;
      GameStateStorage.clearGameState();
      unawaited(adService.onGameEnded());
      notifyListeners();
    }
  }

  /// Force the game to end as a draw/stalemate.
  void devSimulateDraw() {
    if (!gameOver) {
      DevLogger.instance.log(DevLogCategory.system, 'DEV: Simulating DRAW');
      gameOver = true;
      userWon = false;
      stalemate = true;
      GameStateStorage.clearGameState();
      unawaited(adService.onGameEnded());
      notifyListeners();
    }
  }

  /// Skip the interstitial ad requirement for the next game.
  void devSkipAd() {
    DevLogger.instance.log(DevLogCategory.ad, 'DEV: Ad requirement cleared');
    adService.devSkipAd();
  }

  /// Force-trigger interstitial ad requirement (for testing).
  void devTriggerAd() {
    DevLogger.instance.log(DevLogCategory.ad, 'DEV: Ad requirement forced');
    adService.devForceAdRequired();
  }

  Future<void> resetSettingsToDefaults() async {
    await prefs.resetToDefaults();
    audio.enabled = prefs.soundEnabled;
    notifyListeners();
  }

  void refreshCapturedPieces() {
    capturedWhite = [];
    capturedBlack = [];

    final moveStack = gameController?.board.moveStack;
    if (moveStack == null) return;

    for (final MoveStackObject stackObject in moveStack) {
      final takenPiece = stackObject.takenPiece ??
          (stackObject.enPassant ? stackObject.enPassantPiece : null);
      if (takenPiece == null) continue;

      final normalizedType = takenPiece.type == ChessPieceType.promotion
          ? ChessPieceType.pawn
          : takenPiece.type;

      if (takenPiece.player == Player.player1) {
        capturedWhite.add(normalizedType);
      } else {
        capturedBlack.add(normalizedType);
      }
    }

    capturedWhite.sort(_compareCapturedPieceTypes);
    capturedBlack.sort(_compareCapturedPieceTypes);
  }

  int capturedMaterialFor(Player player) {
    final capturedList =
        player == Player.player1 ? capturedWhite : capturedBlack;
    return capturedList.fold<int>(
      0,
      (sum, type) => sum + _materialDisplayScore(type),
    );
  }

  int materialAdvantageFor(Player player) {
    return capturedMaterialFor(oppositePlayer(player)) -
        capturedMaterialFor(player);
  }

  int _compareCapturedPieceTypes(ChessPieceType left, ChessPieceType right) {
    return _materialDisplayScore(right).compareTo(_materialDisplayScore(left));
  }

  int _materialDisplayScore(ChessPieceType type) {
    switch (type) {
      case ChessPieceType.pawn:
        return 1;
      case ChessPieceType.knight:
      case ChessPieceType.bishop:
        return 3;
      case ChessPieceType.rook:
        return 5;
      case ChessPieceType.queen:
        return 9;
      case ChessPieceType.king:
      case ChessPieceType.promotion:
        return 0;
    }
  }

  // ── Utilities ──

  void update() {
    notifyListeners();
  }

  void saveGameState() {
    GameStateStorage.saveGameState(this);
  }

  Future<void> restoreGameState() async {
    final state = await GameStateStorage.loadGameState();
    if (state == null) return;

    gameController?.cancelAIMove();
    timerService.stop();

    playerCount = state['playerCount'] as int;
    aiDifficulty = state['aiDifficulty'] as int;
    playerSide = Player.values[state['playerSide'] as int];
    selectedSide = Player.values[state['selectedSide'] as int];
    timerService.configure(state['timeLimit'] as int);
    gameOver = state['gameOver'] as bool;
    stalemate = state['stalemate'] as bool;
    turn = Player.player1;
    moveMetaList = [];

    // Create a fresh game and replay all moves
    gameController = GameController(this);
    final moves = GameStateStorage.parseMoves(state);
    for (var move in moves) {
      var meta = gameController!.board
          .push(move, getMeta: true, promotionType: move.promotionType);
      moveMetaList.add(meta);
      turn = oppositePlayer(turn);
    }
    refreshCapturedPieces();
    gameController!.snapSprites();

    // Restore timer durations
    player1TimeLeft.value =
        Duration(milliseconds: state['player1TimeLeftMs'] as int);
    player2TimeLeft.value =
        Duration(milliseconds: state['player2TimeLeftMs'] as int);

    // Restore game over / stalemate state
    gameOver = state['gameOver'] as bool;
    stalemate = state['stalemate'] as bool;

    // Update visual state from last move
    if (moveMetaList.isNotEmpty) {
      gameController!.latestMove = moveMetaList.last.move;
      var oppositeTurn = oppositePlayer(turn);
      if (gameController!.board.kingInCheck(oppositeTurn)) {
        gameController!.checkHintTile =
            gameController!.board.kingForPlayer(oppositeTurn)?.tile;
      }
    }

    timerService.start(() => turn, () => gameOver);

    notifyListeners();

    // Trigger AI move if it's AI's turn
    if (isAIsTurn && !gameOver) {
      gameController!.triggerAIMove();
    }

    animateBoardRotation = false;
    Future.delayed(Duration(milliseconds: 50), () {
      animateBoardRotation = true;
      notifyListeners();
    });
  }
}
