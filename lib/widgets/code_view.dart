import 'package:flutter/material.dart';

String formatSize(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
}

/// Recreates TreeNode.svelte: recursively renders the file-tree cache.
class CodeView extends StatelessWidget {
  final String code;
  final String filepath;
  const CodeView({super.key, required this.code, required this.filepath});

  @override
  Widget build(BuildContext context) {
    final lines = code.split('\n');
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 1; i <= lines.length; i++)
                Text('$i',
                    style: TextStyle(
                        color: theme.colorScheme.outline,
                        fontSize: 11,
                        fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              code,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}