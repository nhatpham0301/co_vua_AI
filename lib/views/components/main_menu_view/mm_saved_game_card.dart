import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/app_model.dart';
import '../../chess_view.dart';

// ─── Card shown when the user has a saved game in progress ───────────────────
class SavedGameCard extends StatelessWidget {
  const SavedGameCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final appModel = Provider.of<AppModel>(context, listen: false);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        CupertinoPageRoute(
            builder: (_) => ChessView(appModel, isResuming: true)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.arrow_counterclockwise_circle_fill,
                color: Color(0xFFA855F7), size: 22),
            const SizedBox(width: 10),
            Text(
              l.resumeGame,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            const Icon(CupertinoIcons.chevron_right,
                color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }
}
