import 'package:flutter/material.dart';

import '../i18n.dart';

import '../models.dart';
import '../store.dart';
import '../theme/app_theme.dart';
import '../widgets/code_view.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/diff_view.dart';
import '../widgets/tree_node.dart';
import '../widgets/commit_diff_page.dart';

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

  /// Tablet/desktop: two simultaneously-visible columns — the repo's file
  /// tree (with a repo picker in its header) on the left, file content on the
  /// right. Native app feel (no three-panel browser column stack).
  Widget _desktop(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            SizedBox(
              width: (constraints.maxWidth * 0.30).clamp(240.0, 360.0),
              child: _treeOrCommits(context),
            ),
            const VerticalDivider(),
            Expanded(child: _content(context)),
          ],
        ),
      ),
    );
  }

  Widget _mobile(BuildContext context) {
    final showFile = store.selectedFilePath != null;
    final hasRepo = store.codeRepo.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _pickRepoSheet,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  showFile
                      ? store.selectedFilePath!
                      : hasRepo
                          ? '${store.codeOrg}/${store.codeRepo}'
                              '${store.codeBookmark.isNotEmpty ? '@${store.codeBookmark}' : ''}'
                          : context.l10n.tabCode,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: colorsOf(context).mutedForeground),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open_rounded, size: 20),
            tooltip: context.l10n.pickRepo,
            onPressed: _pickRepoSheet,
          ),
        ],
      ),
      body: showFile
          ? _contentMobile(context)
          : hasRepo
              ? _treeOrCommits(context)
              : _emptyPicker(context),
    );
  }

  /// Mobile has no side selector column — this sheet is the repo picker
  /// (org → repo → branch drill-down), mirroring the desktop _repoSelector.
  Future<void> _pickRepoSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: _RepoPickerSheet(store: store),
      ),
    );
  }

  Widget _emptyPicker(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_rounded,
              size: 44, color: colors.mutedForeground),
          const SizedBox(height: AppSpacing.md),
          Text(context.l10n.codeEmptyHint,
              style: text.meta.copyWith(color: colors.mutedForeground)),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: _pickRepoSheet,
            icon: const Icon(Icons.search_rounded, size: 18),
            label: Text(context.l10n.pickRepo),
          ),
        ],
      ),
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
                          '${store.codeBookmark.isNotEmpty ? '@${store.codeBookmark}' : ''}'
                      : context.l10n.files,
                  overflow: TextOverflow.ellipsis,
                  style: text.meta.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              // From the tree panel, tap to change repo (org → repo sheet)
              IconButton(
                icon: const Icon(Icons.folder_open_rounded, size: 16),
                tooltip: context.l10n.pickRepo,
                onPressed: _pickRepoSheet,
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
              ? _emptyPicker(context)
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

  Widget _content(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    final p = store.selectedFilePath;
    if (p == null) {
      return Center(
        child: Text(
          store.codeRepo.isNotEmpty
              ? context.l10n.selectFile
              : context.l10n.selectBranch,
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
                    onPressed: () => store.clearFileView()),
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
}

/// Three-level (org → repo → branch) bottom-sheet picker for the mobile
/// Code tab. Selecting a branch opens the repo in the code browser.
class _RepoPickerSheet extends StatefulWidget {
  final AppStore store;
  const _RepoPickerSheet({required this.store});

  @override
  State<_RepoPickerSheet> createState() => _RepoPickerSheetState();
}

class _RepoPickerSheetState extends State<_RepoPickerSheet> {
  String? _org;
  String? _repo;

  @override
  void initState() {
    super.initState();
    widget.store.refreshRepos();
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    final orgs = widget.store.orgs;
    Widget body;
    if (_org == null) {
      body = ListView(
        children: [
          _sheetHeader(context.l10n.pickOrg, showBack: false),
          if (orgs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                  child: Text(context.l10n.noRepos,
                      style: TextStyle(color: colors.mutedForeground))),
            ),
          for (final org in orgs)
            ListTile(
              leading: ChatAvatar(org: org.org,
                    repo: '',
                    bookmark: org.org,
                    radius: 14,
                    level: AvatarLevel.org),
              title: Text(org.org,
                  style: text.meta.copyWith(fontWeight: FontWeight.w600)),
              trailing: Text(context.l10n.reposCount('${org.repos.length}'),
                  style: text.micro
                      .copyWith(color: colors.mutedForeground)),
              onTap: () => setState(() => _org = org.org),
            ),
        ],
      );
    } else if (_repo == null) {
      final node = orgs
          .where((o) => o.org == _org!)
          .expand((o) => o.repos)
          .toList();
      body = ListView(
        children: [
          _sheetHeader('$_org', showBack: true),
          for (final repo in node)
            ListTile(
              leading: ChatAvatar(
                  org: _org!,
                  repo: repo.repo,
                  bookmark: '',
                  radius: 14,
                  level: AvatarLevel.repo),
              title: Text(repo.repo, style: text.meta),
              onTap: () => setState(() => _repo = repo.repo),
            ),
        ],
      );
    } else {
      final node = orgs
          .where((o) => o.org == _org!)
          .expand((o) => o.repos)
          .where((r) => r.repo == _repo!)
          .toList();
      body = ListView(
        children: [
          _sheetHeader('$_org/$_repo', showBack: true),
          for (final repo in node)
            for (final bm in repo.bookmarks)
              ListTile(
                leading: ChatAvatar(
                    org: _org!, repo: _repo!, bookmark: bm.bookmark, radius: 14),
                title: Text(bm.bookmark, style: text.meta),
                trailing: bm.session != null
                    ? Icon(Icons.chat_bubble_outline_rounded,
                        size: 14, color: colors.mutedForeground)
                    : null,
                onTap: () {
                  widget.store.openRepo(_org!, _repo!, bm.bookmark);
                  Navigator.pop(context);
                },
              ),
        ],
      );
    }
    return body;
  }

  Widget _sheetHeader(String label, {required bool showBack}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm,
          AppSpacing.md, AppSpacing.xs),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              onPressed: () => setState(() {
                if (_repo != null) {
                  _repo = null;
                } else {
                  _org = null;
                }
              }),
            ),
          Expanded(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: textOf(context)
                    .meta
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
