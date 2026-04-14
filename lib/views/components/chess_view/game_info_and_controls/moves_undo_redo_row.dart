import 'package:flutter/cupertino.dart';

import '../../../../model/app_model.dart';
import 'moves_undo_redo_row/move_list.dart';
import 'moves_undo_redo_row/undo_redo_buttons.dart';

class MovesUndoRedoRow extends StatelessWidget {
  final AppModel appModel;

  MovesUndoRedoRow(this.appModel);

  @override
  Widget build(BuildContext context) {
    final showUndoRedo = appModel.allowUndoRedo && !appModel.isOnlineGameMode;
    return Column(
      children: [
        Row(
          children: [
            appModel.showMoveHistory
                ? Expanded(child: MoveList(appModel))
                : Container(),
            appModel.showMoveHistory && showUndoRedo
                ? SizedBox(width: 10)
                : Container(),
            showUndoRedo
                ? Expanded(child: UndoRedoButtons(appModel))
                : Container(),
          ],
        ),
        appModel.showMoveHistory || showUndoRedo
            ? SizedBox(height: 10)
            : Container(),
      ],
    );
  }
}
