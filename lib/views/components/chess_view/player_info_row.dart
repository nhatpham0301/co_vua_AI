import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../main_menu_view/mm_palette.dart';

class PlayerInfoRow extends StatelessWidget {
  final String name;
  final String subtitle;
  final ValueListenable<Duration> timeLeft;
  final bool isActive;
  final bool hasTimer;
  final bool isBot;
  final int materialDelta;
  final VoidCallback onTapPlayer;

  const PlayerInfoRow({
    super.key,
    required this.name,
    required this.subtitle,
    required this.timeLeft,
    required this.isActive,
    required this.hasTimer,
    required this.isBot,
    required this.materialDelta,
    required this.onTapPlayer,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isActive ? const Color(0xFF8FCB81) : Colors.white54;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF20272F).withValues(alpha: 0.88),
            const Color(0xFF14191F).withValues(alpha: 0.92),
          ],
        ),
        border: Border.all(
          color: isActive
              ? const Color(0xFF769F67).withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.07),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF324B35)
                      .withValues(alpha: isActive ? 0.9 : 0.6),
                  const Color(0xFF1B232B),
                ],
              ),
              border: Border.all(
                color: isActive
                    ? const Color(0xFF9AD67D).withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.12),
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: isActive ? 0.25 : 0.08),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Icon(
              isBot ? Icons.smart_toy_rounded : Icons.person_rounded,
              color: isBot ? primaryLight : Colors.white70,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTapPlayer,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            CupertinoIcons.chevron_up_chevron_down,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.emoji_events_rounded,
                            color: goldMid.withValues(alpha: 0.9),
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.56),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _MaterialDeltaPill(delta: materialDelta),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (hasTimer)
            ValueListenableBuilder<Duration>(
              valueListenable: timeLeft,
              builder: (_, duration, __) {
                return _TimerPill(duration: duration, isActive: isActive);
              },
            ),
        ],
      ),
    );
  }
}

class _TimerPill extends StatelessWidget {
  final Duration duration;
  final bool isActive;

  const _TimerPill({required this.duration, required this.isActive});

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isActive
              ? [
                  const Color(0xFF3D6F49).withValues(alpha: 0.95),
                  const Color(0xFF22382C),
                ]
              : [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.03),
                ],
        ),
        border: Border.all(
          color: isActive
              ? const Color(0xFF9BC885).withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.12),
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF7CC36A).withValues(alpha: 0.16),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.clock_fill,
            size: 12,
            color: isActive ? primaryLight : Colors.white38,
          ),
          const SizedBox(width: 5),
          Text(
            _fmt(duration),
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white60,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialDeltaPill extends StatelessWidget {
  final int delta;

  const _MaterialDeltaPill({required this.delta});

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
