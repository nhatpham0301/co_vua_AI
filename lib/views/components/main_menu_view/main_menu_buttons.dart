import 'package:flutter/cupertino.dart';

import '../../../l10n/app_localizations.dart';
import '../../../logic/game_state_storage.dart';
import '../../../model/app_model.dart';
import '../../chess_view.dart';
import '../../settings_view.dart';
import '../shared/rounded_button.dart';

class MainMenuButtons extends StatefulWidget {
  final AppModel appModel;

  MainMenuButtons(this.appModel);

  @override
  _MainMenuButtonsState createState() => _MainMenuButtonsState();
}

class _MainMenuButtonsState extends State<MainMenuButtons> {
  bool _hasSavedGame = false;

  @override
  void initState() {
    super.initState();
    _checkSavedGame();
  }

  void _checkSavedGame() async {
    final hasSaved = await GameStateStorage.hasSavedGame();
    if (mounted) {
      setState(() {
        _hasSavedGame = hasSaved;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      child: Column(
        children: [
          if (_hasSavedGame) ...[
            RoundedButton(
              l.resumeGame,
              onPressed: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) {
                      return ChessView(widget.appModel, isResuming: true);
                    },
                  ),
                ).then((_) => _checkSavedGame());
              },
            ),
            SizedBox(height: 10),
          ],
          RoundedButton(
            l.start,
            onPressed: () {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) {
                    return ChessView(widget.appModel);
                  },
                ),
              ).then((_) => _checkSavedGame());
            },
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: RoundedButton(
                  l.settings,
                  onPressed: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => SettingsView(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
