class HomeUserSummary {
  final String id;
  final String username;
  final int elo;
  final int? rank;

  HomeUserSummary({
    required this.id,
    required this.username,
    required this.elo,
    this.rank,
  });

  factory HomeUserSummary.fromJson(Map<String, dynamic> json) {
    return HomeUserSummary(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      elo: (json['elo'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt(),
    );
  }
}

class HomeOverview {
  final String authMode;
  final HomeUserSummary? user;
  final int targetCardCount;
  final bool quickPlayEnabled;
  final bool settingsShortcutEnabled;
  final bool showBanner;
  final String bannerPlacement;

  HomeOverview({
    required this.authMode,
    this.user,
    required this.targetCardCount,
    required this.quickPlayEnabled,
    required this.settingsShortcutEnabled,
    required this.showBanner,
    required this.bannerPlacement,
  });

  factory HomeOverview.fromJson(Map<String, dynamic> json) {
    final auth = (json['auth'] as Map<String, dynamic>?) ?? {};
    final home = (json['home'] as Map<String, dynamic>?) ?? {};
    final ads = (json['ads'] as Map<String, dynamic>?) ?? {};
    final userJson = json['user'];

    return HomeOverview(
      authMode: auth['mode'] as String? ?? 'anonymous',
      user: userJson is Map<String, dynamic>
          ? HomeUserSummary.fromJson(userJson)
          : null,
      targetCardCount: (home['targetCardCount'] as num?)?.toInt() ?? 10,
      quickPlayEnabled: home['quickPlayEnabled'] as bool? ?? true,
      settingsShortcutEnabled: home['settingsShortcutEnabled'] as bool? ?? true,
      showBanner: ads['showBanner'] as bool? ?? false,
      bannerPlacement: ads['placement'] as String? ?? 'home_footer',
    );
  }
}

class LiveMatchPlayer {
  final String? id;
  final String username;
  final int elo;

  LiveMatchPlayer({
    required this.id,
    required this.username,
    required this.elo,
  });

  factory LiveMatchPlayer.fromJson(Map<String, dynamic> json) {
    return LiveMatchPlayer(
      id: json['id'] as String?,
      username: json['username'] as String? ?? 'unknown',
      elo: (json['elo'] as num?)?.toInt() ?? 0,
    );
  }
}

class LiveMatchCard {
  final String gameId;
  final LiveMatchPlayer white;
  final LiveMatchPlayer black;
  final String status;
  final String timeControl;
  final String fenPreview;
  final int spectatorCount;
  final String sourceType;
  final DateTime? startedAt;

  LiveMatchCard({
    required this.gameId,
    required this.white,
    required this.black,
    required this.status,
    required this.timeControl,
    required this.fenPreview,
    required this.spectatorCount,
    required this.sourceType,
    required this.startedAt,
  });

  factory LiveMatchCard.fromJson(Map<String, dynamic> json) {
    return LiveMatchCard(
      gameId: json['gameId'] as String? ?? '',
      white: LiveMatchPlayer.fromJson(
        (json['white'] as Map<String, dynamic>?) ?? {},
      ),
      black: LiveMatchPlayer.fromJson(
        (json['black'] as Map<String, dynamic>?) ?? {},
      ),
      status: json['status'] as String? ?? 'unknown',
      timeControl: json['timeControl'] as String? ?? 'rapid_15',
      fenPreview: json['fenPreview'] as String? ?? '',
      spectatorCount: (json['spectatorCount'] as num?)?.toInt() ?? 0,
      sourceType: json['sourceType'] as String? ?? 'human',
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.tryParse(json['startedAt'] as String),
    );
  }
}

class LiveMatchesResponse {
  final List<LiveMatchCard> items;
  final int targetCardCount;
  final String? nextCursor;

  LiveMatchesResponse({
    required this.items,
    required this.targetCardCount,
    required this.nextCursor,
  });

  factory LiveMatchesResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    return LiveMatchesResponse(
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(LiveMatchCard.fromJson)
          .toList(),
      targetCardCount: (json['targetCardCount'] as num?)?.toInt() ?? 10,
      nextCursor: json['nextCursor'] as String?,
    );
  }
}

class QuickPlayResult {
  final String mode;
  final String gameId;
  final String? fallbackReason;
  final int? aiLevel;
  final String? aiColor;
  final String? opponentId;
  final String? matchmakingTicketId;

  QuickPlayResult({
    required this.mode,
    required this.gameId,
    this.fallbackReason,
    this.aiLevel,
    this.aiColor,
    this.opponentId,
    this.matchmakingTicketId,
  });

  factory QuickPlayResult.fromJson(Map<String, dynamic> json) {
    return QuickPlayResult(
      mode: json['mode'] as String? ?? 'online',
      gameId: json['gameId'] as String? ?? '',
      fallbackReason: json['fallbackReason'] as String?,
      aiLevel: (json['aiLevel'] as num?)?.toInt(),
      aiColor: json['aiColor'] as String?,
      opponentId: json['opponentId'] as String?,
      matchmakingTicketId: json['matchmakingTicketId'] as String?,
    );
  }
}

class InterstitialPolicy {
  final bool firstGameFreePerDay;
  final int autoShowAfterGameOverSec;
  final int preloadQueueTarget;
  final bool allowOfflineBypassWhenQueueEmpty;
  final bool showBeforeNextGameWhenAbandoned;

  InterstitialPolicy({
    required this.firstGameFreePerDay,
    required this.autoShowAfterGameOverSec,
    required this.preloadQueueTarget,
    required this.allowOfflineBypassWhenQueueEmpty,
    required this.showBeforeNextGameWhenAbandoned,
  });

  factory InterstitialPolicy.fromJson(Map<String, dynamic> json) {
    return InterstitialPolicy(
      firstGameFreePerDay: json['firstGameFreePerDay'] as bool? ?? true,
      autoShowAfterGameOverSec:
          (json['autoShowAfterGameOverSec'] as num?)?.toInt() ?? 1,
      preloadQueueTarget: (json['preloadQueueTarget'] as num?)?.toInt() ?? 5,
      allowOfflineBypassWhenQueueEmpty:
          json['allowOfflineBypassWhenQueueEmpty'] as bool? ?? true,
      showBeforeNextGameWhenAbandoned:
          json['showBeforeNextGameWhenAbandoned'] as bool? ?? true,
    );
  }
}

class MonetizationConfig {
  final InterstitialPolicy interstitial;

  MonetizationConfig({required this.interstitial});

  factory MonetizationConfig.fromJson(Map<String, dynamic> json) {
    return MonetizationConfig(
      interstitial: InterstitialPolicy.fromJson(
        (json['interstitial'] as Map<String, dynamic>?) ?? {},
      ),
    );
  }
}

class OnlineGameSnapshot {
  final String id;
  final String status;
  final String result;
  final String? whiteId;
  final String? blackId;
  final int? aiLevel;
  final int moveTimeLimit;
  final String currentFen;
  final bool isAiGame;
  final String? startedAt;
  final String? endedAt;

  /// Raw time-control string from server, e.g. "blitz_5", "rapid_10".
  final String? timeControl;

  OnlineGameSnapshot({
    required this.id,
    required this.status,
    required this.result,
    required this.whiteId,
    required this.blackId,
    this.aiLevel,
    required this.moveTimeLimit,
    required this.currentFen,
    required this.isAiGame,
    required this.startedAt,
    required this.endedAt,
    this.timeControl,
  });

  /// Parse time-control string into total minutes.
  /// Format: "<label>_<minutes>" e.g. "blitz_5" → 5, "rapid_10" → 10.
  /// Returns null if cannot parse.
  int? get timeLimitMinutes {
    if (timeControl == null) return null;
    final parts = timeControl!.split('_');
    if (parts.length >= 2) return int.tryParse(parts.last);
    return null;
  }

  factory OnlineGameSnapshot.fromJson(Map<String, dynamic> json) {
    return OnlineGameSnapshot(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      result: json['result'] as String? ?? 'unknown',
      whiteId: json['whiteId'] as String?,
      blackId: json['blackId'] as String?,
      aiLevel: (json['aiLevel'] as num?)?.toInt(),
      moveTimeLimit: (json['moveTimeLimit'] as num?)?.toInt() ?? 0,
      currentFen: json['currentFen'] as String? ?? '',
      isAiGame: json['isAiGame'] as bool? ?? false,
      startedAt: json['startedAt'] as String?,
      endedAt: json['endedAt'] as String?,
      timeControl: json['timeControl'] as String?,
    );
  }
}

class OnlineMoveRecord {
  final String id;
  final int moveNumber;
  final String? playedBy;
  final String fromSquare;
  final String toSquare;
  final String? promotion;
  final String sanNotation;
  final String fenAfter;

  OnlineMoveRecord({
    required this.id,
    required this.moveNumber,
    required this.playedBy,
    required this.fromSquare,
    required this.toSquare,
    required this.promotion,
    required this.sanNotation,
    required this.fenAfter,
  });

  factory OnlineMoveRecord.fromJson(Map<String, dynamic> json) {
    final rawMove = (json['move'] as String?)?.trim() ?? '';
    String? from = (json['fromSquare'] as String?)?.trim();
    String? to = (json['toSquare'] as String?)?.trim();

    from ??= (json['from'] as String?)?.trim();
    to ??= (json['to'] as String?)?.trim();

    if ((from == null || from.isEmpty) && rawMove.length >= 4) {
      from = rawMove.substring(0, 2);
    }
    if ((to == null || to.isEmpty) && rawMove.length >= 4) {
      to = rawMove.substring(2, 4);
    }

    final promotion = (json['promotion'] as String?)?.trim();
    return OnlineMoveRecord(
      id: json['id'] as String? ?? '',
      moveNumber: (json['moveNumber'] as num?)?.toInt() ?? 0,
      playedBy: json['playedBy'] as String?,
      fromSquare: from ?? '',
      toSquare: to ?? '',
      promotion: promotion,
      sanNotation: json['sanNotation'] as String? ?? '',
      fenAfter: json['fenAfter'] as String? ?? '',
    );
  }
}

class OnlineMoveSubmitResult {
  final String type;
  final String gameId;
  final String? status;
  final String? winner;
  final String? fen;

  OnlineMoveSubmitResult({
    required this.type,
    required this.gameId,
    required this.status,
    required this.winner,
    required this.fen,
  });

  factory OnlineMoveSubmitResult.fromJson(Map<String, dynamic> json) {
    return OnlineMoveSubmitResult(
      type: json['type'] as String? ?? 'move',
      gameId: json['gameId'] as String? ?? '',
      status: json['status'] as String?,
      winner: json['winner'] as String?,
      fen: json['fen'] as String?,
    );
  }
}

// ── Game History ──────────────────────────────────────────────────────────────

class GameHistoryItem {
  final String id;
  final String status;
  final String result;
  final String myColor;
  final String myResult; // 'win' | 'loss' | 'draw'
  final String? opponentId;
  final String opponentName;
  final String? opponentAvatarUrl;
  final String timeControl;
  final bool isAiGame;
  final String currentFen;
  final DateTime? startedAt;
  final DateTime? endedAt;

  GameHistoryItem({
    required this.id,
    required this.status,
    required this.result,
    required this.myColor,
    required this.myResult,
    required this.opponentId,
    required this.opponentName,
    required this.opponentAvatarUrl,
    required this.timeControl,
    required this.isAiGame,
    required this.currentFen,
    required this.startedAt,
    required this.endedAt,
  });

  factory GameHistoryItem.fromJson(Map<String, dynamic> json) {
    return GameHistoryItem(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      result: json['result'] as String? ?? 'unknown',
      myColor: json['myColor'] as String? ?? 'white',
      myResult: json['myResult'] as String? ?? 'draw',
      opponentId: json['opponentId'] as String?,
      opponentName: json['opponentName'] as String? ?? 'Unknown',
      opponentAvatarUrl: json['opponentAvatarUrl'] as String?,
      timeControl: json['timeControl'] as String? ?? 'rapid_15',
      isAiGame: json['isAiGame'] as bool? ?? false,
      currentFen: json['currentFen'] as String? ?? '',
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.tryParse(json['startedAt'] as String),
      endedAt: json['endedAt'] == null
          ? null
          : DateTime.tryParse(json['endedAt'] as String),
    );
  }
}

// ── Position Analysis ─────────────────────────────────────────────────────────

class MoveHint {
  final String uci;
  final String san;
  final String from;
  final String to;

  MoveHint({
    required this.uci,
    required this.san,
    required this.from,
    required this.to,
  });

  factory MoveHint.fromJson(Map<String, dynamic> json) {
    return MoveHint(
      uci: json['uci'] as String? ?? '',
      san: json['san'] as String? ?? '',
      from: json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
    );
  }
}

class PositionAnalysis {
  final MoveHint bestMove;
  final String classification; // best/excellent/good/inaccurate/mistake/blunder/unknown
  final int? evalScore;
  final int? evalPlayed;

  PositionAnalysis({
    required this.bestMove,
    required this.classification,
    required this.evalScore,
    required this.evalPlayed,
  });

  factory PositionAnalysis.fromJson(Map<String, dynamic> json) {
    return PositionAnalysis(
      bestMove: MoveHint.fromJson(
        (json['bestMove'] as Map<String, dynamic>?) ?? {},
      ),
      classification: json['classification'] as String? ?? 'unknown',
      evalScore: (json['evalScore'] as num?)?.toInt(),
      evalPlayed: (json['evalPlayed'] as num?)?.toInt(),
    );
  }

  String get classificationLabel {
    switch (classification) {
      case 'best':
        return 'Nước đi tốt nhất!';
      case 'excellent':
        return 'Xuất sắc!';
      case 'good':
        return 'Nước đi tốt';
      case 'inaccurate':
        return 'Không chính xác';
      case 'mistake':
        return 'Sai lầm';
      case 'blunder':
        return 'Sai lầm nghiêm trọng!';
      default:
        return 'Không xác định';
    }
  }

  bool get isPositive =>
      classification == 'best' || classification == 'excellent' || classification == 'good';
}
