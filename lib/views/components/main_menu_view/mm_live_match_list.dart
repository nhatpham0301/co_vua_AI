import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
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
          padding: EdgeInsets.fromLTRB(14, 8, 14, bottomPadding),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const _SectionHeader(),
              const SizedBox(height: 8),
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
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFDEC7A7),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: const Color(0xFFB58752).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Text(
            l.liveMatchesTitle,
            style: const TextStyle(
              color: Color(0xFF5A3821),
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFB64537),
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
