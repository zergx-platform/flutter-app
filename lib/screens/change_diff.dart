import 'package:flutter/material.dart';

import '../api.dart';
import '../i18n.dart';
import '../theme/app_theme.dart';
import '../widgets/diff_view.dart';

/// Change comparison screen. A change_id is a STABLE snapshot anchor (unlike
/// a commit, which a rebase can rewrite); we resolve it to the change's
/// CURRENT commit and fetch that commit's unified diff (jj `show` — before/
/// after of everything this change touched). Renders a file list + per-file
/// diff.
class ChangeDiffScreen extends StatefulWidget {
  final ZergxApi api;
  final String org;
  final String repo;
  final String changeId;
  final String branch;
  const ChangeDiffScreen({
    super.key,
    required this.api,
    required this.org,
    required this.repo,
    required this.changeId,
    this.branch = '',
  });

  @override
  State<ChangeDiffScreen> createState() => _ChangeDiffScreenState();
}

class _ChangeDiffScreenState extends State<ChangeDiffScreen> {
  String _diff = '';
  String _error = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final d = await widget.api.changeDiff(
          widget.org, widget.repo, widget.changeId,
          branch: widget.branch);
      if (!mounted) return;
      setState(() {
        _diff = d;
        if (d.isEmpty) _error = t(context, 'noChanges');
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.changeId.substring(0, 12)}…',
            style: text.mono),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: t(context, 'refresh'),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error,
                          style: TextStyle(color: colors.destructive)),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                          onPressed: _load,
                          child: Text(t(context, 'back'))),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs),
                      child: Row(
                        children: [
                          Icon(Icons.commit_rounded,
                              size: 14, color: colors.primary),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                                '${widget.org}/${widget.repo}',
                                overflow: TextOverflow.ellipsis,
                                style: text.micro),
                          ),
                          Text(
                            '${widget.changeId.substring(0, 12)}…',
                            style: text.micro
                                .copyWith(color: colors.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1,
                        color: colors.border.withValues(alpha: 0.4)),
                    Expanded(
                      child: _diff.isEmpty
                          ? Center(
                              child: Text(t(context, 'noChanges'),
                                  style: TextStyle(
                                      color: colors.mutedForeground)))
                          : DiffView(diffText: _diff),
                    ),
                  ],
                ),
    );
  }
}
