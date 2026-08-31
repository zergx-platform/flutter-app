import 'package:flutter/material.dart';

/// Simple raw markdown renderer wrapper (flutter_markdown).
class MarkdownBody2 extends StatelessWidget {
  final String content;
  const MarkdownBody2({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return SelectableText(content.isEmpty ? '' : content,
        style: const TextStyle(fontSize: 13));
  }
}