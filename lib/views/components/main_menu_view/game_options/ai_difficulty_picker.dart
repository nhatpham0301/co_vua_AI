import 'package:flutter/cupertino.dart';

import '../../../../l10n/app_localizations.dart';
import 'picker.dart';

class AIDifficultyPicker extends StatelessWidget {
  final Map<int, Text> difficultyOptions = {
    1: Text('1'),
    2: Text('2'),
    3: Text('3'),
    4: Text('4'),
    5: Text('5')
  };

  final int aiDifficulty;
  final Function(int?) setFunc;

  AIDifficultyPicker(this.aiDifficulty, this.setFunc);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Picker<int>(
      label: l.aiDifficulty,
      options: difficultyOptions,
      selection: aiDifficulty,
      setFunc: setFunc,
    );
  }
}
