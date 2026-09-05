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
/// Only two adjacent panels are ever visible at once, each 50% wide:
///   Tablet/desktop (>=1024): 1 | 2  → 2 | 3. No repo → just panel 1.
///   Phone (<1024): 1 → 2 → 3 as a single pushed column.
///
/// The "代码" title bar is bound to interface 1 (the org tree) only, mirroring
/// the chat screen: each panel owns its own header, and there is exactly one
/// back bar on panels 2/3 (no duplicated app bar).
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

  // The "代码" title bar is bound to interface 1 (org tree). Like the chat
  // screen, only the CURRENT detail panel carries a back button, so there is
  // exactly one back bar (never a duplicated app bar + back):
  //   level 0 (no repo): [ P1 org tree ]
  //   level 1 (repo):     [ P1 org tree | P2 file list   ]
  //   level 2 (file):     [ P2 file list | P3 content    ]
  Widget _desktop(BuildContext context) {
    return Scaffold(
      body: _desktopRow(),
    );
  }

  Widget _desktopRow() {
    final hasRepo = store.codeRepo.isNotEmpty;
    final hasFile = store.selectedFilePath != null;
    // showBack on P2 is true only when P2 is the CURRENT detail panel, i.e.
    // level 1 (repo selected, no file yet). At level 2, P2 is the nav companion
    // (no back) and only P3 (content) owns a back arrow.
    final fileIsDetail = hasRepo && !hasFile;
    return Row(
      children: [
        if (!hasRepo)
          Expanded(child: _orgColumn()),
        if (hasRepo) ...[
          Expanded(child: _orgColumn()),
          Expanded(child: _fileColumn(showBack: fileIsDetail)),
        ],
        if (hasFile)
          Expanded(child: _content(context)),
      ],
    );
  }

  /// Interface 1 (org tree) — owns the "代码" title bar, no back button.
  Widget _orgColumn() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _panelHeader(context.l10n.tabCode),
          const Divider(height: 1),
          Expanded(child: OrgTree(store: store)),
        ],
      ),
    );
  }

  /// Interface 2 (file tree / commits). Every level >= 1 shows a single back
  /// arrow on this panel: at level 1 it closes the repo (→ P1), at level 2 it
  /// closes the file (→ back to 1|2). The back button ALWAYS appears when a
  /// repo is selected, so the 2|3 layout keeps its back (no duplicated bars —
  /// only [_repoHeader] is rendered here; the body is [_treeBody]).
  Widget _fileColumn({bool showBack = true}) {
    return SafeArea(
      child: Column(
        children: [
          _repoHeader(showBack: showBack, panelHeaderPrefix: context.l10n.files),
          const Divider(height: 1),
          Expanded(child: _treeBody(context)),
        ],
      ),
    );
  }

  // ---- Phone: single pushed column 1 → 2 → 3 ------------------------------

  Widget _mobile(BuildContext context) {
    final hasFile = store.selectedFilePath != null;
    final hasRepo = store.codeRepo.isNotEmpty;
    // Level 1 (org tree) shows the "代码" app bar; deeper levels show a single
    // back bar instead (no duplicated title bar on top).
    return Scaffold(
      appBar: !hasFile && !hasRepo
          ? AppBar(title: Text(context.l10n.tabCode))
          : null,
      body: SafeArea(
        child: hasFile
            ? _contentMobile(context)
            : hasRepo
                ? _treeOrCommits(context)
                : OrgTree(store: store),
      ),
    );
  }
  /// P1/P2 detail body — used inside [_fileColumn] (already has its header).
  /// Rendered as the bare content (tree or commits) with no extra bar.
  Widget _treeBody(BuildContext context) {
    if (store.codeRepo.isEmpty) return _emptyHint(context);
    if (_showCommits) return _commitsList(context);
    if (store.codeLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xs),
      children: [TreeNode(store: store, path: '')],
    );
  }

  /// Mobile (P2) — file tree level. Unlike the tablet split column, mobile
  /// renders its own header here because it is the whole screen.
  Widget _treeOrCommits(BuildContext context) {
    return Column(
      children: [
        _repoHeader(),
        const Divider(height: 1),
        Expanded(child: _treeBody(context)),
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

  // ---- File content (interface 3) ----------------------------------------

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
                  onPressed: () => store.stepFileBack(),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.insert_drive_file_outlined,
                    size: 14, color: colors.mutedForeground),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(p,
                      overflow: TextOverflow.ellipsis, style: text.mono),
                ),
                if (store.codeRepo.isNotEmpty)
                  IconButton(
                    icon: Icon(
                        store.showFileHistory
                            ? Icons.description_outlined
                            : Icons.history_rounded,
                        size: 16),
                    tooltip: context.l10n.history,
                    onPressed: () {
                      if (store.showFileHistory) {
                        setState(() => store.showFileHistory = false);
                      } else {
                        store.loadFileHistory();
                      }
                    },
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _contentBody(context, p)),
        ],
      ),
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
          const Divider(height: 1),
          Expanded(
            child: DiffView(
                diffText: store.fileDiffs[store.activeDiffChangeId] ?? ''),
          ),
        ] else ...[
          _bar(context, () => store.stepFileBack(), p),
          const Divider(height: 1),
          Expanded(child: _contentBody(context, p)),
        ],
      ],
    );
  }

  // ---- shared bars -------------------------------------------------------

  /// Panel 1 title bar (org tree) — mirrors the themed AppBar of the other tabs.
  Widget _panelHeader(String label) {
    final text = textOf(context);
    return Container(
      height: AppBars.height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      alignment: Alignment.centerLeft,
      child: Text(label,
          style: text.meta.copyWith(fontWeight: FontWeight.w600)),
    );
  }

  /// Panel 2 header: back arrow (only when it is the current detail) + repo
  /// path + history toggle.
  Widget _repoHeader({bool showBack = true, String panelHeaderPrefix = ''}) {
    final text = textOf(context);
    return Container(
      height: AppBars.height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          if (showBack)
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
          if (store.codeRepo.isNotEmpty)
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
    );
  }

  /// Simple back bar used on the phone content level.
  Widget _bar(BuildContext context, VoidCallback onBack, String label) {
    final text = textOf(context);
    return Container(
      height: AppBars.height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              onPressed: onBack),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(label,
                overflow: TextOverflow.ellipsis, style: text.meta),
          ),
        ],
      ),
    );
  }
}
