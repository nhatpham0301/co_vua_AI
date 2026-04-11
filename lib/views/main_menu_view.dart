import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/game_state_storage.dart';
import '../model/app_model.dart';
import '../model/app_themes.dart';
import 'components/main_menu_view/mm_background.dart';
import 'components/main_menu_view/mm_banner_ad.dart' show GameBannerAd;
import 'components/main_menu_view/mm_header.dart';
import 'components/main_menu_view/mm_live_match_list.dart';
import 'components/main_menu_view/mm_models.dart';
import 'components/main_menu_view/mm_palette.dart';
import 'components/main_menu_view/mm_quick_play_btn.dart';
import 'settings_view.dart';

class MainMenuView extends StatefulWidget {
  @override
  _MainMenuViewState createState() => _MainMenuViewState();
}

class _MainMenuViewState extends State<MainMenuView> {
  bool _isLoggedIn = false;
  final String _userName = 'Nguyễn Văn A';
  final int _elo = 1850;
  final String _rank = 'Grandmaster';

  bool _hasSavedGame = false;
  List<LiveMatch> _matches = [];
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _matches = MatchGen.generateTen();
    _checkSavedGame();
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

  void _refreshMatches() => setState(() => _matches = MatchGen.generateTen());

  void _handleLogin() {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Đăng nhập'),
        content: const Text(
          'Tính năng đăng nhập đang được phát triển.\nSẽ ra mắt sớm!',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    const bannerHeight = 50.0;
    const fabAreaHeight = 72.0;

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
                  isLoggedIn: _isLoggedIn,
                  userName: _userName,
                  elo: _elo,
                  rank: _rank,
                  onLoginTap: _handleLogin,
                  onSettingsTap: () => Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (_) => SettingsView()),
                  ),
                  onThemeTap: () {
                    final m = Provider.of<AppModel>(context, listen: false);
                    m.setTheme((m.themeIndex + 1) % themeList.length);
                  },
                ),
              ),
              Expanded(
                child: LiveMatchList(
                  matches: _matches,
                  onRefresh: _refreshMatches,
                  hasSavedGame: _hasSavedGame,
                  bottomPadding: fabAreaHeight + bannerHeight + bottomPad + 12,
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
        ],
      ),
    );
  }
}
