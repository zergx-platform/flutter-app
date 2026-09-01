import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import 'tool_icon.dart';

/// Recreates ToolPartView.svelte: a collapsible tool-call card.
class ToolPartView extends StatefulWidget {
  final ChatPart part;
  final bool isStreaming;
  final void Function(String changeId)? onOpenChange;
  const ToolPartView({
    super.key,
    required this.part,
    this.isStreaming = false,
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

  String inputSummary(String t, Map<String, dynamic> inp) {
    final jobId = _s(inp['job_id']);
    switch (t) {
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
      default:
        return browserSummary(t, inp);
    }
  }

  String browserSummary(String t, Map<String, dynamic> inp) {
    final el = _s(inp['element']);
    final url = _s(inp['url']);
    switch (t) {
      case 'browser-navigate':
        return 'navigate $url';
      case 'browser-navigate-back':
        return 'navigate back';
      case 'browser-click':
        return 'click $el';
      case 'browser-type':
        return 'type $el';
      case 'browser-snapshot':
        return 'snapshot';
      case 'browser-take-screenshot':
        return 'screenshot';
      default:
        return '';
    }
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
                  Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: colors.mutedForeground,
                  ),
                  if (changeId != null && widget.onOpenChange != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    InkWell(
                      onTap: () => widget.onOpenChange!(changeId!),
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
    final summary = inputSummary(tool, input);
    if (tool == 'sandbox-run' && input['command'] is String) {
      children.add(_code(context, '\$ ${input['command']}'));
    } else if (input['path'] is String &&
        (tool == 'read' || tool == 'write' || tool == 'edit')) {
      children.add(_code(context, input['path'] as String));
    } else if (input['pattern'] is String && tool == 'grep') {
      children.add(_code(context, 'grep ${input['pattern']}'));
    } else if (summary.isNotEmpty) {
      children.add(_code(context, '$tool $summary'));
    }
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
        child: Text('running...',
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
