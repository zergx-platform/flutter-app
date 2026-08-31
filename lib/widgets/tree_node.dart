import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';

String formatSize(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
}

/// Recreates TreeNode.svelte: recursively renders the cached file tree,
/// lazily loading directories from the store as they expand.
class TreeNode extends StatelessWidget {
  final AppStore store;
  final String path;
  final int depth;
  final List<bool> ancestorsLast;
  const TreeNode(
      {super.key,
      required this.store,
      this.path = '',
      this.depth = 0,
      this.ancestorsLast = const []});

  @override
  Widget build(BuildContext context) {
    final entries = store.treeCache[path] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++)
          _entry(context, entries[i], i, entries.length),
      ],
    );
  }

  String _prefix(int i, int total) {
    var pre = '';
    for (var d = 0; d < depth; d++) {
      pre += ancestorsLast[d] ? '\u00A0\u00A0\u00A0 ' : '\u2502\u00A0\u00A0 ';
    }
    pre += i == total - 1 ? '\u2514\u2500\u2500 ' : '\u251C\u2500\u2500 ';
    return pre;
  }

  Widget _entry(BuildContext context, FileEntry entry, int i, int total) {
    final theme = Theme.of(context);
    final prefix = _prefix(i, total);
    if (entry.isDir) {
      final expanded = store.expandedDirs.contains(entry.path);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => store.toggleDir(entry.path),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                children: [
                  Text(prefix,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 11)),
                  Icon(expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                      size: 16, color: theme.colorScheme.outline),
                  const Icon(Icons.folder, size: 15, color: Colors.lightBlue),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(entry.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            TreeNode(
                store: store,
                path: entry.path,
                depth: depth + 1,
                ancestorsLast: [...ancestorsLast, i == total - 1]),
        ],
      );
    }
    final selected = store.selectedFilePath == entry.path;
    return InkWell(
      onTap: () => store.openFile(entry.path),
      child: Container(
        color: selected ? theme.colorScheme.primary.withValues(alpha: 0.15) : null,
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            Text(prefix, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
            const SizedBox(width: 16),
            Icon(Icons.insert_drive_file_outlined,
                size: 14, color: theme.colorScheme.outline),
            const SizedBox(width: 4),
            Expanded(
              child: Text(entry.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: selected ? theme.colorScheme.primary : null)),
            ),
            if (entry.size > 0)
              Text(formatSize(entry.size),
                  style: TextStyle(
                      fontSize: 9, color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}