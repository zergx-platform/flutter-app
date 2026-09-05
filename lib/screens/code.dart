import 'package:flutter/material.dart';

import '../i18n.dart';
import '../models.dart';
import '../store.dart';
import '../theme/app_theme.dart';
import '../widgets/code_view.dart';
import '../widgets/diff_view.dart';
import '../widgets/org_tree.dart';
import '../widgets/tree_node.dart';
import '../widgets/commit_diff_page.dart';

/// Recreates CodePage.svelte as a sliding-panel repository browser.
///
/// There are three conceptual panels:
///   1. OrgTree   — the persistent org → repo → bookmark tree (repo picker).
///   2. FileTree  — the selected repo's cached file tree (or commit log).
///   3. Content   — the selected file's highlighted content (or history/diff).
///
/// Only two adjacent panels are ever visible at once:
///   Tablet/desktop (>=1024): 1 | 2  → 2 | 3  (the tree stays, the file panel
///   slides in). No repo selected → just panel 1.
///   Phone (<1024): 1 → 2 → 3 as a single pushed column with a back button.
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

  // ---- Tablet/desktop: sliding 1|2 → 2|3 ---------------------------------

  Widget _desktop(BuildContext context) {
    final hasRepo = store.codeRepo.isNotEmpty;
    final hasFile = store.selectedFilePath != null;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.tabCode)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final panel = (constraints.maxWidth * 0.32).clamp(260.0, 390.0);
          final children = <Widget>[
            if (!hasRepo) _orgColumn(panel),
            if (hasRepo && !hasFile) ...[
              _orgColumn(panel),
              _fileColumn(panel),
            ],
            if (hasFile) ...[
              _fileColumn(panel),
              Expanded(child: _content(context)),
            ],
            const VerticalDivider(),
          ];
          // Rightmost panel stretches; leftmost panel in a pair uses [panel].
          return Row(children: children);
        },
      ),
    );
  }

  Widget _orgColumn(double panel) {
    return SizedBox(
      width: panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelHeader(context.l10n.tabCode),
          const Divider(height: 1),
          Expanded(child: OrgTree(store: store)),
        ],
      ),
    );
  }

  Widget _fileColumn(double panel) {
    return SizedBox(
      width: panel,
      child: Column(
        children: [
          _repoHeader(panelHeaderPrefix: context.l10n.files),
          const Divider(height: 1),
          Expanded(child: _treeOrCommits(context)),
        ],
      ),
    );
  }

  Widget _repoHeader({String panelHeaderPrefix = ''}) {
    final text = textOf(context);
    return Container(
      height: AppBars.height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            tooltip: context.l10n.back,
            onPressed: () => store.closeRepo(),
          ),
          Expanded(
            child: Text(
              store.codeRepo.isNotEmpty
                  ? '${store.codeOrg}/${store.codeRepo}'
                      '${store.codeBookmark.isNotEmpty ? '@${store.codeBookmark}' : ''}'
                  : panelHeaderPrefix,
              overflow: TextOverflow.ellipsis,
              style: text.meta.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: Icon(_showCommits ? Icons.folder_rounded : Icons.history_rounded,
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
    );
  }

  // ---- Phone: single pushed column 1 → 2 → 3 ------------------------------

  Widget _mobile(BuildContext context) {
    final hasRepo = store.codeRepo.isNotEmpty;
    final hasFile = store.selectedFilePath != null;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.tabCode)),
      body: hasFile
          ? _contentMobile(context)
          : hasRepo
              ? _treeOrCommits(context)
              : OrgTree(store: store),
    );
  }

  // ---- File tree / commits list ------------------------------------------

  Widget _treeOrCommits(BuildContext context) {
    return Column(
      children: [
        _repoHeader(),
        const Divider(height: 1),
        Expanded(
          child: store.codeRepo.isEmpty
              ? _emptyHint(context)
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

  Widget _emptyHint(BuildContext context) {
    final colors = colorsOf(context);
    return Center(
      child: Text(context.l10n.codeEmptyHint,
          style: TextStyle(color: colors.mutedForeground)),
    );
  }

  /// Open the full diff of a repository commit in a dedicated page.
  void _openCommitDiff(FileCommit c) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CommitDiffPage(
          api: store.api,
          org: store.codeOrg,
          repo: store.codeRepo,
          commit: c),
    ));
  }

  // ---- File content -------------------------------------------------------

  Widget _content(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    final p = store.selectedFilePath;
    if (p == null) {
      return Center(
        child: Text(
          store.codeRepo.isNotEmpty
              ? context.l10n.selectFile
              : context.l10n.selectBookmark,
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
                    onPressed: () => store.closeFileDiff())
              else ...[
                IconButton(
                    icon: Icon(
                        store.showFileHistory
                            ? Icons.description_outlined
                            : Icons.history_rounded,
                        size: 16),
                    onPressed: () {
                      if (store.showFileHistory) {
                        setState(() => store.showFileHistory = false);
                      } else {
                        store.loadFileHistory();
                      }
                    }),
                IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: () => store.stepFileBack()),
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
        return Center(child: Text(context.l10n.noHistory));
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

  Widget _panelHeader(String label) {
    final text = textOf(context);
    return Container(
      height: AppBars.height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: text.meta.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
