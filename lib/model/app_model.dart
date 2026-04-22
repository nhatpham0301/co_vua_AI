import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../logic/ad_service.dart';
import '../logic/audio_service.dart';
import '../logic/auth_service.dart';
import '../logic/chess_piece.dart';
import '../logic/dev_logger.dart';
import '../logic/experimental_api_client.dart';
import '../logic/game_controller.dart';
import '../logic/game_state_storage.dart';
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
  bool moveListUpdated = false;
  bool userWon = false;
  Player turn = Player.player1;
  List<MoveMeta> moveMetaList = [];
  List<ChessPieceType> capturedWhite = [];
  List<ChessPieceType> capturedBlack = [];
  bool _sessionStartedOnline = false;
  bool _endGameAdDisplayed = false;
  bool _onlineVsAiLocalFallbackSession = false;

  // ── Computed Properties ──
  Player get aiTurn => oppositePlayer(playerSide);
  bool get isAIsTurn => playingWithAI && (turn == aiTurn);
  bool get playingWithAI => playerCount == 1;
  bool get isOnlineGameMode => _sessionStartedOnline;
  bool get usePairUndoRedo => playingWithAI && !isOnlineGameMode;
  bool get shouldLockReplayAfterEndAd =>
      isOnlineGameMode && gameOver && _endGameAdDisplayed;
  bool get enableOnlineVsAiLocalFallback =>
      _envOnlineVsAiLocalFallbackEnabled();
  bool get isOnlineVsAiLocalFallbackSession => _onlineVsAiLocalFallbackSession;
  bool get shouldRunLocalAiInOnlineVsAi =>
      isOnlineGameMode &&
      isOnlineVsAiLocalFallbackSession &&
      enableOnlineVsAiLocalFallback;

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
    // Wire up service callbacks
    prefs.onChanged = () {
      // Re-apply timer config from prefs when settings change (only outside game)
      if (gameController == null) {
        timerService.configure(
          prefs.timeLimitMinutes,
          moveTimeLimitSeconds: prefs.moveTimeLimitSeconds,
        );
      }
      audio.enabled = prefs.soundEnabled;
      apiClient.setBaseUrl(prefs.apiBaseUrl);
      notifyListeners();
    };
    timerService.onExpired = () => endGame();
    audio.enabled = prefs.soundEnabled;
    authService.addListener(() => notifyListeners());

    prefs.load();
    authService.init();
  }

  // ── Game Lifecycle ──

  void newGame({bool notify = true}) {
    gameController?.cancelAIMove();
    timerService.stop();
    GameStateStorage.clearGameState();
    gameOver = false;
    stalemate = false;
    userWon = false;
    _endGameAdDisplayed = false;
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
      timerService.configure(prefs.timeLimitMinutes,
          moveTimeLimitSeconds: prefs.moveTimeLimitSeconds);
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
    _endGameAdDisplayed = false;
    _onlineVsAiLocalFallbackSession = false;
    _onlineVsAiLocalFallbackSession = false;
    opponentProfile = null;
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
    _endGameAdDisplayed = false;
    _onlineVsAiLocalFallbackSession = false;
    opponentProfile = null;
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

  void endGame({bool silent = false}) {
    if (gameOver) return;
    gameOver = true;

    userWon = audio.didUserWin(
      playingWithAI: playingWithAI,
      playerSide: playerSide,
      turn: turn,
      player1TimeLeft: player1TimeLeft.value,
      player2TimeLeft: player2TimeLeft.value,
    );

    audio.playGameEndSound(
      stalemate: stalemate,
      playingWithAI: playingWithAI,
      playerSide: playerSide,
      turn: turn,
      player1TimeLeft: player1TimeLeft.value,
      player2TimeLeft: player2TimeLeft.value,
    );

    GameStateStorage.clearGameState();
    unawaited(adService.onGameEnded());
    unawaited(onlineEvents.stopTracking());
    if (!silent) notifyListeners();
  }

  void undoEndGame({bool silent = false}) {
    gameOver = false;
    if (!silent) notifyListeners();
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

  Future<void> startOnlineEventTracking(String gameId) async {
    final token = await authService.ensureValidAccessToken();
    if (token == null || token.isEmpty) {
      DevLogger.instance.log(
        DevLogCategory.http,
        '[SOCKET] Skip tracking: no valid access token available',
      );
      return;
    }
    _sessionStartedOnline = true;
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

    // ── Sync current turn from FEN ───────────────────────────────────────────
    final fen = data['fen'] as String?;
    if (fen != null && fen.contains(' ')) {
      final fenParts = fen.split(' ');
      if (fenParts.length >= 2) {
        turn = fenParts[1] == 'w' ? Player.player1 : Player.player2;
        DevLogger.instance
            .log(DevLogCategory.game, '[SOCKET] game:state: turn=${turn.name}');
      }
    }

    // ── Sync clocks (present on reconnect) ──────────────────────────────────
    final clocks = data['clocks'] as Map<String, dynamic>?;
    if (clocks != null) {
      _syncClocksFromPayload(clocks);
    }

    // ── Waiting-room transition ──────────────────────────────────────────────
    if (isWaitingForOpponent && status == 'in_progress') {
      isWaitingForOpponent = false;
      opponentJoined = true;
      notifyListeners();
      unawaited(hydrateOpponentProfileFromSnapshot());
      return;
    }

    notifyListeners();
  }

  /// Handles `game:move:ok` — broadcast to all players after a valid move.
  /// Applies the opponent's move to the local board if it was their turn.
  void _handleSocketGameMoveOk(Map<String, dynamic> data) {
    final from = data['from']?.toString();
    final to = data['to']?.toString();
    if (from == null || to == null) return;

    final promotion = data['promotion']?.toString();

    // Sync clocks from the move event.
    final clocks = data['clocks'] as Map<String, dynamic>?;
    if (clocks != null) {
      _syncClocksFromPayload(clocks);
    }

    // Determine whose move this was.
    // `turn` field = who plays NEXT. If it's my turn next, the opponent moved.
    final nextTurnRaw = data['turn']?.toString().toLowerCase() ?? '';
    final myColor = playerSide == Player.player1 ? 'white' : 'black';
    final opponentJustMoved = (nextTurnRaw == myColor);

    DevLogger.instance.log(
      DevLogCategory.game,
      '[SOCKET] game:move:ok | $from→$to | nextTurn=$nextTurnRaw | myColor=$myColor | opponentMoved=$opponentJustMoved',
    );

    if (opponentJustMoved && !gameOver) {
      gameController?.applyRemoteMove(from: from, to: to, promotion: promotion);
    }
  }

  /// Handles `game:clock` — server clock tick broadcast every second.
  /// Uses `activeColor` to also keep `turn` in sync with the server.
  void _handleSocketGameClock(Map<String, dynamic> data) {
    final whiteSec = (data['white'] as num?)?.round();
    final blackSec = (data['black'] as num?)?.round();
    // Only correct local clock if server value differs by more than 2 seconds.
    // This prevents the 04:59/05:00 oscillation caused by server rounding.
    _syncClocksIfDrifted(whiteSec, blackSec);

    // Sync whose turn it is from the server clock (authoritative).
    final activeColor = data['activeColor']?.toString();
    if (activeColor == 'white' && turn != Player.player1) {
      turn = Player.player1;
      notifyListeners();
    } else if (activeColor == 'black' && turn != Player.player2) {
      turn = Player.player2;
      notifyListeners();
    }
  }

  /// Sync timer values from a clocks payload `{ white: sec, black: sec }`.
  /// BE sends seconds (e.g. blitz_5 → 300). Use round() to handle floats.
  void _syncClocksFromPayload(Map<String, dynamic> clocks) {
    final whiteSec = (clocks['white'] as num?)?.round();
    final blackSec = (clocks['black'] as num?)?.round();
    // On move events, always accept the server value (authoritative after a move).
    timerService.setServerClocks(
        whiteSeconds: whiteSec, blackSeconds: blackSec);
  }

  /// Update a player clock only when the local value has drifted more than
  /// [_clockDriftThresholdSeconds] from the server value.
  static const int _clockDriftThresholdSeconds = 2;
  void _syncClocksIfDrifted(int? whiteSec, int? blackSec) {
    if (whiteSec != null) {
      final localSec = timerService.player1TimeLeft.value.inSeconds;
      if ((localSec - whiteSec).abs() > _clockDriftThresholdSeconds) {
        timerService.setServerClocks(whiteSeconds: whiteSec);
      }
    }
    if (blackSec != null) {
      final localSec = timerService.player2TimeLeft.value.inSeconds;
      if ((localSec - blackSec).abs() > _clockDriftThresholdSeconds) {
        timerService.setServerClocks(blackSeconds: blackSec);
      }
    }
  }

  /// Handles `game:end` event from socket.
  void _handleSocketGameEnd(Map<String, dynamic> data) {
    DevLogger.instance.log(
      DevLogCategory.game,
      '[SOCKET] game:end handler | data=${data.toString().substring(0, data.toString().length.clamp(0, 120))}',
    );
    if (!gameOver) {
      endGame();
    }
  }

  void markOnlineVsAiLocalFallbackSession(bool enabled, {bool notify = false}) {
    _onlineVsAiLocalFallbackSession = enabled;
    if (notify) notifyListeners();
  }

  // ── Game Options ──

  void setPlayerCount(int? count) {
    if (count != null) {
      playerCount = count;
      notifyListeners();
    }
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
