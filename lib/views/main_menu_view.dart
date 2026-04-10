import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/game_state_storage.dart';
import '../model/app_model.dart';
import '../model/app_themes.dart';
import '../model/player.dart';
import 'chess_view.dart';
import 'settings_view.dart';

// ─── Palette ────────────────────────────────────────────────────────────────
const _bgDark = Color(0xFF060D1F);
const _bgMid = Color(0xFF0A1730);
const _bgCard = Color(0xFF0E2244);
const _primary = Color(0xFF00B4D8);
const _primaryLight = Color(0xFF48CAE4);
const _goldMid = Color(0xFFCC9518);

// ─── Connectivity helper ─────────────────────────────────────────────────────
Future<bool> _checkOnline() async {
  try {
    final r = await InternetAddress.lookup('google.com')
        .timeout(const Duration(seconds: 5));
    return r.isNotEmpty && r[0].rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}

// ─── Live Match data model ───────────────────────────────────────────────────
class _MatchPlayer {
  final String name;
  final int elo;
  final bool isBot;
  const _MatchPlayer(this.name, this.elo, {this.isBot = false});
}

class _LiveMatch {
  final String id;
  final _MatchPlayer white;
  final _MatchPlayer black;
  int moveCount;
  int elapsedSec;
  final List<List<bool>> board; // 8×8 occupancy for mini preview

  _LiveMatch({
    required this.id,
    required this.white,
    required this.black,
    required this.moveCount,
    required this.elapsedSec,
    required this.board,
  });
}

// ─── Match generator ─────────────────────────────────────────────────────────
class _MatchGen {
  static final _rng = math.Random();

  static const _botNames = [
    'Bot Lv.1',
    'Bot Lv.2',
    'Bot Lv.3',
    'Bot Lv.4',
    'Bot Lv.5',
  ];
  static const _humanNames = [
    'VuaLua88',
    'DragonKing',
    'ChessWizard',
    'DarkKnight99',
    'QueenSlayer',
    'MasterMind',
    'PawnStorm',
    'RookRookie',
    'BishopBoss',
    'KnightFury',
    'EndgameGod',
    'SilkRoad',
    'AlphaZero9',
    'NightRider',
    'GrandPawn',
  ];

  static _MatchPlayer _bot() {
    final name = _botNames[_rng.nextInt(_botNames.length)];
    return _MatchPlayer(name, 800 + _rng.nextInt(1000), isBot: true);
  }

  static _MatchPlayer _human() {
    final name = _humanNames[_rng.nextInt(_humanNames.length)];
    return _MatchPlayer(name, 900 + _rng.nextInt(1200));
  }

  static List<List<bool>> _randomBoard() {
    return List.generate(
        8, (_) => List.generate(8, (_) => _rng.nextDouble() > 0.55));
  }

  /// Generates 10 matches: first 2 are human vs human, rest are Bot vs Bot
  static List<_LiveMatch> generateTen() {
    return List.generate(10, (i) {
      final isBotMatch = i >= 2;
      return _LiveMatch(
        id: 'match_$i',
        white: isBotMatch ? _bot() : _human(),
        black: isBotMatch ? _bot() : _human(),
        moveCount: 10 + _rng.nextInt(60),
        elapsedSec: 60 + _rng.nextInt(1800),
        board: _randomBoard(),
      );
    });
  }

  /// Simulate real-time updates (tick every 3 seconds)
  static void tick(List<_LiveMatch> matches) {
    for (final m in matches) {
      m.elapsedSec += 3;
      if (_rng.nextDouble() > 0.4) m.moveCount++;
    }
  }
}

// ─── MainMenuView ────────────────────────────────────────────────────────────
class MainMenuView extends StatefulWidget {
  @override
  _MainMenuViewState createState() => _MainMenuViewState();
}

class _MainMenuViewState extends State<MainMenuView> {
  // Auth state — Phase 2 will replace with real session check
  bool _isLoggedIn = true;
  final String _userName = 'Nguyễn Văn A';
  final int _elo = 1850;
  final String _rank = 'Grandmaster';

  bool _hasSavedGame = false;
  List<_LiveMatch> _matches = [];
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _matches = _MatchGen.generateTen();
    _checkSavedGame();
    // Refresh live match data every 3 s to simulate real-time
    _ticker = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _MatchGen.tick(_matches));
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

  void _refreshMatches() => setState(() => _matches = _MatchGen.generateTen());

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
      backgroundColor: _bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background ──────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_bgMid, _bgDark],
              ),
            ),
          ),
          const _BoardPattern(),
          const _CornerKnots(),

          // ── Main layout ─────────────────────────────────────────────────
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: _Header(
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
              // Scrollable live match list — leaves room for FAB + banner
              Expanded(
                child: _LiveMatchList(
                  matches: _matches,
                  onRefresh: _refreshMatches,
                  hasSavedGame: _hasSavedGame,
                  bottomPadding: fabAreaHeight + bannerHeight + bottomPad + 12,
                ),
              ),
              // Fixed bottom banner
              _BannerAd(bottomPad: bottomPad),
            ],
          ),

          // ── Floating "Chơi nhanh" button — sits above the banner ─────
          Positioned(
            bottom: bannerHeight + bottomPad + 14,
            left: 0,
            right: 0,
            child: Center(
              child: _QuickPlayBtn(
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

// ─── Header ──────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final bool isLoggedIn;
  final String userName;
  final int elo;
  final String rank;
  final VoidCallback onLoginTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onThemeTap;

  const _Header({
    required this.isLoggedIn,
    required this.userName,
    required this.elo,
    required this.rank,
    required this.onLoginTap,
    required this.onSettingsTap,
    required this.onThemeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          // ── Left: auth status ──────────────────────────────────────────
          if (isLoggedIn) ...[
            _AvatarCircle(initial: userName.isNotEmpty ? userName[0] : 'G'),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ELO: $elo | $rank',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ] else ...[
            GestureDetector(
              onTap: onLoginTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2), width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.person_fill,
                        color: Colors.white70, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Đăng nhập / Đăng ký',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const Spacer(),
          // ── Right: settings + theme ────────────────────────────────────
          _IconBtn(
              icon: CupertinoIcons.settings,
              tooltip: 'Cài đặt',
              onTap: onSettingsTap),
          const SizedBox(width: 8),
          _IconBtn(
              icon: CupertinoIcons.paintbrush_fill,
              tooltip: 'Đổi giao diện',
              onTap: onThemeTap),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String initial;
  const _AvatarCircle({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _bgCard,
        border: Border.all(color: _primary.withValues(alpha: 0.6), width: 2),
      ),
      child: Center(
        child: Text(
          initial.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _IconBtn(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
            border:
                Border.all(color: _goldMid.withValues(alpha: 0.35), width: 1.2),
          ),
          child: Icon(icon, color: Colors.white70, size: 17),
        ),
      ),
    );
  }
}

// ─── Live Match List ──────────────────────────────────────────────────────────
class _LiveMatchList extends StatelessWidget {
  final List<_LiveMatch> matches;
  final VoidCallback onRefresh;
  final bool hasSavedGame;
  final double bottomPadding;

  const _LiveMatchList({
    required this.matches,
    required this.onRefresh,
    required this.hasSavedGame,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Cupertino pull-to-refresh (works inside CupertinoApp) ──────
        CupertinoSliverRefreshControl(
          onRefresh: () async => onRefresh(),
          builder: (context, mode, pulledExtent, threshold, snap) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: CupertinoActivityIndicator(color: _primary),
              ),
            );
          },
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(14, 12, 14, bottomPadding),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── Section header ───────────────────────────────────────
              Row(
                children: [
                  const Text(
                    'TRẬN ĐANG DIỄN RA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                      border:
                          Border.all(color: _primary.withValues(alpha: 0.5)),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: _primaryLight,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Resume card ──────────────────────────────────────────
              if (hasSavedGame) ...[
                _SavedGameCard(),
                const SizedBox(height: 8),
              ],

              // ── Match cards ──────────────────────────────────────────
              ...matches.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _LiveMatchCard(match: m),
                  )),
            ]),
          ),
        ),
      ],
    );
  }
}

// ─── Saved Game Card ──────────────────────────────────────────────────────────
class _SavedGameCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appModel = Provider.of<AppModel>(context, listen: false);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        CupertinoPageRoute(
            builder: (_) => ChessView(appModel, isResuming: true)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.5)),
        ),
        child: const Row(
          children: [
            Icon(CupertinoIcons.arrow_counterclockwise_circle_fill,
                color: Color(0xFFA855F7), size: 22),
            SizedBox(width: 10),
            Text(
              'Tiếp tục ván trước',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Spacer(),
            Icon(CupertinoIcons.chevron_right, color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Live Match Card ──────────────────────────────────────────────────────────
class _LiveMatchCard extends StatelessWidget {
  final _LiveMatch match;
  const _LiveMatchCard({required this.match});

  String _fmt(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          splashColor: _primary.withValues(alpha: 0.08),
          onTap: () => _onTap(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                // Mini board preview
                _MiniChessBoard(board: match.board),
                const SizedBox(width: 14),
                // Middle: LIVE badge + player info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: LIVE badge + timer
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _primary.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: _primary.withValues(alpha: 0.55)),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                color: _primaryLight,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _fmt(match.elapsedSec),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Player 1
                      _PlayerRow(player: match.white),
                      const SizedBox(height: 6),
                      // Player 2
                      _PlayerRow(player: match.black),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // XEM button
                GestureDetector(
                  onTap: () => _onTap(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'XEM',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onTap(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Quan sát trận đấu'),
        content: const Text(
          'Chế độ quan sát (observer) đang phát triển.',
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
}

class _PlayerRow extends StatelessWidget {
  final _MatchPlayer player;
  const _PlayerRow({required this.player});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            '${player.name} (${player.elo})',
            style: TextStyle(
              color: player.isBot
                  ? Colors.white.withValues(alpha: 0.75)
                  : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (player.isBot) ...[
          const SizedBox(width: 4),
          const Icon(Icons.bolt_rounded, color: _primaryLight, size: 14),
        ],
      ],
    );
  }
}

// ─── Mini chess board (8×8 dot preview) ─────────────────────────────────────
class _MiniChessBoard extends StatelessWidget {
  final List<List<bool>> board;
  const _MiniChessBoard({required this.board});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _primary.withValues(alpha: 0.25), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: CustomPaint(painter: _MiniChessPainter(board: board)),
      ),
    );
  }
}

class _MiniChessPainter extends CustomPainter {
  final List<List<bool>> board;
  const _MiniChessPainter({required this.board});

  @override
  void paint(Canvas canvas, Size size) {
    const n = 8;
    final cw = size.width / n;
    final ch = size.height / n;
    final light = Paint()..color = const Color(0xFF1A3560);
    final dark = Paint()..color = const Color(0xFF0D2040);
    final pieceW = Paint()..color = Colors.white.withValues(alpha: 0.85);
    final pieceB = Paint()..color = const Color(0xFF00B4D8);

    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        canvas.drawRect(
          Rect.fromLTWH(c * cw, r * ch, cw, ch),
          (r + c).isEven ? light : dark,
        );
        if (r < board.length && c < board[r].length && board[r][c]) {
          final center = Offset(c * cw + cw / 2, r * ch + ch / 2);
          canvas.drawCircle(
              center, cw * 0.27, (r + c).isEven ? pieceB : pieceW);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_MiniChessPainter old) => false;
}

// ─── Floating Quick Play Button ───────────────────────────────────────────────
class _QuickPlayBtn extends StatefulWidget {
  final bool hasSavedGame;
  final VoidCallback onGameFinished;
  const _QuickPlayBtn(
      {required this.hasSavedGame, required this.onGameFinished});

  @override
  State<_QuickPlayBtn> createState() => _QuickPlayBtnState();
}

class _QuickPlayBtnState extends State<_QuickPlayBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.97, end: 1.04)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: GestureDetector(
        onTap: () => _start(context),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 52),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0082C8), Color(0xFF0050A0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF0082C8),
                blurRadius: 20,
                spreadRadius: 1,
              ),
              const BoxShadow(
                color: Colors.black38,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Text(
            'CHƠI',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.5,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _start(BuildContext context) async {
    final appModel = Provider.of<AppModel>(context, listen: false);

    // 1. Check connectivity
    final online = await _checkOnline();
    if (!mounted) return;

    if (!online) {
      // Offline → direct bot game (no matchmaking wait)
      appModel.setPlayerCount(1);
      await Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => ChessView(appModel)),
      );
      widget.onGameFinished();
      return;
    }

    // 2. Online → show 15-second matchmaking countdown (Cupertino-safe)
    final result = await showCupertinoModalPopup<_MatchResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _MatchmakingDialog(timeoutSeconds: 5),
    );
    if (!mounted) return;

    if (result == null || result == _MatchResult.cancelled) return;

    // result == timeout → fallback to bot (Phase 2: replace with real match)
    appModel.setPlayerCount(1);
    await Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => ChessView(appModel)),
    );
    widget.onGameFinished();
  }
}

enum _MatchResult { timeout, cancelled }

// ─── Matchmaking Dialog ───────────────────────────────────────────────────────
class _MatchmakingDialog extends StatefulWidget {
  final int timeoutSeconds;
  const _MatchmakingDialog({required this.timeoutSeconds});

  @override
  State<_MatchmakingDialog> createState() => _MatchmakingDialogState();
}

class _MatchmakingDialogState extends State<_MatchmakingDialog> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.timeoutSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _timer?.cancel();
        Navigator.pop(context, _MatchResult.timeout);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF071428),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sheet handle
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Countdown ring (Cupertino-friendly)
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CupertinoActivityIndicator(
                  radius: 28,
                  color: _primary,
                ),
                Text(
                  '$_remaining',
                  style: const TextStyle(
                    color: _primaryLight,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Đang tìm đối thủ...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ghép trận theo ELO. Nếu hết thời gian\nsẽ tự động chuyển sang Bot.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: () {
              _timer?.cancel();
              Navigator.pop(context, _MatchResult.cancelled);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text(
                'Hủy',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Fixed bottom banner ad ───────────────────────────────────────────────────
class _BannerAd extends StatelessWidget {
  final double bottomPad;
  const _BannerAd({required this.bottomPad});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50 + bottomPad,
      padding: EdgeInsets.only(bottom: bottomPad),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.ad_units, color: Colors.white24, size: 16),
          const SizedBox(width: 8),
          Text(
            'QUẢNG CÁO BANNER',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.18),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Background: subtle checker pattern ──────────────────────────────────────
class _BoardPattern extends StatelessWidget {
  const _BoardPattern();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _BoardPatternPainter());
}

class _BoardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.012)
      ..style = PaintingStyle.fill;
    const cell = 40.0;
    final cols = (size.width / cell).ceil() + 1;
    final rows = (size.height / cell).ceil() + 1;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if ((r + c).isEven) {
          canvas.drawRect(Rect.fromLTWH(c * cell, r * cell, cell, cell), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_BoardPatternPainter _) => false;
}

// ─── Background: corner knot decorations ─────────────────────────────────────
class _CornerKnots extends StatelessWidget {
  const _CornerKnots();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _KnotPainter());
}

class _KnotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _primary.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    _drawKnot(canvas, paint, Offset.zero, 52);
    _drawKnot(canvas, paint, Offset(size.width, 0), 52, flipX: true);
  }

  void _drawKnot(Canvas canvas, Paint paint, Offset origin, double r,
      {bool flipX = false}) {
    final dx = flipX ? -1.0 : 1.0;
    final cx = origin.dx + dx * r;
    final cy = origin.dy + r;
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(Offset(cx, cy), r * i * 0.3, paint);
    }
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy), width: r * 1.6, height: r * 1.6),
      -math.pi / 4,
      math.pi / 2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_KnotPainter _) => false;
}

// ignore_for_file: unused_import
// Player import kept for future AI options integration
