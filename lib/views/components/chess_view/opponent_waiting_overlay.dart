import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../model/app_model.dart';

class OpponentWaitingOverlay extends StatefulWidget {
  const OpponentWaitingOverlay({super.key});

  @override
  State<OpponentWaitingOverlay> createState() => _OpponentWaitingOverlayState();
}

class _OpponentWaitingOverlayState extends State<OpponentWaitingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _codeCopied = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _copyInviteCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    setState(() => _codeCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _codeCopied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appModel = context.watch<AppModel>();

    // Close overlay when opponent joins or game is no longer waiting
    if (appModel.opponentJoined || !appModel.isWaitingForOpponent) {
      return const SizedBox.shrink();
    }

    final inviteCode = appModel.currentGameInviteCode ?? '';

    return Stack(
      children: [
        // Semi-transparent background
        Container(
          color: CupertinoColors.black.withValues(alpha: 0.4),
        ),
        // Centered content
        Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated waiting indicator
                SizedBox(
                  height: 60,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        final value = _animController.value;
                        final dots = '.' *
                            ((value * 3).floor() % 4); // Cycle: . .. ... ....
                        return Text(
                          'Waiting for opponent$dots',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.label,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Invite code section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Share this code:',
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.secondaryLabel,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _copyInviteCode(inviteCode),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: CupertinoColors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _codeCopied
                                  ? CupertinoColors.systemGreen
                                  : CupertinoColors.systemGrey4,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                inviteCode,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                  fontFamily: 'Courier',
                                  color: CupertinoColors.label,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                _codeCopied
                                    ? CupertinoIcons.checkmark_circle_fill
                                    : CupertinoIcons.doc_on_doc,
                                color: _codeCopied
                                    ? CupertinoColors.systemGreen
                                    : CupertinoColors.systemBlue,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _codeCopied ? 'Copied to clipboard!' : 'Tap to copy',
                        style: TextStyle(
                          fontSize: 11,
                          color: _codeCopied
                              ? CupertinoColors.systemGreen
                              : CupertinoColors.secondaryLabel,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Cancel button
                CupertinoButton(
                  onPressed: () {
                    appModel.isWaitingForOpponent = false;
                    appModel.currentGameInviteCode = null;
                    appModel.update();
                  },
                  color: CupertinoColors.systemRed,
                  child: const Text('Cancel Game'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
