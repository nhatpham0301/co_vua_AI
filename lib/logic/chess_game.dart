import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/events.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/cupertino.dart';

import '../model/app_model.dart';
import '../model/player.dart';
import 'chess_board.dart';
import 'chess_piece.dart';
import 'chess_piece_sprite.dart';
import 'dev_logger.dart';
import 'game_controller.dart';
import 'move_calculation/move_classes/move.dart';
import 'shared_functions.dart';

/// Rendering layer for the chess game. Delegates all game logic to
/// [GameController], keeping this class focused on display and input routing.
class ChessGame extends FlameGame with TapCallbacks {
  double? width;
  double? tileSize;
  AppModel appModel;

  late final GameController controller;
  Map<ChessPiece, ChessPieceSprite> spriteMap = Map();

  double currentRotation = 0;
  double targetRotation = 0;
  double startRotation = 0;
  double animationProgress = 1.0;
  final double animationDuration = 0.6;

  // Cached Paint objects to avoid per-frame allocations
  Paint _lightTilePaint = Paint();
  Paint _darkTilePaint = Paint();
  Paint _moveHintPaint = Paint();
  Paint _checkHintPaint = Paint();
  Paint _latestMoveFromPaint = Paint();
  Paint _latestMoveToPaint = Paint();
  Paint _latestMoveToRingPaint = Paint();
  Paint _serverCastleTrailPaint = Paint();
  Paint _serverCastleToRingPaint = Paint();
  Paint _selectedPiecePaint = Paint();
  String? _cachedThemeName;
  ui.Image? _boardTexture;
  // ignore: unused_field
  ui.Image? _boardFrameTexture;

  ChessGame(this.controller, this.appModel) {
    controller.onSnapSprites = () => snapSprites();
    // width and tileSize are calculated in onGameResize
    for (var piece
        in controller.board.player1Pieces + controller.board.player2Pieces) {
      spriteMap[piece] = ChessPieceSprite(piece, appModel.pieceTheme);
    }
    _updatePaints();
    forceSnapRotation();
  }

  void forceSnapRotation() {
    if (appModel.isBoardInverted) {
      currentRotation = math.pi;
      targetRotation = math.pi;
      startRotation = math.pi;
    } else {
      currentRotation = 0;
      targetRotation = 0;
      startRotation = 0;
    }
    animationProgress = 1.0;
  }

  // ── Delegated Accessors (backward compatibility for views) ──

  ChessBoard get board => controller.board;
  List<int> get validMoves => controller.validMoves;
  set validMoves(List<int> v) => controller.validMoves = v;
  ChessPiece? get selectedPiece => controller.selectedPiece;
  set selectedPiece(ChessPiece? v) => controller.selectedPiece = v;
  int? get checkHintTile => controller.checkHintTile;
  set checkHintTile(int? v) => controller.checkHintTile = v;
  Move? get latestMove => controller.latestMove;
  set latestMove(Move? v) => controller.latestMove = v;

  void cancelAIMove() => controller.cancelAIMove();
  void triggerAIMove() => controller.triggerAIMove();
  void undoMove() => controller.undoMove();
  void undoTwoMoves() => controller.undoTwoMoves();
  void redoMove() => controller.redoMove();
  void redoTwoMoves() => controller.redoTwoMoves();
  void promote(ChessPieceType type) => controller.promote(type);

  // ── Input Handling ──

  void onTapDown(TapDownEvent event) {
    DevLogger.instance.log(
      DevLogCategory.game,
      '[TAP] gameOver=${appModel.gameOver} isAIsTurn=${appModel.isAIsTurn} spectator=${appModel.isSpectatorMode} inputLocked=${appModel.isInputLocked} turn=${appModel.turn.name} playerSide=${appModel.playerSide.name} pos=${event.localPosition}',
    );
    if (!appModel.gameOver &&
        !appModel.isAIsTurn &&
        !appModel.isSpectatorMode &&
        !appModel.isInputLocked) {
      var tile = _vector2ToTile(event.localPosition);
      if (tile < 0 || tile >= 64) return;
      var touchedPiece = board.tiles[tile];
      if (touchedPiece == selectedPiece) {
        validMoves = [];
        selectedPiece = null;
      } else {
        if (selectedPiece != null &&
            touchedPiece != null &&
            touchedPiece.player == selectedPiece?.player) {
          if (validMoves.contains(tile)) {
            controller.movePiece(tile);
          } else {
            validMoves = [];
            controller.selectPiece(touchedPiece);
          }
        } else if (selectedPiece == null) {
          controller.selectPiece(touchedPiece);
        } else {
          controller.movePiece(tile);
        }
      }
    }
  }

  // ── Rendering ──

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      _boardTexture = Flame.images.fromCache('boards/wood_board.png');
    } catch (_) {
      _boardTexture = await Flame.images.load('boards/wood_board.png');
    }
    try {
      _boardFrameTexture = Flame.images.fromCache('boards/frame_board.png');
    } catch (_) {
      _boardFrameTexture = await Flame.images.load('boards/frame_board.png');
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    width = size.x;
    tileSize = width! / 8;
    _initSpritePositions();
    snapSprites();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    _drawBoard(canvas);
    if (appModel.showHints) {
      _drawCheckHint(canvas);
      _drawLatestMove(canvas);
      _drawServerCastlingVisual(canvas);
    }
    _drawSelectedPieceHint(canvas);
    _drawPieces(canvas);
    if (appModel.showHints) {
      _drawMoveHints(canvas);
    }
  }

  @override
  void update(double t) {
    super.update(t);

    // Update cached paints if theme changed
    if (_cachedThemeName != appModel.theme.name) {
      _updatePaints();
    }

    double newTargetRotation = 0;
    if (appModel.isBoardInverted) {
      newTargetRotation = math.pi;
    } else {
      newTargetRotation = 0;
    }

    if (newTargetRotation != targetRotation) {
      targetRotation = newTargetRotation;
      startRotation = currentRotation;
      animationProgress = 0;
    }

    if (animationProgress < 1.0) {
      animationProgress += t / animationDuration;
      if (animationProgress > 1.0) animationProgress = 1.0;

      double curviness = animationProgress < 0.5
          ? 4 * animationProgress * animationProgress * animationProgress
          : 1 - math.pow(-2 * animationProgress + 2, 3) / 2;

      currentRotation =
          startRotation + (targetRotation - startRotation) * curviness;
    } else {
      currentRotation = targetRotation;
    }

    for (var piece in board.player1Pieces.followedBy(board.player2Pieces)) {
      spriteMap[piece]?.update(tileSize ?? 0, appModel, piece, t);
    }
  }

  void _updatePaints() {
    var theme = appModel.theme;
    _lightTilePaint = Paint()..color = theme.lightTile;
    _darkTilePaint = Paint()..color = theme.darkTile;
    _moveHintPaint = Paint()
      ..color = const Color(0xFF39D353).withValues(alpha: 0.95);
    _checkHintPaint = Paint()..color = theme.checkHint;
    _latestMoveFromPaint = Paint()..color = const Color(0xFF121212);
    _latestMoveToPaint = Paint()..color = const Color(0xFFF2F2F2);
    _latestMoveToRingPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    _serverCastleTrailPaint = Paint()
      ..color = const Color(0xFFFFE082).withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0;
    _serverCastleToRingPaint = Paint()
      ..color = const Color(0xFFFFF3C4).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    _selectedPiecePaint = Paint()..color = const Color(0xFFF2F2F2);
    _cachedThemeName = theme.name;
  }

  void _initSpritePositions() {
    for (var piece in board.player1Pieces.followedBy(board.player2Pieces)) {
      spriteMap[piece]?.initSpritePosition(tileSize ?? 0, appModel);
    }
  }

  void snapSprites() {
    final livePieces =
        board.player1Pieces.followedBy(board.player2Pieces).toSet();

    // Remove stale sprites from pieces that no longer exist on the board.
    spriteMap.removeWhere((piece, _) => !livePieces.contains(piece));

    // Recreate sprites for pieces loaded from FEN (new object identity),
    // then snap all sprites to their current board positions.
    for (var piece in livePieces) {
      spriteMap.putIfAbsent(
        piece,
        () => ChessPieceSprite(piece, appModel.pieceTheme),
      );
      spriteMap[piece]?.snapToPiece(piece, tileSize ?? 0, appModel);
    }
  }

  int _vector2ToTile(Vector2 vector2) {
    return (vector2.y / (tileSize ?? 0)).floor() * 8 +
        (vector2.x / (tileSize ?? 0)).floor();
  }

  void _drawBoard(Canvas canvas) {
    if (_boardTexture != null && width != null) {
      final boardSize = width!;

      canvas.drawImageRect(
        _boardTexture!,
        Rect.fromLTWH(
          0,
          0,
          _boardTexture!.width.toDouble(),
          _boardTexture!.height.toDouble(),
        ),
        Rect.fromLTWH(
          0,
          0,
          boardSize,
          boardSize,
        ),
        Paint(),
      );

      return;
    }

    for (int tileNo = 0; tileNo < 64; tileNo++) {
      canvas.drawRect(
        Rect.fromLTWH(
          (tileNo % 8) * (tileSize ?? 0),
          (tileNo / 8).floor() * (tileSize ?? 0),
          (tileSize ?? 0),
          (tileSize ?? 0),
        ),
        (tileNo + (tileNo / 8).floor()) % 2 == 0
            ? _lightTilePaint
            : _darkTilePaint,
      );
    }
  }

  void _drawPieces(Canvas canvas) {
    for (var piece in board.player1Pieces.followedBy(board.player2Pieces)) {
      double x = (spriteMap[piece]?.spriteX ?? 0) + 5;
      double y = (spriteMap[piece]?.spriteY ?? 0) + 5;
      double size = (tileSize ?? 0) - 10;

      canvas.save();
      canvas.translate(x + size / 2, y + size / 2);
      canvas.rotate(-currentRotation);
      canvas.translate(-(x + size / 2), -(y + size / 2));

      spriteMap[piece]?.sprite?.render(
            canvas,
            size: Vector2(size, size),
            position: Vector2(x, y),
          );
      canvas.restore();
    }
  }

  void _drawMoveHints(Canvas canvas) {
    for (var tile in validMoves) {
      canvas.drawCircle(
        Offset(
          getXFromTile(tile, (tileSize ?? 0)) + ((tileSize ?? 0) / 2),
          getYFromTile(tile, (tileSize ?? 0)) + ((tileSize ?? 0) / 2),
        ),
        (tileSize ?? 0) / 5,
        _moveHintPaint,
      );
    }
  }

  void _drawLatestMove(Canvas canvas) {
    if (latestMove != null) {
      final fromCenter = Offset(
        getXFromTile(latestMove!.from, (tileSize ?? 0)) + ((tileSize ?? 0) / 2),
        getYFromTile(latestMove!.from, (tileSize ?? 0)) + ((tileSize ?? 0) / 2),
      );
      final toCenter = Offset(
        getXFromTile(latestMove!.to, (tileSize ?? 0)) + ((tileSize ?? 0) / 2),
        getYFromTile(latestMove!.to, (tileSize ?? 0)) + ((tileSize ?? 0) / 2),
      );
      // Prefer live board piece color at destination tile.
      // moveMetaList can be stale after authoritative FEN sync.
      final movedBy = board.tiles[latestMove!.to]?.player ??
          (appModel.moveMetaList.isNotEmpty
              ? appModel.moveMetaList.last.player
              : null);
      final fromDotPaint =
          movedBy == Player.player2 ? _latestMoveFromPaint : _latestMoveToPaint;
      _latestMoveToRingPaint.color = movedBy == Player.player2
          ? const Color(0xFF121212).withValues(alpha: 0.52)
          : const Color(0xFFFFFFFF).withValues(alpha: 0.52);
      final fromDotR = (tileSize ?? 0) / 5;
      final toRingR = (tileSize ?? 0) * 0.43;
      _latestMoveToRingPaint.strokeWidth =
          ((tileSize ?? 0) * 0.042).clamp(1.4, 2.8).toDouble();

      // From-square: solid dot by moved piece color (black piece -> black dot).
      canvas.drawCircle(
        fromCenter,
        fromDotR,
        fromDotPaint,
      );

      // To-square: ring around the moved piece so highlight is never hidden.
      canvas.drawCircle(toCenter, toRingR, _latestMoveToRingPaint);
    }
  }

  void _drawServerCastlingVisual(Canvas canvas) {
    if (!appModel.hasActiveServerCastlingVisual) return;
    final fromTile = appModel.serverCastlingRookFromTile;
    final toTile = appModel.serverCastlingRookToTile;
    if (fromTile == null || toTile == null) return;

    final progress = appModel.serverCastlingVisualProgress;
    if (progress <= 0) return;

    final fromCenter = Offset(
      getXFromTile(fromTile, (tileSize ?? 0)) + ((tileSize ?? 0) / 2),
      getYFromTile(fromTile, (tileSize ?? 0)) + ((tileSize ?? 0) / 2),
    );
    final toCenter = Offset(
      getXFromTile(toTile, (tileSize ?? 0)) + ((tileSize ?? 0) / 2),
      getYFromTile(toTile, (tileSize ?? 0)) + ((tileSize ?? 0) / 2),
    );
    final animatedCenter = Offset(
      fromCenter.dx + (toCenter.dx - fromCenter.dx) * progress,
      fromCenter.dy + (toCenter.dy - fromCenter.dy) * progress,
    );

    final base = (tileSize ?? 0);
    _serverCastleTrailPaint.strokeWidth = (base * 0.065).clamp(2.0, 4.0);
    _serverCastleToRingPaint.strokeWidth = (base * 0.05).clamp(1.8, 3.5);

    canvas.drawLine(fromCenter, animatedCenter, _serverCastleTrailPaint);
    canvas.drawCircle(
      toCenter,
      base * (0.15 + (0.28 * progress)),
      _serverCastleToRingPaint,
    );
  }

  void _drawCheckHint(Canvas canvas) {
    int? highlightTile = checkHintTile;

    // Fallback: derive check target directly from board state in case the
    // session entered an already-in-check position (reconnect/resume/socket sync).
    if (highlightTile == null && board.kingInCheck(appModel.turn)) {
      highlightTile = board.kingForPlayer(appModel.turn)?.tile;
    }

    if (highlightTile != null) {
      final center = Offset(
        getXFromTile(highlightTile, (tileSize ?? 0)) + ((tileSize ?? 0) / 2),
        getYFromTile(highlightTile, (tileSize ?? 0)) + ((tileSize ?? 0) / 2),
      );
      final ringPaint = Paint()
        ..color = _checkHintPaint.color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ((tileSize ?? 0) * 0.06).clamp(2.0, 4.5).toDouble();
      final glowPaint = Paint()
        ..color = _checkHintPaint.color.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ((tileSize ?? 0) * 0.14).clamp(5.0, 10.0).toDouble();

      canvas.drawCircle(center, (tileSize ?? 0) * 0.34, glowPaint);
      canvas.drawCircle(center, (tileSize ?? 0) * 0.37, ringPaint);
    }
  }

  void _drawSelectedPieceHint(Canvas canvas) {
    if (selectedPiece != null) {
      final selectedPaint = selectedPiece!.player == Player.player2
          ? (_selectedPiecePaint..color = const Color(0xFF121212))
          : (_selectedPiecePaint..color = const Color(0xFFF2F2F2));
      final center = Offset(
        getXFromTile(selectedPiece!.tile, (tileSize ?? 0)) +
            ((tileSize ?? 0) / 2),
        getYFromTile(selectedPiece!.tile, (tileSize ?? 0)) +
            ((tileSize ?? 0) / 2),
      );
      canvas.drawCircle(center, (tileSize ?? 0) * 0.12, selectedPaint);
    }
  }
}
