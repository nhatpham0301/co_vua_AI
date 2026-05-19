import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/shared_functions.dart';
import '../model/api_models.dart';
import '../model/app_model.dart';

// ─── FEN Parser ───────────────────────────────────────────────────────────────
// Returns a 64-element list. Index 0 = a8 (top-left from white's perspective)
// Index 7 = h8, index 56 = a1, index 63 = h1.
// null means empty square; strings like 'wK', 'bP', etc.
List<String?> parseFenPieces(String fen) {
  final parts = fen.split(' ');
  final ranks = parts[0].split('/');
  final board = List<String?>.filled(64, null);
  int tile = 0;
  for (final rank in ranks) {
    for (final ch in rank.runes.map(String.fromCharCode)) {
      final num = int.tryParse(ch);
      if (num != null) {
        tile += num;
      } else {
        final isWhite = ch == ch.toUpperCase();
        final colorPrefix = isWhite ? 'w' : 'b';
        final pieceLetter = ch.toLowerCase();
        board[tile] = '$colorPrefix$pieceLetter';
        tile++;
      }
    }
  }
  return board;
}

// Convert algebraic square (e.g. "e4") to board tile index (0=a8, 63=h8→h1)
int algebraicToTile(String sq) {
  if (sq.length < 2) return -1;
  final file = sq.codeUnitAt(0) - 'a'.codeUnitAt(0); // 0-7
  final rank = sq.codeUnitAt(1) - '1'.codeUnitAt(0); // 0-7 (0=rank1)
  return (7 - rank) * 8 + file;
}

// ─── Review Board Painter (for arrow overlay) ────────────────────────────────
class _ArrowPainter extends CustomPainter {
  final String from;
  final String to;
  final double boardSize;

  const _ArrowPainter({required this.from, required this.to, required this.boardSize});

  @override
  void paint(Canvas canvas, Size size) {
    if (from.length < 2 || to.length < 2) return;

    final tileSize = boardSize / 8;
    final fromFile = from.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final fromRank = 7 - (from.codeUnitAt(1) - '1'.codeUnitAt(0));
    final toFile = to.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final toRank = 7 - (to.codeUnitAt(1) - '1'.codeUnitAt(0));

    final fromCenter = Offset(
      fromFile * tileSize + tileSize / 2,
      fromRank * tileSize + tileSize / 2,
    );
    final toCenter = Offset(
      toFile * tileSize + tileSize / 2,
      toRank * tileSize + tileSize / 2,
    );

    const color = Color(0xCCFFD700); // golden arrow
    final paint = Paint()
      ..color = color
      ..strokeWidth = tileSize * 0.12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw shaft
    final dx = toCenter.dx - fromCenter.dx;
    final dy = toCenter.dy - fromCenter.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    final arrowHeadLen = tileSize * 0.28;
    final shaftEndX = fromCenter.dx + dx * (1 - arrowHeadLen / len);
    final shaftEndY = fromCenter.dy + dy * (1 - arrowHeadLen / len);
    canvas.drawLine(fromCenter, Offset(shaftEndX, shaftEndY), paint);

    // Draw arrowhead
    final angle = math.atan2(dy, dx);
    final headPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(toCenter.dx, toCenter.dy);
    path.lineTo(
      toCenter.dx - arrowHeadLen * math.cos(angle - 0.5),
      toCenter.dy - arrowHeadLen * math.sin(angle - 0.5),
    );
    path.lineTo(
      toCenter.dx - arrowHeadLen * math.cos(angle + 0.5),
      toCenter.dy - arrowHeadLen * math.sin(angle + 0.5),
    );
    path.close();
    canvas.drawPath(path, headPaint);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.from != from || old.to != to;
}

// ─── Review Board Widget ──────────────────────────────────────────────────────
class _ReviewBoard extends StatelessWidget {
  final String fen;
  final String? highlightFrom;
  final String? highlightTo;
  final String? arrowFrom;
  final String? arrowTo;
  final AppModel appModel;

  const _ReviewBoard({
    required this.fen,
    required this.appModel,
    this.highlightFrom,
    this.highlightTo,
    this.arrowFrom,
    this.arrowTo,
  });

  String _pieceImagePath(String piece) {
    final theme = formatPieceTheme(appModel.pieceTheme);
    final color = piece[0] == 'w' ? 'white' : 'black';
    final typeMap = {
      'k': 'king',
      'q': 'queen',
      'r': 'rook',
      'b': 'bishop',
      'n': 'knight',
      'p': 'pawn',
    };
    final name = typeMap[piece[1]] ?? 'pawn';
    return 'assets/images/pieces/$theme/${name}_$color.png';
  }

  @override
  Widget build(BuildContext context) {
    final boardSize = MediaQuery.of(context).size.width - 32;
    final tileSize = boardSize / 8;
    final pieces = parseFenPieces(fen);
    final theme = appModel.theme;

    final fromTile = highlightFrom != null ? algebraicToTile(highlightFrom!) : -1;
    final toTile = highlightTo != null ? algebraicToTile(highlightTo!) : -1;

    return SizedBox(
      width: boardSize,
      height: boardSize,
      child: Stack(
        children: [
          // Board squares + pieces
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
            ),
            itemCount: 64,
            itemBuilder: (ctx, tile) {
              final row = tile ~/ 8;
              final col = tile % 8;
              final isLight = (row + col) % 2 == 0;
              final isHighlighted = tile == fromTile || tile == toTile;

              Color tileColor;
              if (isHighlighted) {
                tileColor = theme.latestMove;
              } else {
                tileColor = isLight ? theme.lightTile : theme.darkTile;
              }

              final piece = pieces[tile];

              return Container(
                color: tileColor,
                child: piece != null
                    ? Padding(
                        padding: EdgeInsets.all(tileSize * 0.04),
                        child: Image.asset(
                          _pieceImagePath(piece),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      )
                    : null,
              );
            },
          ),
          // Arrow overlay
          if (arrowFrom != null && arrowTo != null)
            Positioned.fill(
              child: CustomPaint(
                painter: _ArrowPainter(
                  from: arrowFrom!,
                  to: arrowTo!,
                  boardSize: boardSize,
                ),
              ),
            ),
          // File labels (a-h) bottom
          ...List.generate(8, (col) {
            final letter = String.fromCharCode('a'.codeUnitAt(0) + col);
            return Positioned(
              bottom: 2,
              left: col * tileSize + tileSize - 10,
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 9,
                  color: (col % 2 == 0 ? theme.darkTile : theme.lightTile)
                      .withValues(alpha: 0.85),
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }),
          // Rank labels (1-8) left side
          ...List.generate(8, (row) {
            final digit = '${8 - row}';
            return Positioned(
              top: row * tileSize + 2,
              left: 2,
              child: Text(
                digit,
                style: TextStyle(
                  fontSize: 9,
                  color: (row % 2 == 0 ? theme.darkTile : theme.lightTile)
                      .withValues(alpha: 0.85),
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Main Review View ─────────────────────────────────────────────────────────
class GameReviewView extends StatefulWidget {
  final GameHistoryItem game;

  const GameReviewView({super.key, required this.game});

  @override
  State<GameReviewView> createState() => _GameReviewViewState();
}

class _GameReviewViewState extends State<GameReviewView> {
  List<OnlineMoveRecord> _moves = [];
  bool _isLoadingMoves = true;
  int _currentIndex = -1; // -1 = initial position; 0 = after move[0], etc.
  PositionAnalysis? _analysis;
  bool _isAnalyzing = false;
  String? _analyzeError;
  final _moveListScrollController = ScrollController();

  static const String _initialFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  @override
  void initState() {
    super.initState();
    _loadMoves();
  }

  @override
  void dispose() {
    _moveListScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMoves() async {
    final appModel = Provider.of<AppModel>(context, listen: false);
    try {
      final moves = await appModel.apiClient.fetchGameMoves(widget.game.id);
      if (mounted) {
        setState(() {
          _moves = moves;
          _isLoadingMoves = false;
          // Start at final position
          _currentIndex = moves.length - 1;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMoves = false;
          _analyzeError = 'Không tải được nước đi: $e';
        });
      }
    }
  }

  String get _currentFen {
    if (_moves.isEmpty || _currentIndex < 0) return _initialFen;
    return _moves[_currentIndex].fenAfter;
  }

  String? get _currentFromSquare {
    if (_currentIndex < 0 || _currentIndex >= _moves.length) return null;
    return _moves[_currentIndex].fromSquare;
  }

  String? get _currentToSquare {
    if (_currentIndex < 0 || _currentIndex >= _moves.length) return null;
    return _moves[_currentIndex].toSquare;
  }

  // The FEN BEFORE the current move (so we can analyze what was played)
  String get _fenBeforeCurrentMove {
    if (_currentIndex <= 0) return _initialFen;
    return _moves[_currentIndex - 1].fenAfter;
  }

  String? get _playedMoveUci {
    if (_currentIndex < 0 || _currentIndex >= _moves.length) return null;
    final m = _moves[_currentIndex];
    final promo = m.promotion ?? '';
    return '${m.fromSquare}${m.toSquare}$promo';
  }

  Future<void> _analyze() async {
    if (_currentIndex < 0 || _isAnalyzing) return;
    final appModel = Provider.of<AppModel>(context, listen: false);

    setState(() {
      _isAnalyzing = true;
      _analyzeError = null;
      _analysis = null;
    });

    try {
      final result = await appModel.apiClient.analyzePosition(
        fen: _fenBeforeCurrentMove,
        playedMove: _playedMoveUci,
        level: 8,
      );
      if (mounted) setState(() => _analysis = result);
    } catch (e) {
      if (mounted) {
        setState(() => _analyzeError = 'Lỗi phân tích: $e');
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _goTo(int index) {
    setState(() {
      _currentIndex = index.clamp(-1, _moves.length - 1);
      _analysis = null;
      _analyzeError = null;
    });
    _scrollMoveListTo(_currentIndex);
  }

  void _scrollMoveListTo(int index) {
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_moveListScrollController.hasClients) return;
      const rowWidth = 90.0;
      final targetOffset = (index ~/ 2) * rowWidth;
      _moveListScrollController.animateTo(
        targetOffset.clamp(0.0, _moveListScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  String _gameResultLabel() {
    switch (widget.game.result) {
      case 'white':
        return 'Trắng thắng';
      case 'black':
        return 'Đen thắng';
      case 'draw':
        return 'Hòa';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final appModel = Provider.of<AppModel>(context, listen: false);

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF1A140E),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xFF2A1F14),
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.back, color: Color(0xFFE8BE75)),
        ),
        middle: Text(
          'vs ${widget.game.opponentName}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        trailing: Text(
          _gameResultLabel(),
          style: const TextStyle(color: Color(0xFFB0A090), fontSize: 12),
        ),
      ),
      child: SafeArea(
        child: _isLoadingMoves
            ? const Center(
                child: CupertinoActivityIndicator(color: Colors.white54),
              )
            : Column(
                children: [
                  // ── Board ──────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _ReviewBoard(
                      fen: _currentFen,
                      appModel: appModel,
                      highlightFrom: _currentFromSquare,
                      highlightTo: _currentToSquare,
                      arrowFrom: _analysis?.bestMove.from,
                      arrowTo: _analysis?.bestMove.to,
                    ),
                  ),
                  // ── Navigation controls ────────────────────────────────────
                  _NavigationBar(
                    currentIndex: _currentIndex,
                    total: _moves.length,
                    onFirst: () => _goTo(-1),
                    onPrev: () => _goTo(_currentIndex - 1),
                    onNext: () => _goTo(_currentIndex + 1),
                    onLast: () => _goTo(_moves.length - 1),
                  ),
                  // ── Move list ──────────────────────────────────────────────
                  _MoveList(
                    moves: _moves,
                    currentIndex: _currentIndex,
                    scrollController: _moveListScrollController,
                    onTap: _goTo,
                  ),
                  const Divider(color: Color(0xFF3A2A1A), height: 1),
                  // ── Analysis panel ─────────────────────────────────────────
                  Expanded(
                    child: _AnalysisPanel(
                      analysis: _analysis,
                      isAnalyzing: _isAnalyzing,
                      error: _analyzeError,
                      canAnalyze: _currentIndex >= 0 && _moves.isNotEmpty,
                      onAnalyze: _analyze,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Navigation Bar ───────────────────────────────────────────────────────────
class _NavigationBar extends StatelessWidget {
  final int currentIndex;
  final int total;
  final VoidCallback onFirst;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onLast;

  const _NavigationBar({
    required this.currentIndex,
    required this.total,
    required this.onFirst,
    required this.onPrev,
    required this.onNext,
    required this.onLast,
  });

  @override
  Widget build(BuildContext context) {
    final canGoPrev = currentIndex >= 0;
    final canGoNext = currentIndex < total - 1;

    return Container(
      color: const Color(0xFF221810),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavBtn(
            icon: CupertinoIcons.backward_end_fill,
            onTap: canGoPrev ? onFirst : null,
          ),
          _NavBtn(
            icon: CupertinoIcons.backward_fill,
            onTap: canGoPrev ? onPrev : null,
          ),
          Text(
            currentIndex < 0
                ? 'Đầu ván'
                : '${currentIndex + 1} / $total',
            style: const TextStyle(
              color: Color(0xFFB0A090),
              fontSize: 13,
            ),
          ),
          _NavBtn(
            icon: CupertinoIcons.forward_fill,
            onTap: canGoNext ? onNext : null,
          ),
          _NavBtn(
            icon: CupertinoIcons.forward_end_fill,
            onTap: canGoNext ? onLast : null,
          ),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _NavBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.all(10),
      onPressed: onTap,
      child: Icon(
        icon,
        color: onTap != null ? const Color(0xFFE8BE75) : const Color(0xFF4A3A2A),
        size: 22,
      ),
    );
  }
}

// ─── Move List ────────────────────────────────────────────────────────────────
class _MoveList extends StatelessWidget {
  final List<OnlineMoveRecord> moves;
  final int currentIndex;
  final ScrollController scrollController;
  final void Function(int) onTap;

  const _MoveList({
    required this.moves,
    required this.currentIndex,
    required this.scrollController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (moves.isEmpty) {
      return Container(
        height: 48,
        color: const Color(0xFF221810),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Text(
          'Van nay khong co nuoc di nao duoc luu tren server',
          style: TextStyle(
            color: Color(0xFF7A6A5A),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Pair moves: index 0 & 1 form "1. Nf3 d5", etc.
    final pairs = <(int, int?)>[];
    for (int i = 0; i < moves.length; i += 2) {
      pairs.add((i, i + 1 < moves.length ? i + 1 : null));
    }

    return Container(
      height: 48,
      color: const Color(0xFF221810),
      child: ListView.builder(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: pairs.length,
        itemBuilder: (ctx, pi) {
          final (wi, bi) = pairs[pi];
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '${pi + 1}.',
                  style: const TextStyle(
                    color: Color(0xFF7A6A5A),
                    fontSize: 12,
                  ),
                ),
              ),
              _MoveChip(
                san: moves[wi].sanNotation,
                isActive: currentIndex == wi,
                onTap: () => onTap(wi),
              ),
              if (bi != null)
                _MoveChip(
                  san: moves[bi].sanNotation,
                  isActive: currentIndex == bi,
                  onTap: () => onTap(bi),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MoveChip extends StatelessWidget {
  final String san;
  final bool isActive;
  final VoidCallback onTap;

  const _MoveChip({required this.san, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFE8BE75) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          san,
          style: TextStyle(
            color: isActive ? const Color(0xFF1A140E) : const Color(0xFFB0A090),
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Analysis Panel ───────────────────────────────────────────────────────────
class _AnalysisPanel extends StatelessWidget {
  final PositionAnalysis? analysis;
  final bool isAnalyzing;
  final String? error;
  final bool canAnalyze;
  final VoidCallback onAnalyze;

  const _AnalysisPanel({
    required this.analysis,
    required this.isAnalyzing,
    required this.error,
    required this.canAnalyze,
    required this.onAnalyze,
  });

  Color _classificationColor(String cls) {
    switch (cls) {
      case 'best':
        return const Color(0xFF4CAF50);
      case 'excellent':
        return const Color(0xFF66BB6A);
      case 'good':
        return const Color(0xFF26A69A);
      case 'inaccurate':
        return const Color(0xFFFFA726);
      case 'mistake':
        return const Color(0xFFEF6C00);
      case 'blunder':
        return const Color(0xFFEF5350);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  String _classificationIcon(String cls) {
    switch (cls) {
      case 'best':
        return '★';
      case 'excellent':
        return '✓✓';
      case 'good':
        return '✓';
      case 'inaccurate':
        return '?!';
      case 'mistake':
        return '?';
      case 'blunder':
        return '??';
      default:
        return '–';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A140E),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Analyze button
          if (analysis == null && !isAnalyzing && error == null)
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: canAnalyze
                    ? const Color(0xFF8B5E3C)
                    : const Color(0xFF3A2A1A),
                onPressed: canAnalyze ? onAnalyze : null,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.wand_stars, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Phân tích nước này',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          if (isAnalyzing)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoActivityIndicator(color: Color(0xFFE8BE75)),
                    SizedBox(height: 8),
                    Text(
                      'AI đang phân tích...',
                      style: TextStyle(color: Color(0xFFB0A090), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.exclamationmark_circle,
                      color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: onAnalyze,
                    child: const Text(
                      'Thử lại',
                      style: TextStyle(color: Color(0xFFE8BE75), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          if (analysis != null) ...[
            // Classification badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _classificationColor(analysis!.classification)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _classificationColor(analysis!.classification),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _classificationIcon(analysis!.classification),
                        style: TextStyle(
                          color: _classificationColor(analysis!.classification),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        analysis!.classificationLabel,
                        style: TextStyle(
                          color: _classificationColor(analysis!.classification),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Best move suggestion (when not best)
            if (analysis!.classification != 'best' &&
                analysis!.classification != 'unknown')
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A1F14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE8BE75).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Text('♟', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nước đi tốt hơn:',
                            style: TextStyle(
                              color: Color(0xFF9E8E7E),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${analysis!.bestMove.san}  (${analysis!.bestMove.from} → ${analysis!.bestMove.to})',
                            style: const TextStyle(
                              color: Color(0xFFE8BE75),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Eval difference indicator
                    if (analysis!.evalScore != null && analysis!.evalPlayed != null)
                      _EvalPill(
                        evalBest: analysis!.evalScore!,
                        evalPlayed: analysis!.evalPlayed!,
                      ),
                  ],
                ),
              ),
            // When it IS the best move
            if (analysis!.classification == 'best')
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2E1A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(CupertinoIcons.star_fill,
                        color: Color(0xFF4CAF50), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Đây là nước đi tốt nhất trong vị trí này!',
                        style: TextStyle(
                          color: Color(0xFF81C784),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            // Re-analyze button
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onAnalyze,
                child: const Text(
                  'Phân tích lại',
                  style: TextStyle(
                    color: Color(0xFF9E8E7E),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EvalPill extends StatelessWidget {
  final int evalBest;
  final int evalPlayed;

  const _EvalPill({required this.evalBest, required this.evalPlayed});

  @override
  Widget build(BuildContext context) {
    final diff = (evalBest - evalPlayed).abs();
    final diffStr = diff >= 100
        ? '${(diff / 100).toStringAsFixed(1)} ♟'
        : '$diff cp';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF3A2A1A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '-$diffStr',
        style: const TextStyle(
          color: Color(0xFFEF6C00),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
