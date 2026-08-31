import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => store.refreshRepos());
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
    final wide = MediaQuery.of(context).size.width >= 1024;
    return wide ? _desktop(context) : _mobile(context);
  }

  Widget _desktop(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(width: 200, child: _repoSelector(context)),
          Container(width: 1, color: Theme.of(context).dividerColor),
          SizedBox(width: 260, child: _treeOrCommits(context)),
          Container(width: 1, color: Theme.of(context).dividerColor),
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
    return Column(
      children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          child: const Text('Repositories',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final org in store.orgs) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                  child: Text(org.org.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1)),
                ),
                for (final repo in org.repos) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 12, 2),
                    child: Row(
                      children: [
                        const Icon(Icons.folder_copy_outlined,
                            size: 12, color: Colors.lightBlue),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text(repo.repo,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  ),
                  for (final bm in repo.bookmarks)
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.only(left: 32, right: 8),
                      selected: store.codeOrg == org.org &&
                          store.codeRepo == repo.repo &&
                          store.codeBranch == bm.branch,
                      leading: const Icon(Icons.call_split, size: 14),
                      title: Text(bm.branch, style: const TextStyle(fontSize: 12)),
                      onTap: () => store.openRepo(org.org, repo.repo, bm.branch),
                    ),
                ],
              ],
              if (store.orgs.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('No repositories. Create a session first.',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _treeOrCommits(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  store.codeRepo.isNotEmpty
                      ? '${store.codeOrg}/${store.codeRepo}'
                      : 'Files',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              if (store.codeRepo.isNotEmpty)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(_showCommits ? Icons.folder : Icons.history, size: 16),
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
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline)))
              : _showCommits
                  ? _commitsList(context)
                  : store.codeLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          padding: const EdgeInsets.all(4),
                          children: [TreeNode(store: store, path: '')],
                        ),
        ),
      ],
    );
  }

  Widget _commitsList(BuildContext context) {
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
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 4,
              children: [
                for (final t in _tags)
                  Chip(
                    label: Text(t.name,
                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                    visualDensity: VisualDensity.compact,
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.commit, size: 14, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12)),
                        Text('${_short(c.commitId)} · ${c.author}',
                            style: const TextStyle(fontSize: 10)),
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
    final p = store.selectedFilePath;
    if (p == null) {
      return Center(
        child: Text(
          store.codeRepo.isNotEmpty ? 'Select a file to view' : 'Select a branch to browse files',
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      );
    }
    return Column(
      children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.insert_drive_file_outlined, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(p,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ),
              if (store.activeDiffChangeId != null)
                IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      store.activeDiffChangeId = null;
                      store.showFileHistory = false;
                    })
              else ...[
                IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(store.showFileHistory ? Icons.description : Icons.history,
                        size: 16),
                    onPressed: () {
                      if (store.showFileHistory) {
                        store.showFileHistory = false;
                      } else {
                        store.loadFileHistory();
                      }
                    }),
                IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 16),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Text(_short(c.changeId),
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.primary)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(c.message,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12))),
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
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.arrow_back, size: 18),
              onPressed: onBack),
          Expanded(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}