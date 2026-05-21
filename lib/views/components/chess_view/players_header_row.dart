import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../shared/ranked_profile_avatar.dart';

class MatchCornerProfile extends StatelessWidget {
  final String name;
  final int elo;
  final String eloLabel;
  final ValueListenable<Duration> totalTimeLeft;
  final bool showTotalTime;
  final String? avatarUrl;
  final bool isActive;
  final bool mirror;
  final int moveTimeLimitSeconds;
  final ValueListenable<Duration> moveTimeLeft;
  final VoidCallback onTap;
  final bool dockToMenu;
  final bool isTimerActive;

  const MatchCornerProfile({
    super.key,
    required this.name,
    required this.elo,
    required this.eloLabel,
    required this.totalTimeLeft,
    required this.showTotalTime,
    required this.avatarUrl,
    required this.isActive,
    required this.mirror,
    required this.moveTimeLimitSeconds,
    required this.moveTimeLeft,
    required this.onTap,
    this.dockToMenu = false,
    this.isTimerActive = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            dockToMenu ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        textDirection: mirror ? TextDirection.rtl : TextDirection.ltr,
        children: [
          _AvatarWithCountdown(
            name: name,
            elo: elo,
            avatarUrl: avatarUrl,
            isActive: isActive,
            moveTimeLimitSeconds: moveTimeLimitSeconds,
            moveTimeLeft: moveTimeLeft,
            dockToMenu: dockToMenu,
            isTimerActive: isTimerActive,
          ),
          const SizedBox(width: 8),
          _InfoPlates(
            name: name,
            eloLabel: eloLabel,
            totalTimeLeft: totalTimeLeft,
            showTotalTime: showTotalTime,
            mirror: mirror,
          ),
        ],
      ),
    );
  }
}

class _InfoPlates extends StatelessWidget {
  final String name;
  final String eloLabel;
  final ValueListenable<Duration> totalTimeLeft;
  final bool showTotalTime;
  final bool mirror;

  const _InfoPlates({
    required this.name,
    required this.eloLabel,
    required this.totalTimeLeft,
    required this.showTotalTime,
    required this.mirror,
  });

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hh = d.inHours;
    if (hh > 0) {
      return '$hh:$mm:$ss';
    }
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final align = mirror ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: align,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 150, maxWidth: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF6B4629), Color(0xFF3A2518)],
            ),
            border: Border.all(
              color: const Color(0xFFF3CE82).withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            name,
            textAlign: mirror ? TextAlign.end : TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFF9E3B8),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.25,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(minWidth: 92),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: const Color(0xFF4A2E1E).withValues(alpha: 0.92),
            border: Border.all(
              color: const Color(0xFFF3CE82).withValues(alpha: 0.38),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: mirror ? TextDirection.rtl : TextDirection.ltr,
            children: [
              const Icon(
                CupertinoIcons.clock_solid,
                size: 12,
                color: Color(0xFFF3CE82),
              ),
              const SizedBox(width: 5),
              if (showTotalTime)
                ValueListenableBuilder<Duration>(
                  valueListenable: totalTimeLeft,
                  builder: (_, value, __) => Text(
                    _fmt(value),
                    style: const TextStyle(
                      color: Color(0xFFF8D8A0),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Text(
                  eloLabel,
                  style: const TextStyle(
                    color: Color(0xFFF8D8A0),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvatarWithCountdown extends StatefulWidget {
  final String name;
  final int elo;
  final String? avatarUrl;
  final bool isActive;
  final int moveTimeLimitSeconds;
  final ValueListenable<Duration> moveTimeLeft;
  final bool dockToMenu;
  final bool isTimerActive;

  const _AvatarWithCountdown({
    required this.name,
    required this.elo,
    required this.avatarUrl,
    required this.isActive,
    required this.moveTimeLimitSeconds,
    required this.moveTimeLeft,
    required this.dockToMenu,
    this.isTimerActive = true,
  });

  @override
  State<_AvatarWithCountdown> createState() => _AvatarWithCountdownState();
}

class _AvatarWithCountdownState extends State<_AvatarWithCountdown>
    with SingleTickerProviderStateMixin {
  // Animates progress value (1.0 → 0.0) smoothly every frame.
  late AnimationController _countdown;

  @override
  void initState() {
    super.initState();
    _countdown = AnimationController(vsync: this, value: 1.0);
    widget.moveTimeLeft.addListener(_sync);
    _sync();
  }

  void _sync() {
    if (!mounted) return;
    if (!widget.isActive ||
        widget.moveTimeLimitSeconds <= 0 ||
        !widget.isTimerActive) {
      _countdown.stop();
      return;
    }
    final remaining = widget.moveTimeLeft.value;
    final totalMs = widget.moveTimeLimitSeconds * 1000.0;
    final progress = (remaining.inMilliseconds / totalMs).clamp(0.0, 1.0);
    _countdown.value = progress;
    if (remaining > Duration.zero) {
      _countdown.animateTo(0, duration: remaining, curve: Curves.linear);
    }
  }

  @override
  void didUpdateWidget(covariant _AvatarWithCountdown old) {
    super.didUpdateWidget(old);
    if (old.moveTimeLeft != widget.moveTimeLeft) {
      old.moveTimeLeft.removeListener(_sync);
      widget.moveTimeLeft.addListener(_sync);
    }
    if (old.isActive != widget.isActive ||
        old.moveTimeLimitSeconds != widget.moveTimeLimitSeconds ||
        old.isTimerActive != widget.isTimerActive) {
      _sync();
    }
  }

  @override
  void dispose() {
    widget.moveTimeLeft.removeListener(_sync);
    _countdown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showRing = widget.isActive && widget.moveTimeLimitSeconds > 0;
    return SizedBox(
      width: 80,
      height: widget.dockToMenu ? 74 : 100,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            child: SizedBox(
              width: 58,
              height: 58,
              child: AnimatedBuilder(
                animation: _countdown,
                builder: (_, __) => CustomPaint(
                  painter: _CountdownRingPainter(
                    progress: showRing ? _countdown.value : 1,
                    showProgress: showRing,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            child: RankedProfileAvatar(
              name: widget.name,
              elo: widget.elo,
              avatarUrl: widget.avatarUrl,
              avatarSize: 50,
              compactDecorations: true,
              badgeScale: 1.22,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownRingPainter extends CustomPainter {
  final double progress;
  final bool showProgress;

  _CountdownRingPainter({
    required this.progress,
    required this.showProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 1.5;

    // Gray background ring
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..color = const Color(0xFF8A8A8A).withValues(alpha: 0.35);
    canvas.drawCircle(center, radius, base);

    if (!showProgress) return;

    // Green arc — fixed at top (12 o'clock), sweeps clockwise → shrinks from left side
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.2
      ..color = const Color(0xFF4CAF50);

    // Positive sweep = clockwise (arc shrinks from left going clockwise)
    final sweep = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // fixed start: 12 o'clock (top)
      sweep,
      false,
      ring,
    );
  }

  @override
  bool shouldRepaint(covariant _CountdownRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.showProgress != showProgress;
  }
}
