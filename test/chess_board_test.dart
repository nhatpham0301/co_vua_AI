import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_chess_ai/logic/chess_board.dart';
import 'package:infinite_chess_ai/model/player.dart';

void main() {
  group('ChessBoard Bug Fixes', () {
    test('Bug 3: FRC Castling when target square is attacked', () {
      final board = ChessBoard();
      // FEN: Black king at e8, Black rook at a8. White bishop at e6.
      // e6 bishop attacks c8 and d7.
      // Black king at e8, castling queenside means moving to c8.
      // Since c8 is attacked, castling should be invalid.
      board.loadFromFen('r3k2r/8/4B3/8/8/8/8/4K3 b q - 0 1');

      final blackKing = board.kingForPlayer(Player.player2);
      expect(blackKing, isNotNull);
      
      final moves = board.movesForPiece(blackKing!);
      
      // The castling destination tile in this engine is the rook's tile (a8 = tile 0).
      // Since c8 is attacked by the e6 bishop, castling should not be in the list of moves.
      expect(moves.contains(0), isFalse, reason: 'c8 is attacked by e6 bishop, so castling is illegal');
    });

    test('Bug 3: FRC Castling is valid when not attacked', () {
      final board = ChessBoard();
      // FEN: Black king at e8, Black rook at a8. White bishop is away at a1.
      // c8 is safe.
      board.loadFromFen('r3k2r/8/8/8/8/8/8/B3K3 b q - 0 1');

      final blackKing = board.kingForPlayer(Player.player2);
      expect(blackKing, isNotNull);
      
      final moves = board.movesForPiece(blackKing!);
      
      // c8 is safe, so castling to rook tile a8 (tile 0) is legal
      expect(moves.contains(0), isTrue, reason: 'c8 is safe, so castling to rook tile a8 is legal');
    });
  });
}
