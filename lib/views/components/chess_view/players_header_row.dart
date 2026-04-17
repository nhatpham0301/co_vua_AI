import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../main_menu_view/mm_palette.dart';

class MatchCornerProfile extends StatelessWidget {
  final String name;
  final String eloLabel;
  final ValueListenable<Duration> totalTimeLeft;
  final bool showTotalTime;
  final String? avatarUrl;
  final bool isBot;
  final bool isActive;
  final bool mirror;
  final int moveTimeLimitSeconds;
  final ValueListenable<Duration> moveTimeLeft;
  final VoidCallback onTap;

  const MatchCornerProfile({
    super.key,
    required this.name,
    required this.eloLabel,
    required this.totalTimeLeft,
    required this.showTotalTime,
    required this.avatarUrl,
    required this.isBot,
    required this.isActive,
    required this.mirror,
    required this.moveTimeLimitSeconds,
    required this.moveTimeLeft,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: mirror ? TextDirection.rtl : TextDirection.ltr,
        children: [
          _AvatarWithCountdown(
            avatarUrl: avatarUrl,
            isBot: isBot,
            isActive: isActive,
            fallbackText: name,
            moveTimeLimitSeconds: moveTimeLimitSeconds,
            moveTimeLeft: moveTimeLeft,
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

class _AvatarWithCountdown extends StatelessWidget {
  final String? avatarUrl;
  final bool isBot;
  final bool isActive;
  final String fallbackText;
  final int moveTimeLimitSeconds;
  final ValueListenable<Duration> moveTimeLeft;

  const _AvatarWithCountdown({
    required this.avatarUrl,
    required this.isBot,
    required this.isActive,
    required this.fallbackText,
    required this.moveTimeLimitSeconds,
    required this.moveTimeLeft,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: ValueListenableBuilder<Duration>(
        valueListenable: moveTimeLeft,
        builder: (_, value, __) {
          final total = moveTimeLimitSeconds <= 0 ? 1 : moveTimeLimitSeconds;
          final progress = (value.inMilliseconds / (total * 1000))
              .clamp(0.0, 1.0)
              .toDouble();

          return CustomPaint(
            painter: _CountdownRingPainter(
              progress: isActive && moveTimeLimitSeconds > 0 ? progress : 1,
              showProgress: isActive && moveTimeLimitSeconds > 0,
            ),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: goldMid.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF694227), Color(0xFF2F1D12)],
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildAvatar(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatar() {
    if (isBot) {
      return const Icon(Icons.smart_toy_rounded, color: Color(0xFFF3C97A));
    }

    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: avatarUrl!.trim(),
        fit: BoxFit.cover,
        placeholder: (context, _) => const Center(
          child: CupertinoActivityIndicator(color: Colors.white70),
        ),
        errorWidget: (context, _, __) => _fallbackText(),
      );
    }

    return _fallbackText();
  }

  Widget _fallbackText() {
    final c = fallbackText.isEmpty ? '?' : fallbackText.trim().characters.first;
    return Center(
      child: Text(
        c.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CountdownRingPainter extends CustomPainter {
  final double progress;
  final bool showProgress;

  _CountdownRingPainter({required this.progress, required this.showProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 1.5;

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..color = Colors.white.withValues(alpha: 0.2);

    canvas.drawCircle(center, radius, base);

    if (!showProgress) return;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.2
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 1.5 * math.pi,
        colors: const [
          Color(0xFFE15757),
          Color(0xFFE3A64A),
          Color(0xFFF3CE82),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    final sweep = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
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
