import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import 'tool_part.dart';

/// Markdown body pre-styled with the shared type scale.
class _Markdown extends StatelessWidget {
  final String data;
  final bool muted;
  const _Markdown(this.data, {this.muted = false});

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: muted
            ? text.meta.copyWith(color: colors.mutedForeground)
            : text.body,
        h1: text.body.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
        h2: text.body.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
        h3: text.body.copyWith(fontWeight: FontWeight.w600),
        code: text.mono.copyWith(
            color: colors.foreground,
            backgroundColor: colors.muted,
            fontSize: 13),
        codeblockDecoration: BoxDecoration(
          color: colors.muted,
          borderRadius: AppRadius.rSm,
        ),
        blockquote: text.meta.copyWith(color: colors.mutedForeground),
        blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: colors.border, width: 2)),
        ),
        listBullet: text.body,
        tableHead: text.meta.copyWith(fontWeight: FontWeight.w600),
        tableBody: text.meta,
        blockSpacing: AppSpacing.sm,
      ),
    );
  }
}

/// IM-style chat bubble mirroring MessageBubble.svelte. Long-press (mobile)
/// or the hover/overflow affordance exposes copy / undo.
class MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final Future<void> Function(String messageId) onUndo;
  final void Function(String changeId)? onOpenChange;
  const MessageBubble({
    super.key,
    required this.msg,
    required this.onUndo,
    this.onOpenChange,
  });

  bool get _hasText =>
      msg.parts.any((p) => p.type == 'text' || p.type == 'reasoning');

  void _copy(BuildContext context) {
    final text = msg.parts
        .where((p) => p.type == 'text' || p.type == 'reasoning')
        .map((p) => p.text)
        .join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)));
  }

  Future<void> _actions(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy'),
              onTap: () => Navigator.pop(ctx, 'copy'),
            ),
            ListTile(
              leading: const Icon(Icons.undo_rounded),
              title: const Text('Undo until here'),
              onTap: () => Navigator.pop(ctx, 'undo'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'copy':
        _copy(context);
      case 'undo':
        onUndo(msg.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    final isUser = msg.role == 'user';
    final isError = msg.role == 'error';
    final isStreaming = msg.status == 'streaming';

    final parts = <Widget>[];
    for (final part in msg.parts) {
      if (part.type == 'text') {
        parts.add(_Markdown(part.text));
      } else if (part.type == 'reasoning') {
        parts.add(_ReasoningBlock(text: part.text, streaming: isStreaming));
      } else if (part.type == 'tool' && part.state != null) {
        parts.add(ToolPartView(
          part: part,
          isStreaming: isStreaming,
          onOpenChange: onOpenChange,
        ));
      } else if (part.type == 'compaction') {
        parts.add(_CompactionBlock(text: part.text));
      }
    }
    if (isStreaming && parts.isEmpty) {
      parts.add(Text('thinking...',
          style: text.meta
              .copyWith(color: colors.mutedForeground, fontStyle: FontStyle.italic)));
    }
    if (isError) {
      parts.insert(
        0,
        Text('Error',
            style: text.micro.copyWith(
                color: colors.destructive, fontWeight: FontWeight.w600)),
      );
    }

    Widget bubble = Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: isError
            ? colors.destructive.withValues(alpha: 0.10)
            : isUser
                ? colors.primary.withValues(alpha: 0.12)
                : colors.card,
        border: Border.all(
          color: isError
              ? colors.destructive.withValues(alpha: 0.4)
              : isUser
                  ? colors.primary.withValues(alpha: 0.4)
                  : colors.border.withValues(alpha: 0.5),
        ),
        borderRadius: AppRadius.rMd,
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < parts.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              parts[i],
            ],
          ]),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: () => _actions(context),
            child: bubble,
          ),
          if (!isStreaming && _hasText)
            _BubbleActions(
              isUser: isUser,
              onCopy: () => _copy(context),
              onUndo: () => onUndo(msg.id),
            ),
        ],
      ),
    );
  }
}

class _BubbleActions extends StatelessWidget {
  final bool isUser;
  final VoidCallback onCopy;
  final VoidCallback onUndo;
  const _BubbleActions(
      {required this.isUser, required this.onCopy, required this.onUndo});

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.copy_rounded, size: 14, color: colors.mutedForeground),
            tooltip: 'Copy',
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            padding: EdgeInsets.zero,
            onPressed: onCopy,
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton(
            icon: Icon(Icons.undo_rounded, size: 14, color: colors.mutedForeground),
            tooltip: 'Undo',
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            padding: EdgeInsets.zero,
            onPressed: onUndo,
          ),
          if (isUser) ...[
            const SizedBox(width: AppSpacing.xs),
            Text('you',
                style: text.micro.copyWith(color: colors.mutedForeground)),
          ],
        ],
      ),
    );
  }
}

/// Collapsible reasoning block — matches the web `details` style:
/// amber left border, no Material expansion chrome.
class _ReasoningBlock extends StatelessWidget {
  final String text;
  final bool streaming;
  const _ReasoningBlock({required this.text, required this.streaming});

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final text_ = textOf(context);
    return _CollapseBlock(
      label: 'Thinking${streaming ? '...' : ''}',
      labelColor: colors.warning,
      initiallyOpen: true,
      textStyle: text_.micro
          .copyWith(color: colors.warning, fontWeight: FontWeight.w600),
      wrapper: (child) => Container(
        decoration: BoxDecoration(
          color: colors.warning.withValues(alpha: 0.05),
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(AppRadius.sm),
            bottomRight: Radius.circular(AppRadius.sm),
          ),
          border: Border(left: BorderSide(color: colors.warning, width: 2)),
        ),
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.sm, AppSpacing.sm),
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: _Markdown(text, muted: true),
      ),
    );
  }
}

class _CompactionBlock extends StatelessWidget {
  final String text;
  const _CompactionBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    return _CollapseBlock(
      label: '历史已压缩 · 查看摘要',
      labelColor: colors.mutedForeground,
      initiallyOpen: false,
      textStyle: textOf(context).micro.copyWith(color: colors.mutedForeground),
      wrapper: (child) => Container(
        decoration: BoxDecoration(
          color: colors.muted.withValues(alpha: 0.4),
          borderRadius: AppRadius.rSm,
          border: Border.all(color: colors.border.withValues(alpha: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: SelectableText(text, style: textOf(context).meta),
      ),
    );
  }
}

/// Minimal disclosure block without ExpansionTile chrome (no forced min
/// heights, no icon defaults) so spacing stays tight inside bubbles.
class _CollapseBlock extends StatefulWidget {
  final String label;
  final Color labelColor;
  final TextStyle textStyle;
  final bool initiallyOpen;
  final Widget child;
  final Widget Function(Widget child) wrapper;
  const _CollapseBlock({
    required this.label,
    required this.labelColor,
    required this.textStyle,
    required this.initiallyOpen,
    required this.wrapper,
    required this.child,
  });

  @override
  State<_CollapseBlock> createState() => _CollapseBlockState();
}

class _CollapseBlockState extends State<_CollapseBlock> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    return widget.wrapper(
      InkWell(
        onTap: () => setState(() => _open = !_open),
        borderRadius: AppRadius.rSm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _open
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_right_rounded,
                  size: 14,
                  color: widget.labelColor,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(widget.label, style: widget.textStyle),
              ],
            ),
            if (_open) widget.child,
          ],
        ),
      ),
    );
  }
}
