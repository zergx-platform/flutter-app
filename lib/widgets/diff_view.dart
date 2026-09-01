import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'diff_parser.dart';

enum DiffLayout { lineByLine, sideBySide }

Color _addedLight = const Color(0xffe6ffec);
Color _removedLight = const Color(0xffffebe9);
const Color _addedBar = Color(0xff2ea043);
const Color _removedBar = Color(0xffd73a49);

Color _addedBg(bool dark) => dark ? const Color(0x247ac26b) : _addedLight;
Color _removedBg(bool dark) => dark ? const Color(0x24f85149) : _removedLight;

/// Lightweight diff renderer: parses unified diff text and colors +/− lines.
class DiffView extends StatelessWidget {
  final String diffText;
  const DiffView({super.key, required this.diffText});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = colorsOf(context);
    if (diffText.trim().isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text('No changes', style: TextStyle(color: colors.mutedForeground)),
      );
    }
    final files = parseDiff(diffText);
    if (files.isEmpty) {
      return SelectableText(diffText, style: textOf(context).mono);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final f in files) _FileBlock(file: f, dark: dark)],
      ),
    );
  }
}

class _FileBlock extends StatelessWidget {
  final ParsedDiffFile file;
  final bool dark;
  const _FileBlock({required this.file, required this.dark});

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    var added = 0;
    var removed = 0;
    for (final h in file.hunks) {
      for (final l in h.lines) {
        if (l.type == DiffLineType.added) {
          added++;
        } else if (l.type == DiffLineType.removed) {
          removed++;
        }
      }
    }
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
        borderRadius: AppRadius.rSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(file.filename,
                      overflow: TextOverflow.ellipsis,
                      style: text.mono.copyWith(fontSize: 11)),
                ),
                Text('+$added ',
                    style: text.micro.copyWith(color: _addedBar)),
                Text('-$removed',
                    style: text.micro.copyWith(color: _removedBar)),
              ],
            ),
          ),
          for (final h in file.hunks) ...[
            Container(
              color: dark ? const Color(0xff262b3a) : const Color(0xfff6f8fa),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              child: Text(h.header, style: text.mono.copyWith(fontSize: 11)),
            ),
            for (final l in h.lines) _row(context, l),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, DiffLine l) {
    final text = textOf(context);
    Color? bg;
    Color bar = Colors.transparent;
    if (l.type == DiffLineType.removed) {
      bg = _removedBg(dark);
      bar = _removedBar;
    } else if (l.type == DiffLineType.added) {
      bg = _addedBg(dark);
      bar = _addedBar;
    }
    final numColor = colorsOf(context).mutedForeground;
    Widget row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 44,
          child: Text('${l.oldLine ?? ''}',
              textAlign: TextAlign.right,
              style: text.mono.copyWith(fontSize: 11, color: numColor)),
        ),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: 44,
          child: Text('${l.newLine ?? ''}',
              textAlign: TextAlign.right,
              style: text.mono.copyWith(fontSize: 11, color: numColor)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(width: 4, color: bar),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(l.content, style: text.mono),
        ),
      ],
    );
    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: 0.5),
      child: row,
    );
  }
}
