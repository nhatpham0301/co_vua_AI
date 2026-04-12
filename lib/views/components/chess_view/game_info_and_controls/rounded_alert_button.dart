import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../shared/app_dialog.dart';
import '../../shared/rounded_button.dart';

class RoundedAlertButton extends StatelessWidget {
  final String label;
  final Function onConfirm;

  RoundedAlertButton(this.label, {required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return RoundedButton(label, onPressed: () {
      final l = AppLocalizations.of(context)!;
      showAppDialog<void>(
        context: context,
        title: label,
        message: l.restartConfirmMsg(label.toLowerCase()),
        actions: [
          AppDialogAction(
            label: label,
            isPrimary: true,
            onPressed: () => onConfirm(),
          ),
          AppDialogAction(label: l.cancel),
        ],
      );
    });
  }
}
