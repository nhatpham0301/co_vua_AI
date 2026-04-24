import 'package:flutter/material.dart';

import 'mm_live_match_list.dart';
import 'mm_models.dart';

class WatchMatchesDialogContent extends StatelessWidget {
  final List<LiveMatch> matches;
  final Future<void> Function() onRefresh;
  final ValueChanged<LiveMatch>? onSelectMatch;

  const WatchMatchesDialogContent({
    super.key,
    required this.matches,
    required this.onRefresh,
    this.onSelectMatch,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 860),
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF6D4B2D), width: 1.4),
            image: const DecorationImage(
              image: AssetImage('assets/images/home/background_view_match.png'),
              fit: BoxFit.cover,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.48),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Column(
              children: [
                const SizedBox(height: 100),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: _WatchFilterBar(),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: LiveMatchList(
                    matches: matches,
                    onRefresh: onRefresh,
                    hasSavedGame: false,
                    bottomPadding: 10,
                    onWatchTap: onSelectMatch,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 25),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFD9AE73), Color(0xFFAA6F38)],
                        ),
                        border: Border.all(
                          color: const Color(0xFFEBCB9A).withValues(alpha: 0.7),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.24),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back,
                            color: Color(0xFF3D2515),
                            size: 20,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Quay lại',
                            style: TextStyle(
                              color: Color(0xFF3D2515),
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Jura',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WatchFilterBar extends StatelessWidget {
  const _WatchFilterBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF9D6A3D), Color(0xFF6A4528)],
        ),
        border:
            Border.all(color: const Color(0xFFD4AA76).withValues(alpha: 0.6)),
      ),
      child: Row(
        children: const [
          _FilterChip(label: 'Tất cả', selected: false),
          _FilterChip(label: 'Live', selected: true, withDot: true),
          _FilterChip(label: 'Elo cao', selected: false),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool withDot;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.withDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF5E3118), Color(0xFF3E1F11)],
                )
              : null,
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (withDot) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF7E2E),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFFF9CC88)
                      : const Color(0xFFF4D9B0),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Jura',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
