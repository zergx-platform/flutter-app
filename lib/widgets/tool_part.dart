import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api.dart';
import '../i18n.dart';
import '../models.dart';
import '../screens/change_diff.dart';
import '../screens/task_progress.dart';
import '../theme/app_theme.dart';
import 'diff_parser.dart';
import 'diff_view.dart';
import 'tool_icon.dart';

/// Recreates ToolPartView.svelte + family-specific body rendering.
///
/// Every tool is drawn with a shared header (status dot, icon, name, title,
/// fold arrow) and a family-appropriate body:
///   - file/content, git, sandbox-shell, build/deploy, package/pull,
///     browser, memory, generic.
/// A change_id badge (when the tool produced a change) jumps to the change
/// comparison screen; running long tasks offer a live-output screen.
class ToolPartView extends StatefulWidget {
  final ChatPart part;
  final bool isStreaming;
  final ZergxApi? api;
  final String? org;
  final String? repo;
  final String? branch;
  final void Function(String changeId)? onOpenChange;
  const ToolPartView({
    super.key,
    required this.part,
    this.isStreaming = false,
    this.api,
    this.org,
    this.repo,
    this.branch,
    this.onOpenChange,
  });

  @override
  State<ToolPartView> createState() => _ToolPartViewState();
}

class _ToolPartViewState extends State<ToolPartView> {
  bool _open = true;

  String _s(Object? v) => v is String ? v : '';

  String get tool => widget.part.tool;
  ToolState? get state => widget.part.state;
  String get status => state?.status ?? 'complete';
  Map<String, dynamic> get input =>
      (state?.input ?? const <String, dynamic>{});
  bool get hasError => status == 'error';
  String? get changeId {
    final c = state?.changeId;
    return (c is String && c.isNotEmpty) ? c : null;
  }

  String get toolId => tool.toLowerCase();

  /// Unified diff the tool produced (write/delete/edit/sandbox-edit etc).
  String? get _toolDiff => state?.diff;

  /// Family classifier — drives the body renderer.
  String get family {
    final t = toolId;
    if (t.startsWith('git-') || t == 'git-diff' || t == 'git-log' ||
        t == 'git-show' || t == 'git-blame' || t == 'git-branches') {
      return 'git';
    }
    if (t.startsWith('sandbox-') || t == 'sandbox-id' || t == 'sandbox-status') {
      return 'sandbox';
    }
    if (t.startsWith('container-') || t.startsWith('deploy') ||
        t.startsWith('helm') || t == 'image-list' ||
        t == 'deployment-list') {
      return 'deploy';
    }
    if (t.startsWith('package') || t.startsWith('publish') ||
        t.startsWith('list-registry') || t.startsWith('list-containerfile') ||
        t.startsWith('pull-') || t == 'sandbox-download') {
      return 'package';
    }
    if (t.startsWith('browser') || t.startsWith('web') ||
        t == 'navigate' || t == 'navigate_back' || t == 'navigate_forward' ||
        t == 'webfetch' || t == 'snapshot' || t == 'screenshot' ||
        t == 'click' || t == 'type' || t == 'find' || t == 'wait_for') {
      return 'browser';
    }
    if (t.startsWith('todo') || t.startsWith('history') ||
        t == 'file_info' || t == 'image_read') {
      return 'memory';
    }
    if (t == 'read' || t == 'write' || t == 'delete' || t == 'edit' ||
        t == 'ls' || t == 'grep' || t == 'explore' || t == 'org' ||
        t == 'repo' || t == 'bookmark') {
      return 'file';
    }
    return 'generic';
  }

  String inputSummary(Map<String, dynamic> inp) {
    final jobId = _s(inp['job_id']);
    final t = tool;
    final code = _s(inp['code']);
    switch (t) {
      case 'image_read':
      case 'image-read':
        return code.isNotEmpty ? 'image $code' : 'read image';
      case 'sandbox-read':
      case 'sandbox-write':
      case 'sandbox-edit':
        return _s(inp['path']);
      case 'sandbox-delete':
        return 'delete ${_s(inp['path'])}';
      case 'git-restore':
        return 'restore ${_s(inp['path'])} @ ${_s(inp['rev'])}';
      case 'sandbox-job-list':
        return 'list jobs';
      case 'sandbox-job-output':
        return 'output $jobId${_s(inp['grep']).isNotEmpty ? ' · grep ${_s(inp['grep'])}' : ''}';
      case 'sandbox-job-wait':
        return 'wait $jobId';
      case 'sandbox-job-kill':
        return 'kill $jobId';
      case 'sandbox-job-stdin':
        return 'stdin $jobId';
      case 'sandbox-port':
        return 'port ${_s(inp['sandbox_path'])} → ${_s(inp['repo_path'])}';
      case 'explore':
        return _s(inp['org']).isNotEmpty ? _s(inp['org']) : 'explore orgs/repos';
      case 'list-containerfile-templates':
        return 'list build templates';
      case 'container-build':
        return 'build ${_s(inp['tag'])} ← ${_s(inp['dockerfile_path'])}';
      case 'package-publish':
        return 'publish ${_s(inp['protocol'])} ${_s(inp['name'])}';
      case 'container-deploy':
        return 'deploy ${_s(inp['image'])}';
      case 'pull-oci-image':
        return 'pull image ${_s(inp['image'])}';
      case 'pull-git-repo':
        return 'clone ${_s(inp['git_url'])}';
      case 'list-registry-packages':
        return 'list packages';
      case 'browser-navigate':
        return 'navigate ${_s(inp['url'])}';
      case 'browser-navigate-back':
        return 'navigate back';
      case 'browser-navigate-forward':
        return 'navigate forward';
      case 'browser-click':
        return 'click ${_s(inp['element'])}';
      case 'browser-type':
        return 'type ${_s(inp['element'])}';
      case 'browser-snapshot':
        return 'snapshot';
      case 'browser-take-screenshot':
        return 'screenshot';
      case 'browser-webfetch':
        return 'webfetch ${_s(inp['url'])}';
      default:
        return _genericSummary(t, inp);
    }
  }

  String _genericSummary(String t, Map<String, dynamic> inp) {
    // Best-effort: join known scalar args into a short "k v" summary.
    final parts = <String>[];
    for (final kv in inp.entries) {
      final v = kv.value;
      if (v is String && v.isNotEmpty) {
        parts.add(v);
      } else if (v is num) {
        parts.add('$v');
      }
    }
    return parts.take(3).join(' ');
  }

  // ---- live-output / change nav ----

  Future<void> _openChange(String id) async {
    if (widget.api != null && widget.org != null && widget.repo != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChangeDiffScreen(
          api: widget.api!,
          org: widget.org!,
          repo: widget.repo!,
          changeId: id,
          branch: widget.branch ?? '',
        ),
      ));
      return;
    }
    widget.onOpenChange?.call(id);
  }

  /// build_id / task_id carry the live SSE task handle for long-running ops.
  String? get _buildId {
    for (final k in ['build_id', 'task_id', 'id']) {
      final v = input[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }

  bool get _isLongRunning =>
      status == 'running' &&
      (family == 'deploy' || toolId.startsWith('sandbox-job-wait') ||
          toolId.startsWith('container-build'));

  void _openLiveOutput() {
    final bid = _buildId;
    if (bid == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TaskProgressScreen(
        api: widget.api!,
        buildId: bid,
        title: toolDisplayName(tool),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    final dotColor = status == 'running'
        ? colors.warning
        : status == 'pending'
            ? colors.warning
            : hasError
                ? colors.destructive
                : colors.success;
    final canNavChange = changeId != null &&
        (widget.api != null && widget.org != null && widget.repo != null ||
            widget.onOpenChange != null);
    return Container(
      decoration: BoxDecoration(
        color: hasError
            ? colors.destructive.withValues(alpha: 0.05)
            : colors.background.withValues(alpha: 0.5),
        border: Border.all(
            color: hasError
                ? colors.destructive.withValues(alpha: 0.4)
                : colors.border.withValues(alpha: 0.5)),
        borderRadius: AppRadius.rSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.sm),
              bottom: _open ? Radius.zero : Radius.circular(AppRadius.sm),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs + 2),
              child: Row(
                children: [
                  Container(
                      width: 6,
                      height: 6,
                      decoration:
                          BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                  const SizedBox(width: AppSpacing.sm),
                  ToolIcon(tool),
                  const SizedBox(width: AppSpacing.xs),
                  Text(toolDisplayName(tool),
                      style: text.mono.copyWith(
                          fontSize: 12, fontWeight: FontWeight.w500)),
                  if ((state?.title ?? '').isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(state!.title!,
                          overflow: TextOverflow.ellipsis,
                          style: text.micro.copyWith(
                              color: colors.mutedForeground,
                              fontStyle: FontStyle.italic)),
                    ),
                  ],
                  const Spacer(),
                  // Live-output entry for running long tasks.
                  if (_isLongRunning && widget.api != null) ...[
                    InkWell(
                      borderRadius: AppRadius.rSm,
                      onTap: _openLiveOutput,
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.terminal_rounded,
                                size: 12, color: colors.warning),
                            const SizedBox(width: 2),
                            Text(t(context, 'viewOutput'),
                                style: text.micro.copyWith(
                                    fontSize: 10, color: colors.warning)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ] else
                    const Spacer(),
                  Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: colors.mutedForeground,
                  ),
                  if (changeId != null && canNavChange) ...[
                    const SizedBox(width: AppSpacing.xs),
                    InkWell(
                      onTap: () => _openChange(changeId!),
                      borderRadius: AppRadius.rSm,
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.commit_rounded,
                                size: 13, color: colors.primary),
                            const SizedBox(width: 2),
                            Text(changeId!.substring(0, 8),
                                style: text.mono.copyWith(
                                    fontSize: 10, color: colors.primary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
              child: _body(context),
            ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    final children = <Widget>[];
    if (state?.error != null) {
      children.add(Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: colors.destructive.withValues(alpha: 0.12),
          borderRadius: AppRadius.rSm,
        ),
        child: SelectableText(state!.error!,
            style: text.mono.copyWith(
                fontSize: 11, color: colors.destructive)),
      ));
    }
    if (changeId != null) {
      children.add(_code(context, 'change ${changeId!.substring(0, 12)}'));
    }
    final summary = inputSummary(input);
    final fam = family;

    // Family-specific input blocks.
    if (fam == 'file' || fam == 'git') {
      final path = _s(input['path']);
      if (_s(input['pattern']).isNotEmpty && toolId == 'grep') {
        children.add(_code(context, 'grep ${input['pattern']}'));
      } else if (path.isNotEmpty) {
        children.add(_code(context, path));
      } else if (summary.isNotEmpty) {
        children.add(_code(context, '$tool $summary'));
      }
    } else if (fam == 'sandbox') {
      if (toolId == 'sandbox-run' || toolId == 'sandbox-write') {
        if (input['command'] is String) {
          children.add(_code(context, '\$ ${input['command']}'));
        }
      } else if (_s(input['path']).isNotEmpty) {
        children.add(_code(context, _s(input['path'])));
      } else if (summary.isNotEmpty) {
        children.add(_code(context, '$tool $summary'));
      }
    } else if (fam == 'browser') {
      if (summary.isNotEmpty) children.add(_code(context, summary));
    } else if (fam == 'memory') {
      if (toolId == 'image_read' || toolId == 'image-read') {
        children.add(_InputImage(
          code: _s(input['code']),
          api: widget.api,
          maxWidth: 160,
        ));
      } else if (summary.isNotEmpty) {
        children.add(_code(context, '$tool $summary'));
      }
    } else if (fam == 'deploy' || fam == 'package') {
      if (_buildId != null) {
        children.add(_code(context, 'task $_buildId'));
      } else if (summary.isNotEmpty) {
        children.add(_code(context, '$tool $summary'));
      }
    } else {
      if (summary.isNotEmpty) children.add(_code(context, '$tool $summary'));
    }

    // New: inline the unified diff the edit/write/delete tools produce (they
    // now return `diff` in metadata), with a changeId badge linking to the
    // full change-comparison screen.
    final toolDiff = _toolDiff;
    if (toolDiff != null && toolDiff.isNotEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: _InlineDiff(diffText: toolDiff),
      ));
    }

    // Output block (collapsible, monospace scroll).
    final output = state?.output;
    if (output != null && output.isNotEmpty) {
      children.add(Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xs),
        constraints: const BoxConstraints(maxHeight: 220),
        child: SingleChildScrollView(
          child: SelectableText(fmtOutput(output),
              style: text.mono.copyWith(fontSize: 11)),
        ),
      ));
    } else if (widget.isStreaming && status == 'running') {
      children.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Text(t(context, 'running'),
            style: text.micro.copyWith(
                color: colors.mutedForeground,
                fontStyle: FontStyle.italic)),
      ));
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _code(BuildContext context, String text) {
    final colors = colorsOf(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: AppRadius.rSm,
      ),
      child: SelectableText(text,
          style: textOf(context).mono.copyWith(fontSize: 11)),
    );
  }
}

/// Compact inline diff (parse + render) inside a tool card, with a small
/// changeId chip. Tap opens the full change-comparison screen.
class _InlineDiff extends StatefulWidget {
  final String diffText;
  const _InlineDiff({required this.diffText});

  @override
  State<_InlineDiff> createState() => _InlineDiffState();
}

class _InlineDiffState extends State<_InlineDiff> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final files = parseDiff(widget.diffText);
    final summary = files.map((f) => f.filename).take(3).join(', ');
    final count = files.length;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
        borderRadius: AppRadius.rSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.sm)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_right_rounded,
                    size: 14,
                    color: colors.mutedForeground,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(Icons.difference_rounded,
                      size: 13, color: colors.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                        '$count 文件${summary.isEmpty ? '' : ' · $summary'}',
                        overflow: TextOverflow.ellipsis,
                        style: textOf(context)
                            .micro
                            .copyWith(color: colors.mutedForeground)),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(
                  left: AppSpacing.sm, right: AppSpacing.sm, bottom: AppSpacing.sm),
              child: DiffView(diffText: widget.diffText),
            ),
        ],
      ),
    );
  }
}

/// Fetches an image by code and shows a small tappable thumbnail inside a
/// tool card (e.g. the input image of an image_read tool call).
class _InputImage extends StatefulWidget {
  final String code;
  final ZergxApi? api;
  final double maxWidth;
  const _InputImage({required this.code, this.api, this.maxWidth = 160});

  @override
  State<_InputImage> createState() => _InputImageState();
}

class _InputImageState extends State<_InputImage> {
  Uint8List? _bytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = widget.api;
    if (api == null || widget.code.isEmpty) return;
    try {
      final b = await api.fetchFileBytes(widget.code);
      if (mounted) setState(() => _bytes = Uint8List.fromList(b));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text('${t(context, 'image')}: $_error',
            style: textOf(context)
                .micro
                .copyWith(color: colors.mutedForeground, fontSize: 10)),
      );
    }
    final b = _bytes;
    if (b == null) {
      return Container(
        width: 120,
        height: 80,
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        decoration: BoxDecoration(
          color: colors.muted.withValues(alpha: 0.4),
          borderRadius: AppRadius.rSm,
        ),
        child: const Center(
            child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: InteractiveViewer(child: Image.memory(b)),
          ),
        ),
        child: ClipRRect(
          borderRadius: AppRadius.rSm,
          child: Image.memory(b,
              width: widget.maxWidth, fit: BoxFit.cover, cacheWidth: 640),
        ),
      ),
    );
  }
}
