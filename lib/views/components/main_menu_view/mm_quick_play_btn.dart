import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../logic/dev_logger.dart';
import '../../../logic/experimental_api_client.dart';
import '../../../model/app_model.dart';
import '../../ai_levels_test_view.dart';
import '../../chess_view.dart';
import 'mm_models.dart';
import 'mm_palette.dart';

enum _StartMode { human, ai }

// ─── Connectivity helper ──────────────────────────────────────────────────────
Future<bool> _checkOnline() async {
  try {
    final r = await InternetAddress.lookup('google.com')
        .timeout(const Duration(seconds: 5));
    return r.isNotEmpty && r[0].rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}

// ─── Animated "CHƠI" button ───────────────────────────────────────────────────
class QuickPlayBtn extends StatefulWidget {
  final bool hasSavedGame;
  final VoidCallback onGameFinished;
  final Widget Function(BuildContext context, bool isStarting)? buttonBuilder;
  final ValueChanged<bool>? onStartingChanged;

  const QuickPlayBtn({
    super.key,
    required this.hasSavedGame,
    required this.onGameFinished,
    this.buttonBuilder,
    this.onStartingChanged,
  });

  @override
  State<QuickPlayBtn> createState() => _QuickPlayBtnState();
}

class _QuickPlayBtnState extends State<QuickPlayBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.97, end: 1.04)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final defaultButton = Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 52),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0082C8), Color(0xFF0050A0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF0082C8),
            blurRadius: 20,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black38,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: _isStarting
            ? const CupertinoActivityIndicator(color: Colors.white)
            : Text(
                l.play,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.5,
                ),
              ),
      ),
    );

    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: GestureDetector(
        onTap: _isStarting ? null : () => _start(context),
        child:
            widget.buttonBuilder?.call(context, _isStarting) ?? defaultButton,
      ),
    );
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
        '[HOME_PLAY] $action unauthorized (401) -> refreshing token',
      );
      final refreshed = await appModel.authService.refreshTokens();
      if (!refreshed) {
        DevLogger.instance.log(
          DevLogCategory.http,
          '[HOME_PLAY] $action refresh failed -> need re-login',
        );
        rethrow;
      }
      DevLogger.instance.log(
        DevLogCategory.http,
        '[HOME_PLAY] $action retry after refresh',
      );
      return execute();
    }
  }

  Future<void> _showSessionExpiredDialog(BuildContext context) async {
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Phiên đăng nhập hết hạn'),
        content: const Text('Vui lòng đăng nhập lại để chơi online.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  Future<void> _start(BuildContext context) async {
    if (!mounted) return;

    final appModel = Provider.of<AppModel>(context, listen: false);
    final isLoggedIn = appModel.authService.isLoggedIn;

    // Not logged in → skip mode picker and start a local game immediately.
    if (!isLoggedIn) {
      setState(() => _isStarting = true);
      widget.onStartingChanged?.call(true);
      try {
        DevLogger.instance.log(
          DevLogCategory.game,
          '[HOME_PLAY] Guest user -> start local game directly',
        );
        appModel.setPlayerCount(1);
        if (!mounted) return;
        await Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => ChessView(appModel)),
        );
        widget.onGameFinished();
      } finally {
        if (mounted) setState(() => _isStarting = false);
        widget.onStartingChanged?.call(false);
      }
      return;
    }

    final startMode = await _showStartModePicker(context);
    if (startMode == null || !mounted) return;

    if (startMode == _StartMode.ai) {
      await Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => const AiLevelsTestView()),
      );
      widget.onGameFinished();
      return;
    }

    setState(() => _isStarting = true);
    widget.onStartingChanged?.call(true);
    bool transitionLoadingVisible = false;

    Future<void> showTransitionLoading(String message) async {
      if (!mounted) return;
      if (transitionLoadingVisible) {
        Navigator.of(context, rootNavigator: true).pop();
        transitionLoadingVisible = false;
      }
      transitionLoadingVisible = true;
      showCupertinoDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CupertinoAlertDialog(
          content: Row(
            children: [
              const CupertinoActivityIndicator(),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
    }

    void hideTransitionLoading() {
      if (!mounted || !transitionLoadingVisible) return;
      Navigator.of(context, rootNavigator: true).pop();
      transitionLoadingVisible = false;
    }

    try {
      DevLogger.instance.log(
        DevLogCategory.game,
        '[HOME_PLAY] Tap PLAY | login=$isLoggedIn | savedGame=${widget.hasSavedGame}',
      );

      final online = await _checkOnline();
      DevLogger.instance.log(
        DevLogCategory.system,
        '[HOME_PLAY] Connectivity check | online=$online',
      );
      if (!mounted) return;

      if (!online) {
        DevLogger.instance.log(
          DevLogCategory.game,
          '[HOME_PLAY] Offline mode -> start local AI game',
        );
        appModel.setPlayerCount(1);
        if (!mounted) return;
        DevLogger.instance.log(
          DevLogCategory.game,
          '[HOME_PLAY] Open ChessView (offline)',
        );
        await Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => ChessView(appModel)),
        );
        DevLogger.instance.log(
          DevLogCategory.game,
          '[HOME_PLAY] Returned from ChessView (offline)',
        );
        widget.onGameFinished();
        return;
      }

      DevLogger.instance.log(
        DevLogCategory.game,
        '[HOME_PLAY] Online mode -> open matchmaking dialog',
      );

      bool onlineGameReady = false;
      String? matchedGameId;
      bool createdAiFallback = false;
      bool matchmakingDialogVisible = false;

      // Connect socket first so client can receive match events immediately.
      await appModel.startMatchmakingEventTracking();
      appModel.onlineEvents.onMatchFound = (payload) {
        final gameId = payload['gameId']?.toString();
        if (gameId == null || gameId.isEmpty) return;
        matchedGameId = gameId;
        DevLogger.instance.log(
          DevLogCategory.game,
          '[HOME_PLAY] match:found received | gameId=$gameId',
        );
        if (mounted && matchmakingDialogVisible) {
          Navigator.of(context, rootNavigator: true).pop(MatchResult.matched);
        }
      };

      appModel.onlineEvents.onMatchTimeout = (payload) {
        DevLogger.instance.log(
          DevLogCategory.game,
          '[HOME_PLAY] match:timeout received | payload=$payload',
        );
        if (mounted && matchmakingDialogVisible) {
          Navigator.of(context, rootNavigator: true).pop(MatchResult.timeout);
        }
      };

      if (isLoggedIn) {
        try {
          DevLogger.instance.log(
            DevLogCategory.http,
            '[HOME_PLAY] Calling POST /api/matchmaking/join ...',
          );
          final joinJson = await _withAuthRetry(
            appModel: appModel,
            action: 'joinMatchmaking',
            execute: () => appModel.apiClient.joinMatchmaking(
              timeControl: appModel.onlineTimeControl,
              moveTimeLimit: appModel.moveTimeLimit,
            ),
          );
          final joinStatus =
              (joinJson['status']?.toString() ?? '').trim().toLowerCase();
          final joinGameId = (joinJson['gameId']?.toString() ?? '').trim();
          if (joinStatus == 'matched' && joinGameId.isNotEmpty) {
            matchedGameId = joinGameId;
            DevLogger.instance.log(
              DevLogCategory.game,
              '[HOME_PLAY] Matchmaking matched in HTTP response | gameId=$joinGameId',
            );
          }
          DevLogger.instance.log(
            DevLogCategory.http,
            '[HOME_PLAY] Matchmaking joined | status=${joinJson['status'] ?? '-'} | ${joinJson['message'] ?? 'ok'}',
          );
        } catch (e) {
          DevLogger.instance.log(
            DevLogCategory.http,
            '[HOME_PLAY] POST /api/matchmaking/join failed | $e',
          );
          await appModel.onlineEvents.stopTracking();
          return;
        }
      }

      MatchResult? result;
      if (matchedGameId != null && matchedGameId!.isNotEmpty) {
        result = MatchResult.matched;
      } else {
        matchmakingDialogVisible = true;
        result = await showCupertinoModalPopup<MatchResult>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const MatchmakingDialog(timeoutSeconds: 5),
        );
        matchmakingDialogVisible = false;
      }
      if (!mounted) return;

      DevLogger.instance.log(
        DevLogCategory.game,
        '[HOME_PLAY] Matchmaking result=$result',
      );

      if (result == null || result == MatchResult.cancelled) {
        if (isLoggedIn) {
          try {
            await _withAuthRetry(
              appModel: appModel,
              action: 'leaveMatchmaking(cancelled)',
              execute: appModel.apiClient.leaveMatchmaking,
            );
            DevLogger.instance.log(
              DevLogCategory.http,
              '[HOME_PLAY] DELETE /api/matchmaking/leave success (cancelled)',
            );
          } catch (e) {
            DevLogger.instance.log(
              DevLogCategory.http,
              '[HOME_PLAY] DELETE /api/matchmaking/leave failed (cancelled) | $e',
            );
          }
        }
        await appModel.onlineEvents.stopTracking();
        return;
      }

      if (result == MatchResult.timeout) {
        DevLogger.instance.log(
          DevLogCategory.game,
          '[HOME_PLAY] Matchmaking timeout -> leave queue and auto-create AI game',
        );
        if (isLoggedIn) {
          try {
            await showTransitionLoading('Không có đối thủ, đang ghép AI...');
            await _withAuthRetry(
              appModel: appModel,
              action: 'leaveMatchmaking(timeout)',
              execute: appModel.apiClient.leaveMatchmaking,
            );
            DevLogger.instance.log(
              DevLogCategory.http,
              '[HOME_PLAY] DELETE /api/matchmaking/leave success (timeout)',
            );

            final aiLevel = appModel.onlineAiLevelFromPlayerElo();
            final created = await _withAuthRetry(
              appModel: appModel,
              action: 'createAiGame(timeoutFallback)',
              execute: () => appModel.apiClient.createAiGame(
                aiLevel: aiLevel,
                color: appModel.nextOnlineAiColor(),
                timeControl: appModel.onlineTimeControl,
                moveTimeLimit: 0,
              ),
            );
            final createdGameId = (created['id']?.toString() ?? '').trim();
            if (createdGameId.isNotEmpty) {
              matchedGameId = createdGameId;
              createdAiFallback = true;
              DevLogger.instance.log(
                DevLogCategory.http,
                '[HOME_PLAY] POST /api/games/ai fallback success | gameId=$createdGameId | aiLevel=$aiLevel',
              );
            } else {
              DevLogger.instance.log(
                DevLogCategory.http,
                '[HOME_PLAY] POST /api/games/ai fallback failed: missing game id',
              );
            }
          } catch (e) {
            DevLogger.instance.log(
              DevLogCategory.http,
              '[HOME_PLAY] Timeout fallback failed | $e',
            );
            hideTransitionLoading();
          }
        }
        if (matchedGameId == null || matchedGameId!.isEmpty) {
          hideTransitionLoading();
          await appModel.onlineEvents.stopTracking();
          return;
        }

        result = MatchResult.matched;
      }

      if (result == MatchResult.matched) {
        final gameId = matchedGameId;
        if (gameId == null || gameId.isEmpty) {
          DevLogger.instance.log(
            DevLogCategory.http,
            '[HOME_PLAY] match:found missing gameId -> abort',
          );
          await appModel.onlineEvents.stopTracking();
          return;
        }

        try {
          if (createdAiFallback) {
            await showTransitionLoading('Đang kết nối bàn đấu...');
          }

          // Switch socket from matchmaking channel to game room tracking.
          await appModel.startOnlineEventTracking(gameId);

          // Hydrate snapshot/profile for board orientation and header info.
          await appModel.fetchOnlineGameSnapshotPreview(gameId);
          if (createdAiFallback) {
            appModel.currentGameInviteCode = null;
            appModel.isWaitingForOpponent = false;
            appModel.opponentJoined = true;
          } else {
            await appModel.hydrateOpponentProfileFromSnapshot();
            appModel.currentGameInviteCode = null;
            appModel.isWaitingForOpponent = false;
            appModel.opponentJoined = true;
          }
          onlineGameReady = true;
        } on ApiException catch (e) {
          hideTransitionLoading();
          DevLogger.instance.log(
            DevLogCategory.http,
            '[HOME_PLAY] start matched game failed | $e',
          );
          if (e.statusCode == 401) {
            if (mounted) await _showSessionExpiredDialog(context);
            return;
          }
        } catch (e) {
          hideTransitionLoading();
          DevLogger.instance.log(
            DevLogCategory.http,
            '[HOME_PLAY] start matched game failed | $e',
          );
        }
      }

      if (isLoggedIn && !onlineGameReady) {
        DevLogger.instance.log(
          DevLogCategory.http,
          '[HOME_PLAY] Abort opening ChessView: online game was not created successfully',
        );
        return;
      }

      appModel.setPlayerCount(createdAiFallback ? 1 : 2);
      appModel.markOnlineVsAiLocalFallbackSession(createdAiFallback);
      if (!mounted) return;
      hideTransitionLoading();
      DevLogger.instance.log(
        DevLogCategory.game,
        '[HOME_PLAY] Open ChessView (online path)',
      );
      await Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => ChessView(appModel)),
      );
      DevLogger.instance.log(
        DevLogCategory.game,
        '[HOME_PLAY] Returned from ChessView (online path)',
      );
      widget.onGameFinished();
    } catch (e) {
      hideTransitionLoading();
      DevLogger.instance.log(
        DevLogCategory.system,
        '[HOME_PLAY] Start flow error: $e',
      );
      rethrow;
    } finally {
      hideTransitionLoading();
      if (mounted) setState(() => _isStarting = false);
      widget.onStartingChanged?.call(false);
    }
  }

  Future<_StartMode?> _showStartModePicker(BuildContext context) {
    return showGeneralDialog<_StartMode>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'start_mode_picker',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, __) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 360,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: primary.withValues(alpha: 0.45),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Chọn chế độ bắt đầu',
                          style: TextStyle(
                            color: primaryLight,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.2),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Icon(
                            CupertinoIcons.xmark,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _StartModeActionButton(
                    label: 'Đánh với người',
                    onPressed: () => Navigator.of(ctx).pop(_StartMode.human),
                  ),
                  const SizedBox(height: 10),
                  _StartModeActionButton(
                    label: 'Đánh với máy',
                    onPressed: () => Navigator.of(ctx).pop(_StartMode.ai),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
            child: child,
          ),
        );
      },
    );
  }
}

class _StartModeActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _StartModeActionButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD9A14A), Color(0xFF8F5A23)],
          ),
          border: Border.all(
            color: const Color(0xFFF0CA89).withValues(alpha: 0.55),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Matchmaking countdown popup ─────────────────────────────────────────────
class MatchmakingDialog extends StatefulWidget {
  final int timeoutSeconds;
  const MatchmakingDialog({super.key, required this.timeoutSeconds});

  @override
  State<MatchmakingDialog> createState() => _MatchmakingDialogState();
}

class _MatchmakingDialogState extends State<MatchmakingDialog> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.timeoutSeconds;

    if (_remaining <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, MatchResult.timeout);
      });
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _timer?.cancel();
        Navigator.pop(context, MatchResult.timeout);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF071428),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CupertinoActivityIndicator(radius: 28, color: primary),
                Text(
                  '$_remaining',
                  style: const TextStyle(
                    color: primaryLight,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l.matchmakingTitle,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.matchmakingSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: () {
              _timer?.cancel();
              Navigator.pop(context, MatchResult.cancelled);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                l.cancel,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
