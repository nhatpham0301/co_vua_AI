import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/app_model.dart';
import '../shared/app_dialog.dart';
import 'chess_dialogs.dart';

class ActionButtonsPanel extends StatelessWidget {
  final AppModel appModel;
  final VoidCallback onNewGame;

  const ActionButtonsPanel(
    this.appModel, {
    super.key,
    required this.onNewGame,
  });

  bool get _undoOk =>
      appModel.allowUndoRedo &&
      appModel.gameController != null &&
      appModel.gameController!.board.moveStack.isNotEmpty &&
      (!appModel.usePairUndoRedo ||
          appModel.gameController!.board.moveStack.length > 1);

  bool get _redoOk =>
      appModel.allowUndoRedo &&
      appModel.gameController != null &&
      appModel.gameController!.board.redoStack.isNotEmpty &&
      (!appModel.usePairUndoRedo ||
          appModel.gameController!.board.redoStack.length > 1);

  void _undo() {
    final gc = appModel.gameController;
    if (gc == null) return;
    if (appModel.usePairUndoRedo) {
      gc.undoTwoMoves();
    } else {
      gc.undoMove();
    }
  }

  void _redo() {
    final gc = appModel.gameController;
    if (gc == null) return;
    if (appModel.usePairUndoRedo) {
      gc.redoTwoMoves();
    } else {
      gc.redoMove();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: _ActionBtn(
        icon: Icons.menu_rounded,
        enabled: true,
        tooltip: AppLocalizations.of(context)!.settings,
        onTap: () => _showQuickMenu(context),
      ),
    );
  }

  Future<void> _showQuickMenu(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final showUndoRedo = appModel.allowUndoRedo && !appModel.isOnlineGameMode;

    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'quick_menu',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, _, __) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF2C1C12), Color(0xFF130D09)],
                    ),
                    border: Border.all(
                      color: const Color(0xFFB06E2D).withValues(alpha: 0.85),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.30),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _MenuItem(
                        icon: Icons.logout_rounded,
                        label: l.exitBtn,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          if (appModel.gameOver) {
                            appModel.exitChessView();
                            Navigator.pop(context);
                          } else {
                            showExitDialog(context);
                          }
                        },
                      ),
                      _MenuItem(
                        icon: Icons.refresh_rounded,
                        label: l.newGameTitle,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _showRestartDialog(context, l);
                        },
                      ),
                      if (showUndoRedo)
                        _MenuItem(
                          icon: Icons.undo_rounded,
                          label: l.back,
                          enabled: _undoOk,
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _undo();
                          },
                        ),
                      if (showUndoRedo)
                        _MenuItem(
                          icon: Icons.redo_rounded,
                          label: l.redo,
                          enabled: _redoOk,
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _redo();
                          },
                        ),
                      _MenuItem(
                        icon: appModel.soundEnabled
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        label:
                            appModel.soundEnabled ? 'Tắt tiếng' : 'Bật tiếng',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          appModel.setSoundEnabled(!appModel.soundEnabled);
                          appModel.update();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.08),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  void _showRestartDialog(BuildContext context, AppLocalizations l) {
    showAppDialog<void>(
      context: context,
      title: l.newGameTitle,
      message: l.newGameConfirm,
      actions: [
        AppDialogAction(
          label: l.yes,
          isDestructive: true,
          onPressed: () {
            if (!appModel.gameOver) {
              appModel.adService.markGameAbandoned();
              appModel.adService.showAdBeforeGame(
                () {
                  appModel.newGame(notify: false);
                  onNewGame();
                },
                context: context,
              );
            } else if (appModel.adService.needsAd) {
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
        ),
        AppDialogAction(label: l.cancel),
      ],
    );
  }
}

class BottomButtonsPanel extends StatelessWidget {
  final AppModel appModel;
  final VoidCallback onNewGame;

  const BottomButtonsPanel(
    this.appModel, {
    super.key,
    required this.onNewGame,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: _BottomBtn(
              icon: Icons.replay_rounded,
              label: AppLocalizations.of(context)!.replayBtn,
              isPrimary: true,
              onTap: () => _showRestartDialog(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _BottomBtn(
              icon: Icons.exit_to_app_rounded,
              label: AppLocalizations.of(context)!.exitBtn,
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
    if (appModel.shouldLockReplayAfterEndAd) return;
    final l = AppLocalizations.of(context)!;
    showAppDialog<void>(
      context: context,
      title: l.restartTitle,
      message: l.newGameConfirm,
      actions: [
        AppDialogAction(
          label: l.restartConfirm,
          isDestructive: true,
          onPressed: () {
            if (!appModel.gameOver) {
              appModel.adService.markGameAbandoned();
              appModel.adService.showAdBeforeGame(
                () {
                  appModel.newGame(notify: false);
                  onNewGame();
                },
                context: context,
              );
            } else if (appModel.adService.needsAd) {
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
        ),
        AppDialogAction(label: l.cancel),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  // final String label;
  final bool enabled;
  final String? tooltip;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    // required this.label,
    required this.enabled,
    this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = enabled ? Colors.white : Colors.white30;

    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(28),
        splashColor: Colors.white.withValues(alpha: 0.08),
        highlightColor: Colors.white.withValues(alpha: 0.04),
        child: Ink(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: enabled
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF9A6330), Color(0xFF362113)],
                  )
                : null,
            color: enabled ? null : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: enabled
                  ? const Color(0xFFF0C06C).withValues(alpha: 0.72)
                  : Colors.white.withValues(alpha: 0.05),
              width: 1.4,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF1F130C).withValues(alpha: 0.55),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  icon,
                  key: ValueKey(icon),
                  color: textColor,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (tooltip == null || tooltip!.isEmpty) {
      return content;
    }

    return Tooltip(message: tooltip!, child: content);
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
                    colors: [Color(0xFFD79D49), Color(0xFF7A4B1F)],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF5A3923), Color(0xFF24160F)],
                  ),
            border: Border.all(
              color: isPrimary
                  ? const Color(0xFFF3CE82).withValues(alpha: 0.35)
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

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? const Color(0xFFF1C98A) : const Color(0xFF8C7360);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: fg),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
