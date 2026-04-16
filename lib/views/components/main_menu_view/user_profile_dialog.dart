import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../logic/rank_system.dart';
import '../../../model/app_model.dart';
import 'mm_palette.dart';

class UserProfileDialog extends StatefulWidget {
  final String userId;
  final String userName;
  final String? avatarUrl;
  final int elo;

  const UserProfileDialog({
    super.key,
    required this.userId,
    required this.userName,
    this.avatarUrl,
    required this.elo,
  });

  @override
  State<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<UserProfileDialog> {
  int _selectedTab = 0; // 0 = Stats, 1 = History
  List<dynamic>? _eloHistory;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final appModel = Provider.of<AppModel>(context, listen: false);
      final apiClient = appModel.apiClient;

      if (_selectedTab == 0) {
        // Load ELO history for stats
        final history = await apiClient.fetchUserEloHistory(widget.userId);
        if (mounted) {
          setState(() => _eloHistory = history);
        }
      } else {
        // Load game history
        final games = await apiClient.fetchUserGames(
          userId: widget.userId,
          limit: 20,
        );
        if (mounted) {
          final gamesList = (games['games'] as List?)?.toList() ?? [];
          setState(() => _eloHistory = gamesList);
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final rankName = RankSystem.getRankName(widget.elo);
    final rankBadgePath = RankSystem.getRankBadgePath(widget.elo);

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: 0.85,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF09152A),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                // Header with close button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Expanded(child: Container()),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: const Size(30, 30),
                        onPressed: () => Navigator.pop(context),
                        child: const Icon(CupertinoIcons.xmark,
                            color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0x22FFFFFF)),
                // Profile info section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Avatar + Username + Rank
                      Row(
                        children: [
                          // Avatar
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.yellow.withValues(alpha: 0.6),
                                width: 2,
                              ),
                              color: Colors.black.withValues(alpha: 0.3),
                            ),
                            child: widget.avatarUrl != null &&
                                    widget.avatarUrl!.isNotEmpty
                                ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: widget.avatarUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (ctx, url) => const Center(
                                        child: CupertinoActivityIndicator(
                                          color: Colors.white30,
                                        ),
                                      ),
                                      errorWidget: (ctx, url, err) =>
                                          _buildAvatarPlaceholder(),
                                    ),
                                  )
                                : _buildAvatarPlaceholder(),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.userName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${rankName} • ${widget.elo} ELO',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Rank badge
                                Image.asset(
                                  rankBadgePath,
                                  width: 60,
                                  height: 30,
                                  fit: BoxFit.contain,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0x22FFFFFF)),
                // Tabs
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedTab = 0);
                            _loadUserData();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _selectedTab == 0
                                      ? primaryLight
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              l.settingsTooltip,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _selectedTab == 0
                                    ? primaryLight
                                    : Colors.white.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedTab = 1);
                            _loadUserData();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _selectedTab == 1
                                      ? primaryLight
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              'Lịch sử',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _selectedTab == 1
                                    ? primaryLight
                                    : Colors.white.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Tab content
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CupertinoActivityIndicator(
                            color: primaryLight,
                          ),
                        )
                      : _selectedTab == 0
                          ? _buildStatsTab()
                          : _buildHistoryTab(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Text(
          widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsTab() {
    if (_eloHistory == null || _eloHistory!.isEmpty) {
      return Center(
        child: Text(
          'Chưa có dữ liệu',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lịch sử ELO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ..._eloHistory!.take(10).map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      e.toString(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
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
    if (_eloHistory == null || _eloHistory!.isEmpty) {
      return Center(
        child: Text(
          'Chưa có ván nào',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _eloHistory!.take(10).map((game) {
          final isWin = (game['result'] as String?)?.contains('win') ?? false;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isWin
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (isWin ? Colors.green : Colors.red)
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isWin ? '✅ Thắng' : '❌ Thua',
                    style: TextStyle(
                      color: isWin ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    game.toString(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
