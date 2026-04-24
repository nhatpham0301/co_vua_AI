import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../logic/dev_logger.dart';
import '../logic/experimental_api_client.dart';
import '../model/app_model.dart';
import 'ai_levels_test_view.dart';
import 'chess_view.dart';
import 'components/main_menu_view/game_options/game_mode_picker.dart';
import 'components/main_menu_view/mm_background.dart';
import 'components/main_menu_view/mm_palette.dart';
import 'components/settings_view/language_picker.dart';
import 'components/settings_view/toggles.dart';
import 'components/shared/app_dialog.dart';
import 'components/shared/bottom_padding.dart';
import 'components/shared/rounded_button.dart';
import 'developer_view.dart';

class SettingsView extends StatelessWidget {
  Future<T> _withAuthRetry<T>({
    required AppModel appModel,
    required String action,
    required Future<T> Function() execute,
  }) async {
    try {
      return await execute();
    } on ApiException catch (e) {
      if (e.statusCode != 401) rethrow;
      DevLogger.instance.log(
        DevLogCategory.http,
        '[SETTINGS] $action unauthorized (401) -> refreshing token',
      );
      final refreshed = await appModel.authService.refreshTokens();
      if (!refreshed) {
        DevLogger.instance.log(
          DevLogCategory.http,
          '[SETTINGS] $action refresh failed -> need re-login',
        );
        rethrow;
      }
      DevLogger.instance.log(
        DevLogCategory.http,
        '[SETTINGS] $action retry after refresh',
      );
      return execute();
    }
  }

  Future<void> _joinGameByCode(
    BuildContext context,
    AppModel appModel,
    String rawCode,
  ) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) return;

    if (!appModel.authService.isLoggedIn) {
      showAppDialog<void>(
        context: context,
        title: 'Yeu cau dang nhap',
        message: 'Can dang nhap de vao ban bang ma phong.',
        actions: const [AppDialogAction(label: 'Dong')],
      );
      return;
    }

    try {
      final joined = await _withAuthRetry(
        appModel: appModel,
        action: 'joinGameByCode',
        execute: () => appModel.apiClient.joinGameByCode(code),
      );
      final gameId = joined['id']?.toString() ?? '';
      if (gameId.isEmpty) {
        showAppDialog<void>(
          context: context,
          title: 'Khong vao duoc ban',
          message: 'Khong tim thay gameId hop le tu server.',
          actions: const [AppDialogAction(label: 'Dong')],
        );
        return;
      }

      // Chuẩn flow: cập nhật snapshot từ response join trước khi mở socket.
      appModel.applyJoinGameResponse(joined);

      await appModel.startOnlineEventTracking(gameId);
      appModel.currentGameInviteCode = null;
      appModel.isWaitingForOpponent = false;
      appModel.opponentJoined = true;
      appModel.setPlayerCount(2);

      // Nạp profile đối thủ từ GET /api/users/:id (public, không block nếu lỗi).
      await appModel.hydrateOpponentProfileFromSnapshot();

      if (!context.mounted) return;
      await Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => ChessView(appModel)),
      );
    } on ApiException catch (e) {
      showAppDialog<void>(
        context: context,
        title: 'Khong the vao ban',
        message: e.toString(),
        actions: const [AppDialogAction(label: 'Dong')],
      );
    } catch (e) {
      showAppDialog<void>(
        context: context,
        title: 'Loi ket noi',
        message: e.toString(),
        actions: const [AppDialogAction(label: 'Dong')],
      );
    }
  }

  Future<void> _showJoinCodeDialog(BuildContext context, AppModel appModel) {
    final ctrl = TextEditingController();
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'join_game_by_code',
      barrierColor: Colors.black.withValues(alpha: 0.7),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, __) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            final canSubmit = ctrl.text.trim().isNotEmpty;
            return Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 360,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  decoration: BoxDecoration(
                    color: bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: primary.withValues(alpha: 0.45),
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nhập mã vào bàn',
                        style: TextStyle(
                          color: primaryLight,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Dán hoặc nhập mã mời để vào trận online.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(
                          color: bgDark.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: primary.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: CupertinoTextField(
                          controller: ctrl,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          placeholder: 'Ví dụ: ABC123',
                          placeholderStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w600,
                          ),
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.done,
                          autofocus: true,
                          decoration: null,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9]'),
                            ),
                            LengthLimitingTextInputFormatter(12),
                          ],
                          onChanged: (_) => setLocalState(() {}),
                          onSubmitted: (value) async {
                            final code = value.trim();
                            if (code.isEmpty) return;
                            Navigator.pop(dialogContext);
                            await _joinGameByCode(context, appModel, code);
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    Colors.white.withValues(alpha: 0.9),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.25),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('Hủy'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: canSubmit
                                  ? () async {
                                      final code = ctrl.text.trim();
                                      Navigator.pop(dialogContext);
                                      await _joinGameByCode(
                                        context,
                                        appModel,
                                        code,
                                      );
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    primary.withValues(alpha: 0.35),
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Vào bàn',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
            child: child,
          ),
        );
      },
    ).whenComplete(ctrl.dispose);
  }

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
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top),
                Row(
                  children: [
                    _TopActionButton(
                      icon: CupertinoIcons.back,
                      onTap: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Consumer<AppModel>(
                      builder: (context, appModel, child) => _TopActionButton(
                        icon: Icons.settings_backup_restore_rounded,
                        onTap: () => _showResetConfirmation(context, appModel),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: CupertinoScrollbar(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      physics: const ClampingScrollPhysics(),
                      children: [
                        const LanguagePicker(),
                        const SizedBox(height: 10),
                        Consumer<AppModel>(
                          builder: (context, appModel, child) {
                            if (appModel.authService.isLoggedIn) {
                              return const SizedBox.shrink();
                            }
                            return _GuestGameModeSection(appModel: appModel);
                          },
                        ),
                        const SizedBox(height: 10),
                        Consumer<AppModel>(
                          builder: (context, appModel, child) {
                            if (!appModel.authService.isLoggedIn) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              children: [
                                RoundedButton(
                                  'Nhập mã vào bàn',
                                  onPressed: () =>
                                      _showJoinCodeDialog(context, appModel),
                                ),
                                const SizedBox(height: 10),
                                RoundedButton(
                                  'Test AI Levels 1-10',
                                  onPressed: () => Navigator.push(
                                    context,
                                    CupertinoPageRoute(
                                      builder: (_) => const AiLevelsTestView(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                            );
                          },
                        ),
                        Consumer<AppModel>(
                          builder: (context, appModel, child) =>
                              Toggles(appModel),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Consumer<AppModel>(
                  builder: (context, appModel, _) {
                    final isLoggedIn = appModel.authService.isLoggedIn;
                    if (!isLoggedIn) return const SizedBox.shrink();
                    return Column(
                      children: [
                        RoundedButton(
                          l.logoutButton,
                          onPressed: () async {
                            await appModel.authService.logout();
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                ),
                const _DevTapTarget(),
                BottomPadding(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.45),
          border: Border.all(
            color: const Color(0xFFF0CA89).withValues(alpha: 0.45),
          ),
        ),
        child: Icon(icon, color: const Color(0xFFF4D293), size: 20),
      ),
    );
  }
}

class _GuestGameModeSection extends StatelessWidget {
  final AppModel appModel;

  const _GuestGameModeSection({required this.appModel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            bgCard.withValues(alpha: 0.62),
            bgMid.withValues(alpha: 0.68),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFEBC889).withValues(alpha: 0.32),
        ),
      ),
      child: GameModePicker(
        appModel.playerCount,
        appModel.setPlayerCount,
      ),
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
                fontSize: 14,
                fontWeight: FontWeight.w600,
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
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
