import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/app_model.dart';
import '../../../model/app_themes.dart';
import '../main_menu_view/mm_palette.dart';
import '../shared/text_variable.dart';

class AppThemePicker extends StatefulWidget {
  @override
  _AppThemePickerState createState() => _AppThemePickerState();
}

class _AppThemePickerState extends State<AppThemePicker> {
  late FixedExtentScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    final appModel = Provider.of<AppModel>(context, listen: false);
    _scrollController =
        FixedExtentScrollController(initialItem: appModel.themeIndex);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Selector<AppModel, int>(
      selector: (_, m) => m.themeIndex,
      builder: (context, themeIndex, child) {
        if (_scrollController.hasClients &&
            _scrollController.selectedItem != themeIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.jumpToItem(themeIndex);
            }
          });
        }
        return Column(
          children: [
            Container(
              alignment: Alignment.center,
              child: TextRegular(l.appTheme),
              padding: EdgeInsets.symmetric(vertical: 10),
            ),
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(15)),
                color: bgCard.withValues(alpha: 0.42),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: CupertinoPicker(
                scrollController: _scrollController,
                selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                  background: primary.withValues(alpha: 0.08),
                ),
                itemExtent: 50,
                onSelectedItemChanged:
                    Provider.of<AppModel>(context, listen: false).setTheme,
                children: themeList
                    .map(
                      (theme) => Container(
                        alignment: Alignment.center,
                        padding: EdgeInsets.all(10),
                        child: TextRegular(theme.name ?? ""),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}
