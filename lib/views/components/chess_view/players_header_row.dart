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
  final int moveTimeLimitSeconds;
  final int player1MaterialDelta;
  final int player2MaterialDelta;
  final ValueListenable<Duration> player1TimeLeft;
  final ValueListenable<Duration> player2TimeLeft;
  final ValueListenable<Duration> moveTimeLeft;
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
    required this.moveTimeLimitSeconds,
    required this.player1MaterialDelta,
    required this.player2MaterialDelta,
    required this.player1TimeLeft,
    required this.player2TimeLeft,
    required this.moveTimeLeft,
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
        _MoveTimerBadge(
          moveTimeLeft: moveTimeLeft,
          moveTimeLimitSeconds: moveTimeLimitSeconds,
          gameOver: gameOver,
        ),
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

class _MoveTimerBadge extends StatelessWidget {
  final ValueListenable<Duration> moveTimeLeft;
  final int moveTimeLimitSeconds;
  final bool gameOver;

  const _MoveTimerBadge({
    required this.moveTimeLeft,
    required this.moveTimeLimitSeconds,
    required this.gameOver,
  });

  @override
  Widget build(BuildContext context) {
    if (moveTimeLimitSeconds == 0 || gameOver) {
      return const SizedBox(width: 8);
    }
    return ValueListenableBuilder<Duration>(
      valueListenable: moveTimeLeft,
      builder: (_, duration, __) {
        final secs = duration.inSeconds;
        final Color color;
        if (secs <= 5) {
          color = const Color(0xFFE05C5C);
        } else if (secs <= 10) {
          color = const Color(0xFFE8A23A);
        } else {
          color = Colors.white70;
        }
        return Container(
          width: 38,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$secs',
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              Icon(
                CupertinoIcons.timer,
                color: color.withValues(alpha: 0.55),
                size: 9,
              ),
            ],
          ),
        );
      },
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
        ? primaryLight.withValues(alpha: 0.55)
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
                bgCard.withValues(alpha: 0.9),
                const Color(0xFF0A1730).withValues(alpha: 0.92),
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
                      color: bgMid.withValues(alpha: 0.82),
                      border: Border.all(
                        color: isActive
                            ? primaryLight.withValues(alpha: 0.7)
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
    if (d.inHours > 0) {
      final h = d.inHours.toString();
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      // No time limit — show infinity symbol
      return AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.clock_fill, size: 10, color: Colors.white30),
            SizedBox(width: 4),
            Text(
              '∞',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    final secs = duration.inSeconds;
    final isCritical = secs <= 10;
    final isWarning = secs <= 30 && secs > 10;

    final Color accentColor;
    if (isCritical) {
      accentColor = const Color(0xFFE05C5C); // red
    } else if (isWarning) {
      accentColor = const Color(0xFFE8A23A); // amber
    } else if (isActive) {
      accentColor = primaryLight;
    } else {
      accentColor = Colors.white54;
    }

    final List<Color> gradientColors;
    if (isCritical && isActive) {
      gradientColors = [
        const Color(0xFFE05C5C).withValues(alpha: 0.35),
        bgCard,
      ];
    } else if (isWarning && isActive) {
      gradientColors = [
        const Color(0xFFE8A23A).withValues(alpha: 0.28),
        bgCard,
      ];
    } else if (isActive) {
      gradientColors = [primary.withValues(alpha: 0.35), bgCard];
    } else {
      gradientColors = [
        Colors.white.withValues(alpha: 0.08),
        Colors.white.withValues(alpha: 0.03),
      ];
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        border: Border.all(
          color: isActive
              ? accentColor.withValues(alpha: 0.62)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.clock_fill, size: 10, color: accentColor),
          const SizedBox(width: 4),
          Text(
            _fmt(duration),
            style: TextStyle(
              color: isActive
                  ? (isCritical || isWarning ? accentColor : Colors.white)
                  : Colors.white60,
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
