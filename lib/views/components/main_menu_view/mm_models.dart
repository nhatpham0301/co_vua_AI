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
  final MatchPlayer white;
  final MatchPlayer black;
  int moveCount;
  int elapsedSec;
  final List<List<bool>> board; // 8×8 occupancy for mini preview

  LiveMatch({
    required this.id,
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
  ];

  static MatchPlayer _bot() {
    final name = _botNames[_rng.nextInt(_botNames.length)];
    return MatchPlayer(name, 800 + _rng.nextInt(1000), isBot: true);
  }

  static MatchPlayer _human() {
    final name = _humanNames[_rng.nextInt(_humanNames.length)];
    return MatchPlayer(name, 900 + _rng.nextInt(1200));
  }

  static List<List<bool>> generateRandomBoard() => _randomBoard();

  static List<List<bool>> _randomBoard() => List.generate(
      8, (_) => List.generate(8, (_) => _rng.nextDouble() > 0.55));

  /// Generates 10 matches: first 2 human vs human, rest Bot vs Bot.
  static List<LiveMatch> generateTen() {
    return List.generate(10, (i) {
      final isBotMatch = i >= 2;
      return LiveMatch(
        id: 'match_$i',
        white: isBotMatch ? _bot() : _human(),
        black: isBotMatch ? _bot() : _human(),
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
