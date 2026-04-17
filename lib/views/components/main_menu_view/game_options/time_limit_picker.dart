import 'package:flutter/cupertino.dart';

import '../../../../l10n/app_localizations.dart';
import 'picker.dart';

class TimeLimitPicker extends StatelessWidget {
  final int? selectedTime;
  final Function(int?)? setTime;
  final bool themed;

  TimeLimitPicker({this.selectedTime, this.setTime, this.themed = false});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Picker<int>(
      label: l.timeLimit,
      themed: themed,
      options: <int, Text>{
        0: Text(l.timeLimitNone),
        5: const Text('5m'),
        10: const Text('10m'),
        15: const Text('15m'),
        20: const Text('20m'),
        30: const Text('30m'),
        45: const Text('45m'),
        60: const Text('1h'),
      },
      selection: selectedTime,
      setFunc: setTime,
    );
  }
}
