import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/chess_game.dart';
import '../logic/chess_piece.dart';
import '../logic/shared_functions.dart';
import '../model/app_model.dart';
import '../model/app_themes.dart';
import '../model/player.dart';
import 'components/chess_view/chess_board_widget.dart';
import 'components/chess_view/promotion_dialog.dart';
import 'components/main_menu_view/mm_palette.dart';
import 'components/shared/rounded_button.dart';
import 'settings_view.dart';

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

  void _showCapturedPiecesSheet(
    BuildContext context,
    AppModel appModel,
    Player player,
    String title,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (_) => _CapturedPiecesSheet(
        appModel: appModel,
        player: player,
        title: title,
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
        final bottomPad = MediaQuery.of(context).padding.bottom;

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
                            _GameAppBar(rankName: rankName, appModel: appModel),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                              child: _PlayerInfoRow(
                                name: isAI ? 'BOT LV.$diff' : 'ĐỐI THỦ',
                                subtitle: '$botElo ELO',
                                timeLeft: appModel.player2TimeLeft,
                                isActive:
                                    appModel.isAIsTurn && !appModel.gameOver,
                                hasTimer: appModel.timeLimit != 0,
                                isBot: isAI,
                                materialDelta: appModel
                                    .materialAdvantageFor(Player.player2),
                                onTapPlayer: () => _showCapturedPiecesSheet(
                                  context,
                                  appModel,
                                  Player.player2,
                                  isAI
                                      ? 'Quân Bot đã mất'
                                      : 'Quân đối thủ đã mất',
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                child: _BoardStage(
                                  appModel: appModel,
                                  chessGame: chessGame!,
                                  boardSize: boardSize,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                              child: _PlayerInfoRow(
                                name: 'BẠN',
                                subtitle: '2145 ELO',
                                timeLeft: appModel.player1TimeLeft,
                                isActive:
                                    !appModel.isAIsTurn && !appModel.gameOver,
                                hasTimer: appModel.timeLimit != 0,
                                isBot: false,
                                materialDelta: appModel
                                    .materialAdvantageFor(Player.player1),
                                onTapPlayer: () => _showCapturedPiecesSheet(
                                  context,
                                  appModel,
                                  Player.player1,
                                  'Quân của bạn đã mất',
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _ActionButtons(appModel),
                            const SizedBox(height: 10),
                            _BottomButtons(appModel, onNewGame: _initFlameGame),
                            SizedBox(height: bottomPad + 8),
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
}

void showExitDialog(BuildContext context) {
  showGeneralDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    barrierDismissible: true,
    barrierLabel: '',
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (dialogContext, anim1, anim2) {
      return Selector<AppModel, AppTheme>(
        selector: (_, model) => model.theme,
        builder: (dialogContext, theme, child) => Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 340),
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                gradient: theme.background,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Leave Game?',
                    style: TextStyle(
                      fontSize: 32,
                      fontFamily: 'Jura',
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Would you like to save your progress?',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Jura',
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  Consumer<AppModel>(
                    builder: (context, appModel, child) => RoundedButton(
                      'Save & Exit',
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        appModel.saveAndExitChessView();
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  const SizedBox(height: 15),
                  Consumer<AppModel>(
                    builder: (context, appModel, child) => RoundedButton(
                      'Exit',
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        appModel.exitChessView();
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  const SizedBox(height: 15),
                  RoundedButton(
                    'Cancel',
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return Transform.scale(
        scale: 0.95 + 0.05 * anim1.value,
        child: FadeTransition(
          opacity: anim1,
          child: child,
        ),
      );
    },
  );
}

class _BoardStage extends StatelessWidget {
  final AppModel appModel;
  final ChessGame chessGame;
  final double boardSize;

  const _BoardStage({
    required this.appModel,
    required this.chessGame,
    required this.boardSize,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const boardFramePadding = 12.0;
        const stageInnerPadding = 10.0;
        const turnBarSpacing = 12.0;
        const turnBarEstimatedHeight = 44.0;

        final maxBoardWidth = constraints.maxWidth - (stageInnerPadding * 2);
        final maxBoardHeight = constraints.maxHeight -
            (stageInnerPadding * 2) -
            turnBarSpacing -
            turnBarEstimatedHeight -
            (boardFramePadding * 2);

        final double resolvedBoardSize = math
            .max(
              220.0,
              math.min(boardSize, math.min(maxBoardWidth, maxBoardHeight)),
            )
            .toDouble();

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x664A5D23), Color(0x22242B34), Color(0x1110161D)],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(stageInnerPadding),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(boardFramePadding),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xCC4A3B22), Color(0xCC232A33)],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF0A0D11).withValues(alpha: 0.55),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ChessBoardWidget(
                        appModel,
                        chessGame,
                        boardSize: resolvedBoardSize,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: turnBarSpacing),
                _TurnBar(appModel),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GameAppBar extends StatelessWidget {
  final String rankName;
  final AppModel appModel;

  const _GameAppBar({required this.rankName, required this.appModel});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xAA32452B), Color(0xAA1A2128)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF355B3D).withValues(alpha: 0.32),
            ),
            child: const Icon(Icons.shield_rounded, color: goldMid, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MATCH ARENA',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
                Text(
                  rankName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          _IconBtn(
            icon: CupertinoIcons.settings,
            onTap: () => Navigator.push(
              context,
              CupertinoPageRoute(builder: (_) => SettingsView()),
            ),
          ),
          const SizedBox(width: 6),
          _IconBtn(icon: CupertinoIcons.ellipsis_vertical, onTap: () {}),
        ],
      ),
    );
  }
}

class _PlayerInfoRow extends StatelessWidget {
  final String name;
  final String subtitle;
  final ValueListenable<Duration> timeLeft;
  final bool isActive;
  final bool hasTimer;
  final bool isBot;
  final int materialDelta;
  final VoidCallback onTapPlayer;

  const _PlayerInfoRow({
    required this.name,
    required this.subtitle,
    required this.timeLeft,
    required this.isActive,
    required this.hasTimer,
    required this.isBot,
    required this.materialDelta,
    required this.onTapPlayer,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isActive ? const Color(0xFF8FCB81) : Colors.white54;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF20272F).withValues(alpha: 0.88),
            const Color(0xFF14191F).withValues(alpha: 0.92),
          ],
        ),
        border: Border.all(
          color: isActive
              ? const Color(0xFF769F67).withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.07),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF324B35)
                      .withValues(alpha: isActive ? 0.9 : 0.6),
                  const Color(0xFF1B232B),
                ],
              ),
              border: Border.all(
                color: isActive
                    ? const Color(0xFF9AD67D).withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.12),
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: isActive ? 0.25 : 0.08),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Icon(
              isBot ? Icons.smart_toy_rounded : Icons.person_rounded,
              color: isBot ? primaryLight : Colors.white70,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTapPlayer,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            CupertinoIcons.chevron_up_chevron_down,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.emoji_events_rounded,
                            color: goldMid.withValues(alpha: 0.9),
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.56),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _MaterialDeltaPill(delta: materialDelta),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (hasTimer)
            ValueListenableBuilder<Duration>(
              valueListenable: timeLeft,
              builder: (_, duration, __) {
                return _TimerPill(duration: duration, isActive: isActive);
              },
            ),
        ],
      ),
    );
  }
}

class _TimerPill extends StatelessWidget {
  final Duration duration;
  final bool isActive;

  const _TimerPill({required this.duration, required this.isActive});

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isActive
              ? [
                  const Color(0xFF3D6F49).withValues(alpha: 0.95),
                  const Color(0xFF22382C),
                ]
              : [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.03),
                ],
        ),
        border: Border.all(
          color: isActive
              ? const Color(0xFF9BC885).withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.12),
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF7CC36A).withValues(alpha: 0.16),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.clock_fill,
            size: 12,
            color: isActive ? primaryLight : Colors.white38,
          ),
          const SizedBox(width: 5),
          Text(
            _fmt(duration),
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white60,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _TurnBar extends StatelessWidget {
  final AppModel appModel;

  const _TurnBar(this.appModel);

  @override
  Widget build(BuildContext context) {
    return Selector<AppModel, ({bool isAI, bool over, bool draw})>(
      selector: (_, model) => (
        isAI: model.isAIsTurn,
        over: model.gameOver,
        draw: model.stalemate,
      ),
      builder: (_, state, __) {
        final String label;
        final Color dotColor;

        if (state.over) {
          if (state.draw) {
            label = 'HÒA';
            dotColor = Colors.orangeAccent;
          } else if (state.isAI) {
            label = 'BẠN THẮNG';
            dotColor = Colors.greenAccent;
          } else {
            label = 'BẠN THUA';
            dotColor = Colors.redAccent;
          }
        } else {
          label = state.isAI ? 'AI ĐANG SUY NGHĨ...' : 'LƯỢT CỦA BẠN';
          dotColor = state.isAI ? Colors.white38 : primary;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.black.withValues(alpha: 0.3),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!state.over && state.isAI)
                const CupertinoActivityIndicator(
                  radius: 6,
                  color: Colors.white54,
                )
              else
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    boxShadow: [
                      BoxShadow(
                        color: dotColor.withValues(alpha: 0.45),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 9),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final AppModel appModel;

  const _ActionButtons(this.appModel);

  bool get _undoOk =>
      appModel.allowUndoRedo &&
      appModel.gameController != null &&
      appModel.gameController!.board.moveStack.isNotEmpty &&
      (!appModel.playingWithAI ||
          appModel.gameController!.board.moveStack.length > 1);

  bool get _redoOk =>
      appModel.allowUndoRedo &&
      appModel.gameController != null &&
      appModel.gameController!.board.redoStack.isNotEmpty &&
      (!appModel.playingWithAI ||
          appModel.gameController!.board.redoStack.length > 1);

  void _undo() {
    final gc = appModel.gameController;
    if (gc == null) return;
    if (appModel.playingWithAI) {
      gc.undoTwoMoves();
    } else {
      gc.undoMove();
    }
  }

  void _redo() {
    final gc = appModel.gameController;
    if (gc == null) return;
    if (appModel.playingWithAI) {
      gc.redoTwoMoves();
    } else {
      gc.redoMove();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x552F3D2A), Color(0x55161B22)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ActionBtn(
              icon: Icons.undo_rounded,
              label: 'UNDO',
              enabled: _undoOk,
              onTap: _undoOk ? _undo : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionBtn(
              icon: Icons.redo_rounded,
              label: 'REDO',
              enabled: _redoOk,
              onTap: _redoOk ? _redo : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionBtn(
              icon: Icons.visibility_rounded,
              label: appModel.showHints ? 'HINT ON' : 'HINT OFF',
              enabled: true,
              onTap: () async {
                await appModel.prefs.setShowHints(!appModel.showHints);
                appModel.update();
              },
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: _ActionBtn(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'CHAT',
              enabled: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = enabled ? Colors.white : Colors.white30;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        splashColor: Colors.white.withValues(alpha: 0.08),
        highlightColor: Colors.white.withValues(alpha: 0.04),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: enabled
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF314530), Color(0xFF1C2428)],
                  )
                : null,
            color: enabled ? null : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: enabled
                  ? const Color(0xFF8EA770).withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.05),
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: textColor, size: 19),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomButtons extends StatelessWidget {
  final AppModel appModel;
  final VoidCallback onNewGame;

  const _BottomButtons(this.appModel, {required this.onNewGame});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: _BottomBtn(
              icon: Icons.replay_rounded,
              label: 'CHƠI LẠI',
              isPrimary: true,
              onTap: () => _showRestartDialog(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _BottomBtn(
              icon: Icons.exit_to_app_rounded,
              label: 'RỜI BÀN',
              isPrimary: false,
              onTap: () {
                if (appModel.gameOver) {
                  appModel.exitChessView();
                  Navigator.pop(context);
                } else {
                  showExitDialog(context);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showRestartDialog(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Chơi lại?'),
        content: const Text('Bạn có chắc muốn bắt đầu ván mới?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              if (!appModel.gameOver) {
                appModel.adService.markGameAbandoned();
                appModel.adService.showAdBeforeGame(
                  () {
                    appModel.newGame(notify: false);
                    onNewGame();
                  },
                  context: context,
                );
              } else {
                appModel.newGame(notify: false);
                onNewGame();
              }
            },
            child: const Text('Chơi lại'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
  }
}

class _BottomBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _BottomBtn({
    required this.icon,
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: Colors.white.withValues(alpha: 0.08),
        highlightColor: Colors.white.withValues(alpha: 0.04),
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: isPrimary
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF7A5B2B), Color(0xFF405E34)],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF283039), Color(0xFF171C23)],
                  ),
            border: Border.all(
              color: isPrimary
                  ? const Color(0xFFD0BA7A).withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 19),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x553C4A37), Color(0x33161B22)],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Icon(icon, color: Colors.white70, size: 17),
        ),
      ),
    );
  }
}

class _CapturedPiecesSheet extends StatelessWidget {
  final AppModel appModel;
  final Player player;
  final String title;

  const _CapturedPiecesSheet({
    required this.appModel,
    required this.player,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final lostPieces = player == Player.player1
        ? appModel.capturedWhite
        : appModel.capturedBlack;
    final groupedPieces = _groupCapturedPieces(lostPieces);
    final lead = appModel.materialAdvantageFor(Player.player1);
    final leadLabel = _materialLeadLabel(appModel, lead);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: EdgeInsets.fromLTRB(18, 12, 18, 14 + bottomInset),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xEE252C35), Color(0xEE14181F)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            leadLabel,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          if (groupedPieces.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white.withValues(alpha: 0.04),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: const Text(
                'Chưa mất quân nào.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: groupedPieces.entries.map((entry) {
                return _CapturedPieceBadge(
                  appModel: appModel,
                  pieceType: entry.key,
                  lostPlayer: player,
                  count: entry.value,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _CapturedPieceBadge extends StatelessWidget {
  final AppModel appModel;
  final ChessPieceType pieceType;
  final Player lostPlayer;
  final int count;

  const _CapturedPieceBadge({
    required this.appModel,
    required this.pieceType,
    required this.lostPlayer,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final color = lostPlayer == Player.player1 ? 'white' : 'black';
    final typeName = pieceTypeToString(pieceType);
    final assetPath =
        'assets/images/pieces/${formatPieceTheme(appModel.pieceTheme)}/${typeName}_$color.png';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x553F4F3B), Color(0x33222A31)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.extension_rounded,
                color: Colors.white38,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'x$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialDeltaPill extends StatelessWidget {
  final int delta;

  const _MaterialDeltaPill({required this.delta});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String text;

    if (delta > 0) {
      color = const Color(0xFF84C46A);
      text = '+$delta';
    } else if (delta < 0) {
      color = const Color(0xFFE58B6B);
      text = '$delta';
    } else {
      color = Colors.white54;
      text = '±0';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

Map<ChessPieceType, int> _groupCapturedPieces(List<ChessPieceType> pieces) {
  final grouped = <ChessPieceType, int>{};
  for (final piece in pieces) {
    grouped[piece] = (grouped[piece] ?? 0) + 1;
  }

  final entries = grouped.entries.toList()
    ..sort(
      (left, right) => _capturedPieceScore(right.key)
          .compareTo(_capturedPieceScore(left.key)),
    );

  return Map<ChessPieceType, int>.fromEntries(entries);
}

String _materialLeadLabel(AppModel appModel, int whiteLead) {
  if (whiteLead == 0) {
    return 'Cân bằng vật chất';
  }

  final leader = whiteLead > 0 ? Player.player1 : Player.player2;
  final leaderLabel = appModel.playingWithAI
      ? (leader == Player.player1 ? 'Bạn' : 'Bot')
      : (leader == Player.player1 ? 'Trắng' : 'Đen');
  return '$leaderLabel đang hơn +${whiteLead.abs()}';
}

int _capturedPieceScore(ChessPieceType type) {
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
