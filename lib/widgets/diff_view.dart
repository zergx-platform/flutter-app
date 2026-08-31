import 'package:flutter/material.dart';

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
    if (diffText.trim().isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text('No changes',
            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      );
    }
    final files = parseDiff(diffText);
    if (files.isEmpty) {
      return SelectableText(diffText,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(file.filename,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 11)),
                ),
                Text('+$added ',
                    style:
                        const TextStyle(color: _addedBar, fontSize: 11)),
                Text('-$removed',
                    style:
                        const TextStyle(color: _removedBar, fontSize: 11)),
              ],
            ),
          ),
          for (final h in file.hunks) ...[
            Container(
              color: dark ? const Color(0xff262b3a) : const Color(0xfff6f8fa),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(h.header,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
            ),
            for (final l in h.lines) _row(context, l),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, DiffLine l) {
    Color? bg;
    Color bar = Colors.transparent;
    if (l.type == DiffLineType.removed) {
      bg = _removedBg(dark);
      bar = _removedBar;
    } else if (l.type == DiffLineType.added) {
      bg = _addedBg(dark);
      bar = _addedBar;
    }
    final numColor = Theme.of(context).colorScheme.outline;
    Widget row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 44,
          child: Text('${l.oldLine ?? ''}',
              textAlign: TextAlign.right,
              style: TextStyle(color: numColor, fontSize: 11, fontFamily: 'monospace')),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 44,
          child: Text('${l.newLine ?? ''}',
              textAlign: TextAlign.right,
              style: TextStyle(color: numColor, fontSize: 11, fontFamily: 'monospace')),
        ),
        const SizedBox(width: 8),
        Container(width: 4, color: bar),
        const SizedBox(width: 4),
        Expanded(
          child: Text(l.content,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
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