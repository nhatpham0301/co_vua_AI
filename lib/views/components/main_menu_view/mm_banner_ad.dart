import 'package:flutter/material.dart';

// ─── Fixed bottom banner placeholder ─────────────────────────────────────────
class BannerAd extends StatelessWidget {
  final double bottomPad;
  const BannerAd({super.key, required this.bottomPad});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50 + bottomPad,
      padding: EdgeInsets.only(bottom: bottomPad),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.ad_units, color: Colors.white24, size: 16),
          const SizedBox(width: 8),
          Text(
            'QUẢNG CÁO BANNER',
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
