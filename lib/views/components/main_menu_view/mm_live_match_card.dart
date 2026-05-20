import 'package:flutter/material.dart';

import '../shared/ranked_profile_avatar.dart';
import 'mm_models.dart';
import 'mm_palette.dart';

const _kPreviewAssets = [
  'assets/images/home/Chesspreview1.png',
  'assets/images/home/Chesspreview2.png',
  'assets/images/home/Chesspreview3.png',
  'assets/images/home/Chesspreview4.png',
  'assets/images/home/Chesspreview5.png',
];

// ─── One live-match card row ──────────────────────────────────────────────────
class LiveMatchCard extends StatelessWidget {
  final LiveMatch match;
  final int previewIndex;
  final ValueChanged<LiveMatch>? onWatchTap;

  const LiveMatchCard({
    super.key,
    required this.match,
    required this.previewIndex,
    this.onWatchTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final previewAsset = _kPreviewAssets[previewIndex % _kPreviewAssets.length];
    final cardHeight = isTablet ? 150.0 : 132.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 4 : 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        image: DecorationImage(
          image: AssetImage(previewAsset),
          fit: BoxFit.cover,
        ),
        border:
            Border.all(color: const Color(0xFFC49358).withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          splashColor: primary.withValues(alpha: 0.12),
          onTap: () => _onTap(),
          child: Column(
            children: [
              SizedBox(
                height: cardHeight,
                child: Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SidePlayer(
                          player: match.white,
                          alignRight: false,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _VsCenter(moveCount: match.moveCount),
                        ),
                        const SizedBox(width: 8),
                        _SidePlayer(
                          player: match.black,
                          alignRight: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTap() {
    onWatchTap?.call(match);
  }
}

class _SidePlayer extends StatelessWidget {
  final MatchPlayer player;
  final bool alignRight;

  const _SidePlayer({required this.player, required this.alignRight});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        RankedProfileAvatar(
          name: player.name,
          elo: player.elo,
          avatarSize: 46,
          badgeScale: 1.25,
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 72,
          child: Text(
            player.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VsCenter extends StatelessWidget {
  final int moveCount;

  const _VsCenter({required this.moveCount});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // VS title with a chess-themed gold capsule.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFEFCB8B), Color(0xFFC2803B)],
            ),
            border: Border.all(
              color: const Color(0xFFFFE3B6).withValues(alpha: 0.9),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            'VS',
            style: TextStyle(
              color: const Color(0xFF3B2311),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              fontFamily: 'Jura',
              letterSpacing: 1.4,
              shadows: [
                Shadow(
                  color: const Color(0xFFFFE8C5).withValues(alpha: 0.7),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
        // LIVE badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Jura',
                ),
              ),
              const SizedBox(width: 70),
              Icon(
                Icons.visibility_rounded,
                color: const Color(0xFFE8C695),
                size: 15,
              ),
              const SizedBox(width: 2),
              Text(
                '$moveCount',
                style: const TextStyle(
                  color: Color(0xFFF4DDB8),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Jura',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
