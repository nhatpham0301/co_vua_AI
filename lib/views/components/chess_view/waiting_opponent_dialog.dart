import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../logic/dev_logger.dart';
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
  late Future<void> _timeoutFuture;
  bool _codeCopied = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    /// Thay đổi thời gian chờ
    _timeoutFuture = Future.delayed(const Duration(seconds: 5), () async {
      if (!mounted) return;

      DevLogger.instance.log(
        DevLogCategory.game,
        '[WAITING_OPPONENT] 5s timeout -> no opponent joined -> fallback to AI',
      );

      if (mounted) Navigator.of(context).pop();
      await _createAIGameFallback();
    });
  }

  Future<void> _createAIGameFallback() async {
    try {
      final appModel = widget.appModel;
      final aiJson = await appModel.apiClient.createAiGame(
        aiLevel: appModel.aiDifficulty,
        color: appModel.selectedSide.index == 1 ? 'black' : 'white',
        moveTimeLimit: appModel.moveTimeLimit,
      );

      final aiGameId = aiJson['id'];
      DevLogger.instance.log(
        DevLogCategory.http,
        '[WAITING_OPPONENT] POST /api/games/vs-ai (fallback) success | gameId=$aiGameId',
      );

      if (aiGameId is String && aiGameId.isNotEmpty && mounted) {
        await appModel.onlineEvents.stopTracking();
        await appModel.startOnlineEventTracking(aiGameId);
        appModel.markOnlineVsAiLocalFallbackSession(true);
        appModel.setPlayerCount(1);
        appModel.isWaitingForOpponent = false;
        appModel.currentGameInviteCode = null;
        appModel.update();
      }
    } catch (e) {
      DevLogger.instance.log(
        DevLogCategory.http,
        '[WAITING_OPPONENT] POST /api/games/vs-ai (fallback) failed | $e',
      );
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
    Navigator.of(context).pop();
    widget.appModel.isWaitingForOpponent = false;
    widget.appModel.currentGameInviteCode = null;
    widget.appModel.update();
  }

  @override
  Widget build(BuildContext context) {
    final inviteCode = widget.appModel.currentGameInviteCode ?? '';

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
                padding: EdgeInsets.only(bottom: 20),
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
                      onPressed: _onInvitePressed,
                      bgColor: primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildButton(
                      label: 'Exit',
                      onPressed: _onExitPressed,
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
    required VoidCallback onPressed,
    required Color bgColor,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: bgColor.withValues(alpha: 0.8),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: bgColor.withValues(alpha: 0.4),
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

  @override
  void dispose() {
    _timeoutFuture.ignore();
    super.dispose();
  }
}
