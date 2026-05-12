import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../logic/dev_logger.dart';
import '../logic/experimental_api_client.dart';
import '../model/app_model.dart';
import 'chess_view.dart';
import 'components/main_menu_view/mm_background.dart';
import 'components/main_menu_view/mm_palette.dart';
import 'components/shared/app_dialog.dart';
import 'components/shared/bottom_padding.dart';

/// AI Level Test Screen (Level 1–10)
///
/// Displays buttons for each AI level for quick testing purposes.
/// Only available when user is logged in.
/// This screen helps test the game against each AI level quickly.
class AiLevelsTestView extends StatefulWidget {
  const AiLevelsTestView({Key? key}) : super(key: key);

  @override
  State<AiLevelsTestView> createState() => _AiLevelsTestViewState();
}

class _AiLevelsTestViewState extends State<AiLevelsTestView> {
  static const List<Map<String, dynamic>> aiLevels = [
    {
      'level': 1,
      'name': 'Level 1 - Rất dễ',
      'description': 'Minimax depth 1, chọn ngẫu nhiên',
      'engine': 'Minimax',
    },
    {
      'level': 2,
      'name': 'Level 2 - Dễ',
      'description': 'Minimax depth 2, random top 3',
      'engine': 'Minimax',
    },
    {
      'level': 3,
      'name': 'Level 3 - Dễ+',
      'description': 'Minimax depth 3',
      'engine': 'Minimax',
    },
    {
      'level': 4,
      'name': 'Level 4 - Trung bình-',
      'description': 'Minimax depth 4 + quiescence search',
      'engine': 'Minimax',
    },
    {
      'level': 5,
      'name': 'Level 5 - Trung bình',
      'description': 'Minimax depth 5',
      'engine': 'Minimax',
    },
    {
      'level': 6,
      'name': 'Level 6 - Trung bình+',
      'description': 'Minimax depth 6',
      'engine': 'Minimax',
    },
    {
      'level': 7,
      'name': 'Level 7 - Khó',
      'description': 'Stockfish Skill Level 5, 0.1s/nước',
      'engine': 'Stockfish',
    },
    {
      'level': 8,
      'name': 'Level 8 - Khó+',
      'description': 'Stockfish Skill Level 10, 0.3s/nước',
      'engine': 'Stockfish',
    },
    {
      'level': 9,
      'name': 'Level 9 - Rất khó',
      'description': 'Stockfish Skill Level 15, 0.5s/nước',
      'engine': 'Stockfish',
    },
    {
      'level': 10,
      'name': 'Level 10 - Mạnh nhất',
      'description': 'Stockfish Skill Level 20 (max), 1.0s/nước',
      'engine': 'Stockfish',
    },
  ];

  bool _isLoading = false;

  Future<T> _withAuthRetry<T>({
    required AppModel appModel,
    required String action,
    required Future<T> Function() execute,
  }) async {
    try {
      return await execute();
    } on ApiException catch (e) {
      if (e.statusCode != 401) rethrow;
      DevLogger.instance.log(
        DevLogCategory.http,
        '[AI_TEST] $action unauthorized (401) -> refreshing token',
      );
      final refreshed = await appModel.authService.refreshTokens();
      if (!refreshed) {
        DevLogger.instance.log(
          DevLogCategory.http,
          '[AI_TEST] $action refresh failed -> need re-login',
        );
        rethrow;
      }
      DevLogger.instance.log(
        DevLogCategory.http,
        '[AI_TEST] $action retry after refresh',
      );
      return execute();
    }
  }

  Future<void> _startAiGame(
    BuildContext context,
    AppModel appModel,
    int level,
  ) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      DevLogger.instance.log(
        DevLogCategory.game,
        '[AI_TEST] Starting game with AI Level $level, player color: white',
      );

      final gameData = await _withAuthRetry(
        appModel: appModel,
        action: 'createAiGame',
        execute: () => appModel.apiClient.createAiGame(
          aiLevel: level,
          color: 'white',
          timeControl: 'rapid_15',
          moveTimeLimit: 0,
        ),
      );

      if (!mounted) return;

      final gameId = gameData['id']?.toString() ?? '';
      if (gameId.isEmpty) {
        showAppDialog<void>(
          context: context,
          title: 'Lỗi',
          message: 'Không thể tạo game. Vui lòng thử lại.',
          actions: const [AppDialogAction(label: 'Đóng')],
        );
        setState(() => _isLoading = false);
        return;
      }

      // Apply the game snapshot and start online tracking
      appModel.applyJoinGameResponse(gameData);
      await appModel.startOnlineEventTracking(gameId);

      if (!mounted) return;

      // Navigate to chess view
      await Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => ChessView(appModel)),
      );
    } catch (e) {
      if (!mounted) return;
      DevLogger.instance.log(
        DevLogCategory.http,
        '[AI_TEST] Error creating game: $e',
      );
      showAppDialog<void>(
        context: context,
        title: 'Lỗi kết nối',
        message: e.toString(),
        actions: const [AppDialogAction(label: 'Đóng')],
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [bgMid, bgDark],
              ),
            ),
          ),
          const BoardBackground(),
          const CornerKnots(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top),
                // Header with back button
                Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.back),
                          const SizedBox(width: 8),
                          Text(l.back),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Chọn chế độ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF4D293),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(width: 48), // Spacer for alignment
                  ],
                ),
                const SizedBox(height: 12),
                // AI Level buttons grid
                Expanded(
                  child: CupertinoScrollbar(
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      physics: const ClampingScrollPhysics(),
                      itemCount: aiLevels.length,
                      itemBuilder: (context, index) {
                        final levelData = aiLevels[index];
                        return Consumer<AppModel>(
                          builder: (context, appModel, _) => _AiLevelCard(
                            levelData: levelData,
                            isLoading: _isLoading,
                            onPressed: () => _startAiGame(
                              context,
                              appModel,
                              levelData['level'] as int,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                BottomPadding(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiLevelCard extends StatelessWidget {
  final Map<String, dynamic> levelData;
  final bool isLoading;
  final VoidCallback onPressed;

  const _AiLevelCard({
    required this.levelData,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final level = levelData['level'] as int;
    final name = levelData['name'] as String;
    final description = levelData['description'] as String;
    final engine = levelData['engine'] as String;

    final isStockfish = engine == 'Stockfish';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: GestureDetector(
        onTap: isLoading ? null : onPressed,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                isStockfish
                    ? const Color(0xFF1e3a5f).withValues(alpha: 0.5)
                    : const Color(0xFF2d3a2d).withValues(alpha: 0.5),
                bgCard.withValues(alpha: 0.4),
              ],
            ),
            border: Border.all(
              color: isStockfish
                  ? const Color(0xFF00a8ff).withValues(alpha: 0.4)
                  : const Color(0xFFb8860b).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Level circle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isStockfish
                      ? const Color(0xFF00a8ff).withValues(alpha: 0.15)
                      : const Color(0xFFDAA520).withValues(alpha: 0.15),
                  border: Border.all(
                    color: isStockfish
                        ? const Color(0xFF00a8ff).withValues(alpha: 0.6)
                        : const Color(0xFFDAA520).withValues(alpha: 0.6),
                  ),
                ),
                child: Center(
                  child: Text(
                    '$level',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isStockfish
                          ? const Color(0xFF00a8ff)
                          : const Color(0xFFDAA520),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF4D293),
                      ),
                    ),
                    // const SizedBox(height: 4),
                    // Text(
                    //   description,
                    //   style: TextStyle(
                    //     fontSize: 12,
                    //     color: Colors.white.withValues(alpha: 0.5),
                    //   ),
                    //   maxLines: 2,
                    //   overflow: TextOverflow.ellipsis,
                    // ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Start button
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isStockfish
                      ? const Color(0xFF00a8ff).withValues(alpha: 0.2)
                      : const Color(0xFFDAA520).withValues(alpha: 0.2),
                  border: Border.all(
                    color: isStockfish
                        ? const Color(0xFF00a8ff).withValues(alpha: 0.5)
                        : const Color(0xFFDAA520).withValues(alpha: 0.5),
                  ),
                ),
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CupertinoActivityIndicator(),
                        )
                      : Icon(
                          CupertinoIcons.play_fill,
                          size: 16,
                          color: isStockfish
                              ? const Color(0xFF00a8ff)
                              : const Color(0xFFDAA520),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
