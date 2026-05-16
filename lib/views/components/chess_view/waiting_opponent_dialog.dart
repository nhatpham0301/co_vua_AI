import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../logic/dev_logger.dart';
import '../../../logic/experimental_api_client.dart';
import '../../../model/app_model.dart';
import '../main_menu_view/mm_palette.dart';

class WaitingOpponentDialog extends StatefulWidget {
  final AppModel appModel;

  const WaitingOpponentDialog({
    required this.appModel,
    super.key,
  });

  @override
  State<WaitingOpponentDialog> createState() => _WaitingOpponentDialogState();
}

class _WaitingOpponentDialogState extends State<WaitingOpponentDialog> {
  bool _codeCopied = false;
  bool _dialogClosed = false;
  bool _isCreatingAiGame = false;

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
        '[WAITING_OPPONENT] $action unauthorized (401) -> refreshing token',
      );
      final refreshed = await appModel.authService.refreshTokens();
      if (!refreshed) {
        DevLogger.instance.log(
          DevLogCategory.http,
          '[WAITING_OPPONENT] $action refresh failed -> need re-login',
        );
        rethrow;
      }
      DevLogger.instance.log(
        DevLogCategory.http,
        '[WAITING_OPPONENT] $action retry after refresh',
      );
      return execute();
    }
  }

  @override
  void initState() {
    super.initState();
    widget.appModel.addListener(_onModelChanged);
    _startCountdown();
  }

  @override
  void dispose() {
    widget.appModel.removeListener(_onModelChanged);
    super.dispose();
  }

  /// Close this dialog automatically when the opponent has joined.
  void _onModelChanged() {
    if (!mounted || _dialogClosed) return;
    if (widget.appModel.opponentJoined ||
        !widget.appModel.isWaitingForOpponent) {
      _dialogClosed = true;
      // Use Future.microtask to safely pop after current event loop
      Future.microtask(() {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  void _startCountdown() {
    /// Thay đổi thời gian chờ
    Future.delayed(const Duration(seconds: 5), () async {
      if (!mounted) return;
      if (widget.appModel.opponentJoined ||
          !widget.appModel.isWaitingForOpponent ||
          _dialogClosed ||
          _isCreatingAiGame) {
        return;
      }

      DevLogger.instance.log(
        DevLogCategory.game,
        '[WAITING_OPPONENT] 5s timeout -> no opponent joined -> fallback to AI',
      );

      setState(() => _isCreatingAiGame = true);
      await _createAIGameFallback();
    });
  }

  Future<void> _createAIGameFallback() async {
    try {
      final appModel = widget.appModel;
      final aiLevel = appModel.onlineAiLevelFromPlayerElo();
      DevLogger.instance.log(
        DevLogCategory.game,
        '[WAITING_OPPONENT] fallback AI level from ELO -> aiLevel=$aiLevel | elo=${appModel.authService.user?.elo ?? '-'}',
      );

      final aiJson = await _withAuthRetry(
        appModel: appModel,
        action: 'createAiGame(timeoutFallback)',
        execute: () => appModel.apiClient.createAiGame(
          aiLevel: aiLevel,
          color: appModel.nextOnlineAiColor(),
          timeControl: 'rapid_15',
          moveTimeLimit: 0,
        ),
      );

      final aiGameId = aiJson['id'];
      DevLogger.instance.log(
        DevLogCategory.http,
        '[WAITING_OPPONENT] POST /api/games/vs-ai (fallback) success | gameId=$aiGameId',
      );

      if (aiGameId is String && aiGameId.isNotEmpty && mounted) {
        // Match AI Test flow: apply snapshot first, then start socket tracking.
        appModel.applyJoinGameResponse(aiJson);
        await appModel.onlineEvents.stopTracking();
        await appModel.startOnlineEventTracking(aiGameId);
        appModel.markOnlineVsAiLocalFallbackSession(false);
        appModel.setPlayerCount(1);
        appModel.isWaitingForOpponent = false;
        // Reset opponent joined flag so countdown can trigger in ChessView
        appModel.opponentJoined = false;
        appModel.currentGameInviteCode = null;
        appModel.update();

        if (mounted && !_dialogClosed) {
          _dialogClosed = true;
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      DevLogger.instance.log(
        DevLogCategory.http,
        '[WAITING_OPPONENT] POST /api/games/vs-ai (fallback) failed | $e',
      );
      if (mounted) {
        setState(() => _isCreatingAiGame = false);
      }
    }
  }

  void _copyInviteCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    setState(() => _codeCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _codeCopied = false);
    });
  }

  void _onInvitePressed() {
    final inviteCode = widget.appModel.currentGameInviteCode ?? '';
    if (inviteCode.isNotEmpty) _copyInviteCode(inviteCode);
  }

  void _onExitPressed() {
    if (_isCreatingAiGame) return;
    _dialogClosed = true;
    final appModel = widget.appModel;
    appModel.isWaitingForOpponent = false;
    appModel.currentGameInviteCode = null;
    appModel.opponentJoined = false;
    appModel.exitChessView();

    // Exit waiting dialog + chess screen and return to main menu.
    Navigator.of(context, rootNavigator: true)
        .popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final appModel = widget.appModel;
    final inviteCode = appModel.currentGameInviteCode ?? '';
    final gameId = appModel.onlineGameSnapshot?.id ?? '';
    final timeLimit = appModel.timeLimit;
    final playerColor = appModel.playerSide.index == 0 ? 'Trắng' : 'Đen';

    return Material(
      color: Colors.transparent,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: primary.withValues(alpha: 0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withValues(alpha: 0.6),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Bàn chờ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: primaryLight,
                    letterSpacing: 1,
                  ),
                ),
              ),
              // Game info box
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: bgDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                        'Bàn:',
                        gameId.isNotEmpty
                            ? gameId.substring(0, (gameId.length / 2).toInt())
                            : '-'),
                    _buildInfoRow('Thời gian:',
                        timeLimit > 0 ? '${timeLimit} phút' : 'Không giới hạn'),
                    _buildInfoRow('Màu của bạn:', playerColor),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: bgDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        inviteCode,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          fontFamily: 'Courier',
                          color: primaryLight,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _copyInviteCode(inviteCode),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: bgDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _codeCopied
                              ? const Color(0xFF4CAF50).withValues(alpha: 0.7)
                              : primary.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          _codeCopied
                              ? CupertinoIcons.checkmark_circle_fill
                              : CupertinoIcons.doc_on_doc,
                          color: _codeCopied
                              ? const Color(0xFF4CAF50).withValues(alpha: 0.8)
                              : primaryLight,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isCreatingAiGame)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CupertinoActivityIndicator(radius: 8),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Đang tạo bàn AI...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFFFFFFFF).withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                )
              else
                Text(
                  'Chờ người chơi khác...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFFFFFFFF).withValues(alpha: 0.7),
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildButton(
                      label: 'Mã mời',
                      onPressed: _isCreatingAiGame ? null : _onInvitePressed,
                      bgColor: primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildButton(
                      label: 'Exit',
                      onPressed: _isCreatingAiGame ? null : _onExitPressed,
                      bgColor: const Color(0xFFD32F2F),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required VoidCallback? onPressed,
    required Color bgColor,
  }) {
    final isEnabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: isEnabled ? bgColor : bgColor.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isEnabled
                ? bgColor.withValues(alpha: 0.8)
                : bgColor.withValues(alpha: 0.45),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isEnabled
                  ? bgColor.withValues(alpha: 0.4)
                  : Colors.transparent,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFFFFFFFF),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: primaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
