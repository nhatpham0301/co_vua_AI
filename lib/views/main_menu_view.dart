import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../logic/dev_logger.dart';
import '../logic/rank_system.dart';
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
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'watch_matches',
      barrierColor: Colors.black.withValues(alpha: 0.62),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, __) {
        final l = AppLocalizations.of(ctx)!;
        return SafeArea(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 640, maxHeight: 860),
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFE7D4BB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF6D4B2D), width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.48),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    height: 74,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF3E2A1A).withValues(alpha: 0.95),
                          const Color(0xFF24170F).withValues(alpha: 0.95),
                        ],
                      ),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(9)),
                    ),
                    child: Center(
                      child: Text(
                        l.watchMatchTitle,
                        style: const TextStyle(
                          color: Color(0xFFF0CB88),
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Jura',
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: LiveMatchList(
                      matches: _matches,
                      onRefresh: _refreshMatches,
                      hasSavedGame: false,
                      bottomPadding: 12,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 180,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFD9AE73), Color(0xFFAA6F38)],
                          ),
                          border: Border.all(
                            color:
                                const Color(0xFFEBCB9A).withValues(alpha: 0.7),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.24),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Text(
                          l.cancel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF3D2515),
                            fontSize: 26,
                            fontFamily: 'Jura',
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      child: isLoggedIn
                          ? _HomeProfileHeader(
                              userName: userName,
                              elo: userElo,
                              avatarUrl: auth.user?.avatarUrl,
                              onTapProfile: _showUserProfile,
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

class _WatchModeTab extends StatelessWidget {
  final String label;
  final bool selected;

  const _WatchModeTab({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: selected
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFD8A96D), Color(0xFFA76C35)],
              )
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFBCA582), Color(0xFF9E8563)],
              ),
        border: Border.all(
          color: selected
              ? const Color(0xFFF2D5A2).withValues(alpha: 0.82)
              : const Color(0xFF89613E).withValues(alpha: 0.44),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: selected ? const Color(0xFF3D2514) : const Color(0xFF5A402B),
          fontSize: 18,
          fontWeight: FontWeight.w900,
          fontFamily: 'Jura',
        ),
      ),
    );
  }
}

class _HomeProfileHeader extends StatelessWidget {
  final String userName;
  final int elo;
  final String? avatarUrl;
  final VoidCallback onTapProfile;
  final VoidCallback onTapSettings;

  const _HomeProfileHeader({
    required this.userName,
    required this.elo,
    required this.avatarUrl,
    required this.onTapProfile,
    required this.onTapSettings,
  });

  @override
  Widget build(BuildContext context) {
    final rankAsset = RankSystem.getRankBadgePath(elo);
    final rankLevel = RankSystem.getRankFromElo(elo);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTapProfile,
          child: SizedBox(
            width: 92,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF1C57D),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(child: _HomeAvatar(avatarUrl: avatarUrl)),
                ),
                Transform.translate(
                  offset: const Offset(0, -6),
                  child: Image.asset(
                    rankAsset,
                    height: 34,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox(height: 34),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      return Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: index < rankLevel
                            ? const Color(0xFFFFD43C)
                            : const Color(0xFF4E381E),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onTapProfile,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF775032), Color(0xFF472B1A)],
                    ),
                    border: Border.all(
                      color: const Color(0xFFF2CA8A).withValues(alpha: 0.75),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
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
                            color: Color(0xFFF8E1B7),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        CupertinoIcons.pencil,
                        size: 16,
                        color: Color(0xFFEFC67F),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _HomeStatPlate(
                icon: Icons.workspace_premium_rounded,
                value: '$elo',
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onTapSettings,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF7A5030), Color(0xFF472919)],
              ),
              border: Border.all(
                color: const Color(0xFFF0CA89).withValues(alpha: 0.72),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  CupertinoIcons.settings,
                  size: 24,
                  color: Color(0xFFF4D293),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeAvatar extends StatelessWidget {
  final String? avatarUrl;

  const _HomeAvatar({required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: avatarUrl!.trim(),
        fit: BoxFit.cover,
        placeholder: (_, __) => const ColoredBox(
          color: Color(0xFF4B2C1A),
          child: Center(
            child: CupertinoActivityIndicator(color: Color(0xFFF2CA84)),
          ),
        ),
        errorWidget: (_, __, ___) => const _HomeAvatarFallback(),
      );
    }

    return const _HomeAvatarFallback();
  }
}

class _HomeAvatarFallback extends StatelessWidget {
  const _HomeAvatarFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF6B4528),
      child: const Icon(
        Icons.person_rounded,
        color: Color(0xFFF7DEB0),
        size: 38,
      ),
    );
  }
}

class _HomeStatPlate extends StatelessWidget {
  final IconData icon;
  final String value;

  const _HomeStatPlate({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF744829), Color(0xFF492D1B)],
        ),
        border:
            Border.all(color: const Color(0xFFE7BE7E).withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFFF3D194)),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFFCE6BD),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
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
