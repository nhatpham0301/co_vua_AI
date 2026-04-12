import 'package:flutter/cupertino.dart';

import '../../../../model/app_model.dart';
import '../../shared/rounded_button.dart';
import '../chess_dialogs.dart';
import 'rounded_alert_button.dart';

class RestartExitButtons extends StatelessWidget {
  final AppModel appModel;
  final VoidCallback onNewGame;

  RestartExitButtons(this.appModel, {required this.onNewGame});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: RoundedAlertButton(
            'Restart',
            onConfirm: () {
              if (!appModel.gameOver) {
                appModel.adService.markGameAbandoned();
                appModel.adService.showAdBeforeGame(
                  () {
                    appModel.newGame(notify: false);
                    onNewGame();
                  },
                  context: context,
                );
              } else {
                appModel.newGame(notify: false);
                onNewGame();
              }
            },
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: appModel.gameOver
              ? RoundedButton(
                  'Exit',
                  onPressed: () {
                    appModel.exitChessView();
                    Navigator.pop(context);
                  },
                )
              : RoundedButton(
                  'Exit',
                  onPressed: () {
                    showExitDialog(context);
                  },
                ),
        ),
      ],
    );
  }
}
