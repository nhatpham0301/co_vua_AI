import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../logic/dev_logger.dart';
import '../logic/game_state_storage.dart';
import '../model/app_model.dart';
import 'components/main_menu_view/mm_models.dart';
import 'components/main_menu_view/mm_quick_play_btn.dart';
import 'components/shared/ranked_profile_avatar.dart';
import 'components/main_menu_view/user_profile_dialog.dart';
import 'components/main_menu_view/watch_dialog.dart';
import 'login_view.dart';
import 'settings_view.dart';

class MainMenuView extends StatefulWidget {
  @override
  _MainMenuViewState createState() => _MainMenuViewState();
}

class _MainMenuViewState extends State<MainMenuView> {
  bool _hasSavedGame = false;
  bool _isGameStarting = false;
  List<LiveMatch> _matches = [];
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _matches = MatchGen.generateTen(); // fallback data
    _checkSavedGame();
    _fetchRecentGames();
    _ticker = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => MatchGen.tick(_matches));
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _checkSavedGame() async {
    final has = await GameStateStorage.hasSavedGame();
    if (mounted) setState(() => _hasSavedGame = has);
  }

  Future<void> _fetchRecentGames() async {
    try {
      final model = Provider.of<AppModel>(context, listen: false);
      final jsonList = await model.apiClient.fetchRecentGames(limit: 10);
      if (!mounted) return;
      final apiMatches = jsonList.map(_jsonToLiveMatch).toList();
      setState(() {
        _matches = apiMatches.isNotEmpty ? apiMatches : _matches;
      });
    } catch (e) {
      DevLogger.instance.log(
        DevLogCategory.http,
        'fetchRecentGames fallback to fake data: $e',
      );
    }
  }

  static LiveMatch _jsonToLiveMatch(Map<String, dynamic> json) {
    final whiteId = json['whiteId'] as String?;
    final blackId = json['blackId'] as String?;
    final whiteUser = json['white'];
    final blackUser = json['black'];

    String resolveName(dynamic user, String? fallbackId, String sideLabel) {
      if (user is Map<String, dynamic>) {
        final username = user['username'] as String?;
        if (username != null && username.trim().isNotEmpty) {
          return username.trim();
        }
      }
      if (fallbackId != null && fallbackId.isNotEmpty) {
        final short =
            fallbackId.length > 8 ? fallbackId.substring(0, 8) : fallbackId;
        return '$sideLabel-$short';
      }
      return '$sideLabel-?';
    }

    int resolveElo(dynamic user, String key) {
      if (user is Map<String, dynamic>) {
        return (user['elo'] as num?)?.toInt() ?? 0;
      }
      return (json[key] as num?)?.toInt() ?? 0;
    }

    return LiveMatch(
      id: json['id'] as String? ?? '',
      white: MatchPlayer(
        resolveName(whiteUser, whiteId, 'White'),
        resolveElo(whiteUser, 'whiteEloSnapshot'),
      ),
      black: MatchPlayer(
        resolveName(blackUser, blackId, 'Black'),
        resolveElo(blackUser, 'blackEloSnapshot'),
      ),
      moveCount: 0,
      elapsedSec: _calcElapsed(json['startedAt'] as String?),
      board: MatchGen.generateRandomBoard(),
    );
  }

  static int _calcElapsed(String? startedAt) {
    if (startedAt == null) return 0;
    final dt = DateTime.tryParse(startedAt);
    if (dt == null) return 0;
    return DateTime.now().difference(dt).inSeconds.clamp(0, 99999);
  }

  Future<void> _refreshMatches() async {
    await _fetchRecentGames();
  }

  Future<void> _showWatchDialog() async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'watch_matches',
      barrierColor: Colors.black.withValues(alpha: 0.62),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, __) => WatchMatchesDialogContent(
        matches: _matches,
        onRefresh: _refreshMatches,
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1).animate(animation),
            child: child,
          ),
        );
      },
    );
  }

  void _handleLogin() async {
    final result = await Navigator.push<bool>(
      context,
      CupertinoPageRoute(builder: (_) => const LoginView()),
    );
    if (result == true && mounted) {
      // Auth successful — refresh data
      _fetchRecentGames();
    }
  }

  void _showUserProfile() async {
    final auth = Provider.of<AppModel>(context, listen: false).authService;
    if (!auth.isLoggedIn || auth.user == null) return;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => UserProfileDialog(
        userId: auth.user!.id,
        userName: auth.user!.username,
        avatarUrl: auth.user!.avatarUrl,
        elo: auth.user!.elo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppModel>(
      builder: (context, model, _) {
        final auth = model.authService;
        final isLoggedIn = auth.isLoggedIn;
        final userName = auth.user?.username ?? '';
        final userElo =
            auth.user?.elo ?? model.homeOverviewSnapshot?.user?.elo ?? 0;
        final l = AppLocalizations.of(context)!;

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/home/background.png',
                  fit: BoxFit.fitHeight,
                  alignment: Alignment.center,
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.12),
                        Colors.black.withValues(alpha: 0.50),
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  SafeArea(
                    bottom: false,
                    child: isLoggedIn
                        ? _HomeProfileHeader(
                            userName: userName,
                            elo: userElo,
                            avatarUrl: auth.user?.avatarUrl,
                            onTapProfile: _showUserProfile,
                            onTapInbox: _showUserProfile,
                            onTapSettings: () => Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (_) => SettingsView(),
                              ),
                            ),
                          )
                        : Row(
                            children: [
                              const Spacer(),
                              _TopIconButton(
                                icon: CupertinoIcons.person,
                                label: l.loginTitle,
                                onTap: _handleLogin,
                              ),
                              const SizedBox(width: 8),
                              _TopIconButton(
                                icon: CupertinoIcons.settings,
                                label: l.settings,
                                onTap: () => Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (_) => SettingsView(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        _ImageHomeButton(
                          assetPath: 'assets/images/home/watch_match.png',
                          loading: false,
                          semanticLabel: l.watch,
                          onTap: _showWatchDialog,
                        ),
                        const SizedBox(height: 18),
                        QuickPlayBtn(
                          hasSavedGame: _hasSavedGame,
                          onGameFinished: _checkSavedGame,
                          onStartingChanged: (isStarting) {
                            if (!mounted) return;
                            setState(() => _isGameStarting = isStarting);
                          },
                          buttonBuilder: (ctx, isStarting) => _ImageHomeButton(
                            assetPath: 'assets/images/home/play_game.png',
                            loading: false,
                            semanticLabel: l.play,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
                ],
              ),
              if (_isGameStarting)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.32),
                      ),
                      child: Center(
                        child: Container(
                          width: 184,
                          height: 74,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF7A522F), Color(0xFF4A2E1C)],
                            ),
                            border: Border.all(
                              color: const Color(0xFFF3CE82)
                                  .withValues(alpha: 0.72),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.sports_esports_rounded,
                                size: 18,
                                color: Color(0xFFF4D59E),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Vào trận...',
                                style: TextStyle(
                                  color: Color(0xFFF8E1B8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              SizedBox(width: 8),
                              CupertinoActivityIndicator(
                                color: Color(0xFFF4D59E),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeProfileHeader extends StatelessWidget {
  final String userName;
  final int elo;
  final String? avatarUrl;
  final VoidCallback onTapProfile;
  final VoidCallback onTapInbox;
  final VoidCallback onTapSettings;

  const _HomeProfileHeader({
    required this.userName,
    required this.elo,
    required this.avatarUrl,
    required this.onTapProfile,
    required this.onTapInbox,
    required this.onTapSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTapProfile,
          child: RankedProfileAvatar(
            name: userName,
            elo: elo,
            avatarUrl: avatarUrl,
            avatarSize: 60,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onTapProfile,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF111111), Color(0xFF292013)],
                          ),
                          border: Border.all(
                            color:
                                const Color(0xFFE8BE75).withValues(alpha: 0.9),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.26),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFF7D89D),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Jura',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  _HeaderRoundIconButton(
                    icon: CupertinoIcons.mail_solid,
                    onTap: onTapInbox,
                  ),
                  const SizedBox(width: 5),
                  _HeaderRoundIconButton(
                    icon: CupertinoIcons.settings,
                    onTap: onTapSettings,
                  ),
                ],
              ),
              const SizedBox(height: 5),
              // Container(
              //   height: 26,
              //   padding: const EdgeInsets.symmetric(horizontal: 8),
              //   decoration: BoxDecoration(
              //     borderRadius: BorderRadius.circular(16),
              //     gradient: const LinearGradient(
              //       begin: Alignment.topCenter,
              //       end: Alignment.bottomCenter,
              //       colors: [Color(0xFF2B1C0F), Color(0xFF1A120B)],
              //     ),
              //     border: Border.all(
              //       color: const Color(0xFFF1C77D).withValues(alpha: 0.78),
              //     ),
              //   ),
              //   child: Row(
              //     mainAxisSize: MainAxisSize.min,
              //     children: [
              //       const Icon(
              //         Icons.workspace_premium_rounded,
              //         size: 14,
              //         color: Color(0xFFF6C155),
              //       ),
              //       const SizedBox(width: 5),
              //       Text(
              //         _rankLabel(elo),
              //         style: const TextStyle(
              //           color: Color(0xFFFFC752),
              //           fontSize: 13,
              //           fontWeight: FontWeight.w900,
              //           fontFamily: 'Jura',
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
              // const SizedBox(height: 5),
              // Row(
              //   children: [
              //     Expanded(
              //       child: _HeaderResourceBar(
              //         icon: Icons.monetization_on_rounded,
              //         iconColor: const Color(0xFFFFC95D),
              //         value: '12.450',
              //       ),
              //     ),
              //     const SizedBox(width: 6),
              //     Expanded(
              //       child: _HeaderResourceBar(
              //         icon: Icons.diamond_outlined,
              //         iconColor: const Color(0xFF57C6FF),
              //         value: '980',
              //       ),
              //     ),
              //   ],
              // ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderRoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderRoundIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF111111), Color(0xFF2A1E11)],
          ),
          border: Border.all(
            color: const Color(0xFFF1C67E).withValues(alpha: 0.9),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 7,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, size: 16, color: const Color(0xFFF2CB8A)),
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TopIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.45),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.28),
          ),
        ),
        child: Tooltip(
          message: label,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _ImageHomeButton extends StatelessWidget {
  final String assetPath;
  final bool loading;
  final String semanticLabel;
  final VoidCallback? onTap;

  const _ImageHomeButton({
    required this.assetPath,
    required this.loading,
    required this.semanticLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final button = Semantics(
      button: true,
      label: semanticLabel,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            assetPath,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );

    if (onTap == null) return button;
    return GestureDetector(onTap: onTap, child: button);
  }
}
