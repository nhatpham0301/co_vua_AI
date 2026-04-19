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
  final bool compactDecorations;
  final bool hideAvatar;
  final double badgeScale;
  final EdgeInsetsGeometry margin;

  const RankedProfileAvatar({
    super.key,
    required this.name,
    required this.elo,
    this.avatarUrl,
    this.avatarSize = 72,
    this.showBadge = true,
    this.showStars = true,
    this.compactDecorations = false,
    this.hideAvatar = true,
    this.badgeScale = 1.0,
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

    final badgeHeight =
        avatarSize * (compactDecorations ? 0.92 : 1.0) * badgeScale;
    final starSize = avatarSize * (compactDecorations ? 0.36 : 0.30);
    final avatarInset = avatarSize * (compactDecorations ? 0.16 : 0.15);
    final frameHeight = avatarSize;
    final sidePadding = compactDecorations ? 10.0 : 18.0;

    return Container(
      margin: margin,
      width: avatarSize + sidePadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: avatarSize,
            height: frameHeight,
            child: Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                if (showBadge)
                  SizedBox(
                    width: avatarSize,
                    height: avatarSize,
                    child: Image.asset(
                      rankBadgePath,
                      height: badgeHeight,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          SizedBox(height: badgeHeight),
                    ),
                  ),
                if (!hideAvatar)
                  Positioned(
                    top: avatarInset,
                    left: avatarInset,
                    right: avatarInset,
                    bottom: avatarInset,
                    child: ClipOval(child: _buildAvatarContent()),
                  ),
                if (!showBadge)
                  Positioned.fill(
                    child: Image.asset(
                      rankBadgePath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          SizedBox(height: badgeHeight),
                    ),
                  ),
              ],
            ),
          ),
          if (showStars)
            Padding(
              padding: EdgeInsets.only(top: compactDecorations ? 0 : 0.5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  // final active = index < starCount;
                  final active = true;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: Icon(
                      active ? Icons.star_rounded : Icons.star_border_rounded,
                      size: starSize,
                      color: active
                          ? const Color(0xFFFFD43C)
                          : const Color(0xFF6E542E),
                    ),
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
