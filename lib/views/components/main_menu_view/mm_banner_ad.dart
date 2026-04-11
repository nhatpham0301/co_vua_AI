import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as gma;
import 'package:provider/provider.dart';

import '../../../../model/app_model.dart';

// ─── Real Google Mobile Ads banner ───────────────────────────────────────────
class GameBannerAd extends StatefulWidget {
  final double bottomPad;
  const GameBannerAd({super.key, required this.bottomPad});

  @override
  State<GameBannerAd> createState() => _GameBannerAdState();
}

class _GameBannerAdState extends State<GameBannerAd> {
  gma.BannerAd? _bannerAd;
  bool _adLoaded = false;

  @override
  void initState() {
    super.initState();
    final adService = Provider.of<AppModel>(context, listen: false).adService;
    _bannerAd = adService.createBannerAd(
      listener: gma.BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _adLoaded = true);
        },
        onAdFailedToLoad: (_, __) {
          if (mounted) setState(() => _adLoaded = false);
        },
      ),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  'QUẢNG CÁO',
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
