import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme/app_theme.dart';
import '../widgets/code_view.dart';
import '../widgets/diff_view.dart';
import '../widgets/tree_node.dart';

/// Recreates CodePage.svelte: 3-panel repository browser (org/repo/branch,
/// file tree or commits, file content with history/diff).
class CodeScreen extends StatefulWidget {
  final AppStore store;
  const CodeScreen({super.key, required this.store});

  @override
  State<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends State<CodeScreen> {
  AppStore get store => widget.store;
  bool _showCommits = false;
  List<FileCommit> _commits = [];
  List<GitTag> _tags = [];
  bool _commitsLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureRepos());
  }

  Future<void> _ensureRepos() async {
    if (store.orgs.isEmpty) await store.refreshRepos();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadCommits() async {
    if (store.codeOrg.isEmpty || store.codeRepo.isEmpty) return;
    setState(() {
      _commitsLoading = true;
      _showCommits = true;
    });
    try {
      final results = await Future.wait([
        store.api.log(store.codeOrg, store.codeRepo, limit: 100),
        store.api.tags(store.codeOrg, store.codeRepo),
      ]);
      _commits = results[0] as List<FileCommit>;
      _tags = results[1] as List<GitTag>;
    } catch (_) {}
    setState(() => _commitsLoading = false);
  }

  String _short(String id) => id.length > 8 ? id.substring(0, 8) : id;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    return wide ? _desktop(context) : _mobile(context);
  }

  Widget _desktop(BuildContext context) {
    final colors = colorsOf(context);
    return Scaffold(
      body: Row(
        children: [
          SizedBox(width: 200, child: _repoSelector(context)),
          Container(width: 1, color: colors.border.withValues(alpha: 0.5)),
          SizedBox(width: 260, child: _treeOrCommits(context)),
          Container(width: 1, color: colors.border.withValues(alpha: 0.5)),
          Expanded(child: _content(context)),
        ],
      ),
    );
  }

  Widget _mobile(BuildContext context) {
    final showFile = store.selectedFilePath != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(showFile
            ? store.selectedFilePath!
            : store.codeRepo.isNotEmpty
                ? '${store.codeOrg}/${store.codeRepo}'
                : 'Code'),
      ),
      body: showFile ? _contentMobile(context) : _treeOrCommits(context),
    );
  }

  Widget _repoSelector(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    return Column(
      children: [
        Container(
          height: AppBars.height,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          alignment: Alignment.centerLeft,
          child: Text('Repositories',
              style: text.meta.copyWith(fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final org in store.orgs) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.sm, AppSpacing.md, 2),
                  child: Text(org.org.toUpperCase(),
                      style: text.micro.copyWith(
                          fontWeight: FontWeight.w600, letterSpacing: 1)),
                ),
                for (final repo in org.repos) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        20, AppSpacing.xs, AppSpacing.md, 2),
                    child: Row(
                      children: [
                        Icon(Icons.folder_copy_outlined,
                            size: 12, color: colors.primary),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                            child: Text(repo.repo,
                                overflow: TextOverflow.ellipsis,
                                style: text.meta)),
                      ],
                    ),
                  ),
                  for (final bm in repo.bookmarks)
                    ListTile(
                      selected: store.codeOrg == org.org &&
                          store.codeRepo == repo.repo &&
                          store.codeBranch == bm.branch,
                      selectedTileColor: colors.primary.withValues(alpha: 0.10),
                      contentPadding: const EdgeInsets.only(
                          left: 32, right: AppSpacing.sm),
                      leading: Icon(Icons.call_split_rounded,
                          size: 14,
                          color: colors.mutedForeground),
                      title: Text(bm.branch, style: text.meta),
                      onTap: () =>
                          store.openRepo(org.org, repo.repo, bm.branch),
                    ),
                ],
              ],
              if (store.orgs.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text('No repositories. Create a session first.',
                      style: TextStyle(color: colors.mutedForeground)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _treeOrCommits(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    return Column(
      children: [
        Container(
          height: AppBars.height,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  store.codeRepo.isNotEmpty
                      ? '${store.codeOrg}/${store.codeRepo}'
                      : 'Files',
                  overflow: TextOverflow.ellipsis,
                  style: text.meta.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (store.codeRepo.isNotEmpty)
                IconButton(
                  icon: Icon(_showCommits ? Icons.folder_rounded : Icons.history_rounded,
                      size: 16),
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
        Expanded(
          child: store.codeRepo.isEmpty
              ? Center(
                  child: Text('Select a repository',
                      style: TextStyle(color: colors.mutedForeground)))
              : _showCommits
                  ? _commitsList(context)
                  : store.codeLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          children: [TreeNode(store: store, path: '')],
                        ),
        ),
      ],
    );
  }

  Widget _commitsList(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    if (_commitsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_commits.isEmpty) {
      return const Center(child: Text('No commits'));
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
            onTap: () {
              setState(() => _showCommits = false);
              store.selectedFilePath = null;
              store.fileContent = '';
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.commit_rounded,
                      size: 14, color: colors.primary),
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

  Widget _content(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    final p = store.selectedFilePath;
    if (p == null) {
      return Center(
        child: Text(
          store.codeRepo.isNotEmpty
              ? 'Select a file to view'
              : 'Select a branch to browse files',
          style: TextStyle(color: colors.mutedForeground),
        ),
      );
    }
    return Column(
      children: [
        Container(
          height: AppBars.height,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.insert_drive_file_outlined,
                  size: 14, color: colors.mutedForeground),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(p,
                    overflow: TextOverflow.ellipsis, style: text.mono),
              ),
              if (store.activeDiffChangeId != null)
                IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: () {
                      store.activeDiffChangeId = null;
                      store.showFileHistory = false;
                    })
              else ...[
                IconButton(
                    icon: Icon(
                        store.showFileHistory
                            ? Icons.description_outlined
                            : Icons.history_rounded,
                        size: 16),
                    onPressed: () {
                      if (store.showFileHistory) {
                        store.showFileHistory = false;
                      } else {
                        store.loadFileHistory();
                      }
                    }),
                IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: () {
                      store.selectedFilePath = null;
                      store.fileContent = '';
                      store.showFileHistory = false;
                      store.activeDiffChangeId = null;
                    }),
              ],
            ],
          ),
        ),
        Expanded(child: _contentBody(context, p)),
      ],
    );
  }

  Widget _contentBody(BuildContext context, String p) {
    final colors = colorsOf(context);
    final text = textOf(context);
    if (store.activeDiffChangeId != null) {
      return DiffView(diffText: store.fileDiffs[store.activeDiffChangeId] ?? '');
    }
    if (store.showFileHistory) {
      if (store.fileHistoryLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (store.fileHistory.isEmpty) {
        return const Center(child: Text('No changes for this file'));
      }
      return ListView(
        children: [
          for (final c in store.fileHistory)
            InkWell(
              onTap: () => store.toggleCommitDiff(c.changeId),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Text(_short(c.changeId),
                        style: text.mono.copyWith(
                            fontSize: 11, color: colors.primary)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                        child: Text(c.message,
                            overflow: TextOverflow.ellipsis,
                            style: text.meta)),
                  ],
                ),
              ),
            ),
        ],
      );
    }
    return CodeView(code: store.fileContent, filepath: p);
  }

  Widget _contentMobile(BuildContext context) {
    final p = store.selectedFilePath!;
    return Column(
      children: [
        if (store.activeDiffChangeId != null) ...[
          _bar(context, () {
            store.activeDiffChangeId = null;
            store.showFileHistory = false;
          }, '$p — ${store.activeDiffChangeId!.substring(0, 8)}'),
          Expanded(
            child: DiffView(
                diffText: store.fileDiffs[store.activeDiffChangeId] ?? ''),
          ),
        ] else ...[
          _bar(context, () => store.stepFileBack(), p),
          Expanded(child: _contentBody(context, p)),
        ],
      ],
    );
  }

  Widget _bar(BuildContext context, VoidCallback onBack, String label) {
    final text = textOf(context);
    return SizedBox(
      height: AppBars.height,
      child: Row(
        children: [
          IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              onPressed: onBack),
          Expanded(
            child: Text(label,
                overflow: TextOverflow.ellipsis, style: text.meta),
          ),
        ],
      ),
    );
  }
}
