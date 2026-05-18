import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../logic/chess_game.dart';
import '../logic/dev_logger.dart';
import '../logic/experimental_api_client.dart';
import '../model/app_model.dart';
import '../model/player.dart';
import 'components/chess_view/board_stage.dart';
import 'components/chess_view/chess_actions.dart';
import 'components/chess_view/chess_dialogs.dart';
import 'components/chess_view/players_header_row.dart';
import 'components/chess_view/promotion_dialog.dart';
import 'components/chess_view/waiting_opponent_dialog.dart';
import 'components/main_menu_view/mm_background.dart';
import 'components/main_menu_view/mm_banner_ad.dart';
import 'components/main_menu_view/mm_palette.dart';
import 'components/main_menu_view/user_profile_dialog.dart';

const _kRankElos = [0, 800, 1100, 1400, 1650, 2100];
const _kTopBannerSlotHeight = 56.0;

class ChessView extends StatefulWidget {
  final AppModel appModel;
  final bool isResuming;

  const ChessView(this.appModel, {super.key, this.isResuming = false});

  @override
  State<ChessView> createState() => _ChessViewState(appModel);
}

class _ChessViewState extends State<ChessView> with WidgetsBindingObserver {
  AppModel appModel;
  ChessGame? chessGame;
  late ConfettiController _confettiController;

  bool _wasGameOver = false;
  bool _gameEndAdScheduled = false;
  int _readySeconds = 30;
  bool _isReady = false;
  Timer? _readyTimer;
  bool _opponentJoinDetected = false;
  bool _waitingDialogShown = false;
  bool _postGameFlowHandled = false;
  bool _isRecreatingMatch = false;
  bool _showPostGameOptions = false;

  _ChessViewState(this.appModel);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 5));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isResuming) {
        if (appModel.isSpectatorMode) {
          DevLogger.instance.log(
            DevLogCategory.game,
            '[SPECTATOR] ChessView init from resume path',
          );
        }
        appModel.restoreGameState().then((_) => _initFlameGame());
      } else {
        appModel.newGame(notify: false);
        _initFlameGame();
        if (appModel.isSpectatorMode) {
          _isReady = true;
          appModel.timerService.resume();
          DevLogger.instance.log(
            DevLogCategory.game,
            '[SPECTATOR] ChessView init ready immediately (skip countdown/waiting)',
          );
        }
        // Online AI game: skip countdown — server already started the game.
        // User should see the board immediately and start playing.
        final isOnlineAi = appModel.isOnlineGameMode && appModel.playingWithAI;
        if (isOnlineAi && !appModel.isSpectatorMode) {
          _isReady = true;
          appModel.timerService.resume();
          DevLogger.instance.log(
            DevLogCategory.game,
            '[CHESS_VIEW] Online AI game — skip countdown, ready immediately',
          );
        }
        // When waiting for opponent, pause timers and show waiting dialog.
        // When not waiting, start the ready countdown immediately.
        if (appModel.isWaitingForOpponent && !appModel.isSpectatorMode) {
          appModel.timerService.pause();
          appModel.gameController?.cancelAIMove();
        } else if (!appModel.isSpectatorMode && !isOnlineAi) {
          _startReadyCountdown();
        }
      }
      // Show waiting dialog if in PvP waiting state
      _checkAndShowWaitingDialog();
    });
  }

  void _startReadyCountdown() {
    _readyTimer?.cancel();
    _readySeconds = 30;
    _isReady = false;
    appModel.isInputLocked = true;

    appModel.timerService.pause();
    appModel
        .pauseGameClock(); // ngăn socket clock events cập nhật UI trong thời gian đợi
    appModel.gameController?.cancelAIMove();

    _readyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isReady) {
        timer.cancel();
        return;
      }

      final next = _readySeconds - 1;
      setState(() => _readySeconds = next < 0 ? 0 : next);

      if (_readySeconds == 0) {
        timer.cancel();
        appModel.isInputLocked = false;
        appModel.exitChessView();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    });
    setState(() {});
  }

  Future<T> _withAuthRetry<T>({
    required AppModel appModel,
    required String action,
    required Future<T> Function() execute,
  }) async {
    try {
      return await execute();
    } on ApiException catch (e) {
      if (e.statusCode != 401) rethrow;
      DevLogger.instance.log(
        DevLogCategory.http,
        '[CHESS_VIEW] $action unauthorized (401) -> refreshing token',
      );
      final refreshed = await appModel.authService.refreshTokens();
      if (!refreshed) rethrow;
      DevLogger.instance.log(
        DevLogCategory.http,
        '[CHESS_VIEW] $action retry after refresh',
      );
      return execute();
    }
  }

  Future<void> _startMatchFromCurrentMode({bool showError = true}) async {
    if (_isRecreatingMatch || !mounted) return;
    setState(() {
      _isRecreatingMatch = true;
      _showPostGameOptions = false;
    });

    try {
      final isOnline = appModel.isOnlineGameMode && !appModel.isSpectatorMode;

      if (!isOnline) {
        appModel.newGame(notify: false);
        _initFlameGame();
        _opponentJoinDetected = false;
        _waitingDialogShown = false;
        _postGameFlowHandled = false;
        _showPostGameOptions = false;
        _isReady = true;
        appModel.isInputLocked = false;
        appModel.timerService.resume();
        if (appModel.isAIsTurn && !appModel.gameOver) {
          appModel.gameController?.triggerAIMove();
        }
        if (mounted) setState(() {});
        return;
      }

      final isServerAi = appModel.onlineGameSnapshot?.isAiGame == true ||
          appModel.playingWithAI;

      if (isServerAi) {
        final aiLevel = appModel.onlineGameSnapshot?.aiLevel ??
            appModel.onlineAiLevelFromPlayerElo();
        final color = appModel.nextOnlineAiColor();
        DevLogger.instance.log(
          DevLogCategory.game,
          '[CHESS_VIEW] recreate AI match | aiLevel=$aiLevel | source=${appModel.onlineGameSnapshot?.aiLevel != null ? 'snapshot' : 'elo-fallback'}',
        );
        final created = await _withAuthRetry(
          appModel: appModel,
          action: 'createAiGame(rematch)',
          execute: () => appModel.apiClient.createAiGame(
            aiLevel: aiLevel,
            color: color,
            timeControl: 'rapid_15',
            moveTimeLimit: 0,
          ),
        );
        final gameId = (created['id']?.toString() ?? '').trim();
        if (gameId.isEmpty) {
          throw Exception('createAiGame rematch missing game id');
        }

        appModel.applyJoinGameResponse(created);
        await appModel.onlineEvents.stopTracking();
        await appModel.startOnlineEventTracking(gameId);
        appModel.markOnlineVsAiLocalFallbackSession(false);
        appModel.setPlayerCount(1);
        appModel.isWaitingForOpponent = false;
        appModel.opponentJoined = true;
        appModel.currentGameInviteCode = null;
      } else {
        final created = await _withAuthRetry(
          appModel: appModel,
          action: 'createPvPGame(rematch)',
          execute: () => appModel.apiClient.createPvPGame(
            timeControl: appModel.onlineTimeControl,
            moveTimeLimit: appModel.moveTimeLimit,
          ),
        );
        final gameId = (created['id']?.toString() ?? '').trim();
        if (gameId.isEmpty) {
          throw Exception('createPvPGame rematch missing game id');
        }

        appModel.applyJoinGameResponse(created);
        await appModel.onlineEvents.stopTracking();
        await appModel.startOnlineEventTracking(gameId);
        appModel.setPlayerCount(2);
        appModel.isWaitingForOpponent = true;
        appModel.opponentJoined = false;
        final inviteCode = (created['inviteCode']?.toString() ?? '').trim();
        appModel.currentGameInviteCode =
            inviteCode.isNotEmpty ? inviteCode : null;
      }

      appModel.newGame(notify: false);
      _initFlameGame();

      _opponentJoinDetected = false;
      _waitingDialogShown = false;
      _postGameFlowHandled = false;
      _showPostGameOptions = false;

      if (appModel.isWaitingForOpponent && !appModel.isSpectatorMode) {
        appModel.timerService.pause();
        appModel.gameController?.cancelAIMove();
        _isReady = true;
        _checkAndShowWaitingDialog();
      } else {
        _isReady = true;
        appModel.timerService.resume();
        if (appModel.isAIsTurn && !appModel.gameOver) {
          appModel.gameController?.triggerAIMove();
        }
      }

      if (mounted) setState(() {});
    } catch (e) {
      DevLogger.instance.log(
        DevLogCategory.http,
        '[CHESS_VIEW] recreate match failed | $e',
      );
      if (showError && mounted) {
        final langCode = Localizations.localeOf(context).languageCode;
        final title = langCode == 'vi'
            ? 'Không thể tạo ván mới'
            : 'Cannot create new game';
        final msg = langCode == 'vi'
            ? 'Vui lòng thử lại sau ít giây.'
            : 'Please try again in a few seconds.';
        showCupertinoDialog<void>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: Text(title),
            content: Text(msg),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRecreatingMatch = false);
      }
    }
  }

  void _onReadyPressed() {
    if (_isReady || _isRecreatingMatch) return;

    if (appModel.gameOver) {
      unawaited(_startMatchFromCurrentMode());
      return;
    }

    _readyTimer?.cancel();
    _readyTimer = null;
    appModel.isInputLocked = false;
    setState(() => _isReady = true);

    appModel.resumeGameClock(); // tiếp tục nhận clock events từ server
    appModel.timerService.resume();
    if (appModel.isAIsTurn && !appModel.gameOver) {
      appModel.gameController?.triggerAIMove();
    }

    // Show waiting dialog if in PvP waiting state
    _checkAndShowWaitingDialog();
  }

  void _onExitAfterGame() {
    appModel.exitChessView();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _checkAndShowWaitingDialog() {
    if (appModel.isWaitingForOpponent && !_waitingDialogShown && mounted) {
      _waitingDialogShown = true;
      showCupertinoDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => WaitingOpponentDialog(appModel: appModel),
      );
    }
  }

  void _showOpponentProfile(
      BuildContext context, AppModel appModel, AppLocalizations l, int botElo) {
    final opponentId = appModel.opponentUserId;
    final isAI = appModel.playingWithAI;
    final isGuestLocalTwoPlayer = !appModel.authService.isLoggedIn && !isAI;
    final diff = appModel.aiDifficulty.clamp(1, 5);
    final profile = appModel.opponentProfile;
    final opponentName = isAI
        ? l.botLevel(diff)
        : (profile?['username'] as String?)?.isNotEmpty == true
            ? profile!['username'] as String
            : (isGuestLocalTwoPlayer ? l.twoPlayer : l.opponent);
    final opponentElo =
        isAI ? botElo : (profile?['elo'] as num?)?.toInt() ?? botElo;
    final opponentAvatar = isAI ? null : profile?['avatarUrl'] as String?;
    final capturedPieces = appModel.capturedBlack; // quân trắng ăn quân đen

    if (opponentId != null && !isAI) {
      // Online — show full profile dialog with captured tab
      showCupertinoDialog<void>(
        context: context,
        builder: (_) => UserProfileDialog(
          userId: opponentId,
          userName: opponentName,
          avatarUrl: opponentAvatar,
          elo: opponentElo,
          capturedPieces: capturedPieces,
        ),
      );
    } else {
      // AI or no userId — show local info with captured tab only
      showCupertinoDialog<void>(
        context: context,
        builder: (_) => UserProfileDialog(
          userId: 'ai_$diff',
          userName: opponentName,
          avatarUrl: null,
          elo: botElo,
          capturedPieces: capturedPieces,
        ),
      );
    }
  }

  void _initFlameGame() {
    if (appModel.gameController != null) {
      setState(() {
        chessGame = ChessGame(appModel.gameController!, appModel);
      });
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) appModel.update();
      });
    }
  }

  @override
  void dispose() {
    if (appModel.isSpectatorMode) {
      DevLogger.instance.log(
        DevLogCategory.game,
        '[SPECTATOR] ChessView dispose',
      );
    }
    _readyTimer?.cancel();
    // Reset waiting state
    appModel.isWaitingForOpponent = false;
    appModel.currentGameInviteCode = null;
    appModel.opponentJoined = false;
    WidgetsBinding.instance.removeObserver(this);
    _confettiController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (!appModel.gameOver) {
        if (!appModel.isSpectatorMode) appModel.saveGameState();
        appModel.timerService.pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!appModel.gameOver) {
        appModel.timerService.resume();
      }
    }
  }

  double _boardSizeFor(BoxConstraints constraints) {
    final maxBoardWidth = math.min(constraints.maxWidth - 34, 680.0);
    final preferredHeight = constraints.maxHeight * 0.66;
    return math.max(280, math.min(maxBoardWidth, preferredHeight));
  }

  void _showPromotionDialog(AppModel appModel) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => PromotionDialog(appModel),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppModel>(
      builder: (context, appModel, child) {
        final theme = appModel.theme;
        if (appModel.gameController == null || chessGame == null) {
          return Scaffold(
            backgroundColor: bgDark,
            body: const Center(
              child: CupertinoActivityIndicator(color: primary),
            ),
          );
        }

        // Start countdown when ready:
        // 1. Opponent joined in PvP mode, OR
        // 2. Switched to AI mode (fallback from PvP timeout)
        if ((appModel.opponentJoined ||
                (appModel.playingWithAI && appModel.isOnlineGameMode)) &&
            !appModel.isSpectatorMode &&
            !_opponentJoinDetected) {
          _opponentJoinDetected = true;
          _waitingDialogShown = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _startReadyCountdown();
            }
          });
        }

        if (appModel.promotionRequested) {
          appModel.promotionRequested = false;
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _showPromotionDialog(appModel));
        }

        if (appModel.gameOver &&
            !_wasGameOver &&
            !_gameEndAdScheduled &&
            !appModel.isSpectatorMode) {
          _wasGameOver = true;
          _gameEndAdScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(seconds: 1), () async {
              if (!mounted) return;

              _gameEndAdScheduled = false;
              final shown = await appModel.adService.showGameEndAd(context);
              if (!mounted) return;
              if (shown) {
                appModel.markEndGameAdDisplayed();
              }
            });
          });
        } else if (!appModel.gameOver) {
          _wasGameOver = false;
          _postGameFlowHandled = false;
          _showPostGameOptions = false;
        }

        if (appModel.gameOver &&
            !_postGameFlowHandled &&
            !appModel.isSpectatorMode) {
          _postGameFlowHandled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            // After game ends, always let user choose replay or exit.
            _opponentJoinDetected = false;
            _waitingDialogShown = false;
            _readyTimer?.cancel();
            appModel.timerService.pause();
            appModel.gameController?.cancelAIMove();
            setState(() {
              _isReady = false;
              _showPostGameOptions = true;
            });
          });
        }

        if (appModel.gameOver &&
            appModel.userWon &&
            !appModel.isSpectatorMode) {
          _confettiController.play();
        } else {
          _confettiController.stop();
        }

        final l = AppLocalizations.of(context)!;
        final diff = appModel.aiDifficulty.clamp(1, 5);
        final botElo = _kRankElos[diff];
        final isAI = appModel.playingWithAI;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (appModel.gameOver) {
              appModel.exitChessView();
              Navigator.of(context).pop();
            } else {
              // Tạm dừng countdown để dialog không bị đóng tự động
              final wasInCountdown = !_isReady && _readyTimer != null;
              _readyTimer?.cancel();
              _readyTimer = null;
              showExitDialog(
                context,
                onCancel: wasInCountdown ? _startReadyCountdown : null,
              );
            }
          },
          child: Scaffold(
            backgroundColor: bgDark,
            body: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(
                        'assets/images/boards/background_board.png',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const CornerKnots(),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.14),
                        const Color(0xFF2E1B0F).withValues(alpha: 0.38),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final boardSize = _boardSizeFor(constraints);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(
                            height: _kTopBannerSlotHeight,
                            child: GameBannerAd(bottomPad: 0),
                          ),
                          // Chess board stage
                          Expanded(
                            child: BoardStage(
                              appModel: appModel,
                              chessGame: chessGame!,
                              boardSize: boardSize,
                              topReservedHeight: _kTopBannerSlotHeight,
                            ),
                          ),
                          // Action buttons panel
                          ActionButtonsPanel(
                            appModel,
                            onNewGame: () {
                              unawaited(_startMatchFromCurrentMode());
                            },
                          ),
                          // SizedBox(height: bottomPad + 6),
                        ],
                      );
                    },
                  ),
                ),
                if (!_isReady &&
                    !widget.isResuming &&
                    !appModel.isSpectatorMode)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.20),
                      child: Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_showPostGameOptions) ...[
                                  GestureDetector(
                                    onTap: _onReadyPressed,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 28,
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(26),
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFFD79D49),
                                            Color(0xFF9A6330),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFFF3CE82)
                                              .withValues(alpha: 0.55),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.28),
                                            blurRadius: 14,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        l.restartConfirm,
                                        style: const TextStyle(
                                          color: Color(0xFF4B2B15),
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  Text(
                                    '$_readySeconds',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 50,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'Jura',
                                      shadows: [
                                        Shadow(
                                          color: Color(0xFFF5E0BC),
                                          blurRadius: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 0),
                                  GestureDetector(
                                    onTap: _onReadyPressed,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 28,
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(26),
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFFD79D49),
                                            Color(0xFF9A6330),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFFF3CE82)
                                              .withValues(alpha: 0.55),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.28),
                                            blurRadius: 14,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: const Text(
                                        'Sẵn sàng',
                                        style: TextStyle(
                                          color: Color(0xFF4B2B15),
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Nút rời bàn — góc trái trên cùng
                          Positioned(
                            top: 0,
                            left: 0,
                            child: SafeArea(
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(top: 8, left: 12),
                                child: GestureDetector(
                                  onTap: _onExitAfterGame,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3A291F)
                                          .withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFF3CE82)
                                            .withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.arrow_left,
                                      color: Color(0xFFF2D3A2),
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_isRecreatingMatch)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x55000000),
                      child: Center(
                        child: CupertinoActivityIndicator(radius: 14),
                      ),
                    ),
                  ),
                SafeArea(
                  child: Stack(
                    children: [
                      Positioned(
                        top: _kTopBannerSlotHeight + 16,
                        left: 10,
                        child: Builder(builder: (_) {
                          final isSpectator = appModel.isSpectatorMode;
                          final profile = isSpectator
                              ? appModel.spectatorWhiteProfile
                              : appModel.opponentProfile;
                          final opponentName = isAI
                              ? l.botLevel(diff)
                              : (profile?['username'] as String?)?.isNotEmpty ==
                                      true
                                  ? profile!['username'] as String
                                  : (!appModel.authService.isLoggedIn
                                      ? l.twoPlayer
                                      : (isSpectator ? 'White' : l.opponent));
                          final opponentElo = isAI
                              ? botElo
                              : (profile?['elo'] as num?)?.toInt() ?? botElo;
                          final opponentAvatar =
                              profile?['avatarUrl'] as String?;
                          final isOnlinePvP = appModel.isOnlineGameMode &&
                              !appModel.shouldRunLocalAiInOnlineVsAi;
                          final iAmBlack =
                              appModel.playerSide == Player.player2;
                          // Spectator: top = white player = player1TimeLeft
                          // Normal: top = opponent clock
                          final opponentClock = isSpectator
                              ? appModel.player1TimeLeft
                              : (isOnlinePvP && iAmBlack)
                                  ? appModel.player1TimeLeft
                                  : appModel.player2TimeLeft;
                          final opponentActive = isSpectator
                              ? (appModel.turn == Player.player1 &&
                                  !appModel.gameOver)
                              : isOnlinePvP
                                  ? (appModel.turn != appModel.playerSide &&
                                      !appModel.gameOver)
                                  : (appModel.isAIsTurn && !appModel.gameOver);
                          return MatchCornerProfile(
                            name: opponentName,
                            elo: opponentElo,
                            eloLabel: l.eloLabel(opponentElo),
                            totalTimeLeft: opponentClock,
                            showTotalTime: isOnlinePvP ||
                                appModel.timeLimit > 0 ||
                                isSpectator,
                            avatarUrl: opponentAvatar,
                            isActive: opponentActive,
                            mirror: false,
                            moveTimeLimitSeconds: isSpectator
                                ? appModel.timeLimit * 60
                                : appModel.moveTimeLimit,
                            moveTimeLeft: isSpectator
                                ? opponentClock
                                : appModel.moveTimeLeft,
                            onTap: () => _showOpponentProfile(
                                context, appModel, l, opponentElo),
                          );
                        }),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 0,
                        child: Builder(builder: (_) {
                          final isSpectator = appModel.isSpectatorMode;
                          final isOnlinePvP = appModel.isOnlineGameMode &&
                              !appModel.shouldRunLocalAiInOnlineVsAi;
                          // Spectator: bottom = black player
                          final blackProfile = appModel.spectatorBlackProfile;
                          final bottomName = isSpectator
                              ? ((blackProfile?['username'] as String?)
                                          ?.isNotEmpty ==
                                      true
                                  ? blackProfile!['username'] as String
                                  : 'Black')
                              : (!appModel.authService.isLoggedIn
                                  ? l.onePlayer
                                  : (appModel.authService.user?.username
                                              .isNotEmpty ==
                                          true
                                      ? appModel.authService.user!.username
                                      : l.youPlayer));
                          final bottomElo = isSpectator
                              ? ((blackProfile?['elo'] as num?)?.toInt() ??
                                  1200)
                              : (appModel.authService.user?.elo ?? 1200);
                          final bottomAvatar = isSpectator
                              ? (blackProfile?['avatarUrl'] as String?)
                              : appModel.authService.user?.avatarUrl;
                          // Spectator: bottom = black = player2TimeLeft
                          final bottomClock = (isOnlinePvP &&
                                  appModel.playerSide == Player.player2)
                              ? appModel.player2TimeLeft
                              : appModel.player1TimeLeft;
                          final bottomActive = isSpectator
                              ? (appModel.turn == Player.player2 &&
                                  !appModel.gameOver)
                              : isOnlinePvP
                                  ? (appModel.turn == appModel.playerSide &&
                                      !appModel.gameOver)
                                  : (!appModel.isAIsTurn && !appModel.gameOver);
                          return MatchCornerProfile(
                            name: bottomName,
                            elo: bottomElo,
                            eloLabel: l.eloLabel(bottomElo),
                            totalTimeLeft: isSpectator
                                ? appModel.player2TimeLeft
                                : bottomClock,
                            showTotalTime: isOnlinePvP ||
                                appModel.timeLimit > 0 ||
                                isSpectator,
                            avatarUrl: bottomAvatar,
                            isActive: bottomActive,
                            mirror: true,
                            moveTimeLimitSeconds: isSpectator
                                ? appModel.timeLimit * 60
                                : appModel.moveTimeLimit,
                            moveTimeLeft: isSpectator
                                ? appModel.player2TimeLeft
                                : appModel.moveTimeLeft,
                            dockToMenu: true,
                            onTap: () => showCapturedPiecesSheet(
                              context,
                              appModel,
                              Player.player1,
                              l.capturedYourPieces,
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    shouldLoop: false,
                    colors: [
                      theme.lightTile,
                      theme.darkTile,
                      theme.moveHint,
                      theme.latestMove,
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
