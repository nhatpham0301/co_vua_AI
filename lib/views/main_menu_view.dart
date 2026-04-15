import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/dev_logger.dart';
import '../logic/game_state_storage.dart';
import '../logic/online_game_events_service.dart';
import '../model/app_model.dart';
import '../model/app_themes.dart';
import 'components/main_menu_view/mm_background.dart';
import 'components/main_menu_view/mm_banner_ad.dart' show GameBannerAd;
import 'components/main_menu_view/mm_header.dart';
import 'components/main_menu_view/mm_live_match_list.dart';
import 'components/main_menu_view/mm_models.dart';
import 'components/main_menu_view/mm_palette.dart';
import 'components/main_menu_view/mm_quick_play_btn.dart';
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

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    const bannerHeight = 50.0;
    const fabAreaHeight = 72.0;

    return Consumer<AppModel>(
      builder: (context, model, _) {
        final auth = model.authService;
        final isLoggedIn = auth.isLoggedIn;
        final userName = auth.user?.username ?? '';
        final elo = auth.user?.elo ?? 0;

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
              Column(
                children: [
                  SafeArea(
                    bottom: false,
                    child: MenuHeader(
                      isLoggedIn: isLoggedIn,
                      userName: userName,
                      elo: elo,
                      rank: '',
                      onLoginTap: _handleLogin,
                      onSettingsTap: () => Navigator.push(
                        context,
                        CupertinoPageRoute(builder: (_) => SettingsView()),
                      ),
                      onThemeTap: () {
                        model.setTheme(
                            (model.themeIndex + 1) % themeList.length);
                      },
                    ),
                  ),
                  Expanded(
                    child: LiveMatchList(
                      matches: _matches,
                      onRefresh: _refreshMatches,
                      hasSavedGame: _hasSavedGame,
                      bottomPadding:
                          fabAreaHeight + bannerHeight + bottomPad + 12,
                    ),
                  ),
                  GameBannerAd(bottomPad: bottomPad),
                ],
              ),
              Positioned(
                bottom: bannerHeight + bottomPad + 14,
                left: 0,
                right: 0,
                child: Center(
                  child: QuickPlayBtn(
                    hasSavedGame: _hasSavedGame,
                    onGameFinished: _checkSavedGame,
                  ),
                ),
              ),
              if (isLoggedIn)
                Positioned(
                  bottom: bannerHeight + bottomPad + 18,
                  right: 20,
                  child: _SocketTestBtn(model),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Socket Debug Button ───────────────────────────────────────────────────────

class _SocketTestBtn extends StatefulWidget {
  final AppModel model;
  const _SocketTestBtn(this.model);

  @override
  State<_SocketTestBtn> createState() => _SocketTestBtnState();
}

class _SocketTestBtnState extends State<_SocketTestBtn> {
  bool _testing = false;

  Future<void> _runTest() async {
    if (_testing) return;
    setState(() => _testing = true);
    try {
      final token = await widget.model.authService.ensureValidAccessToken();
      if (token == null || token.isEmpty) {
        _showResult(
          context,
          connected: false,
          message: 'Không có access token hợp lệ.',
        );
        return;
      }

      final result = await OnlineGameEventsService.debugSocketAuth(
        socketBaseUrl: widget.model.socketBaseUrl,
        accessToken: token,
      );

      if (!mounted) return;
      _showResult(
        context,
        connected: result.connected,
        message: result.error,
      );
    } catch (e) {
      if (!mounted) return;
      _showResult(context, connected: false, message: e.toString());
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _showResult(
    BuildContext ctx, {
    required bool connected,
    String? message,
  }) {
    showCupertinoDialog<void>(
      context: ctx,
      builder: (_) => CupertinoAlertDialog(
        title: Text(connected ? '✅ Socket Connected' : '❌ Socket Failed'),
        content: Text(
          connected
              ? 'Kết nối /live thành công với auth.token.'
              : 'Lỗi: ${message ?? 'unknown'}',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(_),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _testing ? null : _runTest,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgCard.withValues(alpha: 0.6),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: _testing
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: CupertinoActivityIndicator(color: Colors.white),
              )
            : const Icon(
                Icons.wifi_rounded,
                color: Colors.white70,
                size: 20,
              ),
      ),
    );
  }
}
