import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../api.dart';
import '../i18n.dart';
import '../models.dart';
import '../services/download_service.dart';
import '../theme/app_theme.dart';
import 'tool_part.dart';

/// A file chip surfaced from a text part that carries the
/// `[附件 <name> | file:<code> | <mime> | <size>]` reference we embed in the
/// prompt. Clicking it opens an inline image preview (by [code]) or triggers
/// a public-Downloads save for non-image files.
class _FileChip extends StatelessWidget {
  final String code;
  final String label;
  final String? mime;
  final ZergxApi api;
  const _FileChip({required this.code, required this.label, this.mime, required this.api});

  bool get _isImage => (mime ?? '').startsWith('image/');

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs + 2),
      decoration: BoxDecoration(
        color: colors.muted.withValues(alpha: 0.5),
        borderRadius: AppRadius.rSm,
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        borderRadius: AppRadius.rSm,
        onTap: () => _open(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_isImage ? Icons.image_rounded : Icons.attach_file_rounded,
                size: 14, color: colors.mutedForeground),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: text.micro.copyWith(color: colors.foreground)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    try {
      if (_isImage) {
        final bytes = await api.fetchFileBytes(code);
        if (!context.mounted) return;
        // ignore: use_build_context_synchronously
        showDialog<void>(
          context: context,
          builder: (_) => Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: InteractiveViewer(
              child: Image.memory(Uint8List.fromList(bytes)),
            ),
          ),
        );
      } else {
        // Non-image files save into the public Downloads collection (and
        // show a hop-free snackbar naming the destination).
        final where = await DownloadService(api).download(
          path: api.filePath(code),
          displayName: label,
          mimeType: mime ?? 'application/octet-stream',
        );
        if (!context.mounted) return;
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t(context, 'savedToDownloads', [where])),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (!context.mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t(context, 'sendFailed', ['$e'])),
          duration: const Duration(seconds: 2)));
    }
  }
}

/// Parses embedded `[附件 <name> | file:<code> | <mime> | <size>]` references
/// out of a text part and splits the bubble into inline markdown + file chips.
class _FileRefsText extends StatelessWidget {
  final String text;
  final ZergxApi api;
  const _FileRefsText({required this.text, required this.api});

  @override
  Widget build(BuildContext context) {
    final parts = _splitFileRefs(text);
    if (parts.isEmpty) return _Markdown(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final p in parts)
          p is _FileRef
              ? _FileChip(code: p.code, label: p.label, mime: p.mime, api: api)
              : _Markdown(p as String),
      ],
    );
  }
}

class _FileRef {
  final String code;
  final String label;
  final String? mime;
  _FileRef(this.code, this.label, this.mime);
}

final _fileRefRe = RegExp(
  r'\[附件\s+(.+?)\s*\|\s*file:([0-9a-zA-Z]+)\s*\|\s*([^|\]]*)\s*\|\s*([^\]|]*)\]',
);

List<Object> _splitFileRefs(String text) {
  final out = <Object>[];
  var idx = 0;
  for (final m in _fileRefRe.allMatches(text)) {
    if (m.start > idx) out.add(text.substring(idx, m.start));
    out.add(_FileRef(m.group(2)!, m.group(1)!, m.group(3)));
    idx = m.end;
  }
  if (idx < text.length) out.add(text.substring(idx));
  return out;
}

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
  final ZergxApi api;
  final String org;
  final String repo;
  final String branch;
  const MessageBubble({
    super.key,
    required this.msg,
    required this.onUndo,
    required this.api,
    this.onOpenChange,
    this.org = '',
    this.repo = '',
    this.branch = '',
  });

  ZergxApi get _api => api;

  bool get _hasText =>
      msg.parts.any((p) => p.type == 'text' || p.type == 'reasoning');

  void _copy(BuildContext context) {
    final text = msg.parts
        .where((p) => p.type == 'text' || p.type == 'reasoning')
        .map((p) => p.text)
        .join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t(context, 'copied')), duration: const Duration(seconds: 1)));
  }

  Future<void> _actions(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Copy only makes sense for messages with text/reasoning
            // content; pure tool-call messages have nothing to copy.
            if (_hasText)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: Text(t(ctx, 'copy')),
                onTap: () => Navigator.pop(ctx, 'copy'),
              ),
            ListTile(
              leading: const Icon(Icons.undo_rounded),
              title: Text(t(ctx, 'undo')),
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
        parts.add(_FileRefsText(text: part.text, api: _api));
      } else if (part.type == 'reasoning') {
        parts.add(_ReasoningBlock(text: part.text, streaming: isStreaming));
      } else if (part.type == 'tool' && part.state != null) {
        parts.add(ToolPartView(
          part: part,
          isStreaming: isStreaming,
          api: _api,
          org: org,
          repo: repo,
          branch: branch,
          onOpenChange: onOpenChange,
        ));
      } else if (part.type == 'compaction') {
        parts.add(_CompactionBlock(text: part.text));
      }
    }
    if (isStreaming && parts.isEmpty) {
      parts.add(Text(t(context, 'thinking'),
          style: text.meta
              .copyWith(color: colors.mutedForeground, fontStyle: FontStyle.italic)));
    }
    if (isError) {
      parts.insert(
        0,
        Text(t(context, 'error'),
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
          // The actions row shows for EVERY non-streaming message — the
          // agent-ts /undo endpoint accepts any message in the session
          // chain, so tool-call messages are revertible too. Copy is only
          // offered when there is text to copy.
          if (!isStreaming)
            _BubbleActions(
              isUser: isUser,
              showCopy: _hasText,
              createdAt: msg.createdAt,
              onCopy: () => _copy(context),
              onUndo: () => _undo(context),
            ),
        ],
      ),
    );
  }

  /// Undo asks for confirmation before dispatching the request.
  Future<void> _undo(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t(ctx, 'undoTitle')),
        content: Text(t(ctx, 'undoBody')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t(ctx, 'cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: colorsOf(ctx).destructive,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t(ctx, 'undo')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await onUndo(msg.id);
    }
  }
}

class _BubbleActions extends StatelessWidget {
  final bool isUser;
  final bool showCopy;
  final String createdAt;
  final VoidCallback onCopy;
  final VoidCallback onUndo;
  const _BubbleActions({
    required this.isUser,
    required this.showCopy,
    required this.createdAt,
    required this.onCopy,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    return Align(
      // User bubbles: actions hug the right edge; assistant: the left edge.
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showCopy) ...[
            _tinyIcon(Icons.copy_rounded, t(context, 'copy'), onCopy, colors),
            const SizedBox(width: 2),
          ],
          _tinyIcon(Icons.undo_rounded, t(context, 'undo'), onUndo, colors),
          if (isUser) ...[
            const SizedBox(width: 4),
            // Show the message's persisted timestamp instead of "you".
            Text(_fmtTime(context, createdAt),
                style: text.micro.copyWith(color: colors.mutedForeground)),
          ],
        ],
      ),
    );
  }

  static String _fmtTime(BuildContext context, String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final d = now.difference(dt);
    final hm =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (d.inMinutes < 1) return t(context, 'timeJustNow');
    if (d.inMinutes < 60) {
      return t(context, 'timeMinAgo', ['${d.inMinutes}']);
    }
    if (d.inHours < 24) return hm;
    return '${dt.month}/${dt.day} $hm';
  }

  // Tight inline action — no App-wide icon-button chrome, no outer padding,
  // so the row sits flush against the bubble side.
  Widget _tinyIcon(IconData icon, String tooltip, VoidCallback onTap,
      AppColors colors) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.rSm,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(icon, size: 14, color: colors.mutedForeground),
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
      label: t(context, 'thinkLabel') + (streaming ? '...' : ''),
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
      label: t(context, 'compactedLabel'),
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
