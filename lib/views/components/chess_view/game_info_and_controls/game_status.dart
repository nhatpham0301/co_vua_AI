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
  String? gameEndReason,
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
        gameEndReason: m.gameEndReason,
        aiDifficulty: m.aiDifficulty,
      ),
      builder: (context, state, child) {
        final l = AppLocalizations.of(context)!;
        return Row(
          children: [
            TextRegular(_getStatus(context, state, l)),
            !state.gameOver && state.playerCount == 1 && state.isAIsTurn
                ? CupertinoActivityIndicator(radius: 12)
                : Container()
          ],
          mainAxisAlignment: MainAxisAlignment.center,
        );
      },
    );
  }

  String _drawLabel(BuildContext context, String? reason, AppLocalizations l) {
    if (reason == 'stalemate') return l.stalemate;
    return Localizations.localeOf(context).languageCode == 'vi'
        ? 'Hòa cờ'
        : 'Draw';
  }

  String _getStatus(BuildContext context, _StatusState s, AppLocalizations l) {
    if (!s.gameOver) {
      if (s.playerCount == 1) {
        if (s.isAIsTurn) {
          return l.botLevel(s.aiDifficulty);
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
        return _drawLabel(context, s.gameEndReason, l);
      }
      return s.userWon ? l.youWin : l.youLose;
    }
  }
}
