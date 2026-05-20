import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../logic/chess_piece.dart';
import '../../../logic/rank_system.dart';
import '../../../logic/shared_functions.dart';
import '../../../model/api_models.dart';
import '../../../model/app_model.dart';
import '../../game_review_view.dart';
import '../shared/ranked_profile_avatar.dart';

class UserProfileDialog extends StatefulWidget {
  final String userId;
  final String userName;
  final String? avatarUrl;
  final int elo;

  /// Danh sách quân đã mất (truyền vào từ màn trận đấu để hiện tab Quân cờ)
  final List<ChessPieceType>? capturedPieces;

  const UserProfileDialog({
    super.key,
    required this.userId,
    required this.userName,
    this.avatarUrl,
    required this.elo,
    this.capturedPieces,
  });

  @override
  State<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<UserProfileDialog> {
  // 0 = Stats, 1 = History, 2 = Captured (nếu có)
  int _selectedTab = 0;
  List<dynamic>? _eloHistory;
  bool _loading = false;

  // Game history pagination
  final List<GameHistoryItem> _gameHistory = [];
  bool _historyLoading = false;
  bool _historyHasMore = true;
  int _historyOffset = 0;
  static const int _historyPageSize = 15;

  bool get _hasCapturedTab => widget.capturedPieces != null;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_loading) return;
    // Tab Quân cờ và Tab Lịch sử không dùng _eloHistory
    if (_selectedTab == 1) {
      _loadHistory();
      return;
    }
    if (_hasCapturedTab && _selectedTab == 2) return;
    setState(() => _loading = true);

    try {
      final appModel = Provider.of<AppModel>(context, listen: false);
      final history =
          await appModel.apiClient.fetchUserEloHistory(widget.userId);
      if (mounted) setState(() => _eloHistory = history);
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadHistory({bool refresh = false}) async {
    if (_historyLoading) return;
    if (!_historyHasMore && !refresh) return;

    setState(() {
      _historyLoading = true;
      if (refresh) {
        _gameHistory.clear();
        _historyOffset = 0;
        _historyHasMore = true;
      }
    });

    try {
      final appModel = Provider.of<AppModel>(context, listen: false);
      final items = await appModel.apiClient.fetchGameHistory(
        userId: widget.userId,
        limit: _historyPageSize,
        offset: _historyOffset,
      );
      if (mounted) {
        setState(() {
          _gameHistory.addAll(items);
          _historyOffset += items.length;
          _historyHasMore = items.length == _historyPageSize;
        });
      }
    } catch (e) {
      debugPrint('Error loading game history: $e');
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  void _openReview(GameHistoryItem game) {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => GameReviewView(game: game)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rankName = RankSystem.getRankName(widget.elo);

    return SafeArea(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 860),
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFF0CB88),
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Jura',
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF5A3923),
                            border: Border.all(
                              color: const Color(0xFFF2D09B)
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                          child: const Icon(
                            CupertinoIcons.xmark,
                            color: Color(0xFFF7DEB1),
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Row(
                  children: [
                    RankedProfileAvatar(
                      name: widget.userName,
                      elo: widget.elo,
                      avatarUrl: widget.avatarUrl,
                      avatarSize: 72,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$rankName • ${widget.elo} ELO',
                            style: const TextStyle(
                              color: Color(0xFF5A3921),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(14, 2, 14, 8),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFFD6C1A1),
                  border: Border.all(
                    color: const Color(0xFF9B6D3A).withValues(alpha: 0.55),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ProfileTabButton(
                        label: 'Thống kê',
                        selected: _selectedTab == 0,
                        onTap: () {
                          setState(() => _selectedTab = 0);
                          _loadUserData();
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _ProfileTabButton(
                        label: 'Lịch sử',
                        selected: _selectedTab == 1,
                        onTap: () {
                          setState(() => _selectedTab = 1);
                          if (_gameHistory.isEmpty) _loadHistory();
                        },
                      ),
                    ),
                    if (_hasCapturedTab) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: _ProfileTabButton(
                          label: 'Quân cờ',
                          selected: _selectedTab == 2,
                          onTap: () {
                            setState(() => _selectedTab = 2);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: _loading && _selectedTab == 0
                    ? const Center(
                        child: CupertinoActivityIndicator(
                          color: Color(0xFF9A612E),
                        ),
                      )
                    : _selectedTab == 0
                        ? _buildStatsTab()
                        : _selectedTab == 2
                            ? _buildCapturedTab()
                            : _buildHistoryTab(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsTab() {
    if (_eloHistory == null || _eloHistory!.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có dữ liệu',
          style: TextStyle(
            color: Color(0xFF7E5A3A),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lịch sử ELO',
            style: TextStyle(
              color: Color(0xFF5A3921),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ..._eloHistory!.take(10).map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1E1C7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFBE945F).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      e.toString(),
                      style: const TextStyle(
                        color: Color(0xFF5A3921),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_gameHistory.isEmpty && _historyLoading) {
      return const Center(
        child: CupertinoActivityIndicator(color: Color(0xFF9A612E)),
      );
    }
    if (_gameHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('♟', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 10),
            const Text(
              'Chưa có ván đấu nào',
              style: TextStyle(
                color: Color(0xFF5A3921),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _loadHistory(refresh: true),
              child: const Text(
                'Tải lại',
                style: TextStyle(color: Color(0xFF9A612E)),
              ),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification &&
            n.metrics.pixels >= n.metrics.maxScrollExtent - 160) {
          _loadHistory();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        itemCount: _gameHistory.length + (_historyHasMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i == _gameHistory.length) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: CupertinoActivityIndicator(color: Color(0xFF9A612E)),
              ),
            );
          }
          final game = _gameHistory[i];
          return _ProfileHistoryRow(
            game: game,
            onTap: () => _openReview(game),
          );
        },
      ),
    );
  }

  Widget _buildCapturedTab() {
    final pieces = widget.capturedPieces ?? [];
    if (pieces.isEmpty) {
      return const Center(
        child: Text(
          'Chưa ăn quân nào',
          style: TextStyle(
            color: Color(0xFF7E5A3A),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    // Group by piece type
    final grouped = <ChessPieceType, int>{};
    for (final p in pieces) {
      grouped[p] = (grouped[p] ?? 0) + 1;
    }

    return Consumer<AppModel>(
      builder: (context, appModel, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Đã ăn ${pieces.length} quân',
                style: const TextStyle(
                  color: Color(0xFF5A3921),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: grouped.entries.map((entry) {
                  final typeName = pieceTypeToString(entry.key);
                  final assetPath =
                      'assets/images/pieces/${formatPieceTheme(appModel.pieceTheme)}/${typeName}_black.png';
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1E1C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFBE945F).withValues(alpha: 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          assetPath,
                          width: 40,
                          height: 40,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.extension_rounded,
                            size: 40,
                            color: Color(0xFF8B5A2B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            color:
                                const Color(0xFF9A612E).withValues(alpha: 0.18),
                            border: Border.all(
                              color: const Color(0xFF9A612E)
                                  .withValues(alpha: 0.42),
                            ),
                          ),
                          child: Text(
                            'x${entry.value}',
                            style: const TextStyle(
                              color: Color(0xFF5A3921),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileHistoryRow extends StatelessWidget {
  final GameHistoryItem game;
  final VoidCallback onTap;

  const _ProfileHistoryRow({required this.game, required this.onTap});

  Color get _resultColor {
    switch (game.myResult) {
      case 'win':
        return const Color(0xFF2D7C43);
      case 'loss':
        return const Color(0xFF9B3535);
      default:
        return const Color(0xFF7A6040);
    }
  }

  Color get _resultBg {
    switch (game.myResult) {
      case 'win':
        return const Color(0xFFD4EDD9);
      case 'loss':
        return const Color(0xFFEDD4D4);
      default:
        return const Color(0xFFE8DEC8);
    }
  }

  String get _resultLabel {
    switch (game.myResult) {
      case 'win':
        return 'Thắng';
      case 'loss':
        return 'Thua';
      default:
        return 'Hòa';
    }
  }

  String get _timeControlLabel {
    final tc = game.timeControl;
    if (tc.startsWith('bullet')) return '⚡ Bullet';
    if (tc.startsWith('blitz')) return '⏱ Blitz';
    if (tc.startsWith('rapid')) return '🕐 Rapid';
    if (tc.startsWith('classical')) return '♟ Classical';
    return tc;
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Hôm nay';
    if (diff.inDays == 1) return 'Hôm qua';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1E1C7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _resultColor.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            // Badge kết quả
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _resultBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _resultColor.withValues(alpha: 0.5)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _resultLabel,
                    style: TextStyle(
                      color: _resultColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    game.myColor == 'white' ? '♔' : '♚',
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Thông tin ván
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'vs ${game.opponentName}',
                    style: const TextStyle(
                      color: Color(0xFF3D2514),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        _timeControlLabel,
                        style: const TextStyle(
                          color: Color(0xFF7A5A3A),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(game.endedAt),
                        style: const TextStyle(
                          color: Color(0xFF9E7A55),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              color: Color(0xFFBE945F),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ProfileTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            fontSize: 16,
            fontWeight: FontWeight.w900,
            fontFamily: 'Jura',
          ),
        ),
      ),
    );
  }
}
