import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../logic/dev_logger.dart';
import '../model/app_model.dart';
import 'components/main_menu_view/mm_palette.dart';

// ─── Category tab labels ──────────────────────────────────────────────────────
const _kTabs = ['ALL', 'GAME', 'HTTP', 'AD', 'SYS'];

const _kCategoryMap = {
  'GAME': DevLogCategory.game,
  'HTTP': DevLogCategory.http,
  'AD': DevLogCategory.ad,
  'SYS': DevLogCategory.system,
};

const _kCategoryColors = {
  DevLogCategory.game: Color(0xFF4FC3F7),
  DevLogCategory.http: Color(0xFF81C784),
  DevLogCategory.ad: Color(0xFFFFB74D),
  DevLogCategory.system: Color(0xFFCE93D8),
};

// ─── DeveloperView ────────────────────────────────────────────────────────────
class DeveloperView extends StatefulWidget {
  const DeveloperView({super.key});

  @override
  State<DeveloperView> createState() => _DeveloperViewState();
}

class _DeveloperViewState extends State<DeveloperView> {
  int _tabIndex = 0;
  bool _menuCollapsed = false;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              onBack: () => Navigator.pop(context),
              menuCollapsed: _menuCollapsed,
              onToggleMenu: () {
                setState(() => _menuCollapsed = !_menuCollapsed);
              },
            ),
            if (!_menuCollapsed) ...[
              _SimulationPanel(),
              _AdPanel(),
              _ApiPanel(),
            ],
            _TabBar(
              selectedIndex: _tabIndex,
              onChanged: (i) => setState(() => _tabIndex = i),
            ),
            Expanded(
              child: _LogPanel(
                filterTab: _kTabs[_tabIndex],
                scrollController: _scrollCtrl,
                onNewEntry: _scrollToBottom,
              ),
            ),
            SizedBox(height: bottomPad),
          ],
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final VoidCallback onBack;
  final bool menuCollapsed;
  final VoidCallback onToggleMenu;

  const _Header({
    required this.onBack,
    required this.menuCollapsed,
    required this.onToggleMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onBack,
            child: const Icon(CupertinoIcons.back, color: Colors.white70),
          ),
          const SizedBox(width: 8),
          const Text(
            '🛠 Developer Mode',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onToggleMenu,
            child: Icon(
              menuCollapsed
                  ? CupertinoIcons.chevron_down_circle
                  : CupertinoIcons.chevron_up_circle,
              color: Colors.white70,
              size: 22,
            ),
          ),
          const SizedBox(width: 8),
          ListenableBuilder(
            listenable: DevLogger.instance,
            builder: (_, __) => CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                DevLogger.instance.clear();
                HapticFeedback.lightImpact();
              },
              child:
                  const Icon(CupertinoIcons.trash, color: Colors.red, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Simulation Panel ─────────────────────────────────────────────────────────
class _SimulationPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appModel = Provider.of<AppModel>(context, listen: false);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('🎭 Giả lập kết quả trận'),
          const SizedBox(height: 8),
          Row(
            children: [
              _DevChip(
                label: '🏆 Thắng',
                color: const Color(0xFF4CAF50),
                onTap: () {
                  appModel.devSimulateWin();
                  HapticFeedback.mediumImpact();
                  _toast(context, 'Giả lập: Người chơi THẮNG');
                },
              ),
              const SizedBox(width: 8),
              _DevChip(
                label: '💀 Thua',
                color: const Color(0xFFF44336),
                onTap: () {
                  appModel.devSimulateLose();
                  HapticFeedback.mediumImpact();
                  _toast(context, 'Giả lập: Người chơi THUA');
                },
              ),
              const SizedBox(width: 8),
              _DevChip(
                label: '🤝 Hoà',
                color: const Color(0xFFFF9800),
                onTap: () {
                  appModel.devSimulateDraw();
                  HapticFeedback.mediumImpact();
                  _toast(context, 'Giả lập: HÒA');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Ad Panel ─────────────────────────────────────────────────────────────────
class _AdPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appModel = Provider.of<AppModel>(context, listen: false);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('📢 Quảng cáo'),
          const SizedBox(height: 8),
          Row(
            children: [
              _DevChip(
                label: '⏭ Bỏ qua Ad',
                color: const Color(0xFF607D8B),
                onTap: () {
                  appModel.devSkipAd();
                  HapticFeedback.lightImpact();
                  _toast(context, 'Đã xoá yêu cầu xem quảng cáo');
                },
              ),
              const SizedBox(width: 8),
              _DevChip(
                label: '🔔 Force Ad',
                color: const Color(0xFFFFB300),
                onTap: () {
                  appModel.devTriggerAd();
                  HapticFeedback.lightImpact();
                  _toast(context, 'Đã bật yêu cầu xem quảng cáo');
                },
              ),
              const SizedBox(width: 8),
              _DevChip(
                label: '▶ Test Ad Now',
                color: const Color(0xFFE040FB),
                onTap: () {
                  appModel.devTriggerAd();
                  appModel.adService.showAdBeforeGame(
                    () => _toast(context, 'Ad xong — tiếp tục game'),
                    context: context,
                  );
                  HapticFeedback.lightImpact();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── API Panel ───────────────────────────────────────────────────────────────
class _ApiPanel extends StatefulWidget {
  @override
  State<_ApiPanel> createState() => _ApiPanelState();
}

class _ApiPanelState extends State<_ApiPanel> {
  late final TextEditingController _baseUrlCtrl;
  final TextEditingController _gameIdCtrl = TextEditingController();
  final TextEditingController _userIdCtrl = TextEditingController();
  final TextEditingController _fromCtrl = TextEditingController(text: 'e2');
  final TextEditingController _toCtrl = TextEditingController(text: 'e4');

  @override
  void initState() {
    super.initState();
    final appModel = Provider.of<AppModel>(context, listen: false);
    _baseUrlCtrl = TextEditingController(text: appModel.apiBaseUrl);
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    _gameIdCtrl.dispose();
    _userIdCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appModel = Provider.of<AppModel>(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('🌐 API thử nghiệm'),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _baseUrlCtrl,
            placeholder: 'Base URL (vd: http://localhost:3000)',
            style: const TextStyle(color: Colors.white),
            placeholderStyle: const TextStyle(color: Colors.white38),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DevChip(
                label: '💾 Lưu URL',
                color: const Color(0xFF26C6DA),
                onTap: () async {
                  await appModel.setApiBaseUrl(_baseUrlCtrl.text);
                  _toast(context, 'Base URL: ${appModel.apiBaseUrl}');
                },
              ),
              _DevChip(
                label: '🏠 Test Home',
                color: const Color(0xFF66BB6A),
                onTap: () async {
                  await appModel.fetchHomeOverviewPreview();
                  if (appModel.apiLastError != null) {
                    _toast(context, 'Lỗi: ${appModel.apiLastError}');
                  } else {
                    final mode = appModel.homeOverviewSnapshot?.authMode;
                    _toast(context, 'Home OK | auth=$mode');
                  }
                },
              ),
              _DevChip(
                label: '📺 Test Live',
                color: const Color(0xFF7E57C2),
                onTap: () async {
                  await appModel.fetchLiveMatchesPreview();
                  if (appModel.apiLastError != null) {
                    _toast(context, 'Lỗi: ${appModel.apiLastError}');
                  } else {
                    final count = appModel.liveMatchesSnapshot?.items.length;
                    _toast(context, 'Live OK | items=$count');
                  }
                },
              ),
              _DevChip(
                label: '📢 Test Ads',
                color: const Color(0xFFFFA726),
                onTap: () async {
                  await appModel.fetchMonetizationConfigPreview();
                  if (appModel.apiLastError != null) {
                    _toast(context, 'Lỗi: ${appModel.apiLastError}');
                  } else {
                    final queue = appModel.monetizationConfigSnapshot
                        ?.interstitial.preloadQueueTarget;
                    _toast(context, 'Ads config OK | queue=$queue');
                  }
                },
              ),
              _DevChip(
                label: '⚡ Test QuickPlay',
                color: const Color(0xFFEF5350),
                onTap: () async {
                  await appModel.quickPlayPreview();
                  if (appModel.apiLastError != null) {
                    _toast(context, 'Lỗi: ${appModel.apiLastError}');
                  } else {
                    final mode = appModel.quickPlaySnapshot?.mode;
                    _toast(context, 'QuickPlay OK | mode=$mode');
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            appModel.apiBusy
                ? 'Đang gọi API...'
                : 'BaseURL hiện tại: ${appModel.apiBaseUrl}',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 10),
          const _SectionLabel('🧩 Online persistence test'),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _gameIdCtrl,
            placeholder: 'gameId',
            style: const TextStyle(color: Colors.white),
            placeholderStyle: const TextStyle(color: Colors.white38),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: _fromCtrl,
                  placeholder: 'from',
                  style: const TextStyle(color: Colors.white),
                  placeholderStyle: const TextStyle(color: Colors.white38),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CupertinoTextField(
                  controller: _toCtrl,
                  placeholder: 'to',
                  style: const TextStyle(color: Colors.white),
                  placeholderStyle: const TextStyle(color: Colors.white38),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _userIdCtrl,
            placeholder: 'userId (for /users/:id/games)',
            style: const TextStyle(color: Colors.white),
            placeholderStyle: const TextStyle(color: Colors.white38),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DevChip(
                label: '🎯 Test Game Snapshot',
                color: const Color(0xFF29B6F6),
                onTap: () async {
                  final gameId = _gameIdCtrl.text.trim();
                  if (gameId.isEmpty) {
                    _toast(context, 'Nhập gameId trước');
                    return;
                  }
                  await appModel.fetchOnlineGameSnapshotPreview(gameId);
                  if (appModel.apiLastError != null) {
                    _toast(context, 'Lỗi: ${appModel.apiLastError}');
                  } else {
                    _toast(
                      context,
                      'Snapshot OK | status=${appModel.onlineGameSnapshot?.status}',
                    );
                  }
                },
              ),
              _DevChip(
                label: '📜 Test Game Moves',
                color: const Color(0xFFAB47BC),
                onTap: () async {
                  final gameId = _gameIdCtrl.text.trim();
                  if (gameId.isEmpty) {
                    _toast(context, 'Nhập gameId trước');
                    return;
                  }
                  await appModel.fetchOnlineGameMovesPreview(gameId);
                  if (appModel.apiLastError != null) {
                    _toast(context, 'Lỗi: ${appModel.apiLastError}');
                  } else {
                    _toast(
                      context,
                      'Moves OK | count=${appModel.onlineMoveHistory.length}',
                    );
                  }
                },
              ),
              _DevChip(
                label: '♟️ Test Submit Move',
                color: const Color(0xFFFF7043),
                onTap: () async {
                  final gameId = _gameIdCtrl.text.trim();
                  if (gameId.isEmpty) {
                    _toast(context, 'Nhập gameId trước');
                    return;
                  }
                  await appModel.submitOnlineMovePreview(
                    gameId: gameId,
                    from: _fromCtrl.text.trim(),
                    to: _toCtrl.text.trim(),
                  );
                  if (appModel.apiLastError != null) {
                    _toast(context, 'Lỗi: ${appModel.apiLastError}');
                  } else {
                    _toast(
                      context,
                      'Submit OK | type=${appModel.onlineMoveSubmitSnapshot?.type}',
                    );
                  }
                },
              ),
              _DevChip(
                label: '👤 Test User Games',
                color: const Color(0xFF66BB6A),
                onTap: () async {
                  final userId = _userIdCtrl.text.trim();
                  if (userId.isEmpty) {
                    _toast(context, 'Nhập userId trước');
                    return;
                  }
                  await appModel.fetchUserGamesPreview(userId);
                  if (appModel.apiLastError != null) {
                    _toast(context, 'Lỗi: ${appModel.apiLastError}');
                  } else {
                    final games = appModel.onlineUserGamesSnapshot?['games'];
                    final count = games is List ? games.length : 0;
                    _toast(context, 'User games OK | count=$count');
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Tab Bar ──────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  const _TabBar({required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      color: Colors.black.withValues(alpha: 0.3),
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _kTabs[i],
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Log Panel ────────────────────────────────────────────────────────────────
class _LogPanel extends StatelessWidget {
  final String filterTab;
  final ScrollController scrollController;
  final VoidCallback onNewEntry;

  const _LogPanel({
    required this.filterTab,
    required this.scrollController,
    required this.onNewEntry,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DevLogger.instance,
      builder: (_, __) {
        final allEntries = DevLogger.instance.entries;
        final List<DevLogEntry> filtered;

        if (filterTab == 'ALL') {
          filtered = allEntries.toList();
        } else {
          final cat = _kCategoryMap[filterTab];
          filtered = allEntries.where((e) => e.category == cat).toList();
        }

        // Auto-scroll when new entries arrive
        onNewEntry();

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              'Chưa có log nào.',
              style: TextStyle(color: Colors.white24, fontSize: 13),
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          itemCount: filtered.length,
          itemBuilder: (_, i) => _LogRow(entry: filtered[i]),
        );
      },
    );
  }
}

// ─── Log Row ──────────────────────────────────────────────────────────────────
class _LogRow extends StatelessWidget {
  final DevLogEntry entry;
  const _LogRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = _kCategoryColors[entry.category] ?? Colors.white60;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time
          Text(
            entry.timeLabel,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 6),
          // Category badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
            ),
            child: Text(
              entry.categoryLabel,
              style: TextStyle(
                  color: color, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 6),
          // Message
          Expanded(
            child: Text(
              entry.message,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            color: Colors.white54, fontSize: 11, letterSpacing: 0.5),
      );
}

class _DevChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _DevChip(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.2),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

void _toast(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      bottom: 80,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F30),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 2), entry.remove);
}
