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

// ---------------------------------------------------------------------------
// Palette — dark green chess theme
// ---------------------------------------------------------------------------
const _bgMid = Color(0xFF1A5C38);
const _bgEdge = Color(0xFF0C2C18);

const _goldDark = Color(0xFF9A6C08);
const _goldMid = Color(0xFFCC9518);
const _goldLight = Color(0xFFEDBC50);
const _goldGlow = Color(0xFFFFD86E);

const _orbitR = 118.0;

// ---------------------------------------------------------------------------
// MainMenuView
// ---------------------------------------------------------------------------
class MainMenuView extends StatefulWidget {
  @override
  _MainMenuViewState createState() => _MainMenuViewState();
}

class _MainMenuViewState extends State<MainMenuView> {
  bool _hasSavedGame = false;

  @override
  void initState() {
    super.initState();
    _checkSavedGame();
  }

  Future<void> _checkSavedGame() async {
    final has = await GameStateStorage.hasSavedGame();
    if (mounted) setState(() => _hasSavedGame = has);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgEdge,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background radial gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, 0.05),
                radius: 0.80,
                colors: [_bgMid, _bgEdge],
              ),
            ),
          ),
          // Side piece decorations
          const _SidePieces(),
          // Corner knot decorations
          const _CornerKnots(),
          // Main content
          SafeArea(
            child: Column(
              children: [
                _TopBar(),
                Expanded(
                  child: _RadialMenu(
                    hasSavedGame: _hasSavedGame,
                    onRefresh: _checkSavedGame,
                  ),
                ),
                const _BannerSlot(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------
class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Image.asset('assets/images/logo.png', width: 34, height: 34),
          const SizedBox(width: 10),
          const Text(
            'Chess',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontFamily: 'Jura',
            ),
          ),
          const Spacer(),
          _TopIconBtn(
            icon: CupertinoIcons.settings,
            tooltip: 'Settings',
            onTap: () => Navigator.push(
              context,
              CupertinoPageRoute(builder: (_) => SettingsView()),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Radial menu — 8 satellite buttons + central PLAY
// ---------------------------------------------------------------------------
class _RadialMenu extends StatelessWidget {
  final bool hasSavedGame;
  final VoidCallback onRefresh;

  const _RadialMenu({required this.hasSavedGame, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final appModel = Provider.of<AppModel>(context, listen: false);

    final items = <_SatItem>[
      _SatItem(
        CupertinoIcons.person_2_fill,
        'vs Friend',
        -90,
        () => _startGame(context, appModel, players: 2),
      ),
      _SatItem(
        CupertinoIcons.waveform_path_ecg,
        'Difficulty',
        -45,
        () => _showDifficultySheet(context, appModel),
      ),
      _SatItem(
        CupertinoIcons.clock,
        'Time',
        0,
        () => _showTimerSheet(context, appModel),
      ),
      _SatItem(
        CupertinoIcons.paintbrush_fill,
        'Theme',
        45,
        () {
          final next = (appModel.themeIndex + 1) % themeList.length;
          appModel.setTheme(next);
        },
      ),
      _SatItem(
        hasSavedGame
            ? CupertinoIcons.arrow_counterclockwise_circle_fill
            : CupertinoIcons.star_fill,
        hasSavedGame ? 'Resume' : 'Classic',
        90,
        hasSavedGame
            ? () => _startGame(context, appModel, resume: true)
            : () => _startGame(context, appModel, players: 1),
      ),
      _SatItem(
        CupertinoIcons.rectangle_on_rectangle_angled,
        'Pieces',
        135,
        () {
          final next =
              (appModel.pieceThemeIndex + 1) % appModel.pieceThemes.length;
          appModel.setPieceTheme(next);
        },
      ),
      _SatItem(
        CupertinoIcons.person_crop_circle_fill,
        'Side',
        180,
        () => _showSideSheet(context, appModel),
      ),
      _SatItem(
        CupertinoIcons.flag_fill,
        'vs AI',
        225,
        () => _startGame(context, appModel, players: 1),
      ),
    ];

    return LayoutBuilder(builder: (context, bc) {
      final d = math.min(bc.maxWidth, bc.maxHeight).clamp(0.0, 430.0);
      return Center(
        child: SizedBox(
          width: d,
          height: d,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(d, d),
                painter: _OrbitPainter(radius: _orbitR),
              ),
              ...items.map((item) {
                final rad = item.angleDeg * math.pi / 180.0;
                return Transform.translate(
                  offset: Offset(
                    _orbitR * math.cos(rad),
                    _orbitR * math.sin(rad),
                  ),
                  child: _SatelliteBtn(item: item),
                );
              }),
              _PlayBtn(
                onTap: () =>
                    _showModeSheet(context, appModel, hasSavedGame, onRefresh),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ── Navigation helpers ──

  void _startGame(BuildContext context, AppModel appModel,
      {int players = 1, bool resume = false}) {
    appModel.setPlayerCount(players);
    Navigator.push(
      context,
      CupertinoPageRoute(
          builder: (_) => ChessView(appModel, isResuming: resume)),
    ).then((_) => onRefresh());
  }

  void _showModeSheet(BuildContext context, AppModel appModel, bool hasSaved,
      VoidCallback onRefresh) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => _ModeSheet(
        appModel: appModel,
        hasSavedGame: hasSaved,
        onRefresh: onRefresh,
      ),
    );
  }

  void _showDifficultySheet(BuildContext context, AppModel appModel) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => _DifficultySheet(appModel: appModel),
    );
  }

  void _showTimerSheet(BuildContext context, AppModel appModel) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => _TimerSheet(appModel: appModel),
    );
  }

  void _showSideSheet(BuildContext context, AppModel appModel) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => _SideSheet(appModel: appModel),
    );
  }
}

// ---------------------------------------------------------------------------
// Central PLAY button
// ---------------------------------------------------------------------------
class _PlayBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _PlayBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_goldGlow, _goldMid, _goldDark],
            stops: [0.0, 0.5, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: _goldMid.withValues(alpha: 0.65),
              blurRadius: 28,
              spreadRadius: 6,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow_rounded, color: Colors.white, size: 42),
            SizedBox(height: 1),
            Text(
              'Play',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                fontFamily: 'Jura',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Satellite button
// ---------------------------------------------------------------------------
class _SatelliteBtn extends StatelessWidget {
  final _SatItem item;
  const _SatelliteBtn({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_goldLight, _goldMid, _goldDark],
                stops: [0.0, 0.45, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: _goldDark.withValues(alpha: 0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(item.icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 60,
            child: Text(
              item.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                fontFamily: 'Jura',
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mode selection bottom sheet
// ---------------------------------------------------------------------------
class _ModeSheet extends StatelessWidget {
  final AppModel appModel;
  final bool hasSavedGame;
  final VoidCallback onRefresh;

  const _ModeSheet({
    required this.appModel,
    required this.hasSavedGame,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F3820),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: _goldMid.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Chọn Chế Độ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              fontFamily: 'Jura',
            ),
          ),
          const SizedBox(height: 18),
          if (hasSavedGame) ...[
            _SheetRow(
              icon: CupertinoIcons.arrow_counterclockwise_circle_fill,
              label: 'Resume Game',
              sub: 'Tiếp tục ván trước',
              onTap: () {
                Navigator.pop(context);
                appModel.setPlayerCount(appModel.playerCount);
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                      builder: (_) => ChessView(appModel, isResuming: true)),
                ).then((_) => onRefresh());
              },
            ),
            const SizedBox(height: 10),
          ],
          _SheetRow(
            icon: CupertinoIcons.flag_fill,
            label: 'vs AI',
            sub: 'Chơi với máy tính',
            onTap: () {
              Navigator.pop(context);
              appModel.setPlayerCount(1);
              Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => ChessView(appModel)),
              ).then((_) => onRefresh());
            },
          ),
          const SizedBox(height: 10),
          _SheetRow(
            icon: CupertinoIcons.person_2_fill,
            label: '2 Người Chơi',
            sub: 'Chơi với bạn bè trên cùng thiết bị',
            onTap: () {
              Navigator.pop(context);
              appModel.setPlayerCount(2);
              Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => ChessView(appModel)),
              ).then((_) => onRefresh());
            },
          ),
        ],
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;

  const _SheetRow({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A5C38),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        highlightColor: _goldMid.withValues(alpha: 0.1),
        splashColor: _goldMid.withValues(alpha: 0.2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_goldLight, _goldDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        fontFamily: 'Jura',
                      ),
                    ),
                    Text(
                      sub,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontFamily: 'Jura',
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(CupertinoIcons.chevron_right,
                  color: Colors.white38, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Difficulty bottom sheet
// ---------------------------------------------------------------------------
class _DifficultySheet extends StatelessWidget {
  final AppModel appModel;
  const _DifficultySheet({required this.appModel});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F3820),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHandle(),
          const SizedBox(height: 18),
          const Text(
            'Độ Khó AI',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              fontFamily: 'Jura',
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(5, (i) {
            final level = i + 1;
            final labels = ['Rất dễ', 'Dễ', 'Trung bình', 'Khó', 'Rất khó'];
            final icons = [
              CupertinoIcons.smiley,
              CupertinoIcons.hand_thumbsup,
              CupertinoIcons.person_fill,
              CupertinoIcons.flame,
              CupertinoIcons.bolt_fill,
            ];
            final selected = appModel.aiDifficulty == level;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () {
                  appModel.setAIDifficulty(level);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: selected
                        ? _goldMid.withValues(alpha: 0.25)
                        : const Color(0xFF1A5C38),
                    borderRadius: BorderRadius.circular(12),
                    border: selected
                        ? Border.all(color: _goldMid, width: 1.5)
                        : null,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(icons[i],
                          color: selected ? _goldGlow : Colors.white60,
                          size: 22),
                      const SizedBox(width: 14),
                      Text(
                        'Cấp $level — ${labels[i]}',
                        style: TextStyle(
                          color: selected ? _goldGlow : Colors.white,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                          fontFamily: 'Jura',
                        ),
                      ),
                      const Spacer(),
                      if (selected)
                        const Icon(CupertinoIcons.checkmark_alt,
                            color: _goldGlow, size: 18),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timer bottom sheet
// ---------------------------------------------------------------------------
class _TimerSheet extends StatelessWidget {
  final AppModel appModel;
  const _TimerSheet({required this.appModel});

  @override
  Widget build(BuildContext context) {
    const times = [0, 1, 3, 5, 10, 15, 30];
    const labels = [
      'Không giới hạn',
      '1 phút',
      '3 phút',
      '5 phút',
      '10 phút',
      '15 phút',
      '30 phút',
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F3820),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHandle(),
          const SizedBox(height: 18),
          const Text(
            'Thời Gian',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              fontFamily: 'Jura',
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(times.length, (i) {
            final selected = appModel.timeLimit == times[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () {
                  appModel.setTimeLimit(times[i]);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: selected
                        ? _goldMid.withValues(alpha: 0.25)
                        : const Color(0xFF1A5C38),
                    borderRadius: BorderRadius.circular(12),
                    border: selected
                        ? Border.all(color: _goldMid, width: 1.5)
                        : null,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        times[i] == 0
                            ? CupertinoIcons.minus_circle
                            : CupertinoIcons.clock,
                        color: selected ? _goldGlow : Colors.white60,
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        labels[i],
                        style: TextStyle(
                          color: selected ? _goldGlow : Colors.white,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                          fontFamily: 'Jura',
                        ),
                      ),
                      const Spacer(),
                      if (selected)
                        const Icon(CupertinoIcons.checkmark_alt,
                            color: _goldGlow, size: 18),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Side selection bottom sheet
// ---------------------------------------------------------------------------
class _SideSheet extends StatelessWidget {
  final AppModel appModel;
  const _SideSheet({required this.appModel});

  @override
  Widget build(BuildContext context) {
    final options = [
      (Player.player1, 'Trắng', CupertinoIcons.circle, 'Đi trước'),
      (Player.player2, 'Đen', CupertinoIcons.circle_fill, 'Đi sau'),
      (Player.random, 'Ngẫu nhiên', CupertinoIcons.shuffle, 'Hệ thống chọn'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F3820),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHandle(),
          const SizedBox(height: 18),
          const Text(
            'Chọn Quân',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              fontFamily: 'Jura',
            ),
          ),
          const SizedBox(height: 20),
          ...options.map((opt) {
            final selected = appModel.selectedSide == opt.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () {
                  appModel.setPlayerSide(opt.$1);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: selected
                        ? _goldMid.withValues(alpha: 0.25)
                        : const Color(0xFF1A5C38),
                    borderRadius: BorderRadius.circular(12),
                    border: selected
                        ? Border.all(color: _goldMid, width: 1.5)
                        : null,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(opt.$3,
                          color: selected ? _goldGlow : Colors.white60,
                          size: 22),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opt.$2,
                            style: TextStyle(
                              color: selected ? _goldGlow : Colors.white,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 14,
                              fontFamily: 'Jura',
                            ),
                          ),
                          Text(
                            opt.$4,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 11,
                              fontFamily: 'Jura',
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (selected)
                        const Icon(CupertinoIcons.checkmark_alt,
                            color: _goldGlow, size: 18),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sheet handle widget
// ---------------------------------------------------------------------------
class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 4,
      decoration: BoxDecoration(
        color: _goldMid.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Side chess-piece decorations
// ---------------------------------------------------------------------------
class _SidePieces extends StatelessWidget {
  const _SidePieces();

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Left — white queen
        Positioned(
          left: -28,
          bottom: h * 0.10,
          child: Opacity(
            opacity: 0.15,
            child: Image.asset(
              'assets/images/pieces/classic/queen_white.png',
              width: 170,
              height: 170,
            ),
          ),
        ),
        // Right — black king
        Positioned(
          right: -28,
          bottom: h * 0.10,
          child: Opacity(
            opacity: 0.15,
            child: Image.asset(
              'assets/images/pieces/classic/king_black.png',
              width: 170,
              height: 170,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Corner knot decorations (painted arcs)
// ---------------------------------------------------------------------------
class _CornerKnots extends StatelessWidget {
  const _CornerKnots();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _KnotPainter());
  }
}

class _KnotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _goldMid.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    _drawKnot(canvas, paint, Offset.zero, 60);
    _drawKnot(canvas, paint, Offset(size.width, 0), 60, flipX: true);
  }

  void _drawKnot(
    Canvas canvas,
    Paint paint,
    Offset origin,
    double r, {
    bool flipX = false,
  }) {
    final dx = flipX ? -1.0 : 1.0;
    final cx = origin.dx + dx * r;
    final cy = origin.dy + r;

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(Offset(cx, cy), r * i * 0.28, paint);
    }
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy), width: r * 1.6, height: r * 1.6),
      -math.pi / 4,
      math.pi / 2,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx - dx * r * 0.3, cy - r * 0.3),
        width: r * 1.2,
        height: r * 1.2,
      ),
      math.pi - math.pi / 6,
      -math.pi / 2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_KnotPainter _) => false;
}

// ---------------------------------------------------------------------------
// Orbit ring painter
// ---------------------------------------------------------------------------
class _OrbitPainter extends CustomPainter {
  final double radius;
  const _OrbitPainter({required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _goldMid.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      radius,
      paint,
    );
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.radius != radius;
}

// ---------------------------------------------------------------------------
// Banner slot (placeholder for ads)
// ---------------------------------------------------------------------------
class _BannerSlot extends StatelessWidget {
  const _BannerSlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        border: Border.all(color: _goldMid.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(6),
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

// ---------------------------------------------------------------------------
// Small icon button in top bar
// ---------------------------------------------------------------------------
class _TopIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TopIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

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
            border: Border.all(
              color: _goldMid.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Icon(icon, color: Colors.white70, size: 18),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data class for satellite items
// ---------------------------------------------------------------------------
class _SatItem {
  final IconData icon;
  final String label;
  final double angleDeg;
  final VoidCallback onTap;

  const _SatItem(this.icon, this.label, this.angleDeg, this.onTap);
}
