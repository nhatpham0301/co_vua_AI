import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'mm_palette.dart';

// ─── Top header bar ───────────────────────────────────────────────────────────
class MenuHeader extends StatelessWidget {
  final bool isLoggedIn;
  final String userName;
  final int elo;
  final String rank;
  final VoidCallback onLoginTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onThemeTap;

  const MenuHeader({
    super.key,
    required this.isLoggedIn,
    required this.userName,
    required this.elo,
    required this.rank,
    required this.onLoginTap,
    required this.onSettingsTap,
    required this.onThemeTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          if (isLoggedIn) ...[
            AvatarCircle(initial: userName.isNotEmpty ? userName[0] : 'G'),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.eloRank(elo, rank),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ] else ...[
            GestureDetector(
              onTap: onLoginTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.person_fill,
                        color: Colors.white70, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      l.loginRegister,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const Spacer(),
          MenuIconBtn(
              icon: CupertinoIcons.settings,
              tooltip: l.settingsTooltip,
              onTap: onSettingsTap),
        ],
      ),
    );
  }
}

// ─── Circular avatar with initial letter ─────────────────────────────────────
class AvatarCircle extends StatelessWidget {
  final String initial;
  const AvatarCircle({super.key, required this.initial});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgCard,
        border: Border.all(color: primary.withValues(alpha: 0.6), width: 2),
      ),
      child: Center(
        child: Text(
          initial.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

// ─── Circular icon button used in the header ──────────────────────────────────
class MenuIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const MenuIconBtn({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
            border:
                Border.all(color: goldMid.withValues(alpha: 0.35), width: 1.2),
          ),
          child: Icon(icon, color: Colors.white70, size: 17),
        ),
      ),
    );
  }
}
