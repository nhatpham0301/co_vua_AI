import 'package:flutter/cupertino.dart';

import '../../../../l10n/app_localizations.dart';
import 'picker.dart';

class TimeMoveLimitPicker extends StatelessWidget {
  final int? selectedLimit;
  final Function(int?)? setLimit;

  const TimeMoveLimitPicker({this.selectedLimit, this.setLimit});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Picker<int>(
      label: l.timeMoveLimit,
      options: <int, Text>{
        0: Text(l.timeMoveLimitNone),
        10: const Text('10s'),
        15: const Text('15s'),
        20: const Text('20s'),
        30: const Text('30s'),
        60: const Text('60s'),
      },
      selection: selectedLimit,
      setFunc: setLimit,
    );
  }
}
