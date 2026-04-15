import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_logger.dart';

// ─── Ad Unit IDs ──────────────────────────────────────────────────────────────
// Ad IDs are read from env only (assets/env/config.env).

// ─── Ad Policy Config ─────────────────────────────────────────────────────────
/// Số lượng quảng cáo interstitial tối đa được preload và giữ trong hàng đợi.
const int kAdQueueMaxSize = 3;

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
  static const String _testAndroidBannerId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testIosBannerId =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _testAndroidInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testIosInterstitialId =
      'ca-app-pub-3940256099942544/4411468910';

  // ── Singleton ──────────────────────────────────────────────────────────────
  AdService._();
  static final AdService instance = AdService._();

  // ── Test device IDs ────────────────────────────────────────────────────────
  // 'GADSimulatorID' covers iOS simulator; Android emulators are auto-detected
  // when this list is passed to RequestConfiguration.
  // Add physical device IDs here (printed in logcat on first ad request).
  List<String> get testDeviceIds => const [
        'GADSimulatorID', // iOS Simulator
        // Add your physical test device IDs below, e.g.:
        // 'ABCDEF012345...',
      ];

  // ── Ad Queue ───────────────────────────────────────────────────────────────
  final List<InterstitialAd> _adQueue = [];
  bool _isLoadingAd = false;
  Timer? _retryLoadTimer;
  int _retryAttempt = 0;

  // ── SDK init guard ─────────────────────────────────────────────────────────
  bool _sdkReady = false;
  Completer<void>? _initCompleter;

  /// Call once after MobileAds.instance.initialize() completes.
  void markSdkReady() {
    _sdkReady = true;
    _initCompleter?.complete();
    _initCompleter = null;
    DevLogger.instance.log(DevLogCategory.ad, 'AdMob SDK ready');
  }

  /// Await this before any ad operation to ensure the SDK is initialised.
  Future<void> ensureInitialized() {
    if (_sdkReady) return Future.value();
    _initCompleter ??= Completer<void>();
    return _initCompleter!.future;
  }

  bool get sdkReady => _sdkReady;

  // ── State ──────────────────────────────────────────────────────────────────
  /// True khi một ván đã kết thúc và cần hiện ad.
  bool _needsAd = false;
  bool get needsAd => _needsAd;
  int get queueSize => _adQueue.length;
  bool get isLoadingAd => _isLoadingAd;

  // ── Dev flags ──────────────────────────────────────────────────────────────
  bool _devForceAd = false;
  bool _devSkipNextAd = false;

  String get _androidBannerId =>
      _envOrDefault('ADMOB_ANDROID_BANNER_ID', _testAndroidBannerId);

  String get _iosBannerId =>
      _envOrDefault('ADMOB_IOS_BANNER_ID', _testIosBannerId);

  String get _androidInterstitialId => _envOrDefault(
      'ADMOB_ANDROID_INTERSTITIAL_ID', _testAndroidInterstitialId);

  String get _iosInterstitialId =>
      _envOrDefault('ADMOB_IOS_INTERSTITIAL_ID', _testIosInterstitialId);

  String get _bannerId => Platform.isAndroid ? _androidBannerId : _iosBannerId;

  String get _interstitialId =>
      Platform.isAndroid ? _androidInterstitialId : _iosInterstitialId;

  String _envOrDefault(String key, String fallback) {
    final value = dotenv.env[key]?.trim();
    if (value == null || value.isEmpty) {
      DevLogger.instance.log(
        DevLogCategory.ad,
        'Missing env key: $key. Using test ad unit id as fallback.',
      );
      return fallback;
    }
    return value;
  }

  // ── Banner ──────────────────────────────────────────────────────────────────

  BannerAd? createBannerAd(
      {BannerAdListener listener = const BannerAdListener()}) {
    if (!_sdkReady) {
      DevLogger.instance.log(
        DevLogCategory.ad,
        'SDK not ready — skipping banner creation',
      );
      return null;
    }
    return BannerAd(
      adUnitId: _bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: listener,
    )..load();
  }

  // ── Queue Management ────────────────────────────────────────────────────────

  /// Nạp quảng cáo vào hàng đợi cho đến khi đầy [kAdQueueMaxSize].
  void fillQueue() {
    if (!_sdkReady) {
      DevLogger.instance.log(
        DevLogCategory.ad,
        'SDK not ready — deferring fillQueue',
      );
      return;
    }
    _loadNextAdIfNeeded();
  }

  void _loadNextAdIfNeeded() {
    _retryLoadTimer?.cancel();
    _retryLoadTimer = null;
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
          _retryAttempt = 0;
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
          _scheduleRetryAfterLoadFailure(error);
        },
      ),
    );
  }

  static const int _kMaxRetryAttempts = 5;

  void _scheduleRetryAfterLoadFailure(LoadAdError error) {
    if (_adQueue.length >= kAdQueueMaxSize || _retryLoadTimer != null) return;

    _retryAttempt++;
    if (_retryAttempt > _kMaxRetryAttempts) {
      DevLogger.instance.log(
        DevLogCategory.ad,
        'Max retry attempts ($_kMaxRetryAttempts) reached — stop retrying',
      );
      return;
    }

    final seconds = switch (error.code) {
      3 => (_retryAttempt * 5).clamp(5, 30),
      _ => (_retryAttempt * 3).clamp(3, 20),
    };

    DevLogger.instance.log(
      DevLogCategory.ad,
      'Retry interstitial load in ${seconds}s (attempt $_retryAttempt, code ${error.code})',
    );

    _retryLoadTimer = Timer(Duration(seconds: seconds), () {
      _retryLoadTimer = null;
      fillQueue();
    });
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
  /// Trả về true nếu ad đã được hiển thị/đóng thành công.
  Future<bool> showGameEndAd(BuildContext context) async {
    if (!_needsAd) return false;
    await ensureInitialized();

    if (_devSkipNextAd) {
      _devSkipNextAd = false;
      _needsAd = false;
      DevLogger.instance.log(DevLogCategory.ad, 'DEV: Ad bị bỏ qua (devSkip)');
      return false;
    }

    // Dev mode: hiện dialog giả lập
    if (DevLogger.instance.devModeEnabled && context.mounted) {
      _needsAd = false;
      DevLogger.instance
          .log(DevLogCategory.ad, 'DEV: Hiện interstitial giả lập (game end)');
      await _showDevSimulatedAd(context);
      DevLogger.instance.log(DevLogCategory.ad, 'DEV: Ad giả lập đóng');
      return true;
    }

    if (_adQueue.isEmpty) {
      // Hàng đợi trống — giữ _needsAd = true để showAdBeforeGame làm fallback
      DevLogger.instance.log(
        DevLogCategory.ad,
        'Hàng đợi trống — giữ _needsAd để fallback trước ván kế',
      );
      fillQueue();
      return false;
    }

    _needsAd = false;
    final ad = _adQueue.removeAt(0);
    fillQueue(); // nạp ngay ad thay thế

    DevLogger.instance.log(
      DevLogCategory.ad,
      'Hiện ad kết thúc game. Còn lại trong hàng đợi: ${_adQueue.length}/$kAdQueueMaxSize',
    );

    final result = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) {
        DevLogger.instance.log(DevLogCategory.ad, 'Ad đóng sau kết thúc ván');
        ad.dispose();
        if (!result.isCompleted) result.complete(true);
      },
      onAdFailedToShowFullScreenContent: (_, error) {
        DevLogger.instance.log(DevLogCategory.ad, 'Ad không hiện được: $error');
        debugPrint('[AdService] Ad failed to show: $error');
        ad.dispose();
        // Khôi phục để fallback
        _needsAd = true;
        if (!result.isCompleted) result.complete(false);
      },
    );

    await ad.show();
    return result.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        DevLogger.instance.log(
          DevLogCategory.ad,
          'Timeout chờ callback đóng ad kết thúc game',
        );
        return false;
      },
    );
  }

  // ── Fallback: Show Ad Before Game (main menu "CHƠI" button) ───────────────

  /// Fallback cho nút "CHƠI" ở main menu. Chỉ hiện ad nếu [_needsAd] vẫn còn
  /// (tức ad tại game end chưa được hiện do hàng đợi trống lúc đó).
  Future<void> showAdBeforeGame(
    FutureOr<void> Function() onComplete, {
    BuildContext? context,
  }) async {
    if (_devSkipNextAd) {
      _devSkipNextAd = false;
      _needsAd = false;
      DevLogger.instance.log(DevLogCategory.ad, 'DEV: Ad bị bỏ qua (devSkip)');
      await onComplete();
      return;
    }

    if (!_needsAd) {
      await onComplete();
      return;
    }

    await ensureInitialized();

    // Dev mode
    if (DevLogger.instance.devModeEnabled &&
        context != null &&
        context.mounted) {
      _needsAd = false;
      DevLogger.instance
          .log(DevLogCategory.ad, 'DEV: Hiện interstitial giả lập (fallback)');
      await _showDevSimulatedAd(context);
      await onComplete();
      return;
    }

    if (_adQueue.isEmpty) {
      DevLogger.instance.log(
          DevLogCategory.ad, 'Hàng đợi trống (fallback) — sẽ thử lại lượt sau');
      debugPrint('[AdService] Queue empty — keep pending ad requirement.');
      await onComplete();
      fillQueue();
      return;
    }

    _needsAd = false;
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
        unawaited(Future.sync(onComplete));
      },
      onAdFailedToShowFullScreenContent: (_, error) {
        DevLogger.instance
            .log(DevLogCategory.ad, 'Ad fallback thất bại: $error');
        debugPrint('[AdService] Ad failed to show: $error');
        ad.dispose();
        unawaited(Future.sync(onComplete));
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
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.56),
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            margin: const EdgeInsets.symmetric(horizontal: 22),
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0E2244).withValues(alpha: 0.96),
                  const Color(0xFF060D1F).withValues(alpha: 0.96),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '📢 Quảng cáo [DEV]',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontFamily: 'Jura',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Giả lập quảng cáo interstitial.\n\n'
                  'Trong môi trường production, quảng cáo thật từ AdMob sẽ xuất hiện ở đây.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xFF00B4D8),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    '× Đóng quảng cáo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return Transform.scale(
          scale: 0.96 + (0.04 * animation.value),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }
}
