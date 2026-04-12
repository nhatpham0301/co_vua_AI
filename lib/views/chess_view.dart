import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/chess_game.dart';
import '../model/app_model.dart';
import '../model/player.dart';
import 'components/chess_view/board_stage.dart';
import 'components/chess_view/chess_actions.dart';
import 'components/chess_view/chess_dialogs.dart';
import 'components/chess_view/game_app_bar.dart';
import 'components/chess_view/players_header_row.dart';
import 'components/chess_view/promotion_dialog.dart';
import 'components/main_menu_view/mm_palette.dart';

const _kRankNames = [
  '',
  'Tập sự',
  'Trung cấp',
  'Cao cấp',
  'Chuyên gia',
  'Đại kiện tướng',
];

const _kRankElos = [0, 800, 1100, 1400, 1650, 2100];

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
      }
    });
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
        appModel.timerService.resume();
      }
    }
  }

  double _boardSizeFor(BoxConstraints constraints) {
    final maxBoardWidth = constraints.maxWidth - 24;
    final preferredHeight = constraints.maxHeight * 0.68;
    return math.max(280, math.min(maxBoardWidth, preferredHeight));
  }

  void _showPromotionDialog(AppModel appModel) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => PromotionDialog(appModel),
    );
  }

  void _showCheckAlert(BuildContext context, AppModel appModel) {
    final isPlayerChecked =
        appModel.turn == appModel.playerSide || !appModel.playingWithAI;
    final message = isPlayerChecked
        ? 'Bạn đang bị chiếu tướng!'
        : 'Đối thủ đang bị chiếu tướng!';

    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('⚠️ Chiếu Tướng'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
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

        if (appModel.promotionRequested) {
          appModel.promotionRequested = false;
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _showPromotionDialog(appModel));
        }

        if (appModel.checkAlert && !appModel.gameOver) {
          appModel.checkAlert = false;
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _showCheckAlert(context, appModel));
        }

        if (appModel.gameOver && !_wasGameOver && !_gameEndAdScheduled) {
          _wasGameOver = true;
          _gameEndAdScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(seconds: 1), () {
              if (!mounted) return;
              _gameEndAdScheduled = false;
              appModel.adService.showGameEndAd(context);
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

        final diff = appModel.aiDifficulty.clamp(1, 5);
        final rankName = _kRankNames[diff];
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
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1C241D),
                    Color(0xFF111721),
                    Color(0xFF080B10),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.15),
                          radius: 1.0,
                          colors: [
                            const Color(0xFF3A5A40).withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                        ),
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
                            // AppBar with rank and settings button
                            GameAppBar(rankName: rankName, appModel: appModel),
                            // Players info row
                            _playerRow(isAI: isAI, diff: diff, botElo: botElo),
                            // Chess board stage
                            Expanded(
                              child: BoardStage(
                                appModel: appModel,
                                chessGame: chessGame!,
                                boardSize: boardSize,
                              ),
                            ),
                            const SizedBox(height: 8),
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
          ),
        );
      },
    );
  }

  Widget _playerRow(
      {required bool isAI, required int diff, required int botElo}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: PlayersHeaderRow(
        isAI: isAI,
        diff: diff,
        botElo: botElo,
        gameOver: appModel.gameOver,
        isAIsTurn: appModel.isAIsTurn,
        timeLimitMinutes: appModel.timeLimit,
        player1MaterialDelta: appModel.materialAdvantageFor(Player.player1),
        player2MaterialDelta: appModel.materialAdvantageFor(Player.player2),
        player1TimeLeft: appModel.player1TimeLeft,
        player2TimeLeft: appModel.player2TimeLeft,
        onTapPlayer1: () => showCapturedPiecesSheet(
          context,
          appModel,
          Player.player1,
          'Quân của bạn đã mất',
        ),
        onTapPlayer2: () => showCapturedPiecesSheet(
          context,
          appModel,
          Player.player2,
          isAI ? 'Quân Bot đã mất' : 'Quân đối thủ đã mất',
        ),
      ),
    );
  }
}
