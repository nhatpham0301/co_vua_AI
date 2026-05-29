import 'dart:async';
import 'dart:math' as math;

import 'package:async/async.dart';
import 'package:flutter/foundation.dart';

import '../model/app_model.dart';
import '../model/player.dart';
import 'chess_board.dart';
import 'chess_piece.dart';
import 'dev_logger.dart';
import 'move_calculation/ai_move_calculation.dart';
import 'move_calculation/move_classes/move.dart';
import 'move_calculation/move_classes/move_meta.dart';
import 'shared_functions.dart';

/// Handles game logic orchestration: move execution, AI, undo/redo, promotion.
/// Separated from ChessGame (the view/rendering layer) for clean MVVM.
class GameController {
  final AppModel appModel;
  final ChessBoard board = ChessBoard();

  CancelableOperation? aiOperation;
  List<int> validMoves = [];
  ChessPiece? selectedPiece;
  int? checkHintTile;
  Move? latestMove;

  /// Called when the view needs to refresh sprites (e.g. after game restore).
  VoidCallback? onSnapSprites;

  static const int _aiThinkDelayMinMs = 3000;
  static const int _aiThinkDelayMaxMs = 5000;

  GameController(this.appModel) {}

  // ── Piece Selection ──

  void selectPiece(ChessPiece? piece) {
    if (appModel.isSpectatorMode) return;
    if (piece != null) {
      // In online PvP, only allow selecting own pieces on own turn.
      final isOnlinePvP =
          appModel.isOnlineGameMode && !appModel.shouldRunLocalAiInOnlineVsAi;
      if (piece.player == appModel.turn &&
          (!isOnlinePvP || piece.player == appModel.playerSide)) {
        selectedPiece = piece;
        if (isOnlinePvP) {
          // In online PvP, legal moves come from server (authoritative),
          // including castling availability only when king is selected.
          unawaited(_selectPieceUsingServerLegalMoves(piece));
        } else {
          if (selectedPiece != null) {
            validMoves = board.movesForPiece(piece);
          }
          if (validMoves.isEmpty) {
            selectedPiece = null;
          }
        }
      }
    }
  }

  Future<void> _selectPieceUsingServerLegalMoves(ChessPiece piece) async {
    final gameId = appModel.onlineEvents.activeGameId;
    if (gameId == null || gameId.isEmpty) {
      validMoves = board.movesForPiece(piece);
      if (validMoves.isEmpty) selectedPiece = null;
      appModel.update();
      return;
    }

    final from = _tileToAlgebraic(piece.tile);
    try {
      final payload = await appModel.apiClient.fetchGameLegalMoves(
        gameId: gameId,
        from: from,
      );
      // Selection may have changed while waiting for the network response.
      if (selectedPiece?.tile != piece.tile) return;

      // If the server says it's not our turn but the local state disagrees,
      // this is likely an auth issue (expired token → treated as guest by
      // optionalAuth, whiteId !== GUEST_USER_ID → waitingForTurn:true).
      // Fall back to local moves so the player is never stuck.
      final isWaitingForTurn = payload['waitingForTurn'] == true;
      if (isWaitingForTurn && appModel.turn == appModel.playerSide) {
        DevLogger.instance.log(
          DevLogCategory.http,
          '[ONLINE] legal-moves: waitingForTurn=true but local turn=${appModel.turn.name}==playerSide=${appModel.playerSide.name} for $from — auth issue suspected, using local moves',
        );
        validMoves = board.movesForPiece(piece);
        if (validMoves.isEmpty) selectedPiece = null;
        appModel.update();
        return;
      }

      validMoves = _extractServerLegalMoveTiles(payload);
      if (validMoves.isEmpty) {
        selectedPiece = null;
      }
      appModel.update();
    } catch (e) {
      DevLogger.instance.log(
        DevLogCategory.http,
        '[ONLINE] legal-moves fetch failed for $from | error=$e',
      );
      // Fallback to local moves to avoid blocking input when endpoint fails.
      validMoves = board.movesForPiece(piece);
      if (validMoves.isEmpty) selectedPiece = null;
      appModel.update();
    }
  }

  List<int> _extractServerLegalMoveTiles(Map<String, dynamic> payload) {
    final rawMoves = payload['moves'];
    if (rawMoves is! List) return [];
    final result = <int>[];
    for (final item in rawMoves) {
      if (item is! Map) continue;
      final map = item.cast<Object?, Object?>();
      final to = map['to']?.toString().trim().toLowerCase() ?? '';
      if (!_isAlgebraicSquare(to)) continue;
      result.add(_algebraicToTile(to));
    }
    return result;
  }

  bool _isAlgebraicSquare(String value) {
    if (value.length != 2) return false;
    final file = value.codeUnitAt(0);
    final rank = value.codeUnitAt(1);
    return file >= 97 && file <= 104 && rank >= 49 && rank <= 56;
  }

  void movePiece(int tile) {
    if (appModel.isSpectatorMode) return;
    // In online PvP, block moves when it is not the local player's turn.
    if (appModel.isOnlineGameMode && !appModel.shouldRunLocalAiInOnlineVsAi) {
      if (appModel.turn != appModel.playerSide) return;
    }
    if (validMoves.contains(tile)) {
      validMoves = [];
      final fromTile = selectedPiece?.tile ?? 0;
      int internalToTile = tile;
      // Online server legal-moves uses UCI castling squares (e1->g1/c1).
      // Convert to internal Chess960-style king->rook tile so local board
      // updates king+rook atomically in the same move.
      if (appModel.isOnlineGameMode &&
          !appModel.shouldRunLocalAiInOnlineVsAi &&
          selectedPiece?.type == ChessPieceType.king) {
        final fromRow = tileToRow(fromTile);
        final toRow = tileToRow(tile);
        final fromCol = tileToCol(fromTile);
        final toCol = tileToCol(tile);
        if (fromRow == toRow &&
            (toCol - fromCol).abs() == 2 &&
            board.tiles[tile] == null) {
          final rookTile = _findCastlingRookTile(
              fromRow, toCol > fromCol, selectedPiece!.player);
          if (rookTile != null) {
            internalToTile = rookTile;
          }
        }
      }

      var move = Move(fromTile, internalToTile);
      var meta = board.push(move, getMeta: true);
      DevLogger.instance.log(
        DevLogCategory.game,
        'Player move: ${selectedPiece?.type.name ?? "?"} ${selectedPiece?.tile} → $tile',
      );
      appModel.audio.playMovedSound();
      // For promotions, emit AFTER the promotion type is chosen (in promote()).
      if (!meta.promotion) {
        _emitMoveIfOnline(move, meta);
      }
      if (meta.promotion) {
        appModel.requestPromotion();
      }
      _moveCompletion(meta, changeTurn: !meta.promotion);
    }
  }

  // ── AI ──

  void _aiMove() async {
    if (appModel.gameOver) return;
    final thinkDelayMs = _aiThinkDelayMinMs +
        math.Random().nextInt(_aiThinkDelayMaxMs - _aiThinkDelayMinMs + 1);
    DevLogger.instance.log(
      DevLogCategory.game,
      'AI thinking for ${thinkDelayMs}ms before move',
    );
    await Future.delayed(Duration(milliseconds: thinkDelayMs));
    if (appModel.gameOver || !appModel.isAIsTurn) return;
    var args = Map();
    args['aiPlayer'] = appModel.aiTurn;
    args['aiDifficulty'] = appModel.aiDifficulty;
    args['board'] = board;
    aiOperation = CancelableOperation.fromFuture(
      compute(calculateAIMove, args),
    );
    aiOperation?.value.then((move) {
      if (move == null || appModel.gameOver || !appModel.isAIsTurn) {
        DevLogger.instance
            .log(DevLogCategory.game, 'AI has no valid moves — ending game');
        appModel.endGame();
      } else {
        validMoves = [];
        var meta = board.push(move, getMeta: true);
        _emitMoveIfOnline(move, meta);
        DevLogger.instance.log(
          DevLogCategory.game,
          'AI move: ${move.from} → ${move.to}${meta.took ? " (capture)" : ""}${meta.isCheck ? " +" : ""}${meta.isCheckmate ? " #" : ""}',
        );
        appModel.audio.playMovedSound();
        _moveCompletion(meta, changeTurn: !meta.promotion);
        if (meta.promotion) {
          promote(move.promotionType);
        }
      }
    });
  }

  void cancelAIMove() {
    aiOperation?.cancel();
  }

  void triggerAIMove() {
    _aiMove();
  }

  // ── Undo / Redo ──

  void undoMove() {
    DevLogger.instance.log(DevLogCategory.game, 'Undo 1 move');
    board.redoStack.add(board.pop());
    if (appModel.moveMetaList.length > 1) {
      var meta = appModel.moveMetaList[appModel.moveMetaList.length - 2];
      _moveCompletion(meta, clearRedo: false, undoing: true);
    } else {
      _undoOpeningMove();
      appModel.changeTurn();
    }
  }

  void undoTwoMoves() {
    DevLogger.instance.log(DevLogCategory.game, 'Undo 2 moves');
    board.redoStack.add(board.pop());
    board.redoStack.add(board.pop());
    appModel.popMoveMeta();
    if (appModel.moveMetaList.length > 1) {
      _moveCompletion(appModel.moveMetaList[appModel.moveMetaList.length - 2],
          clearRedo: false, undoing: true, changeTurn: false);
    } else {
      _undoOpeningMove();
    }
  }

  void _undoOpeningMove() {
    selectedPiece = null;
    validMoves = [];
    latestMove = null;
    checkHintTile = null;
    appModel.popMoveMeta();
  }

  void redoMove() {
    _moveCompletion(board.pushMSO(board.redoStack.removeLast()),
        clearRedo: false);
  }

  void redoTwoMoves() {
    _moveCompletion(board.pushMSO(board.redoStack.removeLast()),
        clearRedo: false, updateMetaList: true);
    _moveCompletion(board.pushMSO(board.redoStack.removeLast()),
        clearRedo: false, updateMetaList: true);
  }

  // ── Promotion ──

  void promote(ChessPieceType type) {
    board.moveStack.last.movedPiece?.type = type;
    board.moveStack.last.promotionType = type;
    board.addPromotedPiece(board.moveStack.last);
    appModel.moveMetaList.last.promotionType = type;
    // Emit promotion move now that we have the final piece type.
    final mso = board.moveStack.last;
    final promoMove = Move(mso.move.from, mso.move.to, promotionType: type);
    _emitMoveIfOnline(promoMove, appModel.moveMetaList.last);
    _moveCompletion(appModel.moveMetaList.last, updateMetaList: false);
  }

  /// Apply an opponent move received via socket. Does NOT re-emit to socket.
  void applyRemoteMove({
    required String from,
    required String to,
    String? promotion,
  }) {
    final fromTile = _algebraicToTile(from);
    int toTile = _algebraicToTile(to);
    final piece = board.tiles[fromTile];
    if (piece == null) {
      DevLogger.instance.log(
        DevLogCategory.game,
        '[ONLINE] applyRemoteMove: no piece at $from (tile=$fromTile)',
      );
      return;
    }
    // Detect standard UCI castling: king moves 2+ columns on the same row to
    // an empty square. Convert to Chess960 king-to-rook format so board.push()
    // detects it correctly via _castled() (which checks for friendly piece at to).
    if (piece.type == ChessPieceType.king) {
      final fromRow = tileToRow(fromTile);
      final toRow = tileToRow(toTile);
      final fromCol = tileToCol(fromTile);
      final toCol = tileToCol(toTile);
      if (fromRow == toRow &&
          (toCol - fromCol).abs() >= 2 &&
          board.tiles[toTile] == null) {
        final isKingside = toCol > fromCol;
        final rookTile =
            _findCastlingRookTile(fromRow, isKingside, piece.player);
        if (rookTile != null) {
          DevLogger.instance.log(
            DevLogCategory.game,
            '[ONLINE] applyRemoteMove: detected UCI castling $from→$to | isKingside=$isKingside | rookTile=$rookTile',
          );
          toTile = rookTile;
        }
      }
    }
    final promoType = promotion != null
        ? _promoStringToPieceType(promotion)
        : ChessPieceType.promotion;
    final move = Move(fromTile, toTile, promotionType: promoType);
    final meta = board.push(move, getMeta: true);
    DevLogger.instance.log(
      DevLogCategory.game,
      '[ONLINE] applyRemoteMove: $from → $to${promotion != null ? ' promo=$promotion' : ''}',
    );
    appModel.audio.playMovedSound();
    if (meta.promotion && promotion != null) {
      final resolvedType = _promoStringToPieceType(promotion);
      board.moveStack.last.movedPiece?.type = resolvedType;
      board.moveStack.last.promotionType = resolvedType;
      board.addPromotedPiece(board.moveStack.last);
      meta.promotionType = resolvedType;
    }
    _moveCompletion(meta);
  }

  int _algebraicToTile(String algebraic) {
    final file = algebraic.codeUnitAt(0) - 97; // 'a'=0
    final rank = 8 - int.parse(algebraic[1]); // '8'=row0
    return rank * 8 + file;
  }

  /// Find the rook tile used for castling on the given row/side.
  /// Searches from the board edge inward toward the king (col 4).
  int? _findCastlingRookTile(int row, bool kingside, Player player) {
    if (kingside) {
      for (int col = 7; col > 4; col--) {
        final p = board.tiles[row * 8 + col];
        if (p?.type == ChessPieceType.rook && p?.player == player) {
          return row * 8 + col;
        }
      }
    } else {
      for (int col = 0; col < 4; col++) {
        final p = board.tiles[row * 8 + col];
        if (p?.type == ChessPieceType.rook && p?.player == player) {
          return row * 8 + col;
        }
      }
    }
    return null;
  }

  ChessPieceType _promoStringToPieceType(String s) {
    switch (s.toLowerCase()) {
      case 'q':
        return ChessPieceType.queen;
      case 'r':
        return ChessPieceType.rook;
      case 'b':
        return ChessPieceType.bishop;
      case 'n':
        return ChessPieceType.knight;
      default:
        return ChessPieceType.queen;
    }
  }

  // ── Move Completion ──

  void _moveCompletion(
    MoveMeta meta, {
    bool clearRedo = true,
    bool undoing = false,
    bool changeTurn = true,
    bool updateMetaList = true,
  }) async {
    if (clearRedo) {
      board.redoStack = [];
    }
    validMoves = [];
    latestMove = meta.move;
    checkHintTile = null;
    var oppositeTurn = oppositePlayer(appModel.turn);

    // kingInCheck is lightweight (no push/pop), keep synchronous
    if (board.kingInCheck(oppositeTurn)) {
      meta.isCheck = true;
      checkHintTile = board.kingForPlayer(oppositeTurn)?.tile;
      if (!undoing) {
        appModel.audio.playCheckFeedback();
        DevLogger.instance.log(DevLogCategory.game,
            'CHECK on ${oppositeTurn.name} king at tile $checkHintTile');
      }
    }

    // Run synchronously to avoid expensive object graph serialization in Isolates
    bool isCheckmate = board.kingInCheckmate(oppositeTurn);
    if (isCheckmate) {
      if (!meta.isCheck) {
        appModel.stalemate = true;
        meta.isStalemate = true;
        DevLogger.instance.log(DevLogCategory.game, 'STALEMATE');
      } else {
        DevLogger.instance.log(DevLogCategory.game, 'CHECKMATE — game over');
      }
      meta.isCheck = false;
      meta.isCheckmate = true;
      // In online PvP, do NOT call endGame() locally — the server's game:end
      // event is the authoritative source for winner determination.
      // Calling endGame() here would bypass forceUserWon and use didUserWin()
      // which returns true for both players in P2P mode (wrong result).
      final isOnlinePvP =
          appModel.isOnlineGameMode && !appModel.shouldRunLocalAiInOnlineVsAi;
      if (!isOnlinePvP) {
        appModel.endGame(silent: true);
      }
    }
    if (undoing) {
      appModel.popMoveMeta(silent: true);
      appModel.undoEndGame(silent: true);
    } else if (updateMetaList) {
      appModel.pushMoveMeta(meta, silent: true);
    }
    if (changeTurn) {
      // Record who made the move (current turn) so we can give that player
      // the per-move bonus before switching turns.
      final movedPlayer = appModel.turn;
      appModel.changeTurn(silent: true);
      // Apply per-move increment to the player who just moved (applies to
      // all modes: offline, AI, and online). Then reset move timer for the
      // player who just received the turn.
      if (!undoing) {
        try {
          appModel.timerService.addSecondsToPlayer(movedPlayer, 10);
        } catch (e) {
          DevLogger.instance
              .log(DevLogCategory.game, 'Failed to add increment to timer: $e');
        }
        appModel.timerService.resetMoveTimer();
      }
    }
    selectedPiece = null;
    // Single rebuild for all the state changes above
    appModel.update();
    if (appModel.isAIsTurn &&
        clearRedo &&
        changeTurn &&
        !appModel.isInputLocked &&
        (!appModel.isOnlineGameMode || appModel.shouldRunLocalAiInOnlineVsAi)) {
      _aiMove();
    }
  }

  void _emitMoveIfOnline(Move move, MoveMeta meta) {
    if (appModel.isSpectatorMode) return;
    // Emit for any online session EXCEPT local AI-fallback mode
    // (in AI-fallback, moves are computed locally and don't go to the socket server).
    if (!appModel.isOnlineGameMode) return;
    if (appModel.shouldRunLocalAiInOnlineVsAi) return;

    final gameId = appModel.onlineEvents.activeGameId;
    if (gameId == null || gameId.isEmpty) return;

    final from = _tileToAlgebraic(move.from);
    // For castling, the local board uses Chess960 king-to-rook notation
    // (move.to = rook's tile). Convert to standard UCI (king's destination
    // square) so the backend understands it: kingside → g-file (col 6),
    // queenside → c-file (col 2).
    String to;
    if (meta.kingCastle || meta.queenCastle) {
      final kingRow = tileToRow(move.from);
      final destCol = meta.kingCastle ? 6 : 2;
      to = _tileToAlgebraic(kingRow * 8 + destCol);
    } else {
      to = _tileToAlgebraic(move.to);
    }
    final promotion =
        meta.promotion ? pieceTypeToString(move.promotionType) : null;

    appModel.onlineEvents.emitMove(
      gameId: gameId,
      from: from,
      to: to,
      promotion: promotion,
    );

    DevLogger.instance.log(
      DevLogCategory.game,
      '[ONLINE] emit move via socket | gameId=$gameId | $from -> $to${meta.kingCastle ? ' (kingCastle→UCI)' : meta.queenCastle ? ' (queenCastle→UCI)' : ''}${promotion != null ? ' | promotion=$promotion' : ''}',
    );
  }

  String _tileToAlgebraic(int tile) {
    final file = String.fromCharCode(97 + tileToCol(tile));
    final rank = 8 - tileToRow(tile);
    return '$file$rank';
  }

  void snapSprites() {
    onSnapSprites?.call();
  }
}
