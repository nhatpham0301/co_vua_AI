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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1E1C7),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFBE945F).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8D6339).withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: primary.withValues(alpha: 0.12),
          onTap: () => _onTap(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    _LiveBadge(),
                    const Spacer(),
                    Text(
                      _fmt(match.elapsedSec),
                      style: const TextStyle(
                        color: Color(0xFF654225),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child:
                          _SidePlayer(player: match.white, alignRight: false),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      children: [
                        MiniChessBoard(board: match.board),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility_rounded,
                              color: const Color(0xFF8F6A43)
                                  .withValues(alpha: 0.92),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${match.moveCount}',
                              style: const TextStyle(
                                color: Color(0xFF5B3A21),
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Jura',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SidePlayer(player: match.black, alignRight: true),
                    ),
                  ],
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

// ─── LIVE pill badge ─────────────────────────────────────────────────────────
class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFB84739),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        l.live,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SidePlayer extends StatelessWidget {
  final MatchPlayer player;
  final bool alignRight;

  const _SidePlayer({required this.player, required this.alignRight});

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length.clamp(0, 2))
          .toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final textAlign = alignRight ? TextAlign.right : TextAlign.left;
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFD8A968), Color(0xFF9D6532)],
            ),
            border: Border.all(color: const Color(0xFFF6D9A9), width: 1.4),
          ),
          child: Center(
            child: Text(
              _initials(player.name),
              style: const TextStyle(
                color: Color(0xFF4C2E17),
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          player.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: const TextStyle(
            color: Color(0xFF573721),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          'A${player.elo}',
          textAlign: textAlign,
          style: TextStyle(
            color: const Color(0xFF5F3B22).withValues(alpha: 0.85),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
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
      width: 110,
      height: 76,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE2B875), Color(0xFFBD7E3D)],
        ),
        border:
            Border.all(color: const Color(0xFFF2D3A2).withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
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
    final light = Paint()..color = const Color(0xFFEBCB95);
    final dark = Paint()..color = const Color(0xFFB88347);
    final pieceW = Paint()..color = const Color(0xFFF7E5C8);
    final pieceB = Paint()..color = const Color(0xFF6F4221);

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
