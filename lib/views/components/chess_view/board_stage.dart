import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../logic/chess_game.dart';
import '../../../model/app_model.dart';
import '../main_menu_view/mm_palette.dart';
import 'chess_board_widget.dart';

class BoardStage extends StatelessWidget {
  final AppModel appModel;
  final ChessGame chessGame;
  final double boardSize;

  const BoardStage({
    super.key,
    required this.appModel,
    required this.chessGame,
    required this.boardSize,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const stageHorizontalPadding = 0.0;
        const stageVerticalPadding = 8.0;
        const boardHorizontalPadding = 0.0;
        const boardVerticalPadding = 8.0;
        const turnBarSpacing = 12.0;
        const turnBarEstimatedHeight = 44.0;

        final maxBoardWidth =
            constraints.maxWidth - (stageHorizontalPadding * 2);
        final maxBoardHeight = constraints.maxHeight -
            (stageVerticalPadding * 2) -
            turnBarSpacing -
            turnBarEstimatedHeight -
            (boardVerticalPadding * 2);

        final double resolvedBoardSize = math
            .max(
              220.0,
              math.min(boardSize, math.min(maxBoardWidth, maxBoardHeight)),
            )
            .toDouble();

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: stageHorizontalPadding,
            vertical: stageVerticalPadding,
          ),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: boardHorizontalPadding,
                      vertical: boardVerticalPadding,
                    ),
                    child: ChessBoardWidget(
                      appModel,
                      chessGame,
                      boardSize: resolvedBoardSize,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: turnBarSpacing),
              _TurnBar(appModel),
            ],
          ),
        );
      },
    );
  }
}

class _TurnBar extends StatelessWidget {
  final AppModel appModel;

  const _TurnBar(this.appModel);

  @override
  Widget build(BuildContext context) {
    return Selector<AppModel, ({bool isAI, bool over, bool draw})>(
      selector: (_, model) => (
        isAI: model.isAIsTurn,
        over: model.gameOver,
        draw: model.stalemate,
      ),
      builder: (context, state, __) {
        final l = AppLocalizations.of(context)!;
        final String label;
        final Color dotColor;

        if (state.over) {
          if (state.draw) {
            label = l.stalemate;
            dotColor = Colors.orangeAccent;
          } else if (state.isAI) {
            label = l.youWin;
            dotColor = Colors.greenAccent;
          } else {
            label = l.youLose;
            dotColor = Colors.redAccent;
          }
        } else {
          label = state.isAI ? l.aiThinking(appModel.aiDifficulty) : l.yourTurn;
          dotColor = state.isAI ? Colors.white38 : primary;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.black.withValues(alpha: 0.3),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!state.over && state.isAI)
                const CupertinoActivityIndicator(
                  radius: 6,
                  color: Colors.white54,
                )
              else
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    boxShadow: [
                      BoxShadow(
                        color: dotColor.withValues(alpha: 0.45),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 9),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
