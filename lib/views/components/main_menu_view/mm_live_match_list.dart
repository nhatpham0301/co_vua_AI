import 'package:flutter/cupertino.dart';

import 'mm_live_match_card.dart';
import 'mm_models.dart';
import 'mm_palette.dart';
import 'mm_saved_game_card.dart';

// ─── Scrollable live match list with pull-to-refresh ─────────────────────────
class LiveMatchList extends StatelessWidget {
  final List<LiveMatch> matches;
  final Future<void> Function() onRefresh;
  final bool hasSavedGame;
  final double bottomPadding;
  final ValueChanged<LiveMatch>? onWatchTap;

  const LiveMatchList({
    super.key,
    required this.matches,
    required this.onRefresh,
    required this.hasSavedGame,
    required this.bottomPadding,
    this.onWatchTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: onRefresh,
          builder: (context, mode, pulledExtent, threshold, snap) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: CupertinoActivityIndicator(color: primary),
              ),
            );
          },
        ),
        if (hasSavedGame)
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(12, 2, 12, 0),
            sliver: SliverToBoxAdapter(child: SavedGameCard()),
          ),
        if (isTablet)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: LiveMatchCard(
                    match: matches[index],
                    previewIndex: index,
                    onWatchTap: onWatchTap,
                  ),
                ),
                childCount: matches.length,
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(12, 2, 12, bottomPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 2),
                ...matches.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: LiveMatchCard(
                        match: entry.value,
                        previewIndex: entry.key,
                        onWatchTap: onWatchTap,
                      ),
                    )),
              ]),
            ),
          ),
      ],
    );
  }
}
