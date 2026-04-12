import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../shared/app_dialog.dart';
import 'mm_models.dart';
import 'mm_palette.dart';

// ─── One live-match card row ──────────────────────────────────────────────────
class LiveMatchCard extends StatelessWidget {
  final LiveMatch match;
  const LiveMatchCard({super.key, required this.match});

  String _fmt(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          splashColor: primary.withValues(alpha: 0.08),
          onTap: () => _onTap(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                // ── Left: mini board preview ──────────────────────────
                MiniChessBoard(board: match.board),
                const SizedBox(width: 14),

                // ── Middle: LIVE badge + timer + players ──────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _LiveBadge(),
                          const Spacer(),
                          Text(
                            _fmt(match.elapsedSec),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      PlayerRow(player: match.white),
                      const SizedBox(height: 6),
                      PlayerRow(player: match.black),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // ── Right: XEM button ─────────────────────────────────
                _WatchButton(onTap: () => _onTap(context)),
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

// ─── LIVE pill badge ──────────────────────────────────────────────────────────
class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: primary.withValues(alpha: 0.55)),
      ),
      child: Text(
        l.live,
        style: TextStyle(
          color: primaryLight,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─── "XEM" watch button ───────────────────────────────────────────────────────
class _WatchButton extends StatelessWidget {
  final VoidCallback onTap;
  const _WatchButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          l.watch,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ─── Single player name row ───────────────────────────────────────────────────
class PlayerRow extends StatelessWidget {
  final MatchPlayer player;
  const PlayerRow({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            '${player.name} (${player.elo})',
            style: TextStyle(
              color: player.isBot
                  ? Colors.white.withValues(alpha: 0.75)
                  : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (player.isBot) ...[
          const SizedBox(width: 4),
          const Icon(Icons.bolt_rounded, color: primaryLight, size: 14),
        ],
      ],
    );
  }
}

// ─── 8×8 mini chess board preview ────────────────────────────────────────────
class MiniChessBoard extends StatelessWidget {
  final List<List<bool>> board;
  const MiniChessBoard({super.key, required this.board});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primary.withValues(alpha: 0.25), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: CustomPaint(painter: _MiniChessPainter(board: board)),
      ),
    );
  }
}

class _MiniChessPainter extends CustomPainter {
  final List<List<bool>> board;
  const _MiniChessPainter({required this.board});

  @override
  void paint(Canvas canvas, Size size) {
    const n = 8;
    final cw = size.width / n;
    final ch = size.height / n;
    final light = Paint()..color = const Color(0xFF1A3560);
    final dark = Paint()..color = const Color(0xFF0D2040);
    final pieceW = Paint()..color = Colors.white.withValues(alpha: 0.85);
    final pieceB = Paint()..color = const Color(0xFF00B4D8);

    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        canvas.drawRect(
          Rect.fromLTWH(c * cw, r * ch, cw, ch),
          (r + c).isEven ? light : dark,
        );
        if (r < board.length && c < board[r].length && board[r][c]) {
          final center = Offset(c * cw + cw / 2, r * ch + ch / 2);
          canvas.drawCircle(
              center, cw * 0.27, (r + c).isEven ? pieceB : pieceW);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_MiniChessPainter old) => false;
}
