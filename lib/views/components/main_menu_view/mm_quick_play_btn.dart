import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../logic/dev_logger.dart';
import '../../../logic/experimental_api_client.dart';
import '../../../model/app_model.dart';
import '../../../model/player.dart';
import '../../chess_view.dart';
import 'mm_models.dart';
import 'mm_palette.dart';

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

  const QuickPlayBtn({
    super.key,
    required this.hasSavedGame,
    required this.onGameFinished,
    this.buttonBuilder,
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
    setState(() => _isStarting = true);
    try {
      final appModel = Provider.of<AppModel>(context, listen: false);
      final isLoggedIn = appModel.authService.isLoggedIn;
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
        await appModel.adService.showAdBeforeGame(
          () async {
            if (!mounted) return;
            DevLogger.instance.log(
              DevLogCategory.ad,
              '[HOME_PLAY] Ad completed -> open ChessView (offline)',
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
          },
          context: context,
        );
        return;
      }

      DevLogger.instance.log(
        DevLogCategory.game,
        '[HOME_PLAY] Online mode -> open matchmaking dialog',
      );

      bool onlineGameReady = false;

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
              moveTimeLimit: appModel.moveTimeLimit,
            ),
          );
          DevLogger.instance.log(
            DevLogCategory.http,
            '[HOME_PLAY] Matchmaking joined | ${joinJson['message'] ?? 'ok'}',
          );
        } catch (e) {
          DevLogger.instance.log(
            DevLogCategory.http,
            '[HOME_PLAY] POST /api/matchmaking/join failed | $e',
          );
        }
      }

      final result = await showCupertinoModalPopup<MatchResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const MatchmakingDialog(timeoutSeconds: 10),
      );
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
        return;
      }
      if (result == MatchResult.timeout) {
        DevLogger.instance.log(
          DevLogCategory.game,
          '[HOME_PLAY] Matchmaking timeout -> leave queue -> fallback AI game',
        );
        if (isLoggedIn) {
          try {
            await _withAuthRetry(
              appModel: appModel,
              action: 'leaveMatchmaking(timeout)',
              execute: appModel.apiClient.leaveMatchmaking,
            );
            DevLogger.instance.log(
              DevLogCategory.http,
              '[HOME_PLAY] DELETE /api/matchmaking/leave success (timeout)',
            );
          } catch (e) {
            DevLogger.instance.log(
              DevLogCategory.http,
              '[HOME_PLAY] DELETE /api/matchmaking/leave failed (timeout) | $e',
            );
          }
        }
      }

      if (isLoggedIn) {
        try {
          DevLogger.instance.log(
            DevLogCategory.http,
            '[HOME_PLAY] Calling POST /api/games/vs-ai after matchmaking timeout ...',
          );
          final gameJson = await _withAuthRetry(
            appModel: appModel,
            action: 'createAiGame',
            execute: () => appModel.apiClient.createAiGame(
              aiLevel: appModel.aiDifficulty,
              color:
                  appModel.selectedSide == Player.player2 ? 'black' : 'white',
              moveTimeLimit: appModel.moveTimeLimit,
            ),
          );
          final gameId = gameJson['id'];
          DevLogger.instance.log(
            DevLogCategory.http,
            '[HOME_PLAY] POST /api/games/vs-ai success | gameId=$gameId',
          );
          if (gameId is String && gameId.isNotEmpty) {
            await appModel.startOnlineEventTracking(gameId);
            DevLogger.instance.log(
              DevLogCategory.http,
              '[HOME_PLAY] Realtime tracking attached | gameId=$gameId',
            );
            onlineGameReady = true;
          } else {
            DevLogger.instance.log(
              DevLogCategory.http,
              '[HOME_PLAY] Skip socket tracking: missing gameId in createAiGame response',
            );
          }
        } on ApiException catch (e) {
          DevLogger.instance.log(
            DevLogCategory.http,
            '[HOME_PLAY] POST /api/games/vs-ai failed | $e',
          );
          if (e.statusCode == 401) {
            await _showSessionExpiredDialog(context);
            return;
          }
        } catch (e) {
          DevLogger.instance.log(
            DevLogCategory.http,
            '[HOME_PLAY] POST /api/games/vs-ai failed | $e',
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

      appModel.setPlayerCount(1);
      await appModel.adService.showAdBeforeGame(
        () async {
          if (!mounted) return;
          DevLogger.instance.log(
            DevLogCategory.ad,
            '[HOME_PLAY] Ad completed -> open ChessView (online path)',
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
        },
        context: context,
      );
    } catch (e) {
      DevLogger.instance.log(
        DevLogCategory.system,
        '[HOME_PLAY] Start flow error: $e',
      );
      rethrow;
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
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
