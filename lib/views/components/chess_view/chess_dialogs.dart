import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../logic/chess_piece.dart';
import '../../../logic/shared_functions.dart';
import '../../../model/app_model.dart';
import '../../../model/app_themes.dart';
import '../../../model/player.dart';
import '../shared/rounded_button.dart';

void showExitDialog(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  showGeneralDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    barrierDismissible: true,
    barrierLabel: '',
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (dialogContext, anim1, anim2) {
      return Selector<AppModel, AppTheme>(
        selector: (_, model) => model.theme,
        builder: (dialogContext, theme, child) => Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 340),
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                gradient: theme.background,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.leaveGameTitle,
                    style: const TextStyle(
                      fontSize: 32,
                      fontFamily: 'Jura',
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    l.leaveGameSubtitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontFamily: 'Jura',
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  Consumer<AppModel>(
                    builder: (context, appModel, child) => RoundedButton(
                      l.saveAndExit,
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        appModel.saveAndExitChessView();
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  const SizedBox(height: 15),
                  Consumer<AppModel>(
                    builder: (context, appModel, child) => RoundedButton(
                      l.exit,
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        appModel.exitChessView();
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  const SizedBox(height: 15),
                  RoundedButton(
                    l.cancel,
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return Transform.scale(
        scale: 0.95 + 0.05 * anim1.value,
        child: FadeTransition(
          opacity: anim1,
          child: child,
        ),
      );
    },
  );
}

void showCapturedPiecesSheet(
  BuildContext context,
  AppModel appModel,
  Player player,
  String title,
) {
  showCupertinoModalPopup<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.48),
    builder: (_) => SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.transparent,
          child: _CapturedPiecesSheet(
            appModel: appModel,
            player: player,
            title: title,
          ),
        ),
      ),
    ),
  );
}

class _CapturedPiecesSheet extends StatelessWidget {
  final AppModel appModel;
  final Player player;
  final String title;

  const _CapturedPiecesSheet({
    required this.appModel,
    required this.player,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final lostPieces = player == Player.player1
        ? appModel.capturedWhite
        : appModel.capturedBlack;
    final groupedPieces = _groupCapturedPieces(lostPieces);
    final lead = appModel.materialAdvantageFor(Player.player1);
    final leadLabel = _materialLeadLabel(appModel, lead, l);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: EdgeInsets.fromLTRB(18, 12, 18, 14 + bottomInset),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xEE252C35), Color(0xEE14181F)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            leadLabel,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          if (groupedPieces.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white.withValues(alpha: 0.04),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Text(
                l.noPiecesCaptured,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: groupedPieces.entries.map((entry) {
                return _CapturedPieceBadge(
                  appModel: appModel,
                  pieceType: entry.key,
                  lostPlayer: player,
                  count: entry.value,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _CapturedPieceBadge extends StatelessWidget {
  final AppModel appModel;
  final ChessPieceType pieceType;
  final Player lostPlayer;
  final int count;

  const _CapturedPieceBadge({
    required this.appModel,
    required this.pieceType,
    required this.lostPlayer,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final color = lostPlayer == Player.player1 ? 'white' : 'black';
    final typeName = pieceTypeToString(pieceType);
    final assetPath =
        'assets/images/pieces/${formatPieceTheme(appModel.pieceTheme)}/${typeName}_$color.png';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x553F4F3B), Color(0x33222A31)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.extension_rounded,
                color: Colors.white38,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'x$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

Map<ChessPieceType, int> _groupCapturedPieces(List<ChessPieceType> pieces) {
  final grouped = <ChessPieceType, int>{};
  for (final piece in pieces) {
    grouped[piece] = (grouped[piece] ?? 0) + 1;
  }

  final entries = grouped.entries.toList()
    ..sort(
      (left, right) => _capturedPieceScore(right.key)
          .compareTo(_capturedPieceScore(left.key)),
    );

  return Map<ChessPieceType, int>.fromEntries(entries);
}

String _materialLeadLabel(
    AppModel appModel, int whiteLead, AppLocalizations l) {
  if (whiteLead == 0) {
    return l.materialBalance;
  }

  final leader = whiteLead > 0 ? Player.player1 : Player.player2;
  final leaderLabel = appModel.playingWithAI
      ? (leader == Player.player1 ? l.materialLeadYou : l.materialLeadBot)
      : (leader == Player.player1 ? l.materialLeadWhite : l.materialLeadBlack);
  return l.materialLead(leaderLabel, whiteLead.abs());
}

int _capturedPieceScore(ChessPieceType type) {
  switch (type) {
    case ChessPieceType.pawn:
      return 1;
    case ChessPieceType.knight:
    case ChessPieceType.bishop:
      return 3;
    case ChessPieceType.rook:
      return 5;
    case ChessPieceType.queen:
      return 9;
    case ChessPieceType.king:
    case ChessPieceType.promotion:
      return 0;
  }
}
