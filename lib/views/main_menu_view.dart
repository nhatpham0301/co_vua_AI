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
const _bgMid = Color(0xFF1A5C38);
const _bgEdge = Color(0xFF0C2C18);
const _goldDark = Color(0xFF9A6C08);
const _goldMid = Color(0xFFCC9518);
const _goldLight = Color(0xFFEDBC50);
const _goldGlow = Color(0xFFFFD86E);

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
  bool _isLoggedIn = false;
  final String _userName = 'Guest';
  final int _elo = 1200;

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
        title: const Text('Đăng nhập', style: TextStyle(fontFamily: 'Jura')),
        content: const Text(
          'Tính năng đăng nhập đang được phát triển.\nSẽ ra mắt sớm!',
          style: TextStyle(fontFamily: 'Jura'),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK', style: TextStyle(fontFamily: 'Jura')),
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
      backgroundColor: _bgEdge,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background ──────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                radius: 0.9,
                colors: [_bgMid, _bgEdge],
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
  final VoidCallback onLoginTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onThemeTap;

  const _Header({
    required this.isLoggedIn,
    required this.userName,
    required this.elo,
    required this.onLoginTap,
    required this.onSettingsTap,
    required this.onThemeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        border: Border(
          bottom: BorderSide(color: _goldMid.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          // ── Left: auth status ──────────────────────────────────────────
          if (isLoggedIn) ...[
            _AvatarCircle(initial: userName.isNotEmpty ? userName[0] : 'G'),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Jura',
                  ),
                ),
                Row(
                  children: [
                    const Icon(CupertinoIcons.star_fill,
                        color: _goldMid, size: 11),
                    const SizedBox(width: 3),
                    Text(
                      'ELO $elo',
                      style: TextStyle(
                        color: _goldLight.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontFamily: 'Jura',
                      ),
                    ),
                  ],
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
                  gradient: const LinearGradient(colors: [_goldGlow, _goldMid]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: _goldMid.withValues(alpha: 0.4), blurRadius: 8),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.person_fill,
                        color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Đăng nhập / Đăng ký',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Jura',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const Spacer(),
          // ── Right: theme + settings ────────────────────────────────────
          _IconBtn(
              icon: CupertinoIcons.paintbrush_fill,
              tooltip: 'Đổi giao diện',
              onTap: onThemeTap),
          const SizedBox(width: 8),
          _IconBtn(
              icon: CupertinoIcons.settings,
              tooltip: 'Cài đặt',
              onTap: onSettingsTap),
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
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [_goldLight, _goldDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _goldMid, width: 1.5),
      ),
      child: Center(
        child: Text(
          initial.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            fontFamily: 'Jura',
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
                child: CupertinoActivityIndicator(color: _goldMid),
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
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Color(0xFF4ADE80)),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'TRẬN ĐANG DIỄN RA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontFamily: 'Jura',
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${matches.length}/10',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                      fontFamily: 'Jura',
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
                fontFamily: 'Jura',
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
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _goldMid.withValues(alpha: 0.18)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          splashColor: _goldMid.withValues(alpha: 0.08),
          onTap: () => _onTap(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Mini board preview
                _MiniChessBoard(board: match.board),
                const SizedBox(width: 12),
                // Player info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PlayerRow(player: match.white, label: '♔ Trắng'),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          'vs',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 10,
                            fontFamily: 'Jura',
                          ),
                        ),
                      ),
                      _PlayerRow(player: match.black, label: '♚ Đen'),
                    ],
                  ),
                ),
                // Right stats
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // LIVE badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color:
                                const Color(0xFF4ADE80).withValues(alpha: 0.6)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fiber_manual_record,
                              color: Color(0xFF4ADE80), size: 8),
                          SizedBox(width: 3),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: Color(0xFF4ADE80),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Jura',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${match.moveCount} nước',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11,
                          fontFamily: 'Jura'),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _fmt(match.elapsedSec),
                      style: TextStyle(
                          color: _goldLight.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontFamily: 'Jura'),
                    ),
                  ],
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
        title: const Text('Quan sát trận đấu',
            style: TextStyle(fontFamily: 'Jura')),
        content: const Text(
          'Chế độ quan sát (observer) đang phát triển.',
          style: TextStyle(fontFamily: 'Jura'),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK', style: TextStyle(fontFamily: 'Jura')),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final _MatchPlayer player;
  final String label;
  const _PlayerRow({required this.player, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
              fontFamily: 'Jura'),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            player.name,
            style: TextStyle(
              color: player.isBot ? const Color(0xFF22D3EE) : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Jura',
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '(${player.elo})',
          style: TextStyle(
              color: _goldLight.withValues(alpha: 0.6),
              fontSize: 10,
              fontFamily: 'Jura'),
        ),
        if (player.isBot) ...[
          const SizedBox(width: 3),
          const Icon(CupertinoIcons.waveform_path_ecg,
              color: Color(0xFF22D3EE), size: 10),
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
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _goldMid.withValues(alpha: 0.35), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
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
    final light = Paint()..color = const Color(0xFF8FAF7A);
    final dark = Paint()..color = const Color(0xFF2D6A4F);
    final pieceW = Paint()..color = Colors.white.withValues(alpha: 0.85);
    final pieceB = Paint()..color = Colors.black.withValues(alpha: 0.7);

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
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 36),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_goldGlow, _goldMid, _goldDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: _goldMid.withValues(alpha: 0.65),
                blurRadius: 20,
                spreadRadius: 2,
              ),
              const BoxShadow(
                color: Colors.black38,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'CHƠI NHANH',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontFamily: 'Jura',
                ),
              ),
            ],
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
        color: Color(0xFF0F3820),
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
              color: _goldMid.withValues(alpha: 0.5),
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
                  color: _goldMid,
                ),
                Text(
                  '$_remaining',
                  style: const TextStyle(
                    color: _goldGlow,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Jura',
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
              fontFamily: 'Jura',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ghép trận theo ELO. Nếu hết thời gian\nsẽ tự động chuyển sang Bot.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontFamily: 'Jura',
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
                  fontFamily: 'Jura',
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
        color: Colors.black.withValues(alpha: 0.35),
        border:
            Border(top: BorderSide(color: _goldMid.withValues(alpha: 0.15))),
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
              fontFamily: 'Jura',
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
      ..color = Colors.white.withValues(alpha: 0.018)
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
      ..color = _goldMid.withValues(alpha: 0.12)
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
