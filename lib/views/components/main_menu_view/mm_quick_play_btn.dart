import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../model/app_model.dart';
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

  const QuickPlayBtn({
    super.key,
    required this.hasSavedGame,
    required this.onGameFinished,
  });

  @override
  State<QuickPlayBtn> createState() => _QuickPlayBtnState();
}

class _QuickPlayBtnState extends State<QuickPlayBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;

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
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: GestureDetector(
        onTap: () => _start(context),
        child: Container(
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
          child: const Center(
            child: Text(
              'CHƠI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _start(BuildContext context) async {
    final appModel = Provider.of<AppModel>(context, listen: false);
    final online = await _checkOnline();
    if (!mounted) return;

    if (!online) {
      appModel.setPlayerCount(1);
      await Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => ChessView(appModel)),
      );
      widget.onGameFinished();
      return;
    }

    final result = await showCupertinoModalPopup<MatchResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const MatchmakingDialog(timeoutSeconds: 5),
    );
    if (!mounted) return;

    if (result == null || result == MatchResult.cancelled) return;

    appModel.setPlayerCount(1);
    await Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => ChessView(appModel)),
    );
    widget.onGameFinished();
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
          const Text(
            'Đang tìm đối thủ...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ghép trận theo ELO. Nếu hết thời gian\nsẽ tự động chuyển sang Bot.',
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
              child: const Text(
                'Hủy',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
