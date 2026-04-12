import 'package:flutter/cupertino.dart';

import '../../../../l10n/app_localizations.dart';
import 'picker.dart';

class GameModePicker extends StatelessWidget {
  final int playerCount;
  final Function(int?) setFunc;

  GameModePicker(this.playerCount, this.setFunc);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Picker<int>(
      label: l.gameMode,
      options: <int, Text>{
        1: Text(l.onePlayer),
        2: Text(l.twoPlayer),
      },
      selection: playerCount,
      setFunc: setFunc,
    );
  }
}
