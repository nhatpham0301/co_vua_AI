import 'package:confetti/confetti.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/chess_game.dart';
import '../model/app_model.dart';
import '../model/app_themes.dart';
import 'components/chess_view/chess_board_widget.dart';
import 'components/chess_view/promotion_dialog.dart';
import 'components/main_menu_view/mm_palette.dart';
import 'components/shared/rounded_button.dart';
import 'settings_view.dart';

// ── Difficulty-to-rank mapping (index 0 unused) ───────────────────────────────
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

  ChessView(this.appModel, {this.isResuming = false});

  @override
  _ChessViewState createState() => _ChessViewState(appModel);
}

class _ChessViewState extends State<ChessView> with WidgetsBindingObserver {
  AppModel appModel;
  ChessGame? chessGame;
  late ConfettiController _confettiController;

  // Tracks the previous gameOver state to detect the transition false → true
  // and trigger the post-game ad exactly once.
  bool _wasGameOver = false;
  bool _gameEndAdScheduled = false;

  _ChessViewState(this.appModel);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 5));

    // Defer game initialization to after the page transition completes.
    // This prevents heavy work (sprite creation, board setup) from
    // blocking the navigation animation.
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
      // Defer notifying listeners if needed to let the flame engine setup
      Future.delayed(Duration(milliseconds: 50), () {
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

  @override
  Widget build(BuildContext context) {
    return Consumer<AppModel>(
      builder: (context, appModel, child) {
        final theme = appModel.theme;
        if (appModel.gameController == null || chessGame == null) {
          return Scaffold(
            backgroundColor: bgDark,
            body: Center(
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

        // Detect transition: game just ended → schedule ad after 1 second
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
            body: Stack(
              fit: StackFit.expand,
              children: [
                // ── Gradient background ───────────────────────────────
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [bgMid, bgDark],
                    ),
                  ),
                ),
                // ── Main layout ───────────────────────────────────────
                SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _GameAppBar(rankName: rankName, appModel: appModel),
                      _PlayerInfoRow(
                        name: isAI ? 'Bot Lv.$diff' : 'Đối thủ',
                        subtitle: '$botElo ELO',
                        timeLeft: appModel.player2TimeLeft,
                        isActive: appModel.isAIsTurn && !appModel.gameOver,
                        hasTimer: appModel.timeLimit != 0,
                        isBot: isAI,
                      ),
                      const SizedBox(height: 6),
                      Center(child: ChessBoardWidget(appModel, chessGame!)),
                      const SizedBox(height: 6),
                      Center(child: _TurnBar(appModel)),
                      const SizedBox(height: 6),
                      _PlayerInfoRow(
                        name: 'Bạn (Vietnam)',
                        subtitle: '2145 ELO',
                        timeLeft: appModel.player1TimeLeft,
                        isActive: !appModel.isAIsTurn && !appModel.gameOver,
                        hasTimer: appModel.timeLimit != 0,
                        isBot: false,
                      ),
                      const SizedBox(height: 10),
                      _ActionButtons(appModel),
                      const SizedBox(height: 10),
                      _BottomButtons(appModel, onNewGame: _initFlameGame),
                      SizedBox(height: bottomPad + 8),
                    ],
                  ),
                ),
                // ── Confetti ──────────────────────────────────────────
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

  void _showPromotionDialog(AppModel appModel) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return PromotionDialog(appModel);
      },
    );
  }

  void _showCheckAlert(BuildContext context, AppModel appModel) {
    final isPlayerChecked =
        appModel.turn == appModel.playerSide || !appModel.playingWithAI;
    final message = isPlayerChecked
        ? 'Bạn đang bị chiếu tướng!'
        : 'Đối thủ đang bị chiếu tướng!';

    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('⚠️ Chiếu Tướng'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

void showExitDialog(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    barrierDismissible: true,
    barrierLabel: '',
    transitionDuration: Duration(milliseconds: 250),
    pageBuilder: (dialogContext, anim1, anim2) {
      return Selector<AppModel, AppTheme>(
        selector: (_, m) => m.theme,
        builder: (dialogContext, theme, child) => Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(maxWidth: 340),
              padding: EdgeInsets.all(30),
              decoration: BoxDecoration(
                gradient: theme.background,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Leave Game?',
                    style: TextStyle(
                      fontSize: 32,
                      fontFamily: 'Jura',
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 15),
                  Text(
                    'Would you like to save your progress?',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Jura',
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 15),
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
                  SizedBox(height: 15),
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
                  SizedBox(height: 15),
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

// ── App header bar ─────────────────────────────────────────────────────────────
class _GameAppBar extends StatelessWidget {
  final String rankName;
  final AppModel appModel;
  const _GameAppBar({required this.rankName, required this.appModel});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt_rounded, color: primary, size: 22),
          const SizedBox(width: 6),
          Text(
            rankName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          _IconBtn(
            icon: CupertinoIcons.settings,
            onTap: () => Navigator.push(
              context,
              CupertinoPageRoute(builder: (_) => SettingsView()),
            ),
          ),
          const SizedBox(width: 4),
          _IconBtn(icon: CupertinoIcons.ellipsis_vertical, onTap: () {}),
        ],
      ),
    );
  }
}

// ── Player info row ───────────────────────────────────────────────────────────
class _PlayerInfoRow extends StatelessWidget {
  final String name;
  final String subtitle;
  final ValueListenable<Duration> timeLeft;
  final bool isActive;
  final bool hasTimer;
  final bool isBot;

  const _PlayerInfoRow({
    required this.name,
    required this.subtitle,
    required this.timeLeft,
    required this.isActive,
    required this.hasTimer,
    required this.isBot,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Row(
        children: [
          // Avatar with active glow border
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgCard,
              border: Border.all(
                color: isActive
                    ? primary.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.12),
                width: 2,
              ),
            ),
            child: Icon(
              isBot ? Icons.smart_toy_rounded : Icons.person_rounded,
              color: isBot ? primaryLight : Colors.white70,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          // Name + ELO
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.emoji_events_rounded, color: goldMid, size: 13),
                    const SizedBox(width: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Timer pill
          if (hasTimer)
            ValueListenableBuilder<Duration>(
              valueListenable: timeLeft,
              builder: (_, duration, __) =>
                  _TimerPill(duration: duration, isActive: isActive),
            ),
        ],
      ),
    );
  }
}

// ── Timer pill ─────────────────────────────────────────────────────────────────
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? primary.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? primary.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.clock,
            size: 13,
            color: isActive ? primary : Colors.white38,
          ),
          const SizedBox(width: 4),
          Text(
            _fmt(duration),
            style: TextStyle(
              color: isActive ? primaryLight : Colors.white60,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Turn indicator bar ────────────────────────────────────────────────────────
class _TurnBar extends StatelessWidget {
  final AppModel appModel;
  const _TurnBar(this.appModel);

  @override
  Widget build(BuildContext context) {
    return Selector<AppModel, ({bool isAI, bool over, bool draw})>(
      selector: (_, m) =>
          (isAI: m.isAIsTurn, over: m.gameOver, draw: m.stalemate),
      builder: (_, s, __) {
        final String label;
        final Color dotColor;
        if (s.over) {
          if (s.draw) {
            label = 'Hòa!';
            dotColor = Colors.orange;
          } else if (s.isAI) {
            label = 'Bạn thắng! 🎉';
            dotColor = Colors.greenAccent;
          } else {
            label = 'Bạn thua!';
            dotColor = Colors.redAccent;
          }
        } else {
          label = s.isAI ? 'AI đang suy nghĩ...' : 'LƯỢT CỦA BẠN';
          dotColor = s.isAI ? Colors.white38 : primary;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!s.over && s.isAI)
                const CupertinoActivityIndicator(
                    radius: 6, color: Colors.white54)
              else
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    boxShadow: [
                      BoxShadow(
                        color: dotColor.withValues(alpha: 0.5),
                        blurRadius: 4,
                      )
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Action buttons row ────────────────────────────────────────────────────────
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
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
              icon: Icons.lightbulb_outline_rounded,
              label: 'HINT',
              enabled: appModel.showHints,
              onTap: () async {
                await appModel.prefs.setShowHints(!appModel.showHints);
                appModel.update();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionBtn(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'CHAT',
              enabled: false,
              onTap: null,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: enabled ? 0.1 : 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: enabled ? 0.15 : 0.06),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: enabled ? Colors.white : Colors.white30,
              size: 20,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white70 : Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom buttons ────────────────────────────────────────────────────────────
class _BottomButtons extends StatelessWidget {
  final AppModel appModel;
  final VoidCallback onNewGame;
  const _BottomButtons(this.appModel, {required this.onNewGame});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: _BottomBtn(
              icon: Icons.replay_rounded,
              label: 'Chơi lại',
              isPrimary: true,
              onTap: () => _showRestartDialog(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _BottomBtn(
              icon: Icons.exit_to_app_rounded,
              label: 'Rời bàn',
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
    showCupertinoDialog(
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
                // Game chưa kết thúc: đánh dấu bỏ dở → hiện ad → bắt đầu ván mới.
                appModel.adService.markGameAbandoned();
                appModel.adService.showAdBeforeGame(
                  () {
                    appModel.newGame(notify: false);
                    onNewGame();
                  },
                  context: context,
                );
              } else {
                // Game đã kết thúc: ad đã hiện tự động sau 1s → bắt đầu trực tiếp.
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [Color(0xFF0082C8), Color(0xFF0050A0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isPrimary ? null : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPrimary
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small icon button helper ──────────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, color: Colors.white70, size: 16),
      ),
    );
  }
}
