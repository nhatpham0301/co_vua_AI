import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../shared/text_variable.dart';

class Picker<T extends Object> extends StatelessWidget {
  final String? label;
  final Map<T, Text>? options;
  final T? selection;
  final Function(T?)? setFunc;
  final bool themed;

  Picker({
    this.label,
    this.options,
    this.selection,
    this.setFunc,
    this.themed = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelWidget = themed
        ? Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              label ?? '',
              style: const TextStyle(
                color: Color(0xFFF0D2A0),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          )
        : TextSmall(label ?? "");

    final segmentedControl = CupertinoTheme(
      data: CupertinoThemeData(
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(
            fontFamily: 'Jura',
            fontSize: themed ? 12 : 8,
            color: themed ? const Color(0xFFF8E4BF) : CupertinoColors.white,
            fontWeight: themed ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
      child: CupertinoSlidingSegmentedControl<T>(
        children: options ?? {},
        groupValue: selection,
        onValueChanged: (T? val) {
          if (setFunc != null) {
            setFunc!(val);
          }
        },
        thumbColor: themed ? const Color(0xFFB57B3E) : const Color(0x88FFFFFF),
        backgroundColor:
            themed ? const Color(0x66472C1A) : const Color(0x20000000),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        labelWidget,
        Container(
          width: double.infinity,
          padding: themed
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
              : null,
          decoration: themed
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF6E4628), Color(0xFF3C2416)],
                  ),
                  border: Border.all(
                    color: const Color(0xFFE9C081).withValues(alpha: 0.45),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                )
              : null,
          child: segmentedControl,
        ),
      ],
    );
  }
}
