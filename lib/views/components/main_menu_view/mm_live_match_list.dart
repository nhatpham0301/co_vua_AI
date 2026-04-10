import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'mm_live_match_card.dart';
import 'mm_models.dart';
import 'mm_palette.dart';
import 'mm_saved_game_card.dart';

// ─── Scrollable live match list with pull-to-refresh ─────────────────────────
class LiveMatchList extends StatelessWidget {
  final List<LiveMatch> matches;
  final VoidCallback onRefresh;
  final bool hasSavedGame;
  final double bottomPadding;

  const LiveMatchList({
    super.key,
    required this.matches,
    required this.onRefresh,
    required this.hasSavedGame,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () async => onRefresh(),
          builder: (context, mode, pulledExtent, threshold, snap) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: CupertinoActivityIndicator(color: primary),
              ),
            );
          },
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(14, 12, 14, bottomPadding),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const _SectionHeader(),
              const SizedBox(height: 10),
              if (hasSavedGame) ...[
                const SavedGameCard(),
                const SizedBox(height: 8),
              ],
              ...matches.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LiveMatchCard(match: m),
                  )),
            ]),
          ),
        ),
      ],
    );
  }
}

// ─── "TRẬN ĐANG DIỄN RA (LIVE)" section header ───────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'TRẬN ĐANG DIỄN RA',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: primary.withValues(alpha: 0.5)),
          ),
          child: const Text(
            'LIVE',
            style: TextStyle(
              color: primaryLight,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
