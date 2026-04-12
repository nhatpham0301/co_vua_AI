import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/app_model.dart';
import 'toggle.dart';

class Toggles extends StatelessWidget {
  final AppModel appModel;

  Toggles(this.appModel);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      children: [
        Toggle(
          l.boardRotation,
          toggle: appModel.enableRotation,
          setFunc: appModel.setEnableRotation,
        ),
        Toggle(
          l.showHints,
          toggle: appModel.showHints,
          setFunc: appModel.setShowHints,
        ),
        Toggle(
          l.showNotation,
          toggle: appModel.showNotation,
          setFunc: appModel.setShowNotation,
        ),
        Toggle(
          l.allowUndoRedo,
          toggle: appModel.allowUndoRedo,
          setFunc: appModel.setAllowUndoRedo,
        ),
        Toggle(
          l.showMoveHistory,
          toggle: appModel.showMoveHistory,
          setFunc: appModel.setShowMoveHistory,
        ),
        Toggle(
          l.sound,
          toggle: appModel.soundEnabled,
          setFunc: appModel.setSoundEnabled,
        ),
      ],
    );
  }
}
