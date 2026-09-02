import '../api.dart';
import '../i18n.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/diff_view.dart';
import 'package:flutter/material.dart';

/// Full-diff viewer for a single repository commit (Code tab commits list).
class CommitDiffPage extends StatefulWidget {
  final ZergxApi api;
  final String org;
  final String repo;
  final FileCommit commit;
  const CommitDiffPage(
      {super.key,
      required this.api,
      required this.org,
      required this.repo,
      required this.commit});

  @override
  State<CommitDiffPage> createState() => _CommitDiffPageState();
}

class _CommitDiffPageState extends State<CommitDiffPage> {
  List<DiffFile> _files = [];
  String _error = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final f =
          await widget.api.diffChange(widget.org, widget.repo, widget.commit.changeId);
      if (!mounted) return;
      setState(() {
        _files = f;
        if (f.isEmpty) _error = t(context, 'noChanges');
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
    final c = widget.commit;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          c.message.isNotEmpty ? c.message : c.commitId.substring(0, 8),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Text(_error,
                      style: TextStyle(color: colors.mutedForeground)))
              : ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (_, i) {
                    final f = _files[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm),
                          child: Text(f.path,
                              style: text.mono.copyWith(
                                  fontSize: 12, color: colors.primary)),
                        ),
                        if (f.diffText != null && f.diffText!.isNotEmpty)
                          DiffView(diffText: f.diffText!),
                        Divider(height: 1, color: colors.border),
                      ],
                    );
                  },
                ),
    );
  }
}
