import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../main_menu_view/mm_palette.dart';

class AppDialogAction {
  final String label;
  final FutureOr<void> Function()? onPressed;
  final bool isPrimary;
  final bool isDestructive;
  final bool closeOnPress;

  const AppDialogAction({
    required this.label,
    this.onPressed,
    this.isPrimary = false,
    this.isDestructive = false,
    this.closeOnPress = true,
  });
}

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  required List<AppDialogAction> actions,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.56),
    barrierDismissible: barrierDismissible,
    barrierLabel: '',
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, anim1, anim2) {
      return Center(
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
                  bgCard.withValues(alpha: 0.96),
                  bgDark.withValues(alpha: 0.96),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontFamily: 'Jura',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (message != null && message.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ...actions.map((action) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _DialogActionButton(
                      action: action,
                      onPressed: () async {
                        if (action.closeOnPress) {
                          Navigator.of(dialogContext).pop();
                        }
                        await action.onPressed?.call();
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return Transform.scale(
        scale: 0.96 + (0.04 * animation.value),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
}

class _DialogActionButton extends StatelessWidget {
  final AppDialogAction action;
  final VoidCallback onPressed;

  const _DialogActionButton({
    required this.action,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final background = action.isDestructive
        ? const Color(0xFF8D2F2F)
        : action.isPrimary
            ? primary
            : Colors.white.withValues(alpha: 0.08);

    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        borderRadius: BorderRadius.circular(14),
        color: background,
        onPressed: onPressed,
        child: Text(
          action.label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
