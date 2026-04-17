import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../logic/rank_system.dart';
import '../../../model/app_model.dart';

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
    final rankName = RankSystem.getRankName(widget.elo);
    final rankBadgePath = RankSystem.getRankBadgePath(widget.elo);

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
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFF1C57D),
                          width: 2.5,
                        ),
                        color: const Color(0xFF4D2F1B),
                      ),
                      child: widget.avatarUrl != null &&
                              widget.avatarUrl!.isNotEmpty
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: widget.avatarUrl!,
                                fit: BoxFit.cover,
                                placeholder: (ctx, url) => const Center(
                                  child: CupertinoActivityIndicator(
                                    color: Color(0xFFF2CA84),
                                  ),
                                ),
                                errorWidget: (ctx, url, err) =>
                                    _buildAvatarPlaceholder(),
                              ),
                            )
                          : _buildAvatarPlaceholder(),
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
                          const SizedBox(height: 6),
                          Image.asset(
                            rankBadgePath,
                            width: 74,
                            height: 34,
                            fit: BoxFit.contain,
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
                          _loadUserData();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CupertinoActivityIndicator(
                          color: Color(0xFF9A612E),
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
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      color: const Color(0xFF6B4528),
      child: Center(
        child: Text(
          widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Color(0xFFF7DEB0),
            fontSize: 24,
            fontWeight: FontWeight.bold,
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
    if (_eloHistory == null || _eloHistory!.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có ván nào',
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
        children: _eloHistory!.take(10).map((game) {
          final isWin = (game['result'] as String?)?.contains('win') ?? false;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1E1C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (isWin
                          ? const Color(0xFF3E8A50)
                          : const Color(0xFF9B4444))
                      .withValues(alpha: 0.45),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isWin ? 'Thắng' : 'Thua',
                    style: TextStyle(
                      color: isWin
                          ? const Color(0xFF2D7C43)
                          : const Color(0xFF8E3535),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    game.toString(),
                    style: const TextStyle(
                      color: Color(0xFF6D4B2E),
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
