import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../main_menu_view/mm_palette.dart';

class PlayersHeaderRow extends StatelessWidget {
  final bool isAI;
  final int diff;
  final int botElo;
  final bool gameOver;
  final bool isAIsTurn;
  final int timeLimitMinutes;
  final int player1MaterialDelta;
  final int player2MaterialDelta;
  final ValueListenable<Duration> player1TimeLeft;
  final ValueListenable<Duration> player2TimeLeft;
  final VoidCallback onTapPlayer1;
  final VoidCallback onTapPlayer2;

  const PlayersHeaderRow({
    super.key,
    required this.isAI,
    required this.diff,
    required this.botElo,
    required this.gameOver,
    required this.isAIsTurn,
    required this.timeLimitMinutes,
    required this.player1MaterialDelta,
    required this.player2MaterialDelta,
    required this.player1TimeLeft,
    required this.player2TimeLeft,
    required this.onTapPlayer1,
    required this.onTapPlayer2,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _PlayerCompactCard(
            name: l.youPlayer,
            subtitle: '2145 ELO',
            isBot: false,
            isActive: !isAIsTurn && !gameOver,
            timeLimitMinutes: timeLimitMinutes,
            timeLeft: player1TimeLeft,
            materialDelta: player1MaterialDelta,
            onTap: onTapPlayer1,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PlayerCompactCard(
            name: isAI ? l.botLevel(diff) : l.opponent,
            subtitle: l.eloLabel(botElo),
            isBot: isAI,
            isActive: isAIsTurn && !gameOver,
            timeLimitMinutes: timeLimitMinutes,
            timeLeft: player2TimeLeft,
            materialDelta: player2MaterialDelta,
            onTap: onTapPlayer2,
          ),
        ),
      ],
    );
  }
}

class _PlayerCompactCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final bool isBot;
  final bool isActive;
  final int timeLimitMinutes;
  final ValueListenable<Duration> timeLeft;
  final int materialDelta;
  final VoidCallback onTap;

  const _PlayerCompactCard({
    required this.name,
    required this.subtitle,
    required this.isBot,
    required this.isActive,
    required this.timeLimitMinutes,
    required this.timeLeft,
    required this.materialDelta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isActive
        ? const Color(0xFF8FCB81).withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.08);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF20272F).withValues(alpha: 0.9),
                const Color(0xFF151A20).withValues(alpha: 0.95),
              ],
            ),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2B3C33).withValues(alpha: 0.7),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFFA7DA85).withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Icon(
                      isBot ? Icons.smart_toy_rounded : Icons.person_rounded,
                      color: isBot ? primaryLight : Colors.white70,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _MaterialDeltaBadge(delta: materialDelta),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ValueListenableBuilder<Duration>(
                    valueListenable: timeLeft,
                    builder: (_, duration, __) {
                      return _CompactTimerPill(
                        duration: duration,
                        isActive: isActive,
                        enabled: timeLimitMinutes > 0,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactTimerPill extends StatelessWidget {
  final Duration duration;
  final bool isActive;
  final bool enabled;

  const _CompactTimerPill({
    required this.duration,
    required this.isActive,
    required this.enabled,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final displayText = enabled ? _fmt(duration) : '∞';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isActive
              ? [
                  const Color(0xFF3D6F49).withValues(alpha: 0.95),
                  const Color(0xFF253A2D),
                ]
              : [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.03),
                ],
        ),
        border: Border.all(
          color: isActive
              ? const Color(0xFFA5D47D).withValues(alpha: 0.62)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.clock_fill,
            size: 10,
            color: enabled
                ? (isActive ? primaryLight : Colors.white54)
                : Colors.white38,
          ),
          const SizedBox(width: 4),
          Text(
            displayText,
            style: TextStyle(
              color: enabled
                  ? (isActive ? Colors.white : Colors.white60)
                  : Colors.white54,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialDeltaBadge extends StatelessWidget {
  final int delta;

  const _MaterialDeltaBadge({required this.delta});

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
      constraints: const BoxConstraints(minWidth: 28),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
