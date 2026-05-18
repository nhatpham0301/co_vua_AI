import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/api_models.dart';
import '../model/app_model.dart';
import 'game_review_view.dart';

class GameHistoryView extends StatefulWidget {
  const GameHistoryView({super.key});

  @override
  State<GameHistoryView> createState() => _GameHistoryViewState();
}

class _GameHistoryViewState extends State<GameHistoryView> {
  final List<GameHistoryItem> _games = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _pageSize = 20;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_isLoading) return;
    if (!_hasMore && !refresh) return;

    final appModel = Provider.of<AppModel>(context, listen: false);
    final userId = appModel.authService.user?.id;
    if (userId == null || userId.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      if (refresh) {
        _games.clear();
        _offset = 0;
        _hasMore = true;
      }
    });

    try {
      final items = await appModel.apiClient.fetchGameHistory(
        userId: userId,
        limit: _pageSize,
        offset: _offset,
      );
      setState(() {
        _games.addAll(items);
        _offset += items.length;
        _hasMore = items.length == _pageSize;
      });
    } catch (e) {
      setState(() => _error = 'Không tải được lịch sử: $e');
    } finally {
      setState(() => _isLoading = false);
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
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF1A140E),
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: Color(0xFF2A1F14),
        border: null,
        middle: Text(
          'Ván đấu của tôi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      child: SafeArea(
        child: _error != null
            ? _ErrorState(message: _error!, onRetry: () => _load(refresh: true))
            : _games.isEmpty && !_isLoading
                ? _EmptyState(onRefresh: () => _load(refresh: true))
                : NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n is ScrollEndNotification &&
                          n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                        _load();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _games.length + (_hasMore ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i == _games.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CupertinoActivityIndicator(color: Colors.white54),
                            ),
                          );
                        }
                        return _GameHistoryRow(
                          game: _games[i],
                          onTap: () => _openReview(_games[i]),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

class _GameHistoryRow extends StatelessWidget {
  final GameHistoryItem game;
  final VoidCallback onTap;

  const _GameHistoryRow({required this.game, required this.onTap});

  Color get _resultColor {
    switch (game.myResult) {
      case 'win':
        return const Color(0xFF4CAF50);
      case 'loss':
        return const Color(0xFFEF5350);
      default:
        return const Color(0xFF9E9E9E);
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
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF2A1F14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _resultColor.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Result badge
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _resultColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _resultColor.withValues(alpha: 0.6)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _resultLabel,
                    style: TextStyle(
                      color: _resultColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    game.myColor == 'white' ? '♔' : '♚',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Game info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'vs ${game.opponentName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _timeControlLabel,
                        style: const TextStyle(
                          color: Color(0xFFB0A090),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(game.endedAt),
                        style: const TextStyle(
                          color: Color(0xFF7A6A5A),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Arrow
            const Icon(
              CupertinoIcons.chevron_right,
              color: Color(0xFF7A6A5A),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.exclamationmark_circle,
                color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            CupertinoButton(
              color: const Color(0xFF8B5E3C),
              onPressed: onRetry,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('♟', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            const Text(
              'Chưa có ván đấu nào',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hãy chơi vài ván để xem lịch sử tại đây',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 20),
            CupertinoButton(
              onPressed: onRefresh,
              child: const Text(
                'Làm mới',
                style: TextStyle(color: Color(0xFFE8BE75)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
