import 'package:flame/game.dart';
import 'package:flutter/cupertino.dart';

import '../../../logic/chess_game.dart';
import '../../../model/app_model.dart';

class ChessBoardWidget extends StatelessWidget {
  final AppModel appModel;
  final ChessGame chessGame;
  final double? boardSize;

  const ChessBoardWidget(this.appModel, this.chessGame,
      {super.key, this.boardSize});

  @override
  Widget build(BuildContext context) {
    final resolvedBoardSize =
        boardSize ?? MediaQuery.of(context).size.width - 68;
    final isVideoTheme = appModel.theme.name == 'Video Chess';

    // Adaptive frame keeps the board readable on small screens and avoids heavy padding.
    final frameWidth = isVideoTheme
        ? 0.0
        : (resolvedBoardSize * 0.009).clamp(1.5, 3.0).toDouble();
    final outerRadius = isVideoTheme
        ? 0.0
        : (resolvedBoardSize * 0.024).clamp(6.0, 10.0).toDouble();

    return Stack(
      children: [
        SizedBox(
          width: resolvedBoardSize,
          height: resolvedBoardSize,
          child: AnimatedRotation(
            turns: appModel.isBoardInverted ? 0.5 : 0,
            duration: appModel.animateBoardRotation
                ? const Duration(milliseconds: 600)
                : Duration.zero,
            curve: Curves.easeInOut,
            child: DecoratedBox(
              decoration: isVideoTheme
                  ? const BoxDecoration()
                  : BoxDecoration(
                      border: Border.all(
                        color: appModel.theme.border,
                        width: frameWidth,
                      ),
                      borderRadius: BorderRadius.circular(outerRadius),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 6,
                          spreadRadius: -1,
                          offset: Offset(0, 0),
                          color: Color(0x55000000),
                        ),
                      ],
                    ),
              child: ClipRRect(
                borderRadius: isVideoTheme
                    ? BorderRadius.zero
                    : BorderRadius.circular(outerRadius),
                child: SizedBox.expand(
                  child: GameWidget(game: chessGame),
                ),
              ),
            ),
          ),
        ),
        if (appModel.showNotation)
          SizedBox(
            width: resolvedBoardSize,
            height: resolvedBoardSize,
            child: _NotationOverlay(
              appModel.theme.notation,
              isRotated: appModel.isBoardInverted,
              boardSize: resolvedBoardSize,
            ),
          ),
      ],
    );
  }
}

class _NotationOverlay extends StatefulWidget {
  final Color color;
  final bool isRotated;
  final double boardSize;

  const _NotationOverlay(
    this.color, {
    required this.isRotated,
    required this.boardSize,
  });

  @override
  _NotationOverlayState createState() => _NotationOverlayState();
}

class _NotationOverlayState extends State<_NotationOverlay> {
  late bool _visibleRotated;
  double _opacity = 1.0;

  @override
  void initState() {
    super.initState();
    _visibleRotated = widget.isRotated;
  }

  @override
  void didUpdateWidget(_NotationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRotated != widget.isRotated) {
      setState(() {
        _opacity = 0.0;
      });
      Future.delayed(Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _visibleRotated = widget.isRotated;
            _opacity = 1.0;
          });
        }
      });
    } else {
      // If color changed but flip didn't (e.g. theme change), update state immediately if needed
      if (oldWidget.color != widget.color) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: Duration(milliseconds: _opacity == 0.0 ? 100 : 300),
        opacity: _opacity,
        child: Stack(
          children: [
            // Files (Letters)
            for (int i = 0; i < 8; i++)
              Positioned(
                left: (i * widget.boardSize / 8),
                bottom: 1,
                width: widget.boardSize / 8,
                child: Text(
                  String.fromCharCode(
                      (_visibleRotated ? 'h' : 'a').codeUnitAt(0) +
                          (_visibleRotated ? -i : i)),
                  style: TextStyle(
                    color: widget.color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            // Ranks (Numbers)
            for (int i = 0; i < 8; i++)
              Positioned(
                top: (i * widget.boardSize / 8) + 2,
                left: 6,
                height: widget.boardSize / 8,
                child: Text(
                  (_visibleRotated ? i + 1 : 8 - i).toString(),
                  style: TextStyle(
                    color: widget.color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
