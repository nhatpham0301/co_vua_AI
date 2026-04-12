import 'package:flutter/cupertino.dart';

import '../../../../l10n/app_localizations.dart';
import 'picker.dart';

class TimeLimitPicker extends StatelessWidget {
  final int? selectedTime;
  final Function(int?)? setTime;

  TimeLimitPicker({this.selectedTime, this.setTime});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Picker<int>(
      label: l.timeLimit,
      options: <int, Text>{
        0: Text(l.timeLimitNone),
        15: const Text('15m'),
        30: const Text('30m'),
        60: const Text('1h'),
        90: const Text('1.5h'),
        120: const Text('2h'),
      },
      selection: selectedTime,
      setFunc: setTime,
    );
  }
}
