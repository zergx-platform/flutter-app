import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../widgets/code_view.dart';
import '../widgets/diff_view.dart';
import '../widgets/tree_node.dart';

/// Recreates FilesPage.svelte: file tree drill-in with history/diff.
class FilesOverlay extends StatefulWidget {
  final AppStore store;
  const FilesOverlay({super.key, required this.store});

  @override
  State<FilesOverlay> createState() => _FilesOverlayState();
}

class _FilesOverlayState extends State<FilesOverlay> {
  AppStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    if (store.activeDiffChangeId != null && store.selectedFilePath != null) {
      return Column(
        children: [
          _filesHeader(context,
              label:
                  '${store.selectedFilePath} · ${store.activeDiffChangeId!.substring(0, 10)}'),
          Expanded(
            child: DiffView(
                diffText: store.fileDiffs[store.activeDiffChangeId] ?? ''),
          ),
        ],
      );
    }
    if (store.selectedFilePath != null) {
      return Column(
        children: [
          _filesHeader(
            context,
            label: store.selectedFilePath!,
            trailing: IconButton(
              icon: Icon(store.showFileHistory ? Icons.description : Icons.history,
                  size: 16),
              tooltip: 'History',
              onPressed: () {
                if (store.showFileHistory) {
                  store.showFileHistory = false;
                } else {
                  store.loadFileHistory();
                }
              },
            ),
          ),
          Expanded(
            child: store.showFileHistory
                ? _history(context)
                : CodeView(
                    code: store.fileContent,
                    filepath: store.selectedFilePath!),
          ),
        ],
      );
    }
    return Column(
      children: [
        _filesHeader(context,
            label: store.codeRepo.isNotEmpty
                ? '${store.codeOrg}/${store.codeRepo}'
                : 'Files'),
        Expanded(
          child: store.codeLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(8),
                  children: [TreeNode(store: store, path: '')],
                ),
        ),
      ],
    );
  }

  Widget _history(BuildContext context) {
    if (store.fileHistoryLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (store.fileHistory.isEmpty) {
      return Center(
          child: Text('No history for this file.',
              style: TextStyle(color: Theme.of(context).colorScheme.outline)));
    }
    final commits = store.fileHistory;
    return ListView(
      children: [
        for (final c in commits)
          InkWell(
            onTap: () => store.toggleCommitDiff(c.changeId),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Text(c.changeId.substring(0, 10),
                      style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(c.message.isNotEmpty ? c.message : '(no description)',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12)),
                  ),
                  Text(c.author,
                      style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.outline)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _filesHeader(BuildContext context,
      {required String label, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.arrow_back, size: 18),
            onPressed: () => store.stepFileBack(),
          ),
          Expanded(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Recreates the todos overlay (in-chat panel).
class TodosOverlay extends StatefulWidget {
  final AppStore store;
  const TodosOverlay({super.key, required this.store});

  @override
  State<TodosOverlay> createState() => _TodosOverlayState();
}

class _TodosOverlayState extends State<TodosOverlay> {
  AppStore get store => widget.store;
  List<Todo> _todos = [];
  int _rev = -1;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    _load();
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (store.sessionRevision != _rev) {
      _rev = store.sessionRevision;
      _load();
    }
  }

  Future<void> _load() async {
    final sid = store.activeSessionId;
    if (sid == null) return;
    try {
      final t = await store.api.todos(sid);
      if (mounted) setState(() => _todos = t);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_todos.isEmpty) {
      return Center(
          child: Text('No todos yet — the agent tracks its plan here via todowrite.',
              style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final t in _todos)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_todoIcon(t.status), size: 14, color: _todoColor(t.status)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  t.content,
                  style: TextStyle(
                      fontSize: 12,
                      decoration: (t.status == 'completed' ||
                              t.status == 'cancelled')
                          ? TextDecoration.lineThrough
                          : null),
                ),
              ),
            ],
          ),
      ],
    );
  }

  IconData _todoIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.radio_button_checked;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  Color _todoColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.amber;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}