import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as gma;
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../model/app_model.dart';

// ─── Real Google Mobile Ads banner ───────────────────────────────────────────
class GameBannerAd extends StatefulWidget {
  final double bottomPad;
  const GameBannerAd({super.key, required this.bottomPad});

  @override
  State<GameBannerAd> createState() => _GameBannerAdState();
}

class _GameBannerAdState extends State<GameBannerAd> {
  static const Duration _retryFast = Duration(milliseconds: 250);
  static const Duration _retryMedium = Duration(milliseconds: 500);
  static const Duration _retrySlow = Duration(seconds: 1);

  gma.BannerAd? _bannerAd;
  bool _adLoaded = false;
  bool _isCreatingBanner = false;
  int _retryAttempt = 0;
  Timer? _retryTimer;

  void _loadBanner() {
    if (!mounted) return;
    if (_isCreatingBanner) return;
    if (_bannerAd != null && _adLoaded) return;

    _retryTimer?.cancel();
    _retryTimer = null;
    _isCreatingBanner = true;

    final adService = Provider.of<AppModel>(context, listen: false).adService;
    final existing = _bannerAd;
    final created = adService.createBannerAd(
      listener: gma.BannerAdListener(
        onAdLoaded: (_) {
          _isCreatingBanner = false;
          _retryAttempt = 0;
          _retryTimer?.cancel();
          _retryTimer = null;
          if (mounted) setState(() => _adLoaded = true);
        },
        onAdFailedToLoad: (ad, __) {
          _isCreatingBanner = false;
          ad.dispose();
          if (identical(_bannerAd, ad)) {
            _bannerAd = null;
          }
          if (mounted) setState(() => _adLoaded = false);
          _scheduleRetry();
        },
      ),
    );

    if (created == null) {
      _isCreatingBanner = false;
      _scheduleRetry();
      return;
    }

    _bannerAd = created;
    if (existing != null && !identical(existing, created)) {
      existing.dispose();
    }
  }

  void _scheduleRetry() {
    if (_retryTimer != null) return;
    _retryAttempt++;
    final delay = _retryAttempt <= 3
        ? _retryFast
        : _retryAttempt <= 8
            ? _retryMedium
            : _retrySlow;

    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      _loadBanner();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      height: 50 + widget.bottomPad,
      padding: EdgeInsets.only(bottom: widget.bottomPad),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: _adLoaded && _bannerAd != null
          ? gma.AdWidget(ad: _bannerAd!)
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.ad_units, color: Colors.white24, size: 16),
                const SizedBox(width: 8),
                Text(
                  l.adLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.18),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
    );
  }
}
