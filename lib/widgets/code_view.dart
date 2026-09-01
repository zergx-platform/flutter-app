import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Line-numbered code viewer (recreates CodeView.svelte). Uses a
/// scrollable TextField-free layout: header gutter column + selectable
/// code, both scrolling horizontally together.
class CodeView extends StatelessWidget {
  final String code;
  final String filepath;
  const CodeView({super.key, required this.code, required this.filepath});

  @override
  Widget build(BuildContext context) {
    final lines = code.split('\n');
    final colors = colorsOf(context);
    final text = textOf(context);
    final codeStyle = text.mono.copyWith(fontSize: 12);
    return Scrollbar(
      child: SingleChildScrollView(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 36,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 1; i <= lines.length; i++)
                      Text('$i',
                          style: codeStyle.copyWith(color: colors.mutedForeground)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              ConstrainedBox(
                constraints: BoxConstraints(
                    minWidth: MediaQuery.sizeOf(context).width - 80),
                child: SelectableText(
                  code,
                  style: codeStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
