import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../logic/dev_logger.dart';
import '../logic/game_state_storage.dart';
import '../model/app_model.dart';
import 'components/main_menu_view/mm_live_match_list.dart';
import 'components/main_menu_view/mm_models.dart';
import 'components/main_menu_view/mm_quick_play_btn.dart';
import 'components/main_menu_view/user_profile_dialog.dart';
import 'login_view.dart';
import 'settings_view.dart';

class MainMenuView extends StatefulWidget {
  @override
  _MainMenuViewState createState() => _MainMenuViewState();
}

class _MainMenuViewState extends State<MainMenuView> {
  bool _hasSavedGame = false;
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
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx)!;
        return SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.8,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF09152A),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 10, 6),
                      child: Row(
                        children: [
                          const Icon(
                            CupertinoIcons.eye,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l.watchMatchTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            minimumSize: const Size(30, 30),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Đóng'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0x22FFFFFF)),
                    Expanded(
                      child: LiveMatchList(
                        matches: _matches,
                        onRefresh: _refreshMatches,
                        hasSavedGame: false,
                        bottomPadding: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      child: Row(
                        children: [
                          if (isLoggedIn)
                            Expanded(
                              child: GestureDetector(
                                onTap: _showUserProfile,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Text(
                                    '$userName • ${auth.user?.elo ?? 0} ELO',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else ...[
                            const Spacer(),
                          ],
                          const SizedBox(width: 8),
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
                                  builder: (_) => SettingsView()),
                            ),
                          ),
                        ],
                      ),
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
                          buttonBuilder: (ctx, isStarting) => _ImageHomeButton(
                            assetPath: 'assets/images/home/play_game.png',
                            loading: isStarting,
                            semanticLabel: l.play,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
                ],
              ),
            ],
          ),
        );
      },
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
          if (loading)
            Container(
              width: 80,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const CupertinoActivityIndicator(color: Colors.white),
            ),
        ],
      ),
    );

    if (onTap == null) return button;
    return GestureDetector(onTap: onTap, child: button);
  }
}
