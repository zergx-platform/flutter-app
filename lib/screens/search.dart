import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/session_row.dart';

/// Full-screen session search (WeChat-style). Filters the loaded session
/// list by org / repo / bookmark substring, and searches the org/repo tree
/// so tapping an unbound bookmark opens/adopts it.
class SessionSearchPage extends StatefulWidget {
  final AppStore store;
  const SessionSearchPage({super.key, required this.store});

  @override
  State<SessionSearchPage> createState() => _SessionSearchPageState();
}

class _SessionSearchPageState extends State<SessionSearchPage> {
  AppStore get store => widget.store;
  final TextEditingController _q = TextEditingController();
  List<Session> _hits = [];

  @override
  void initState() {
    super.initState();
    store.refreshSessions();
    store.refreshRepos();
    _q.addListener(_search);
  }

  @override
  void dispose() {
    _q.removeListener(_search);
    _q.dispose();
    super.dispose();
  }

  void _search() {
    final q = _q.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _hits = [];
        return;
      }
      final all = [...store.sessions];
      all.sort((a, b) => (b.updatedAt).compareTo(a.updatedAt));
      _hits = all.where((s) {
        final hay = '${s.org}/${s.repo}/${s.branch} ${s.id}'.toLowerCase();
        return hay.contains(q);
      }).toList();
    });
  }

  void _pick(Session s) {
    store.pickSession(s.id);
    Navigator.of(context).pop();
  }

  Future<void> _adopt(String org, String repo, String branch) async {
    try {
      final name = await store.api.adoptSession(org, repo, branch);
      await store.refreshRepos();
      await store.refreshSessions();
      if (mounted) store.pickSession(name);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Adopt failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: TextField(
          controller: _q,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索 org / repo / bookmark',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_q.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => _q.clear(),
            ),
        ],
      ),
      body: _q.text.trim().isEmpty
          ? _treeResults(context)
          : ListView.builder(
              itemCount: _hits.length,
              itemBuilder: (_, i) => SessionRow(
                session: _hits[i],
                isActive: store.activeSessionId == _hits[i].id,
                subtitle: _hits[i].org.isNotEmpty
                    ? '${_hits[i].org}/${_hits[i].repo}'
                    : _hits[i].id,
                onTap: () => _pick(_hits[i]),
              ),
            ),
    );
  }

  /// Empty-query view: browse the org/repo tree for searchable bookmarks.
  Widget _treeResults(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    if (store.orgs.isEmpty) {
      return Center(
          child: Text('No repositories yet.',
              style: TextStyle(color: colors.mutedForeground)));
    }
    return ListView(
      children: [
        const _Header('All repositories'),
        for (final org in store.orgs)
          for (final repo in org.repos)
            for (final bm in repo.bookmarks)
              ListTile(
                leading:
                    ChatAvatar(org: org.org, repo: repo.repo, branch: bm.branch, radius: 16),
                title: Text(bm.branch,
                    style: text.meta.copyWith(
                        fontWeight: FontWeight.w600)),
                subtitle: Text('${org.org}/${repo.repo}',
                    style:
                        text.micro.copyWith(color: colors.mutedForeground)),
                trailing: bm.session != null
                    ? Icon(Icons.call_split_rounded,
                        size: 15, color: colors.primary)
                    : Icon(Icons.add_rounded,
                        size: 15, color: colors.mutedForeground),
                onTap: () {
                  if (bm.session != null) {
                    store.pickSession(bm.session!.sessionId);
                    Navigator.of(context).pop();
                  } else {
                    _adopt(org.org, repo.repo, bm.branch);
                  }
                },
              ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
      child: Text(text.toUpperCase(),
          style: textOf(context).micro.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: colorsOf(context).mutedForeground)),
    );
  }
}
