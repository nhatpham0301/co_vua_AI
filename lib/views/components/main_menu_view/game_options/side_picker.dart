import 'package:flutter/cupertino.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../model/player.dart';
import 'picker.dart';

class SidePicker extends StatelessWidget {
  final Player playerSide;
  final Function(Player?) setFunc;

  SidePicker(this.playerSide, this.setFunc);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Picker<Player>(
      label: l.side,
      options: <Player, Text>{
        Player.player1: Text(l.sideWhite),
        Player.player2: Text(l.sideBlack),
        Player.random: Text(l.sideRandom),
      },
      selection: playerSide,
      setFunc: setFunc,
    );
  }
}
