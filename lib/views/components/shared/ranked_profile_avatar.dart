import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../logic/rank_system.dart';

class RankedProfileAvatar extends StatelessWidget {
  final String name;
  final int elo;
  final String? avatarUrl;
  final double avatarSize;
  final bool showBadge;
  final bool showStars;
  final EdgeInsetsGeometry margin;

  const RankedProfileAvatar({
    super.key,
    required this.name,
    required this.elo,
    this.avatarUrl,
    this.avatarSize = 72,
    this.showBadge = true,
    this.showStars = true,
    this.margin = EdgeInsets.zero,
  });

  int _starCountForRank(int rank) {
    if (rank <= 2) return 2;
    return 3;
  }

  String _initials(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      final word = parts.first;
      return word.substring(0, word.length.clamp(0, 2)).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final rank = RankSystem.getRankFromElo(elo);
    final rankBadgePath = RankSystem.getRankBadgePath(elo);
    final starCount = _starCountForRank(rank);
    final badgeHeight = avatarSize * 0.48;
    final starSize = avatarSize * 0.26;

    return Container(
      margin: margin,
      width: avatarSize + 18,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF1C57D), width: 2.6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(child: _buildAvatarContent()),
          ),
          if (showBadge)
            Transform.translate(
              offset: const Offset(0, -25),
              child: Image.asset(
                rankBadgePath,
                height: badgeHeight,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => SizedBox(height: badgeHeight),
              ),
            ),
          if (showStars)
            Transform.translate(
              offset: Offset(0, showBadge ? -38 : -2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return Icon(
                    Icons.star_rounded,
                    size: starSize,
                    color: index < starCount
                        ? const Color(0xFFFFD43C)
                        : const Color(0xFF4E381E),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarContent() {
    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: avatarUrl!.trim(),
        fit: BoxFit.cover,
        placeholder: (_, __) => const ColoredBox(
          color: Color(0xFF4B2C1A),
          child: Center(
            child: CupertinoActivityIndicator(color: Color(0xFFF2CA84)),
          ),
        ),
        errorWidget: (_, __, ___) => _buildFallbackAvatar(),
      );
    }

    return _buildFallbackAvatar();
  }

  Widget _buildFallbackAvatar() {
    return Container(
      color: const Color(0xFF6B4528),
      alignment: Alignment.center,
      child: Text(
        _initials(name),
        style: TextStyle(
          color: const Color(0xFFF7DEB0),
          fontSize: avatarSize * 0.34,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
