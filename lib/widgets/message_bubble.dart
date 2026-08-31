import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models.dart';
import 'tool_part.dart';

/// Recreates MessageBubble.svelte.
class MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final Future<void> Function(String messageId) onUndo;
  final void Function(String changeId)? onOpenChange;
  const MessageBubble(
      {super.key,
      required this.msg,
      required this.onUndo,
      this.onOpenChange});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = msg.role == 'user';
    final isError = msg.role == 'error';
    final isStreaming = msg.status == 'streaming';

    final parts = <Widget>[];
    for (final part in msg.parts) {
      if (part.type == 'text') {
        parts.add(MarkdownBody(data: part.text));
      } else if (part.type == 'reasoning') {
        parts.add(_reasoning(context, part.text, isStreaming));
      } else if (part.type == 'tool' && part.state != null) {
        parts.add(ToolPartView(
          part: part,
          isStreaming: isStreaming,
          onOpenChange: onOpenChange,
        ));
      } else if (part.type == 'compaction') {
        parts.add(_compaction(context, part.text));
      }
    }
    if (isStreaming && parts.isEmpty) {
      parts.add(Text('thinking...',
          style: TextStyle(
              color: theme.colorScheme.outline, fontStyle: FontStyle.italic)));
    }

    BoxDecoration decoration;
    if (isError) {
      decoration = BoxDecoration(
        border: Border.all(color: theme.colorScheme.error),
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      );
    } else if (isUser) {
      decoration = BoxDecoration(
        border: Border.all(color: theme.colorScheme.primary),
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      );
    } else if (isStreaming) {
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.surfaceContainerHighest,
      );
    } else {
      decoration = BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: decoration,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: parts),
          ),
          if (!isStreaming)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.content_copy, size: 16),
                  tooltip: 'Copy',
                  onPressed: () => _copy(context),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.undo, size: 16),
                  tooltip: 'Undo',
                  onPressed: () => onUndo(msg.id),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _copy(BuildContext context) {
    final text = msg.parts
        .where((p) => p.type == 'text' || p.type == 'reasoning')
        .map((p) => p.text)
        .join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)));
  }

  Widget _reasoning(BuildContext context, String text, bool streaming) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          border: Border(
              left: BorderSide(color: Colors.amber, width: 2)),
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text('Thinking${streaming ? '...' : ''}',
              style: const TextStyle(color: Colors.amber, fontSize: 12)),
          children: [
            Align(
                alignment: Alignment.centerLeft,
                child: MarkdownBody(data: text)),
          ],
        ),
      ),
    );
  }

  Widget _compaction(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text('历史已压缩 · 查看摘要',
              style: TextStyle(
                  color: theme.colorScheme.outline, fontSize: 12)),
          children: [
            Text(text, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}