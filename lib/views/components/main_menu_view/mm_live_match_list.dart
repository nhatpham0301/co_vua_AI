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
        SliverPadding(
          padding: EdgeInsets.fromLTRB(12, 2, 12, bottomPadding),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 2),
              if (hasSavedGame) ...[
                const SavedGameCard(),
                const SizedBox(height: 8),
              ],
              ...matches.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: LiveMatchCard(
                      match: entry.value,
                      previewIndex: entry.key,
                    ),
                  )),
            ]),
          ),
        ),
      ],
    );
  }
}
