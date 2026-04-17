import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../shared/app_dialog.dart';
import '../shared/ranked_profile_avatar.dart';
import 'mm_models.dart';
import 'mm_palette.dart';

// ─── One live-match card row ──────────────────────────────────────────────────
class LiveMatchCard extends StatelessWidget {
  final LiveMatch match;
  final int previewIndex;

  const LiveMatchCard({
    super.key,
    required this.match,
    required this.previewIndex,
  });

  String _fmt(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6C4124), Color(0xFF4E2F1A)],
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
          onTap: () => _onTap(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      match.white.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFF2D8B0),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 132,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        top: 26,
                        bottom: 16,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF7F4D28), Color(0xFF5B351B)],
                            ),
                            border: Border.all(
                              color: const Color(0xFFC79A63)
                                  .withValues(alpha: 0.32),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SidePlayer(
                            player: match.white,
                            alignRight: false,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                MatchPreviewBoard(previewIndex: previewIndex),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Icon(
                                      Icons.visibility_rounded,
                                      color: const Color(0xFFE8C695),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${match.moveCount}',
                                      style: const TextStyle(
                                        color: Color(0xFFF4DDB8),
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'Jura',
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Flexible(
                                      child: Text(
                                        'LIVE',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Color(0xFFFF7E2E),
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          fontFamily: 'Jura',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
      ),
    );
  }

  void _onTap(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    showAppDialog<void>(
      context: context,
      title: l.watchMatchTitle,
      message: l.watchMatchComingSoon,
      actions: [
        AppDialogAction(label: l.ok, isPrimary: true),
      ],
    );
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
          avatarSize: 62,
        ),
      ],
    );
  }
}

class MatchPreviewBoard extends StatelessWidget {
  final int previewIndex;

  static const List<String> _previewAssets = [
    'assets/images/home/Chesspreview1.png',
    'assets/images/home/Chesspreview2.png',
    'assets/images/home/Chesspreview3.png',
    'assets/images/home/Chesspreview4.png',
    'assets/images/home/Chesspreview5.png',
  ];

  const MatchPreviewBoard({
    super.key,
    required this.previewIndex,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = _previewAssets[previewIndex % _previewAssets.length];
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardWidth = constraints.maxWidth.clamp(120.0, 250.0).toDouble();
        return Container(
          width: boardWidth,
          height: 74,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE2B875), Color(0xFFBD7E3D)],
            ),
            border: Border.all(
                color: const Color(0xFFF2D3A2).withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
        );
      },
    );
  }
}
