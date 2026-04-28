import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../logic/chess_board.dart';
import '../logic/chess_piece.dart';
import '../logic/move_calculation/ai_move_calculation.dart';
import '../logic/move_calculation/move_classes/move.dart';
import '../logic/move_calculation/move_classes/move_meta.dart';
import '../logic/shared_functions.dart';
import '../model/player.dart';
import 'components/main_menu_view/mm_background.dart';
import 'components/main_menu_view/mm_palette.dart';

// ─── Mode constants ───────────────────────────────────────────────────────────

enum _TestMode {
  fullAutoLocalLocal,
  castling,
  enPassant,
  promotion,
}

extension _TestModeX on _TestMode {
  String get label {
    switch (this) {
      case _TestMode.fullAutoLocalLocal:
        return 'Full Auto: Bot vs Bot (Local)';
      case _TestMode.castling:
        return 'Case: Nhập thành (Castling)';
      case _TestMode.enPassant:
        return 'Case: Bắt tốt qua đường (En Passant)';
      case _TestMode.promotion:
        return 'Case: Phong cấp (Promotion)';
    }
  }

  String get title {
    switch (this) {
      case _TestMode.fullAutoLocalLocal:
        return 'Full Auto Play — Bot vs Bot';
      case _TestMode.castling:
        return 'Case 1: Castling Logic';
      case _TestMode.enPassant:
        return 'Case 2: En Passant Logic';
      case _TestMode.promotion:
        return 'Case 3: Promotion Logic';
    }
  }

  String get description {
    switch (this) {
      case _TestMode.fullAutoLocalLocal:
        return 'Hai bot tự đánh từ đầu đến cuối (depth 2)';
      case _TestMode.castling:
        return 'Trắng: Vua e1, Xe a1+h1. Nhấn ▶ để xem nhập thành.';
      case _TestMode.enPassant:
        return 'Trắng: Tốt d5. Đen: Tốt e5 (vừa đi 2 bước). Nhấn ▶ để xem bắt tốt qua đường.';
      case _TestMode.promotion:
        return 'Trắng: Tốt a7, gần phong hậu. Nhấn ▶ để xem phong cấp.';
    }
  }
}

// ─── Main Widget ─────────────────────────────────────────────────────────────

class TestGameView extends StatefulWidget {
  const TestGameView({Key? key}) : super(key: key);

  @override
  State<TestGameView> createState() => _TestGameViewState();
}

class _TestGameViewState extends State<TestGameView> {
  _TestMode _selectedMode = _TestMode.fullAutoLocalLocal;

  late ChessBoard _board;
  Timer? _playTimer;
  bool _isRunning = false;
  bool _isThinking = false;
  Player _currentTurn = Player.player1;
  Move? _lastMove;
  List<String> _moveLog = [];
  String _statusText = 'Nhấn ▶ Bắt đầu để xem bot tự đánh';
  bool _gameOver = false;

  // Forced moves played before handing off to the AI (for special cases).
  List<Move> _forcedMoves = [];

  @override
  void initState() {
    super.initState();
    _resetBoard();
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    super.dispose();
  }

  // ── Board setup ──────────────────────────────────────────────────────────

  void _resetBoard() {
    _playTimer?.cancel();
    _isRunning = false;
    _isThinking = false;
    _currentTurn = Player.player1;
    _lastMove = null;
    _moveLog = [];
    _gameOver = false;
    _forcedMoves = [];

    switch (_selectedMode) {
      case _TestMode.fullAutoLocalLocal:
        _board = ChessBoard();
        _statusText = 'Nhấn ▶ để xem Bot tự đánh từ đầu đến cuối';
        break;
      case _TestMode.castling:
        _board = _buildCastlingBoard();
        // Forced first move: white castles kingside — king e1(60) → rook h1(63)
        _forcedMoves = [Move(60, 63)];
        _statusText = _selectedMode.description;
        break;
      case _TestMode.enPassant:
        _board = _buildEnPassantBoard();
        // Forced first move: white d5(27) → e6(20) capturing en passant
        _forcedMoves = [Move(27, 20)];
        _statusText = _selectedMode.description;
        break;
      case _TestMode.promotion:
        _board = _buildPromotionBoard();
        // Forced first move: white a7(8) → a8(0) = promotion to queen
        _forcedMoves = [Move(8, 0)];
        _statusText = _selectedMode.description;
        break;
    }
    setState(() {});
  }

  // Castling: King + 2 Rooks ready to castle (no pieces blocking).
  ChessBoard _buildCastlingBoard() {
    final b = ChessBoard();
    b.clearForCustomSetup();
    var id = 0;
    // White
    b.addPieceAt(id++, ChessPieceType.king, Player.player1, 60); // e1
    b.addPieceAt(id++, ChessPieceType.rook, Player.player1, 56); // a1 queenside
    b.addPieceAt(id++, ChessPieceType.rook, Player.player1, 63); // h1 kingside
    b.addPieceAt(id++, ChessPieceType.pawn, Player.player1, 48); // a2
    b.addPieceAt(id++, ChessPieceType.pawn, Player.player1, 52); // e2
    b.addPieceAt(id++, ChessPieceType.pawn, Player.player1, 55); // h2
    // Black
    b.addPieceAt(id++, ChessPieceType.king, Player.player2, 4); // e8
    b.addPieceAt(id++, ChessPieceType.rook, Player.player2, 0); // a8
    b.addPieceAt(id++, ChessPieceType.rook, Player.player2, 7); // h8
    b.addPieceAt(id++, ChessPieceType.pawn, Player.player2, 8); // a7
    b.addPieceAt(id++, ChessPieceType.pawn, Player.player2, 12); // e7
    b.addPieceAt(id++, ChessPieceType.pawn, Player.player2, 15); // h7
    b.finalizeCustomPosition();
    return b;
  }

  // En Passant: White pawn d5, Black pawn e5 marked as en passant target.
  ChessBoard _buildEnPassantBoard() {
    final b = ChessBoard();
    b.clearForCustomSetup();
    var id = 0;
    // White
    b.addPieceAt(id++, ChessPieceType.king, Player.player1, 60); // e1
    b.addPieceAt(id++, ChessPieceType.pawn, Player.player1, 27); // d5
    b.addPieceAt(id++, ChessPieceType.queen, Player.player1,
        59); // d1 (keeps game from trivial mate)
    // Black
    b.addPieceAt(id++, ChessPieceType.king, Player.player2, 4); // e8
    b.addPieceAt(id++, ChessPieceType.pawn, Player.player2, 28,
        moveCountVal: 1); // e5
    b.addPieceAt(id++, ChessPieceType.queen, Player.player2, 3); // d8
    // Mark the black pawn at e5 as the en passant target.
    b.enPassantPiece = b.tiles[28];
    b.finalizeCustomPosition();
    return b;
  }

  // Promotion: White pawn one step from rank 8.
  ChessBoard _buildPromotionBoard() {
    final b = ChessBoard();
    b.clearForCustomSetup();
    var id = 0;
    // White
    b.addPieceAt(id++, ChessPieceType.king, Player.player1, 60); // e1
    b.addPieceAt(
        id++, ChessPieceType.pawn, Player.player1, 8); // a7 (one step from a8)
    // Black
    b.addPieceAt(id++, ChessPieceType.king, Player.player2, 4); // e8
    b.finalizeCustomPosition();
    return b;
  }

  // ── Playback control ─────────────────────────────────────────────────────

  void _startPlaying() {
    if (_isRunning || _gameOver) return;
    setState(() {
      _isRunning = true;
      _statusText = 'Đang chạy...';
    });
    _scheduleNextMove();
  }

  void _pausePlaying() {
    _playTimer?.cancel();
    setState(() {
      _isRunning = false;
      _statusText = 'Đã tạm dừng';
    });
  }

  void _scheduleNextMove() {
    _playTimer?.cancel();
    _playTimer = Timer(const Duration(milliseconds: 1100), _doNextMove);
  }

  Future<void> _doNextMove() async {
    if (!_isRunning || _gameOver || !mounted) return;

    // Pre-check: stalemate / checkmate
    if (_board.kingInCheckmate(_currentTurn)) {
      final winner = _currentTurn == Player.player2 ? 'Trắng' : 'Đen';
      setState(() {
        _gameOver = true;
        _isRunning = false;
        _isThinking = false;
        _statusText = '🏆 $winner thắng! (Chiếu hết)';
      });
      return;
    }

    setState(() => _isThinking = true);

    Move? move;

    // Use a forced move if available (for special-case demos).
    if (_forcedMoves.isNotEmpty) {
      move = _forcedMoves.removeAt(0);
    } else {
      // AI calculation (depth 2 for full-game speed, 3 for special cases).
      final depth = _selectedMode == _TestMode.fullAutoLocalLocal ? 2 : 3;
      final args = <String, dynamic>{
        'aiPlayer': _currentTurn,
        'aiDifficulty': depth,
        'board': _board,
      };
      try {
        move = await compute(calculateAIMove, args);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isThinking = false;
          _isRunning = false;
          _statusText = 'Lỗi tính toán: $e';
        });
        return;
      }
    }

    if (!mounted) return;

    if (move == null || (move.from == 0 && move.to == 0)) {
      setState(() {
        _gameOver = true;
        _isRunning = false;
        _isThinking = false;
        _statusText = 'Không còn nước đi — hòa cờ hoặc chiếu hết';
      });
      return;
    }

    // Apply the move, auto-promoting to queen.
    final MoveMeta meta =
        _board.push(move, getMeta: true, promotionType: ChessPieceType.queen);

    // Build move label.
    final fromAlg = _tileToAlgebraic(move.from);
    final toAlg = _tileToAlgebraic(move.to);
    String moveStr;
    if (meta.kingCastle) {
      moveStr = '${_turnLabel(_currentTurn)}: O-O (nhập thành cánh vua)';
    } else if (meta.queenCastle) {
      moveStr = '${_turnLabel(_currentTurn)}: O-O-O (nhập thành cánh hậu)';
    } else if (meta.promotion) {
      moveStr = '${_turnLabel(_currentTurn)}: $fromAlg→$toAlg=♛ (phong hậu)';
    } else {
      moveStr = '${_turnLabel(_currentTurn)}: $fromAlg→$toAlg';
    }
    if (meta.isCheck && !meta.isCheckmate) moveStr += ' +';
    if (meta.isCheckmate) moveStr += '#';

    final nextTurn =
        _currentTurn == Player.player1 ? Player.player2 : Player.player1;

    String status = '${_turnLabel(nextTurn)} đang suy nghĩ...';
    bool gameOver = false;

    if (meta.isCheckmate) {
      status = '🏆 ${_turnLabel(_currentTurn)} thắng! (Chiếu hết)';
      gameOver = true;
    } else if (_board.kingInCheckmate(nextTurn)) {
      status = '🤝 Hòa cờ (Stalemate)';
      gameOver = true;
    }

    setState(() {
      _lastMove = move;
      _currentTurn = nextTurn;
      _moveLog.insert(0, moveStr);
      if (_moveLog.length > 30) _moveLog = _moveLog.sublist(0, 30);
      _isThinking = false;
      _statusText = status;
      _gameOver = gameOver;
      if (gameOver) _isRunning = false;
    });

    if (!gameOver && _isRunning) {
      _scheduleNextMove();
    }
  }

  String _turnLabel(Player p) => p == Player.player1 ? '♔ Trắng' : '♚ Đen';

  String _tileToAlgebraic(int tile) {
    final file = String.fromCharCode(97 + tileToCol(tile));
    final rank = 8 - tileToRow(tile);
    return '$file$rank';
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [bgMid, bgDark],
              ),
            ),
          ),
          const BoardBackground(),
          const CornerKnots(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                const SizedBox(height: 6),
                _buildCaseHeader(),
                const SizedBox(height: 8),
                _buildBoard(),
                const SizedBox(height: 8),
                _buildControls(),
                const SizedBox(height: 8),
                _buildModeSelector(),
                const SizedBox(height: 8),
                Expanded(child: _buildMoveLog()),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            child: const Row(
              children: [
                Icon(CupertinoIcons.back, color: Colors.white70),
                Text(
                  ' Quay lại',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
            ),
          ),
          const Spacer(),
          const Text(
            'Test Game',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF4D293),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _buildCaseHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
        decoration: BoxDecoration(
          color: bgCard.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primary.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _selectedMode.title,
              style: const TextStyle(
                color: Color(0xFFF4D293),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _statusText,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            border:
                Border.all(color: primary.withValues(alpha: 0.65), width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: CustomPaint(
              painter: _BoardPainter(
                board: _board,
                lastMove: _lastMove,
                repaintTrigger: _moveLog.length,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CtrlBtn(
          icon: Icons.restart_alt_rounded,
          label: 'Reset',
          color: Colors.deepOrange,
          onPressed: _resetBoard,
        ),
        const SizedBox(width: 12),
        if (!_isRunning)
          _CtrlBtn(
            icon: Icons.play_arrow_rounded,
            label: 'Bắt đầu',
            color: const Color(0xFF2E7D32),
            onPressed: _gameOver ? null : _startPlaying,
          )
        else
          _CtrlBtn(
            icon: Icons.pause_rounded,
            label: 'Tạm dừng',
            color: Colors.orange.shade700,
            onPressed: _pausePlaying,
          ),
        if (_isThinking) ...[
          const SizedBox(width: 14),
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFF4D293),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildModeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: bgCard.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primary.withValues(alpha: 0.35)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<_TestMode>(
            value: _selectedMode,
            isExpanded: true,
            dropdownColor: bgCard,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFFF4D293),
            ),
            onChanged: (v) {
              if (v == null) return;
              _playTimer?.cancel();
              setState(() => _selectedMode = v);
              _resetBoard();
            },
            items: _TestMode.values
                .map(
                  (m) => DropdownMenuItem(
                    value: m,
                    child: Text(
                      m.label,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMoveLog() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lịch sử nước đi (mới nhất ở trên)',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: _moveLog.isEmpty
                  ? Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        '— chưa có nước đi —',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.28),
                          fontSize: 12,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _moveLog.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          '${_moveLog.length - i}. ${_moveLog[i]}',
                          style: TextStyle(
                            color: i == 0
                                ? const Color(0xFFF4D293)
                                : Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                            fontWeight:
                                i == 0 ? FontWeight.w700 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Control button ───────────────────────────────────────────────────────────

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _CtrlBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      color: disabled ? Colors.grey.shade800 : color.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(10),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Board painter ────────────────────────────────────────────────────────────

class _BoardPainter extends CustomPainter {
  final ChessBoard board;
  final Move? lastMove;
  final int repaintTrigger;

  static const _light = Color(0xFFEECDA5);
  static const _dark = Color(0xFFAA7444);
  static const _hlFrom = Color(0x88F6F66A);
  static const _hlTo = Color(0xCCF6F66A);

  const _BoardPainter({
    required this.board,
    required this.lastMove,
    required this.repaintTrigger,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ts = size.width / 8; // tile size
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final tile = row * 8 + col;
        final rect = Rect.fromLTWH(col * ts, row * ts, ts, ts);

        // Square background
        canvas.drawRect(
          rect,
          Paint()..color = (row + col).isEven ? _light : _dark,
        );

        // Last-move highlight
        if (lastMove != null &&
            (tile == lastMove!.from || tile == lastMove!.to)) {
          canvas.drawRect(
            rect,
            Paint()..color = tile == lastMove!.to ? _hlTo : _hlFrom,
          );
        }

        // Piece
        final piece = board.tiles[tile];
        if (piece != null) _drawPiece(canvas, piece, rect, ts);
      }
    }
    _drawLabels(canvas, size, ts);
  }

  void _drawPiece(Canvas canvas, ChessPiece piece, Rect rect, double ts) {
    final isWhite = piece.player == Player.player1;
    final tp = TextPainter(
      text: TextSpan(
        text: _symbol(piece.type, piece.player),
        style: TextStyle(
          fontSize: ts * 0.7,
          color: isWhite ? const Color(0xFFF5F0E8) : const Color(0xFF1A1008),
          shadows: [
            Shadow(
              color: isWhite
                  ? Colors.black.withValues(alpha: 0.75)
                  : Colors.white.withValues(alpha: 0.45),
              blurRadius: 3,
              offset: const Offset(1, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      rect.center - Offset(tp.width / 2, tp.height / 2),
    );
  }

  void _drawLabels(Canvas canvas, Size size, double ts) {
    const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    const ranks = ['8', '7', '6', '5', '4', '3', '2', '1'];
    final style = TextStyle(
      fontSize: ts * 0.18,
      color: Colors.black.withValues(alpha: 0.45),
      fontWeight: FontWeight.bold,
    );
    for (int i = 0; i < 8; i++) {
      _paintLabel(canvas, files[i], style,
          Offset(i * ts + ts - ts * 0.18 - 1, size.height - ts * 0.2 - 1));
      _paintLabel(canvas, ranks[i], style, Offset(2, i * ts + 2));
    }
  }

  void _paintLabel(Canvas canvas, String text, TextStyle style, Offset pos) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  String _symbol(ChessPieceType type, Player player) {
    const w = {
      ChessPieceType.king: '♔',
      ChessPieceType.queen: '♕',
      ChessPieceType.rook: '♖',
      ChessPieceType.bishop: '♗',
      ChessPieceType.knight: '♘',
      ChessPieceType.pawn: '♙',
    };
    const b = {
      ChessPieceType.king: '♚',
      ChessPieceType.queen: '♛',
      ChessPieceType.rook: '♜',
      ChessPieceType.bishop: '♝',
      ChessPieceType.knight: '♞',
      ChessPieceType.pawn: '♟',
    };
    return (player == Player.player1 ? w : b)[type] ?? '?';
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.repaintTrigger != repaintTrigger || old.lastMove != lastMove;
}
