import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../logic/chess_game.dart';
import '../../../model/app_model.dart';
import '../../../model/player.dart';
import '../main_menu_view/mm_palette.dart';
import 'chess_board_widget.dart';

class BoardStage extends StatelessWidget {
  final AppModel appModel;
  final ChessGame chessGame;
  final double boardSize;
  final double topReservedHeight;

  const BoardStage({
    super.key,
    required this.appModel,
    required this.chessGame,
    required this.boardSize,
    this.topReservedHeight = 0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const stageHorizontalPadding = 0.0;
        const stageVerticalPadding = 8.0;
        const boardHorizontalPadding = 0.0;
        const boardVerticalPadding = 6.0;
        const turnBarSpacing = 8.0;
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

        final contentHeight = resolvedBoardSize +
            (boardVerticalPadding * 2) +
            turnBarSpacing +
            turnBarEstimatedHeight;
        final freeVerticalSpace = math.max(
          0.0,
          constraints.maxHeight - (stageVerticalPadding * 2) - contentHeight,
        );
        final adCompensation = (topReservedHeight * 0.18).clamp(0.0, 14.0);
        final topInset =
            (freeVerticalSpace * 0.20 + adCompensation).clamp(10.0, 34.0);

        return Padding(
          padding: EdgeInsets.only(
            top: topInset,
            left: stageHorizontalPadding,
            right: stageHorizontalPadding,
            bottom: stageVerticalPadding,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
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
                const SizedBox(height: turnBarSpacing),
                _TurnBar(appModel),
              ],
            ),
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
    return Selector<
        AppModel,
        ({
          bool isAI,
          bool over,
          bool inCheck,
          String? checkMessage,
          bool draw,
          bool userWon,
          bool isOnlinePvP,
          bool isSpectator,
          bool isMyTurn,
          Player turn,
          bool opponentDisconnected,
          String? gameEndReason,
          String? onlineWinner,
        })>(
      selector: (_, model) => (
        isAI: model.isAIsTurn,
        over: model.gameOver,
        inCheck: model.isOnlineGameMode && !model.shouldRunLocalAiInOnlineVsAi
            ? model.serverCheck
            : model.gameController != null
                ? model.gameController!.board.kingInCheck(model.turn)
                : false,
        checkMessage: model.serverCheckMessage,
        draw: model.stalemate,
        userWon: model.userWon,
        isOnlinePvP:
            model.isOnlineGameMode && !model.shouldRunLocalAiInOnlineVsAi,
        isSpectator: model.isSpectatorMode,
        isMyTurn: model.turn == model.playerSide,
        turn: model.turn,
        opponentDisconnected: model.opponentDisconnected,
        gameEndReason: model.gameEndReason,
        onlineWinner: model.onlineWinner,
      ),
      builder: (context, state, __) {
        final l = AppLocalizations.of(context)!;
        final String label;
        final Color dotColor;

        final showAiState = state.isAI && !state.isOnlinePvP;

        if (state.over) {
          if (state.draw) {
            label = l.stalemate;
            dotColor = Colors.orangeAccent;
          } else if (state.isSpectator) {
            // Spectator: show who actually won, not "Bạn thắng/thua"
            final langCode = Localizations.localeOf(context).languageCode;
            if (state.onlineWinner == 'white') {
              label = langCode == 'vi' ? 'Trắng thắng' : 'White wins';
              dotColor = Colors.white;
            } else if (state.onlineWinner == 'black') {
              label = langCode == 'vi' ? 'Đen thắng' : 'Black wins';
              dotColor = Colors.grey.shade400;
            } else {
              label = l.stalemate;
              dotColor = Colors.orangeAccent;
            }
          } else if (state.isOnlinePvP &&
              (state.gameEndReason == 'abandoned' ||
                  state.gameEndReason == 'resigned')) {
            // Show reason-specific label (who left/resigned) and outcome colour
            label = state.userWon ? l.opponentLeft : l.youLose;
            dotColor = state.userWon ? Colors.greenAccent : Colors.redAccent;
          } else if (state.userWon) {
            label = l.youWin;
            dotColor = Colors.greenAccent;
          } else {
            label = l.youLose;
            dotColor = Colors.redAccent;
          }
        } else if (state.inCheck) {
          if (state.isOnlinePvP &&
              state.checkMessage != null &&
              state.checkMessage!.isNotEmpty) {
            final raw = state.checkMessage!.trim().toLowerCase();
            if (raw == 'dang_bi_chieu' || raw == 'check') {
              label = state.isMyTurn ? l.checkAlertYou : l.checkAlertOpponent;
            } else {
              label = state.checkMessage!;
            }
          } else {
            label = state.isMyTurn ? l.checkAlertYou : l.checkAlertOpponent;
          }
          dotColor = const Color(0xFFFF6B6B);
        } else if (state.isSpectator) {
          final langCode = Localizations.localeOf(context).languageCode;
          label = langCode == 'vi' ? 'Đang xem trực tiếp' : 'Watching Live';
          dotColor = const Color(0xFF6EC1FF);
        } else if (state.isOnlinePvP) {
          // Opponent disconnected but game not yet ended (grace period)
          if (state.opponentDisconnected) {
            label = l.opponentDisconnected;
            dotColor = Colors.orangeAccent;
          } else if (state.isMyTurn) {
            label = l.yourTurn;
            dotColor = primary;
          } else {
            label = state.turn == Player.player1 ? l.whiteTurn : l.blackTurn;
            dotColor = Colors.white38;
          }
        } else {
          label = showAiState ? l.botLevel(appModel.aiDifficulty) : l.yourTurn;
          dotColor = showAiState ? Colors.white38 : primary;
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
              if (!state.over && showAiState)
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
