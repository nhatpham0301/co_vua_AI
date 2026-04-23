import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../model/app_model.dart';
import '../../../../model/player.dart';
import '../../shared/text_variable.dart';

/// State tuple for GameStatus — only rebuilds when these fields change.
typedef _StatusState = ({
  bool gameOver,
  int playerCount,
  bool isAIsTurn,
  bool userWon,
  Player turn,
  bool stalemate,
  int aiDifficulty,
});

class GameStatus extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Selector<AppModel, _StatusState>(
      selector: (_, m) => (
        gameOver: m.gameOver,
        playerCount: m.playerCount,
        isAIsTurn: m.isAIsTurn,
        userWon: m.userWon,
        turn: m.turn,
        stalemate: m.stalemate,
        aiDifficulty: m.aiDifficulty,
      ),
      builder: (context, state, child) {
        final l = AppLocalizations.of(context)!;
        return Row(
          children: [
            TextRegular(_getStatus(state, l)),
            !state.gameOver && state.playerCount == 1 && state.isAIsTurn
                ? CupertinoActivityIndicator(radius: 12)
                : Container()
          ],
          mainAxisAlignment: MainAxisAlignment.center,
        );
      },
    );
  }

  String _getStatus(_StatusState s, AppLocalizations l) {
    if (!s.gameOver) {
      if (s.playerCount == 1) {
        if (s.isAIsTurn) {
          return l.aiThinking(s.aiDifficulty);
        } else {
          return l.yourTurn;
        }
      } else {
        if (s.turn == Player.player1) {
          return l.whiteTurn;
        } else {
          return l.blackTurn;
        }
      }
    } else {
      if (s.stalemate) {
        return l.stalemate;
      } else {
        if (s.playerCount == 1) {
          if (s.isAIsTurn) {
            return l.youWin;
          } else {
            return l.youLose;
          }
        } else {
          // P2P (local or online): use userWon which is set correctly per player
          if (s.userWon) {
            return l.youWin;
          } else {
            return l.youLose;
          }
        }
      }
    }
  }
}
