import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../logic/dev_logger.dart';
import '../model/app_model.dart';
import 'components/main_menu_view/game_options/time_increment_picker.dart';
import 'components/main_menu_view/game_options/time_limit_picker.dart';
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
                        SizedBox(height: 10),
                        Consumer<AppModel>(
                          builder: (context, appModel, child) =>
                              _TimerSettingsSection(appModel: appModel),
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

// ─── Timer Settings Section ───────────────────────────────────────────────────
class _TimerSettingsSection extends StatelessWidget {
  final AppModel appModel;

  const _TimerSettingsSection({required this.appModel});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            l.timerSettings,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
        TimeLimitPicker(
          selectedTime: appModel.timeLimit,
          setTime: appModel.setTimeLimit,
        ),
        const SizedBox(height: 10),
        TimeMoveLimitPicker(
          selectedLimit: appModel.moveTimeLimit,
          setLimit: appModel.setMoveTimeLimit,
        ),
      ],
    );
  }
}

// ─── Secret Developer Mode Entry ──────────────────────────────────────────────
// Tap the version label 5 times to open the Developer panel.
// When dev mode is already active, show a toggle to disable it + button to
// open the dev panel directly.
class _DevTapTarget extends StatefulWidget {
  const _DevTapTarget();

  @override
  State<_DevTapTarget> createState() => _DevTapTargetState();
}

class _DevTapTargetState extends State<_DevTapTarget> {
  int _taps = 0;
  static const _kRequired = 5;

  void _onTap() {
    if (DevLogger.instance.devModeEnabled) return;
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
    return ListenableBuilder(
      listenable: DevLogger.instance,
      builder: (context, _) {
        if (DevLogger.instance.devModeEnabled) {
          return _DevModeActiveSection(l: l);
        }
        return _buildVersionTap(l);
      },
    );
  }

  Widget _buildVersionTap(AppLocalizations l) {
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

class _DevModeActiveSection extends StatelessWidget {
  final AppLocalizations l;
  const _DevModeActiveSection({required this.l});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: bgCard.withValues(alpha: 0.32),
            border: Border.all(color: primaryLight.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.developer_mode, color: primaryLight, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.devModeLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              CupertinoSwitch(
                value: true,
                onChanged: (val) {
                  if (!val) DevLogger.instance.setDevMode(false);
                },
              ),
            ],
          ),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            Navigator.push(
              context,
              CupertinoPageRoute(builder: (_) => const DeveloperView()),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: primary.withValues(alpha: 0.18),
              border: Border.all(color: primaryLight.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.terminal, color: primaryLight, size: 16),
                const SizedBox(width: 6),
                Text(
                  l.openDevPanel,
                  style: const TextStyle(
                    color: primaryLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'v1.0.2+3',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.15),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
