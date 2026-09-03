import 'package:flutter/material.dart';

import '../i18n.dart';

import '../models.dart';
import '../store.dart';
import '../theme/app_theme.dart';
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
  void initState() {
    super.initState();
    // The Files overlay is always bound to the ACTIVE session's repository
    // (web: store.openRepo on the files overlay). This never touches the
    // independent Code tab's own selection.
    final s = store.activeSession;
    if (s != null && (store.codeOrg != s.org || store.codeRepo != s.repo)) {
      store.openRepo(s.org, s.repo, s.branch);
    }
  }

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
              icon: Icon(
                  store.showFileHistory
                      ? Icons.description_outlined
                      : Icons.history_rounded,
                  size: 16),
              tooltip: context.l10n.history,
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
        _filesHeader(
          context,
          label: store.codeRepo.isNotEmpty
              ? '${store.codeOrg}/${store.codeRepo}'
              : context.l10n.files,
          // Root level: no back arrow (drill-in only), matching FilesPage.
          showBack: false,
        ),
        Expanded(
          child: store.codeLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  children: [TreeNode(store: store, path: '')],
                ),
        ),
      ],
    );
  }

  Widget _history(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    if (store.fileHistoryLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (store.fileHistory.isEmpty) {
      return Center(
          child: Text(context.l10n.noHistory,
              style: TextStyle(color: colors.mutedForeground)));
    }
    final commits = store.fileHistory;
    return ListView(
      children: [
        for (final c in commits)
          InkWell(
            onTap: () => store.toggleCommitDiff(c.changeId),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Text(c.changeId.substring(0, 10),
                      style: text.mono.copyWith(
                          fontSize: 11, color: colors.primary)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                        c.message.isNotEmpty ? c.message : context.l10n.noDescription,
                        overflow: TextOverflow.ellipsis,
                        style: text.meta),
                  ),
                  Text(c.author,
                      style: text.micro.copyWith(color: colors.mutedForeground)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _filesHeader(BuildContext context,
      {required String label, Widget? trailing, bool showBack = true}) {
    final text = textOf(context);
    // Web's FilesPage shows the back arrow only at drill-in levels
    // (a selected file or an open diff), never at the tree root.
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              onPressed: () => store.stepFileBack(),
            ),
          Expanded(
            child: Text(label,
                overflow: TextOverflow.ellipsis, style: text.mono),
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
    final colors = colorsOf(context);
    final text = textOf(context);
    if (_todos.isEmpty) {
      return Center(
          child: Text(context.l10n.noTodosYet,
              style: TextStyle(color: colors.mutedForeground, fontSize: 12)));
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        for (final t in _todos)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_todoIcon(t.status),
                    size: 14, color: _todoColor(t.status, colors)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    t.content,
                    style: text.meta.copyWith(
                        decoration: (t.status == 'completed' ||
                                t.status == 'cancelled')
                            ? TextDecoration.lineThrough
                            : null,
                        color: (t.status == 'completed' ||
                                t.status == 'cancelled')
                            ? colors.mutedForeground
                            : null),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  IconData _todoIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle_rounded;
      case 'in_progress':
        return Icons.radio_button_checked_rounded;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.radio_button_unchecked_rounded;
    }
  }

  Color _todoColor(String status, AppColors colors) {
    switch (status) {
      case 'completed':
        return colors.success;
      case 'in_progress':
        return colors.warning;
      case 'cancelled':
        return colors.mutedForeground;
      default:
        return colors.mutedForeground;
    }
  }
}
