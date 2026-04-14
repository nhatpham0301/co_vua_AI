import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/app_model.dart';
import '../main_menu_view/mm_palette.dart';
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
    final l = AppLocalizations.of(context)!;
    final showUndoRedo = appModel.allowUndoRedo && !appModel.isOnlineGameMode;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: bgCard.withValues(alpha: 0.38),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          if (showUndoRedo) ...[
            Expanded(
              child: _ActionBtn(
                icon: Icons.undo_rounded,
                enabled: _undoOk,
                onTap: _undoOk ? _undo : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionBtn(
                icon: Icons.redo_rounded,
                enabled: _redoOk,
                onTap: _redoOk ? _redo : null,
                tooltip: l.redo,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionBtn(
                icon: Icons.add_circle_outline_rounded,
                enabled: true,
                isActive: false,
                tooltip: l.newGameTitle,
                onTap: () => _showRestartDialog(context, l),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionBtn(
                icon: appModel.showHints
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                enabled: true,
                isActive: appModel.showHints,
                tooltip: l.toggleHints,
                onTap: () async {
                  await appModel.prefs.setShowHints(!appModel.showHints);
                  appModel.update();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionBtn(
                icon: Icons.exit_to_app_rounded,
                enabled: true,
                tooltip: l.exitTooltip,
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
          ] else ...[
            Expanded(
              child: _ActionBtn(
                icon: appModel.showHints
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                enabled: true,
                isActive: appModel.showHints,
                tooltip: l.toggleHints,
                onTap: () async {
                  await appModel.prefs.setShowHints(!appModel.showHints);
                  appModel.update();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionBtn(
                icon: Icons.add_circle_outline_rounded,
                enabled: true,
                isActive: false,
                tooltip: l.newGameTitle,
                onTap: () => _showRestartDialog(context, l),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionBtn(
                icon: Icons.exit_to_app_rounded,
                enabled: true,
                tooltip: l.exitTooltip,
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
        ],
      ),
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
  final bool isActive;
  final String? tooltip;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    // required this.label,
    required this.enabled,
    this.isActive = false,
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
        borderRadius: BorderRadius.circular(18),
        splashColor: Colors.white.withValues(alpha: 0.08),
        highlightColor: Colors.white.withValues(alpha: 0.04),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: enabled
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isActive
                        ? const [Color(0xFF4C7A3E), Color(0xFF24412D)]
                        : const [Color(0xFF314530), Color(0xFF1C2428)],
                  )
                : null,
            color: enabled ? null : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: enabled
                  ? (isActive
                      ? const Color(0xFFA9D67A).withValues(alpha: 0.72)
                      : const Color(0xFF8EA770).withValues(alpha: 0.25))
                  : Colors.white.withValues(alpha: 0.05),
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: isActive
                          ? const Color(0xFF89D46A).withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
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
                  size: 19,
                ),
              ),
              if (enabled && isActive)
                Positioned(
                  top: 4,
                  right: 8,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFA9D67A),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFFA9D67A).withValues(alpha: 0.55),
                          blurRadius: 6,
                        ),
                      ],
                    ),
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
