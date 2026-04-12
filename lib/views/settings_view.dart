import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../logic/dev_logger.dart';
import '../model/app_model.dart';
import 'components/main_menu_view/mm_background.dart';
import 'components/main_menu_view/mm_palette.dart';
import 'components/settings_view/app_theme_picker.dart';
import 'components/settings_view/language_picker.dart';
import 'components/settings_view/piece_theme_picker.dart';
import 'components/settings_view/toggles.dart';
import 'components/shared/app_dialog.dart';
import 'components/shared/bottom_padding.dart';
import 'components/shared/rounded_button.dart';
import 'developer_view.dart';

class SettingsView extends StatelessWidget {
  void _showResetConfirmation(BuildContext context, AppModel appModel) {
    final l = AppLocalizations.of(context)!;
    showAppDialog<void>(
      context: context,
      title: l.resetSettingsTitle,
      message: l.resetSettingsConfirm,
      actions: [
        AppDialogAction(
          label: l.reset,
          isPrimary: true,
          onPressed: appModel.resetSettingsToDefaults,
        ),
        AppDialogAction(label: l.cancel),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [bgMid, bgDark],
              ),
            ),
          ),
          const BoardBackground(),
          const CornerKnots(),
          Padding(
            padding: EdgeInsets.all(30),
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top),
                Expanded(
                  child: CupertinoScrollbar(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      physics: ClampingScrollPhysics(),
                      children: [
                        AppThemePicker(),
                        SizedBox(height: 10),
                        PieceThemePicker(),
                        SizedBox(height: 10),
                        const LanguagePicker(),
                        SizedBox(height: 10),
                        Consumer<AppModel>(
                          builder: (context, appModel, child) =>
                              Toggles(appModel),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                RoundedButton(
                  l.back,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 12),
                const _DevTapTarget(),
                BottomPadding(),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 30,
            right: 30,
            child: Consumer<AppModel>(
              builder: (context, appModel, child) => CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  _showResetConfirmation(context, appModel);
                },
                child: Icon(
                  Icons.settings_backup_restore_rounded,
                  color: const Color(0x99FFFFFF), // semi-transparent white
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Secret Developer Mode Entry ──────────────────────────────────────────────
// Tap the version label 5 times to open the Developer panel.
class _DevTapTarget extends StatefulWidget {
  const _DevTapTarget();

  @override
  State<_DevTapTarget> createState() => _DevTapTargetState();
}

class _DevTapTargetState extends State<_DevTapTarget> {
  int _taps = 0;
  static const _kRequired = 5;

  void _onTap() {
    setState(() => _taps++);
    if (_taps >= _kRequired) {
      _taps = 0;
      DevLogger.instance.setDevMode(true);
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => const DeveloperView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final remaining = _kRequired - _taps;
    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Text(
              'v1.0.2+3',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.15),
                fontSize: 11,
              ),
            ),
            if (_taps > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l.devModeHint(remaining),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
