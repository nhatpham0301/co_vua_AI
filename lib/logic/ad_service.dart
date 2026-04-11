import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_logger.dart';

// ─── Ad Unit IDs ──────────────────────────────────────────────────────────────
// TODO: Replace test IDs with your real AdMob ad unit IDs before release.
const _kAndroidBannerId = 'ca-app-pub-3940256099942544/6300978111';
const _kIosBannerId = 'ca-app-pub-3940256099942544/2934735716';
const _kAndroidInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
const _kIosInterstitialId = 'ca-app-pub-3940256099942544/4411468910';

// ─── Ad Policy Config ─────────────────────────────────────────────────────────
/// Số lượng quảng cáo interstitial tối đa được preload và giữ trong hàng đợi.
const int kAdQueueMaxSize = 5;

// SharedPreferences keys
const _kPrefDateKey = 'ad_last_date_played'; // "yyyy-MM-dd"
const _kPrefCountKey = 'ad_daily_game_count'; // số ván hôm nay

/// Quản lý banner và interstitial ads — Singleton pattern.
///
/// Luồng mới:
///   1. Ván kết thúc → [onGameEnded] → theo dõi ngày, bật [_needsAd] nếu cần.
///   2. Chess view sau 1 giây → [showGameEndAd] → hiện ad ngay trong màn hình game.
///   3. Nút "Chơi lại" / "CHƠI" → [showAdBeforeGame] → chỉ là fallback nếu
///      ad chưa được hiện tại bước 2 (ví dụ: hàng đợi lúc đó trống).
class AdService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  AdService._();
  static final AdService instance = AdService._();

  // ── Ad Queue ───────────────────────────────────────────────────────────────
  final List<InterstitialAd> _adQueue = [];
  bool _isLoadingAd = false;

  // ── State ──────────────────────────────────────────────────────────────────
  /// True khi một ván đã kết thúc và cần hiện ad.
  bool _needsAd = false;

  // ── Dev flags ──────────────────────────────────────────────────────────────
  bool _devForceAd = false;
  bool _devSkipNextAd = false;

  String get _bannerId =>
      Platform.isAndroid ? _kAndroidBannerId : _kIosBannerId;

  String get _interstitialId =>
      Platform.isAndroid ? _kAndroidInterstitialId : _kIosInterstitialId;

  // ── Banner ──────────────────────────────────────────────────────────────────

  BannerAd createBannerAd(
      {BannerAdListener listener = const BannerAdListener()}) {
    return BannerAd(
      adUnitId: _bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: listener,
    )..load();
  }

  // ── Queue Management ────────────────────────────────────────────────────────

  /// Nạp quảng cáo vào hàng đợi cho đến khi đầy [kAdQueueMaxSize].
  void fillQueue() => _loadNextAdIfNeeded();

  void _loadNextAdIfNeeded() {
    if (_isLoadingAd || _adQueue.length >= kAdQueueMaxSize) return;
    _isLoadingAd = true;

    DevLogger.instance.log(
      DevLogCategory.ad,
      'Loading ad into queue (${_adQueue.length}/$kAdQueueMaxSize)...',
    );

    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _adQueue.add(ad);
          _isLoadingAd = false;
          DevLogger.instance.log(
            DevLogCategory.ad,
            'Ad loaded. Queue: ${_adQueue.length}/$kAdQueueMaxSize',
          );
          debugPrint(
              '[AdService] Ad loaded. Queue: ${_adQueue.length}/$kAdQueueMaxSize');
          _loadNextAdIfNeeded();
        },
        onAdFailedToLoad: (error) {
          _isLoadingAd = false;
          DevLogger.instance.log(
            DevLogCategory.ad,
            'Ad failed to load: $error. Queue: ${_adQueue.length}/$kAdQueueMaxSize',
          );
          debugPrint('[AdService] Ad failed to load: $error');
        },
      ),
    );
  }

  // ── Game End Tracking ──────────────────────────────────────────────────────

  /// Gọi khi một ván kết thúc. Theo dõi số ván hôm nay qua SharedPreferences
  /// và bật [_needsAd] nếu đã qua ván miễn phí đầu tiên trong ngày.
  Future<void> onGameEnded() async {
    if (_devForceAd) {
      _needsAd = true;
      _devForceAd = false;
      DevLogger.instance
          .log(DevLogCategory.ad, 'DEV: Ad bắt buộc — _needsAd = true');
      fillQueue();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    final lastDate = prefs.getString(_kPrefDateKey) ?? '';
    int gameCount;

    if (lastDate != today) {
      gameCount = 1;
      await prefs.setString(_kPrefDateKey, today);
    } else {
      gameCount = (prefs.getInt(_kPrefCountKey) ?? 0) + 1;
    }
    await prefs.setInt(_kPrefCountKey, gameCount);

    DevLogger.instance.log(
      DevLogCategory.ad,
      'Ván #$gameCount hôm nay | Queue: ${_adQueue.length}/$kAdQueueMaxSize',
    );

    if (gameCount == 1) {
      // Ván đầu tiên trong ngày — miễn ad
      DevLogger.instance.log(DevLogCategory.ad, 'Ván 1 hôm nay — không cần ad');
      fillQueue(); // preload cho ván sau
      return;
    }

    _needsAd = true;
    fillQueue();
    DevLogger.instance.log(
        DevLogCategory.ad, '_needsAd = true — sẽ hiện ad khi kết thúc game');
  }

  // ── Show Ad at Game End (called from chess_view after 1s) ─────────────────

  /// Hiện ad ngay tại màn hình kết thúc ván (được gọi tự động sau 1 giây).
  /// Không nhận callback — người dùng xem xong và tiếp tục tự trong app.
  Future<void> showGameEndAd(BuildContext context) async {
    if (!_needsAd) return;

    if (_devSkipNextAd) {
      _devSkipNextAd = false;
      _needsAd = false;
      DevLogger.instance.log(DevLogCategory.ad, 'DEV: Ad bị bỏ qua (devSkip)');
      return;
    }

    // Dev mode: hiện dialog giả lập
    if (DevLogger.instance.devModeEnabled && context.mounted) {
      _needsAd = false;
      DevLogger.instance
          .log(DevLogCategory.ad, 'DEV: Hiện interstitial giả lập (game end)');
      await _showDevSimulatedAd(context);
      DevLogger.instance.log(DevLogCategory.ad, 'DEV: Ad giả lập đóng');
      return;
    }

    if (_adQueue.isEmpty) {
      // Hàng đợi trống — giữ _needsAd = true để showAdBeforeGame làm fallback
      DevLogger.instance.log(
        DevLogCategory.ad,
        'Hàng đợi trống — giữ _needsAd để fallback trước ván kế',
      );
      fillQueue();
      return;
    }

    _needsAd = false;
    final ad = _adQueue.removeAt(0);
    fillQueue(); // nạp ngay ad thay thế

    DevLogger.instance.log(
      DevLogCategory.ad,
      'Hiện ad kết thúc game. Còn lại trong hàng đợi: ${_adQueue.length}/$kAdQueueMaxSize',
    );

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) {
        DevLogger.instance.log(DevLogCategory.ad, 'Ad đóng sau kết thúc ván');
        ad.dispose();
      },
      onAdFailedToShowFullScreenContent: (_, error) {
        DevLogger.instance.log(DevLogCategory.ad, 'Ad không hiện được: $error');
        debugPrint('[AdService] Ad failed to show: $error');
        ad.dispose();
        // Khôi phục để fallback
        _needsAd = true;
      },
    );

    await ad.show();
  }

  // ── Fallback: Show Ad Before Game (main menu "CHƠI" button) ───────────────

  /// Fallback cho nút "CHƠI" ở main menu. Chỉ hiện ad nếu [_needsAd] vẫn còn
  /// (tức ad tại game end chưa được hiện do hàng đợi trống lúc đó).
  Future<void> showAdBeforeGame(
    VoidCallback onComplete, {
    BuildContext? context,
  }) async {
    if (_devSkipNextAd) {
      _devSkipNextAd = false;
      _needsAd = false;
      DevLogger.instance.log(DevLogCategory.ad, 'DEV: Ad bị bỏ qua (devSkip)');
      onComplete();
      return;
    }

    if (!_needsAd) {
      onComplete();
      return;
    }

    _needsAd = false;

    // Dev mode
    if (DevLogger.instance.devModeEnabled &&
        context != null &&
        context.mounted) {
      DevLogger.instance
          .log(DevLogCategory.ad, 'DEV: Hiện interstitial giả lập (fallback)');
      await _showDevSimulatedAd(context);
      onComplete();
      return;
    }

    if (_adQueue.isEmpty) {
      DevLogger.instance
          .log(DevLogCategory.ad, 'Hàng đợi trống (fallback) — bỏ qua ad');
      debugPrint('[AdService] Queue empty — skipping ad.');
      onComplete();
      fillQueue();
      return;
    }

    final ad = _adQueue.removeAt(0);
    fillQueue();

    DevLogger.instance.log(
      DevLogCategory.ad,
      'Hiện ad fallback trước game. Queue còn: ${_adQueue.length}/$kAdQueueMaxSize',
    );

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) {
        DevLogger.instance
            .log(DevLogCategory.ad, 'Ad fallback đóng — tiếp tục game');
        ad.dispose();
        onComplete();
      },
      onAdFailedToShowFullScreenContent: (_, error) {
        DevLogger.instance
            .log(DevLogCategory.ad, 'Ad fallback thất bại: $error');
        debugPrint('[AdService] Ad failed to show: $error');
        ad.dispose();
        onComplete();
      },
    );

    await ad.show();
  }

  // ── Dev Helpers ───────────────────────────────────────────────────────────

  void devForceAdRequired() {
    _devForceAd = true;
    DevLogger.instance.log(DevLogCategory.ad, 'DEV: Ad bị force bắt buộc');
  }

  void devSkipAd() {
    _devSkipNextAd = true;
    DevLogger.instance.log(DevLogCategory.ad, 'DEV: Ad kế tiếp sẽ bị bỏ qua');
  }

  /// Đánh dấu ván đấu bị bỏ dở (restart hoặc exit khi chưa kết thúc).
  /// Đặt [_needsAd] = true ngay lập tức — sẽ được consume ở lần chơi tiếp theo.
  void markGameAbandoned() {
    _needsAd = true;
    DevLogger.instance
        .log(DevLogCategory.ad, 'Game bị bỏ dở — _needsAd = true');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _showDevSimulatedAd(BuildContext context) async {
    await showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('📢 Quảng cáo [DEV]'),
        content: const Text(
          'Giả lập quảng cáo interstitial.\n\n'
          'Trong môi trường production, quảng cáo thật từ AdMob sẽ xuất hiện ở đây.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('× Đóng quảng cáo'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }
}
