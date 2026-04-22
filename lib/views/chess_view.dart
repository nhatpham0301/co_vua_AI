import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../logic/chess_game.dart';
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

  _ChessViewState(this.appModel);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 5));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isResuming) {
        appModel.restoreGameState().then((_) => _initFlameGame());
      } else {
        appModel.newGame(notify: false);
        _initFlameGame();
        // When waiting for opponent, pause timers and show waiting dialog.
        // When not waiting, start the ready countdown immediately.
        if (appModel.isWaitingForOpponent) {
          appModel.timerService.pause();
          appModel.gameController?.cancelAIMove();
        } else {
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

    appModel.timerService.pause();
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
        appModel.exitChessView();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    });
    setState(() {});
  }

  void _onReadyPressed() {
    if (_isReady) return;
    _readyTimer?.cancel();
    _readyTimer = null;
    setState(() => _isReady = true);

    // For online PvP the server drives time via game:clock — keep local timer off.
    if (!(appModel.isOnlineGameMode &&
        !appModel.shouldRunLocalAiInOnlineVsAi)) {
      appModel.timerService.resume();
    }
    if (appModel.isAIsTurn && !appModel.gameOver) {
      appModel.gameController?.triggerAIMove();
    }

    // Show waiting dialog if in PvP waiting state
    _checkAndShowWaitingDialog();
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
        appModel.saveGameState();
        appModel.timerService.pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!appModel.gameOver) {
        // Online PvP: server is authoritative for time — do not restart local timer.
        if (!(appModel.isOnlineGameMode &&
            !appModel.shouldRunLocalAiInOnlineVsAi)) {
          appModel.timerService.resume();
        }
      }
    }
  }

  double _boardSizeFor(BoxConstraints constraints) {
    final maxBoardWidth = constraints.maxWidth - 34;
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

        if (appModel.gameOver && !_wasGameOver && !_gameEndAdScheduled) {
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
        }

        if (appModel.gameOver && appModel.userWon) {
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
              showExitDialog(context);
            }
          },
          child: Scaffold(
            backgroundColor: bgDark,
            body: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [bgMid, bgDark],
                    ),
                  ),
                ),
                const BoardBackground(),
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
                            onNewGame: _initFlameGame,
                          ),
                          // SizedBox(height: bottomPad + 6),
                        ],
                      );
                    },
                  ),
                ),
                if (!_isReady && !widget.isResuming)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.20),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                                      color:
                                          Colors.black.withValues(alpha: 0.28),
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
                        ),
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
                          final profile = appModel.opponentProfile;
                          final opponentName = isAI
                              ? l.botLevel(diff)
                              : (profile?['username'] as String?)?.isNotEmpty ==
                                      true
                                  ? profile!['username'] as String
                                  : (!appModel.authService.isLoggedIn
                                      ? l.twoPlayer
                                      : l.opponent);
                          final opponentElo = isAI
                              ? botElo
                              : (profile?['elo'] as num?)?.toInt() ?? botElo;
                          final opponentAvatar =
                              profile?['avatarUrl'] as String?;
                          return MatchCornerProfile(
                            name: opponentName,
                            elo: opponentElo,
                            eloLabel: l.eloLabel(opponentElo),
                            totalTimeLeft: appModel.player2TimeLeft,
                            showTotalTime: appModel.timeLimit > 0,
                            avatarUrl: opponentAvatar,
                            isActive: appModel.isAIsTurn && !appModel.gameOver,
                            mirror: false,
                            moveTimeLimitSeconds: appModel.moveTimeLimit,
                            moveTimeLeft: appModel.moveTimeLeft,
                            onTap: () => _showOpponentProfile(
                                context, appModel, l, opponentElo),
                          );
                        }),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 0,
                        child: MatchCornerProfile(
                          name: !appModel.authService.isLoggedIn
                              ? l.onePlayer
                              : (appModel.authService.user?.username
                                          .isNotEmpty ==
                                      true
                                  ? appModel.authService.user!.username
                                  : l.youPlayer),
                          elo: appModel.authService.user?.elo ?? 1200,
                          eloLabel: l
                              .eloLabel(appModel.authService.user?.elo ?? 1200),
                          totalTimeLeft: appModel.player1TimeLeft,
                          showTotalTime: appModel.timeLimit > 0,
                          avatarUrl: appModel.authService.user?.avatarUrl,
                          isActive: !appModel.isAIsTurn && !appModel.gameOver,
                          mirror: true,
                          moveTimeLimitSeconds: appModel.moveTimeLimit,
                          moveTimeLeft: appModel.moveTimeLeft,
                          dockToMenu: true,
                          onTap: () => showCapturedPiecesSheet(
                            context,
                            appModel,
                            Player.player1,
                            l.capturedYourPieces,
                          ),
                        ),
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
