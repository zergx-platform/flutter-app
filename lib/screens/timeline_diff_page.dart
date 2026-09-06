import 'package:flutter/material.dart';

import '../i18n.dart';
import '../store.dart';
import '../theme/app_theme.dart';
import '../widgets/diff_view.dart';
import 'change_diff.dart';

/// Timeline drill-in page: shows the unified diff for a change_id, with a link
/// to the full-screen diff viewer. Lives in the chat overlay stack.
class TimelineDiffScreen extends StatefulWidget {
  final AppStore store;
  final String changeId;
  const TimelineDiffScreen(
      {super.key, required this.store, required this.changeId});

  @override
  State<TimelineDiffScreen> createState() => _TimelineDiffScreenState();
}

class _TimelineDiffScreenState extends State<TimelineDiffScreen> {
  AppStore get store => widget.store;
  String _diff = '';
  String _error = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = widget.store.activeSession;
    if (s == null) return;
    try {
      // change_id → current commit_id → unified diff (rebase-safe). Old
      // code called /repos/{o}/{r}/diff/{change_id} which no longer exists
      // on the jjlab that dropped that route (404 "not a git endpoint").
      final d = await widget.store.api.changeDiff(
          s.org, s.repo, widget.changeId,
          bookmark: s.bookmark);
      setState(() {
        _diff = d;
        if (d.isEmpty) _error = context.l10n.noChanges;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _openFullScreen() async {
    final s = widget.store.activeSession;
    if (s == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChangeDiffScreen(
        api: widget.store.api,
        org: s.org,
        repo: s.repo,
        changeId: widget.changeId,
        bookmark: s.bookmark,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.commit_rounded),
          title: Text('${widget.changeId.substring(0, 12)}…',
              style: textOf(context).mono),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                tooltip: context.l10n.changeDiff,
                onPressed: _openFullScreen,
              ),
              TextButton(
                  // Go back to the change list (notifies the store so both
                  // the desktop panel and the mobile overlay page rebuild).
                  onPressed: () => store.closeDiff(),
                  child: Text(context.l10n.back)),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error.isNotEmpty
                  ? Center(
                      child: Text(_error,
                          style:
                              TextStyle(color: colors.mutedForeground)))
                  : _diff.isEmpty
                      ? Center(
                          child: Text(context.l10n.noChanges,
                              style: TextStyle(
                                  color: colors.mutedForeground)))
                      : DiffView(diffText: _diff),
        ),
      ],
    );
  }
}
