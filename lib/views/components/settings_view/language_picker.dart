import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/app_model.dart';
import '../main_menu_view/mm_palette.dart';
import '../shared/text_variable.dart';

class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Consumer<AppModel>(
      builder: (context, appModel, child) {
        final selectedLocale = appModel.locale?.languageCode ?? 'vi';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: bgCard.withValues(alpha: 0.42),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Expanded(child: TextRegular(l.language)),
              CupertinoSlidingSegmentedControl<String>(
                groupValue: selectedLocale,
                onValueChanged: (value) {
                  if (value != null) {
                    appModel.setLocale(value);
                  }
                },
                children: {
                  'vi': Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: TextDefault(l.vietnamese),
                  ),
                  'en': Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: TextDefault(l.english),
                  ),
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
