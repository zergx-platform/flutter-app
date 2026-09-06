import 'package:flutter/material.dart';

import '../i18n.dart';
import '../store.dart';
import '../theme/app_theme.dart';
import '../widgets/code_view.dart';
import '../widgets/diff_view.dart';

/// Code tab — a file's content (highlighted) with history/diff. [path] is the
/// file to show; the store may not have loaded it yet, so this page loads it
/// on mount.
class CodeFilePageWidget extends StatefulWidget {
  final AppStore store;
  final String path;
  const CodeFilePageWidget({super.key, required this.store, required this.path});

  @override
  State<CodeFilePageWidget> createState() => _CodeFilePageState();
}

class _CodeFilePageState extends State<CodeFilePageWidget> {
  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (store.codeOrg.isEmpty || store.codeRepo.isEmpty) return;
    await store.openFile(widget.path);
    if (mounted) setState(() {});
  }

  String _short(String id) => id.length > 8 ? id.substring(0, 8) : id;

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    final p = store.selectedFilePath ?? widget.path;
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
                Icon(Icons.insert_drive_file_outlined,
                    size: 14, color: colors.mutedForeground),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(p, overflow: TextOverflow.ellipsis, style: text.mono),
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
          Expanded(child: _body(context, p)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, String p) {
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
}
