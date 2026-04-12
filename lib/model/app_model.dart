import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/ad_service.dart';
import '../logic/audio_service.dart';
import '../logic/chess_piece.dart';
import '../logic/dev_logger.dart';
import '../logic/game_controller.dart';
import '../logic/game_state_storage.dart';
import '../logic/move_calculation/move_classes/move_meta.dart';
import '../logic/move_calculation/move_classes/move_stack_object.dart';
import '../logic/shared_functions.dart';
import '../logic/timer_service.dart';
import 'app_themes.dart';
import 'player.dart';
import 'user_preferences.dart';

class AppModel extends ChangeNotifier {
  // ── Game Settings ──
  int playerCount = 1;
  int aiDifficulty = 3;
  Player selectedSide = Player.player1;
  Player playerSide = Player.player1;

  // ── Services ──
  final UserPreferences prefs = UserPreferences();
  final AudioService audio = AudioService();
  final TimerService timerService = TimerService();
  final AdService adService = AdService.instance;

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

  // ── Computed Properties ──
  Player get aiTurn => oppositePlayer(playerSide);
  bool get isAIsTurn => playingWithAI && (turn == aiTurn);
  bool get playingWithAI => playerCount == 1;

  // Used to prevent AnimatedRotation from sweeping across the screen when first loading the board.
  bool animateBoardRotation = false;

  bool get isBoardInverted {
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
      notifyListeners();
    };
    timerService.onExpired = () => endGame();
    audio.enabled = prefs.soundEnabled;

    prefs.load();
  }

  // ── Game Lifecycle ──

  void newGame({bool notify = true}) {
    gameController?.cancelAIMove();
    timerService.stop();
    GameStateStorage.clearGameState();
    gameOver = false;
    stalemate = false;
    userWon = false;
    turn = Player.player1;
    moveMetaList = [];
    capturedWhite = [];
    capturedBlack = [];
    timerService.configure(prefs.timeLimitMinutes,
        moveTimeLimitSeconds: prefs.moveTimeLimitSeconds);
    audio.enabled = prefs.soundEnabled;
    if (selectedSide == Player.random) {
      playerSide = math.Random.secure().nextInt(2) == 0
          ? Player.player1
          : Player.player2;
    } else {
      playerSide = selectedSide;
    }

    // In a 2-player game, rotation is always relative to player1 being at the bottom.
    if (!playingWithAI) {
      playerSide = Player.player1;
    }
    gameController = GameController(this);
    timerService.start(() => turn, () => gameOver);

    // Preload ads into queue so they're ready for the next game start.
    adService.fillQueue();

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
    notifyListeners();
  }

  void saveAndExitChessView() {
    // Nếu game chưa kết thúc, đánh dấu cần hiện ad trước ván tiếp theo.
    if (!gameOver) adService.markGameAbandoned();
    saveGameState();
    gameController?.cancelAIMove();
    timerService.stop();
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
