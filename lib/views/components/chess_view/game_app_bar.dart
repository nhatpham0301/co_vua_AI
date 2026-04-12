import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/app_model.dart';
import '../../settings_view.dart';
import '../main_menu_view/mm_palette.dart';

class GameAppBar extends StatelessWidget {
  final String rankName;
  final AppModel appModel;

  const GameAppBar({
    super.key,
    required this.rankName,
    required this.appModel,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      height: 54,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgCard,
              border:
                  Border.all(color: primary.withValues(alpha: 0.5), width: 1.2),
            ),
            child: const Icon(Icons.shield_rounded, color: goldMid, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.matchArena,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
                Text(
                  rankName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          _IconBtn(
            icon: CupertinoIcons.settings,
            onTap: () => Navigator.push(
              context,
              CupertinoPageRoute(builder: (_) => SettingsView()),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
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
