import 'package:flutter/material.dart';

import '../i18n.dart';
import '../models.dart';
import '../navigation.dart';
import '../store.dart';
import '../theme/app_theme.dart';
import '../widgets/tree_node.dart';
import '../widgets/commit_diff_page.dart';

/// Code tab — a repo is open (org/repo/bookmark given). Shows the file tree /
/// commit log with a back arrow to the org tree and a "code" title header.
/// Tapping a file pushes a [CodeFilePage].
class CodeRepoPageWidget extends StatefulWidget {
  final AppStore store;
  final String org;
  final String repo;
  final String bookmark;
  const CodeRepoPageWidget({
    super.key,
    required this.store,
    required this.org,
    required this.repo,
    required this.bookmark,
  });

  @override
  State<CodeRepoPageWidget> createState() => _CodeRepoPageState();
}

class _CodeRepoPageState extends State<CodeRepoPageWidget> {
  AppStore get store => widget.store;
  bool _showCommits = false;
  List<FileCommit> _commits = [];
  List<GitTag> _tags = [];
  bool _commitsLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTree());
  }

  Future<void> _loadTree() async {
    // openRepo seeds the store with the repo selection + first dir.
    await store.openRepo(widget.org, widget.repo, widget.bookmark);
    if (mounted) setState(() {});
  }

  Future<void> _loadCommits() async {
    setState(() {
      _commitsLoading = true;
      _showCommits = true;
    });
    try {
      final results = await Future.wait([
        store.api.log(widget.org, widget.repo, limit: 100),
        store.api.tags(widget.org, widget.repo),
      ]);
      _commits = results[0] as List<FileCommit>;
      _tags = results[1] as List<GitTag>;
    } catch (_) {}
    setState(() => _commitsLoading = false);
  }

  String _short(String id) => id.length > 8 ? id.substring(0, 8) : id;

  @override
  Widget build(BuildContext context) {
    final text = textOf(context);
    final title = '${widget.org}/${widget.repo}'
        '${widget.bookmark.isNotEmpty ? '@${widget.bookmark}' : ''}';
    return SafeArea(
      child: Column(
        children: [
          Container(
            height: AppBars.height,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  tooltip: context.l10n.back,
                  onPressed: () => store.popPage(),
                ),
                Expanded(
                  child: Text(title,
                      overflow: TextOverflow.ellipsis,
                      style: text.meta.copyWith(fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: Icon(
                      _showCommits ? Icons.folder_rounded : Icons.history_rounded,
                      size: 16),
                  tooltip: context.l10n.history,
                  onPressed: () {
                    if (_showCommits) {
                      setState(() => _showCommits = false);
                    } else {
                      _loadCommits();
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_showCommits) return _commitsList(context);
    if (store.codeLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xs),
      children: [TreeNode(store: store, path: '')],
    );
  }

  Widget _commitsList(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    if (_commitsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_commits.isEmpty) {
      return Center(child: Text(context.l10n.noCommits));
    }
    return ListView(
      children: [
        if (_tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final t in _tags)
                  Chip(
                    label: Text(t.name, style: text.mono.copyWith(fontSize: 10)),
                  ),
              ],
            ),
          ),
        for (final c in _commits)
          InkWell(
            onTap: () => _openCommitDiff(c),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.commit_rounded, size: 14, color: colors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.meta),
                        Text('${_short(c.commitId)} · ${c.author}',
                            style: text.micro
                                .copyWith(color: colors.mutedForeground)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _openCommitDiff(FileCommit c) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CommitDiffPage(
          api: store.api,
          org: widget.org,
          repo: widget.repo,
          commit: c),
    ));
  }
}
