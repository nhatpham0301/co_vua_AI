import 'dart:math' as math;

// ─── Data models ─────────────────────────────────────────────────────────────
class MatchPlayer {
  final String name;
  final int elo;
  final bool isBot;
  const MatchPlayer(this.name, this.elo, {this.isBot = false});
}

class LiveMatch {
  final String id;
  final String title;
  final MatchPlayer white;
  final MatchPlayer black;
  int moveCount;
  int elapsedSec;
  final List<List<bool>> board; // 8×8 occupancy for mini preview

  LiveMatch({
    required this.id,
    required this.title,
    required this.white,
    required this.black,
    required this.moveCount,
    required this.elapsedSec,
    required this.board,
  });
}

enum MatchResult { matched, timeout, cancelled }

// ─── Match generator ─────────────────────────────────────────────────────────
class MatchGen {
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
    'TigerBlitz',
    'ShadowRook',
    'PhongVu99',
    'LongKy2k',
    'ThanCo88',
    'HoangAnh_CK',
    'MinhTuong',
    'KyThuViet',
    'VietChess01',
    'TrungHau7',
    'CoVuaPro',
    'AnhViet_CK',
    'QuanCoVua',
    'SteelBishop',
    'BlitzRaider',
    'CastleRush',
    'ForkMaster',
    'PinBreaker',
    'SkeweredKing',
    'ZugZwang99',
    'FianchettoX',
    'EnPassant7',
    'TacticsGod',
    'QueenGambit',
    'SicilianDrg',
    'CaroKann55',
    'KingsCourt',
    'IronDefense',
    'GambitKing',
    'XuatThan99',
    'BaoVe_Vua',
    'TocChien88',
    'SieuCoVua',
    'HoaNghiem',
    'ThachTung07',
  ];

  static MatchPlayer _bot() {
    final name = _botNames[_rng.nextInt(_botNames.length)];
    return MatchPlayer(name, 800 + _rng.nextInt(1000), isBot: true);
  }

  /// Returns a random human name, optionally using a provided [rng].
  static String randomHumanName([math.Random? rng]) {
    final r = rng ?? _rng;
    return _humanNames[r.nextInt(_humanNames.length)];
  }

  static List<List<bool>> generateRandomBoard() => _randomBoard();

  static List<List<bool>> _randomBoard() => List.generate(
      8, (_) => List.generate(8, (_) => _rng.nextDouble() > 0.55));

  /// Generates 10 matches: first 2 human vs human, rest Bot vs Bot.
  static List<LiveMatch> generateTen() {
    // Shuffle a copy so each generation picks different names without repeats.
    final names = List<String>.from(_humanNames)..shuffle(_rng);
    int nameIdx = 0;
    MatchPlayer nextHuman() {
      final name = names[nameIdx % names.length];
      nameIdx++;
      return MatchPlayer(name, 900 + _rng.nextInt(1200));
    }

    return List.generate(10, (i) {
      final isBotMatch = i >= 2;
      final white = isBotMatch ? _bot() : nextHuman();
      final black = isBotMatch ? _bot() : nextHuman();
      return LiveMatch(
        id: 'match_$i',
        title: 'Trận của ${white.name} vs ${black.name}',
        white: white,
        black: black,
        moveCount: 10 + _rng.nextInt(60),
        elapsedSec: 60 + _rng.nextInt(1800),
        board: _randomBoard(),
      );
    });
  }

  /// Simulates real-time updates (called every 3 seconds).
  static void tick(List<LiveMatch> matches) {
    for (final m in matches) {
      m.elapsedSec += 3;
      if (_rng.nextDouble() > 0.4) m.moveCount++;
    }
  }
}
