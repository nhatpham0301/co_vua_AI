import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../main_menu_view/mm_palette.dart';
import '../shared/text_variable.dart';

class Toggle extends StatelessWidget {
  final String label;
  final bool? toggle;
  final Function(bool)? setFunc;

  Toggle(this.label, {this.toggle, this.setFunc});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: bgCard.withValues(alpha: 0.32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          TextRegular(label),
          Spacer(),
          CupertinoSwitch(
            value: toggle ?? false,
            onChanged: setFunc,
          ),
        ],
      ),
    );
  }
}
