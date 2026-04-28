import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../logic/dev_logger.dart';
import '../logic/game_state_storage.dart';
import '../model/app_model.dart';
import 'chess_view.dart';
import 'components/main_menu_view/mm_models.dart';
import 'components/main_menu_view/mm_quick_play_btn.dart';
import 'components/main_menu_view/user_profile_dialog.dart';
import 'components/main_menu_view/watch_dialog.dart';
import 'components/shared/ranked_profile_avatar.dart';
import 'login_view.dart';
import 'settings_view.dart';

class MainMenuView extends StatefulWidget {
  @override
  _MainMenuViewState createState() => _MainMenuViewState();
}

class _MainMenuViewState extends State<MainMenuView> {
  bool _hasSavedGame = false;
  List<LiveMatch> _matches = [];
  bool _guestModeInitialized = false;
  bool _isLoadingLiveMatches = false;
  bool _isOpeningSpectator = false;
  bool _autoRecoverChecked = false;
  bool _isAutoRecovering = false;
  AppModel? _boundModel;
  VoidCallback? _authListener;

  static const List<_HomeBackgroundVariant> _homeBackgroundVariants = [
    _HomeBackgroundVariant(
      assetPath: 'assets/images/home/background_home/1080x1920.png',
      width: 1080,
      height: 1920,
    ),
    _HomeBackgroundVariant(
      assetPath: 'assets/images/home/background_home/1080x2400.png',
      width: 1080,
      height: 2400,
    ),
    _HomeBackgroundVariant(
      assetPath: 'assets/images/home/background_home/1170x2532.png',
      width: 1170,
      height: 2532,
    ),
    _HomeBackgroundVariant(
      assetPath: 'assets/images/home/background_home/1290x2796.png',
      width: 1290,
      height: 2796,
    ),
    _HomeBackgroundVariant(
      assetPath: 'assets/images/home/background_home/1440x2560.png',
      width: 1440,
      height: 2560,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkSavedGame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bindAuthAndTryRecover();
    });
  }

  @override
  void dispose() {
    final model = _boundModel;
    final listener = _authListener;
    if (model != null && listener != null) {
      model.authService.removeListener(listener);
    }
    super.dispose();
  }

  void _bindAuthAndTryRecover() {
    if (!mounted) return;
    final model = Provider.of<AppModel>(context, listen: false);

    if (_boundModel == null) {
      _boundModel = model;
      _authListener = () {
        if (!mounted) return;
        final auth = model.authService;
        // Retry recovery when auth becomes ready/logged in.
        if (auth.isLoggedIn) {
          _tryAutoRecoverOnlineGame(force: true);
        } else {
          // Allow a fresh auto-recover check on next successful login.
          _autoRecoverChecked = false;
        }
      };
      model.authService.addListener(_authListener!);
    }

    _tryAutoRecoverOnlineGame();
  }

  Future<void> _checkSavedGame() async {
    final has = await GameStateStorage.hasSavedGame();
    if (mounted) setState(() => _hasSavedGame = has);
  }

  Future<void> _tryAutoRecoverOnlineGame({bool force = false}) async {
    if (!mounted) return;
    if (_isAutoRecovering) return;
    if (_autoRecoverChecked && !force) return;
    _autoRecoverChecked = true;

    final model = Provider.of<AppModel>(context, listen: false);
    final auth = model.authService;
    final user = auth.user;
    DevLogger.instance.log(
      DevLogCategory.game,
      '[AUTO_RECOVER] check start | force=$force | isLoggedIn=${auth.isLoggedIn} | hasUser=${user != null} | checked=$_autoRecoverChecked',
    );
    if (!auth.isLoggedIn || user == null || user.id.trim().isEmpty) {
      return;
    }

    // If user explicitly has a local saved game, don't auto-jump to online
    // recovery to avoid overriding the manual Resume flow.
    if (_hasSavedGame && !force) {
      DevLogger.instance.log(
        DevLogCategory.game,
        '[AUTO_RECOVER] skipped because local saved game exists',
      );
      return;
    }

    setState(() => _isAutoRecovering = true);
    try {
      const pageSize = 50;
      const maxPages = 5;
      const unfinishedStatuses = {'in_progress', 'waiting'};

      Map<String, dynamic>? latestRecoverable;
      DateTime latestTs = DateTime.fromMillisecondsSinceEpoch(0);
      int offset = 0;
      int page = 0;
      int? total;

      while (page < maxPages) {
        DevLogger.instance.log(
          DevLogCategory.http,
          '[AUTO_RECOVER] calling GET /api/users/${user.id}/games | limit=$pageSize | offset=$offset',
        );

        final json = await model.apiClient.fetchUserGames(
          userId: user.id,
          limit: pageSize,
          offset: offset,
        );

        final rawGames = json['games'];
        if (rawGames is! List) {
          DevLogger.instance.log(
            DevLogCategory.http,
            '[AUTO_RECOVER] /users/:id/games has no games list | payload=$json',
          );
          return;
        }

        total ??= (json['total'] as num?)?.toInt();
        DevLogger.instance.log(
          DevLogCategory.game,
          '[AUTO_RECOVER] page=${page + 1} | got=${rawGames.length} | total=${total ?? '-'}',
        );

        for (final g in rawGames) {
          if (g is! Map) continue;
          final game = g.cast<String, dynamic>();
          final status =
              (game['status']?.toString() ?? '').trim().toLowerCase();
          if (!unfinishedStatuses.contains(status)) continue;

          final endedAt = game['endedAt']?.toString();
          if (endedAt != null && endedAt.isNotEmpty) continue;

          final tsStr = game['updatedAt']?.toString() ??
              game['startedAt']?.toString() ??
              game['createdAt']?.toString() ??
              '';
          final ts = DateTime.tryParse(tsStr) ?? DateTime.now();
          if (latestRecoverable == null || ts.isAfter(latestTs)) {
            latestRecoverable = game;
            latestTs = ts;
          }
        }

        if (latestRecoverable != null) {
          break;
        }

        if (rawGames.isEmpty) {
          break;
        }

        offset += rawGames.length;
        page += 1;
        if (total != null && offset >= total) {
          break;
        }
      }

      if (latestRecoverable == null) {
        DevLogger.instance.log(
          DevLogCategory.game,
          '[AUTO_RECOVER] no unfinished game found for user=${user.id}',
        );
        return;
      }

      final gameId = latestRecoverable['id']?.toString() ?? '';
      if (gameId.isEmpty) return;

      final recoveredStatus =
          (latestRecoverable['status']?.toString() ?? '').trim().toLowerCase();

      DevLogger.instance.log(
        DevLogCategory.game,
        '[AUTO_RECOVER] found unfinished gameId=$gameId | status=$recoveredStatus -> restoring',
      );

      await model.fetchOnlineGameSnapshotPreview(gameId);
      if (model.apiLastError != null || model.onlineGameSnapshot == null) {
        DevLogger.instance.log(
          DevLogCategory.http,
          '[AUTO_RECOVER] snapshot load failed | gameId=$gameId | err=${model.apiLastError}',
        );
        return;
      }

      await model.fetchOnlineGameMovesPreview(gameId);
      await model.startOnlineEventTracking(gameId);
      await model.hydrateOpponentProfileFromSnapshot();

      model.setPlayerCount(model.onlineGameSnapshot!.isAiGame ? 1 : 2);
      model.isWaitingForOpponent = false;
      model.opponentJoined = true;
      model.currentGameInviteCode = null;
      model.update();

      if (!mounted) return;
      await Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => ChessView(model)),
      );
    } catch (e) {
      DevLogger.instance.log(
        DevLogCategory.http,
        '[AUTO_RECOVER] failed | error=$e',
      );
    } finally {
      if (mounted) {
        setState(() => _isAutoRecovering = false);
      }
    }
  }

  Future<void> _fetchRecentGames({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() => _isLoadingLiveMatches = true);
    }
    try {
      final model = Provider.of<AppModel>(context, listen: false);
      final jsonList = await model.apiClient.fetchRecentGames(limit: 10);
      if (!mounted) return;
      final apiMatches =
          jsonList.map(_jsonToLiveMatch).where((m) => m.id.isNotEmpty).toList();
      setState(() {
        _matches = apiMatches;
      });
      DevLogger.instance.log(
        DevLogCategory.http,
        '[SPECTATOR] live list loaded via GET /api/games | count=${apiMatches.length}',
      );
    } catch (e) {
      DevLogger.instance.log(
        DevLogCategory.http,
        '[SPECTATOR] live list load failed | error=$e',
      );
      if (mounted) {
        setState(() => _matches = []);
      }
    } finally {
      if (showLoading && mounted) {
        setState(() => _isLoadingLiveMatches = false);
      }
    }
  }

  static LiveMatch _jsonToLiveMatch(Map<String, dynamic> json) {
    final status = (json['status']?.toString() ?? '').toLowerCase();
    if (status == 'ended' || status == 'draw' || status == 'checkmate') {
      return LiveMatch(
        id: '',
        white: const MatchPlayer('White', 0),
        black: const MatchPlayer('Black', 0),
        moveCount: 0,
        elapsedSec: 0,
        board: MatchGen.generateRandomBoard(),
      );
    }

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

    final gameId = (json['id'] ?? json['gameId'] ?? '').toString().trim();
    final startedAt = (json['startedAt'] as String?)?.trim();
    final elapsed = startedAt == null || startedAt.isEmpty
        ? 0
        : DateTime.now()
            .difference(DateTime.tryParse(startedAt) ?? DateTime.now())
            .inSeconds
            .clamp(0, 99999);

    return LiveMatch(
      id: gameId,
      white: MatchPlayer(
        resolveName(json['white'], json['whiteId'] as String?, 'White'),
        resolveElo(json['white'], 'whiteEloSnapshot'),
      ),
      black: MatchPlayer(
        resolveName(json['black'], json['blackId'] as String?, 'Black'),
        resolveElo(json['black'], 'blackEloSnapshot'),
      ),
      moveCount: (json['spectatorCount'] as num?)?.toInt() ?? 0,
      elapsedSec: elapsed,
      board: MatchGen.generateRandomBoard(),
    );
  }

  Future<void> _refreshMatches() async {
    await _fetchRecentGames();
  }

  Future<void> _showWatchDialog() async {
    if (_isLoadingLiveMatches || _isOpeningSpectator) return;
    // Always refresh from GET /api/games right before opening watch dialog.
    await _fetchRecentGames(showLoading: true);
    if (!mounted) return;

    final selected = await showGeneralDialog<LiveMatch>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'watch_matches',
      barrierColor: Colors.black.withValues(alpha: 0.62),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, __) => WatchMatchesDialogContent(
        matches: _matches,
        onRefresh: _refreshMatches,
        onSelectMatch: (match) => Navigator.of(ctx).pop(match),
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

    if (!mounted || selected == null) return;
    await _openSpectatorMatch(selected);
  }

  Future<void> _openSpectatorMatch(LiveMatch match) async {
    final appModel = Provider.of<AppModel>(context, listen: false);
    final l = AppLocalizations.of(context)!;
    final watch = Stopwatch()..start();

    if (mounted) {
      setState(() => _isOpeningSpectator = true);
    }

    DevLogger.instance.log(
      DevLogCategory.game,
      '[SPECTATOR] open requested | gameId=${match.id} | white=${match.white.name} | black=${match.black.name}',
    );

    final looksLikeLocalFakeId = match.id.startsWith('match_');
    if (looksLikeLocalFakeId) {
      DevLogger.instance.log(
        DevLogCategory.http,
        '[SPECTATOR][CLIENT] blocked local placeholder match id=${match.id} (not BE gameId)',
      );
      showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Không thể xem trận này'),
          content: const Text(
            'Danh sách này là dữ liệu tạm ở client, không có gameId thật từ server.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: Text(l.ok),
            ),
          ],
        ),
      );
      return;
    }

    if (!appModel.authService.isLoggedIn) {
      showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: Text(l.watchMatchTitle),
          content: const Text('Vui lòng đăng nhập để xem trực tiếp trận đấu.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: Text(l.ok),
            ),
          ],
        ),
      );
      return;
    }

    try {
      final s1 = Stopwatch()..start();
      await appModel.fetchOnlineGameSnapshotPreview(match.id);
      if (appModel.apiLastError != null ||
          appModel.onlineGameSnapshot == null) {
        DevLogger.instance.log(
          DevLogCategory.http,
          '[SPECTATOR][BE?] snapshot fetch failed | gameId=${match.id} | apiLastError=${appModel.apiLastError}',
        );
        throw Exception('Không tải được snapshot trận đấu từ server.');
      }
      DevLogger.instance.log(
        DevLogCategory.http,
        '[SPECTATOR] snapshot loaded | gameId=${match.id} | ms=${s1.elapsedMilliseconds} | status=${appModel.onlineGameSnapshot?.status}',
      );

      final s2 = Stopwatch()..start();
      await appModel.fetchOnlineGameMovesPreview(match.id);
      if (appModel.apiLastError != null) {
        DevLogger.instance.log(
          DevLogCategory.http,
          '[SPECTATOR][BE?] moves fetch failed | gameId=${match.id} | apiLastError=${appModel.apiLastError}',
        );
        throw Exception('Không tải được lịch sử nước đi từ server.');
      }
      DevLogger.instance.log(
        DevLogCategory.http,
        '[SPECTATOR] moves loaded | gameId=${match.id} | ms=${s2.elapsedMilliseconds} | moves=${appModel.onlineMoveHistory.length}',
      );

      final s3 = Stopwatch()..start();
      await appModel.startOnlineEventTracking(match.id, spectatorMode: true);
      DevLogger.instance.log(
        DevLogCategory.http,
        '[SPECTATOR] socket tracking started | gameId=${match.id} | ms=${s3.elapsedMilliseconds} | connected=${appModel.onlineEvents.isConnected} (false right away is expected before onConnect)',
      );

      final s4 = Stopwatch()..start();
      await appModel.hydrateOpponentProfileFromSnapshot();
      DevLogger.instance.log(
        DevLogCategory.http,
        '[SPECTATOR] opponent profile hydrated | gameId=${match.id} | ms=${s4.elapsedMilliseconds} | hasProfile=${appModel.opponentProfile != null}',
      );

      appModel.setPlayerCount(2);
      appModel.isWaitingForOpponent = false;
      appModel.opponentJoined = true;
      appModel.currentGameInviteCode = null;
      appModel.update();

      if (!mounted) return;
      DevLogger.instance.log(
        DevLogCategory.game,
        '[SPECTATOR] pushing ChessView | gameId=${match.id} | totalMs=${watch.elapsedMilliseconds}',
      );
      await Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => ChessView(appModel)),
      );
      DevLogger.instance.log(
        DevLogCategory.game,
        '[SPECTATOR] returned from ChessView | gameId=${match.id} | totalMs=${watch.elapsedMilliseconds}',
      );
    } catch (e) {
      DevLogger.instance.log(
        DevLogCategory.http,
        '[SPECTATOR] open failed | gameId=${match.id} | totalMs=${watch.elapsedMilliseconds} | error=$e',
      );
      if (!mounted) return;
      showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Không thể xem trận đấu'),
          content: Text(e.toString()),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: Text(l.ok),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningSpectator = false);
      }
    }
  }

  void _handleLogin() async {
    final result = await Navigator.push<bool>(
      context,
      CupertinoPageRoute(builder: (_) => const LoginView()),
    );
    if (result == true && mounted) {
      // Auth successful — refresh data
      _fetchRecentGames();
      await _checkSavedGame();
      await _tryAutoRecoverOnlineGame(force: true);
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

  String _pickBackgroundAssetForViewport(BuildContext context) {
    final media = MediaQuery.of(context);
    final widthPx = media.size.width * media.devicePixelRatio;
    final heightPx = media.size.height * media.devicePixelRatio;

    _HomeBackgroundVariant best = _homeBackgroundVariants.first;
    var bestScore = double.infinity;

    for (final variant in _homeBackgroundVariants) {
      final scale =
          math.max(widthPx / variant.width, heightPx / variant.height);
      final aspectDiff =
          ((widthPx / heightPx) - (variant.width / variant.height)).abs();
      final upscalePenalty = scale > 1.0 ? (scale - 1.0) * 2.0 : 0.0;
      final score = aspectDiff * 4.0 + upscalePenalty;

      if (score < bestScore ||
          (score == bestScore &&
              (variant.width * variant.height) > (best.width * best.height))) {
        best = variant;
        bestScore = score;
      }
    }

    return best.assetPath;
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
        final backgroundAsset = _pickBackgroundAssetForViewport(context);

        if (!isLoggedIn && !_guestModeInitialized) {
          _guestModeInitialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            model.setPlayerCount(1);
          });
        }
        if (isLoggedIn) {
          _guestModeInitialized = false;
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Image.asset(
                  backgroundAsset,
                  fit: BoxFit.cover,
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
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _GuestHeaderActionButton(
                                      icon: CupertinoIcons.person_crop_circle,
                                      label: l.loginTitle,
                                      primary: true,
                                      onTap: _handleLogin,
                                    ),
                                    _GuestHeaderActionButton(
                                      icon: CupertinoIcons.settings,
                                      label: l.settings,
                                      primary: true,
                                      onTap: () => Navigator.push(
                                        context,
                                        CupertinoPageRoute(
                                          builder: (_) => SettingsView(),
                                        ),
                                      ),
                                    ),
                                  ],
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
                          loading: _isLoadingLiveMatches,
                          semanticLabel: l.watch,
                          onTap: (_isLoadingLiveMatches || _isOpeningSpectator)
                              ? null
                              : _showWatchDialog,
                        ),
                        const SizedBox(height: 18),
                        QuickPlayBtn(
                          hasSavedGame: _hasSavedGame,
                          onGameFinished: _checkSavedGame,
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
              if (_isLoadingLiveMatches || _isOpeningSpectator)
                Positioned.fill(
                  child: AbsorbPointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.48),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF1A140E).withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFE8BE75)
                                  .withValues(alpha: 0.65),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CupertinoActivityIndicator(radius: 14),
                              const SizedBox(height: 10),
                              Text(
                                _isOpeningSpectator
                                    ? 'Đang vào xem trận...'
                                    : 'Đang tải danh sách trận...',
                                style: const TextStyle(
                                  color: Color(0xFFF4D293),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_isAutoRecovering)
                Positioned.fill(
                  child: AbsorbPointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.48),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF1A140E).withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFE8BE75)
                                  .withValues(alpha: 0.65),
                            ),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CupertinoActivityIndicator(radius: 14),
                              SizedBox(height: 10),
                              Text(
                                'Đang khôi phục ván đang chơi...',
                                style: TextStyle(
                                  color: Color(0xFFF4D293),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
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

class _GuestHeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _GuestHeaderActionButton({
    required this.icon,
    required this.label,
    this.primary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: primary
                ? const [Color(0xFF4B2F1A), Color(0xFF2B1A0D)]
                : const [Color(0xFF141414), Color(0xFF262626)],
          ),
          border: Border.all(
            color: primary
                ? const Color(0xFFF1C67E).withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: primary ? const Color(0xFFF4D396) : Colors.white70,
              size: 15,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: primary ? const Color(0xFFF4D396) : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
    final screenWidth = MediaQuery.of(context).size.width;
    final targetWidth = math.min(screenWidth * 0.7, 360.0);

    final button = Semantics(
      button: true,
      label: semanticLabel,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: targetWidth,
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return button;
    return GestureDetector(onTap: onTap, child: button);
  }
}

class _HomeBackgroundVariant {
  final String assetPath;
  final double width;
  final double height;

  const _HomeBackgroundVariant({
    required this.assetPath,
    required this.width,
    required this.height,
  });
}
