import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/app_model.dart';
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
          padding: const EdgeInsets.symmetric(vertical: 10),
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
