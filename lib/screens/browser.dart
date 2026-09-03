import 'package:flutter/material.dart';

import '../i18n.dart';
import '../models.dart';
import '../store.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/dialogs.dart';
import '../widgets/session_row.dart';
import 'org_detail.dart';
import 'repo_detail.dart';

/// Full-screen browse + search page (WeChat-style "所有仓库" moved here).
///
/// Empty query: org → repo → bookmark tree. Org rows open [OrgDetailPage],
/// repo rows open the repo detail screen, bookmark rows pick/adopt a session.
/// Long-press exposes the destructive actions that used to live on the chat
/// sidebar tree (delete org/repo, fork bookmark).
///
/// Non-empty query: matching sessions plus matching bookmarks.
class BrowserPage extends StatefulWidget {
  final AppStore store;
  const BrowserPage({super.key, required this.store});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  AppStore get store => widget.store;
  final TextEditingController _q = TextEditingController();
  List<Session> _hits = [];
  List<(OrgNode, RepoNode, BookmarkNode)> _bmHits = [];

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
        _bmHits = [];
        return;
      }
      final all = [...store.sessions];
      all.sort((a, b) => (b.updatedAt).compareTo(a.updatedAt));
      _hits = all.where((s) {
        final hay = '${s.org}/${s.repo}/${s.branch} ${s.id}'.toLowerCase();
        return hay.contains(q);
      }).toList();
      _bmHits = [
        for (final org in store.orgs)
          for (final repo in org.repos)
            for (final bm in repo.bookmarks)
              if ('${org.org}/${repo.repo}/${bm.branch}'
                  .toLowerCase()
                  .contains(q))
                (org, repo, bm),
      ];
    });
  }

  Future<void> _refresh() async {
    await store.refreshSessions();
    await store.refreshRepos();
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
            .showSnackBar(SnackBar(content: Text(context.l10n.adoptFailed(e.toString()))));
      }
    }
  }

  Future<void> _deleteOrgFlow(String org) async {
    final ok = await confirmDialog(context,
        title: context.l10n.deleteOrgTitle,
        description: context.l10n.deleteOrgBody(org));
    if (ok) await store.deleteOrg(org);
  }

  Future<void> _deleteRepoFlow(String org, String repo) async {
    final ok = await confirmDialog(context,
        title: context.l10n.deleteRepoTitle,
        description: context.l10n.deleteRepoBody(org, repo));
    if (ok) await store.deleteRepo(org, repo);
  }

  Future<void> _forkDialog(String sessionId) async {
    final ctrl = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.fork),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: context.l10n.forkBranchLabel),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: Text(ctx.l10n.fork)),
        ],
      ),
    );
    if (r != null && r.trim().isNotEmpty) {
      final branch = r.trim();
      if (store.existingBookmarks.contains(branch)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.branchExists)));
        return;
      }
      store.activeSessionId = sessionId;
      await store.forkSession(branch);
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
          autofocus: false,
          decoration: InputDecoration(
            hintText: context.l10n.searchHint,
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
          : _searchResults(context),
    );
  }

  /// Non-empty query: matching sessions first, then matching bookmarks.
  Widget _searchResults(BuildContext context) {
    final colors = colorsOf(context);
    return ListView(
      children: [
        if (_hits.isNotEmpty) ...[
          _Header(context.l10n.recent),
          for (final s in _hits)
            SessionRow(
              session: s,
              isActive: store.activeSessionId == s.id,
              subtitle: s.org.isNotEmpty
                  ? '${s.org}/${s.repo}/${s.branch}'
                  : s.id,
              onTap: () => _pick(s),
            ),
        ],
        if (_bmHits.isNotEmpty) ...[
          _Header(context.l10n.bookmarksSection),
          for (final (org, repo, bm) in _bmHits)
            _bookmarkRow(org, repo, bm),
        ],
        if (_hits.isEmpty && _bmHits.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
                child: Text(context.l10n.noRepos,
                    style: TextStyle(color: colors.mutedForeground))),
          ),
      ],
    );
  }

  /// Empty-query view: the full org → repo → bookmark tree.
  Widget _treeResults(BuildContext context) {
    final colors = colorsOf(context);
    if (store.orgs.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                  child: Text(context.l10n.noRepos,
                      style: TextStyle(color: colors.mutedForeground))),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: store.orgs.length,
        itemBuilder: (_, i) => _orgSection(store.orgs[i]),
      ),
    );
  }

  Widget _orgSection(OrgNode org) {
    final colors = colorsOf(context);
    final text = textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => OrgDetailPage(store: store, org: org.org),
          )),
          onLongPress: () => _deleteOrgFlow(org.org),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                ChatAvatar(org: org.org, repo: '', branch: org.org, radius: 16, level: AvatarLevel.org),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(org.org,
                      style:
                          text.meta.copyWith(fontWeight: FontWeight.w600)),
                ),
                Text(context.l10n.reposCount('${org.repos.length}'),
                    style: text.micro
                        .copyWith(color: colors.mutedForeground)),
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: colors.mutedForeground),
              ],
            ),
          ),
        ),
        for (final repo in org.repos) ...[
          _repoRow(org, repo),
          for (final bm in repo.bookmarks)
            _bookmarkRow(org, repo, bm, indent: true),
        ],
        Divider(height: 1, color: colors.border.withValues(alpha: 0.4)),
      ],
    );
  }

  Widget _repoRow(OrgNode org, RepoNode repo) {
    final colors = colorsOf(context);
    final text = textOf(context);
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            RepoDetailScreen(store: store, org: org.org, repo: repo.repo),
      )),
      onLongPress: () => _deleteRepoFlow(org.org, repo.repo),
      child: Padding(
        padding: const EdgeInsets.only(
            left: AppSpacing.md + 40, right: AppSpacing.sm, top: 2, bottom: 2),
        child: Row(
          children: [
            ChatAvatar(
                org: org.org,
                repo: repo.repo,
                branch: '',
                radius: 12,
                level: AvatarLevel.repo),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
                child: Text(repo.repo,
                    overflow: TextOverflow.ellipsis, style: text.meta)),
            Icon(Icons.chevron_right_rounded,
                size: 16, color: colors.mutedForeground),
          ],
        ),
      ),
    );
  }

  Widget _bookmarkRow(OrgNode org, RepoNode repo, BookmarkNode bm,
      {bool indent = false}) {
    final colors = colorsOf(context);
    final text = textOf(context);
    final bound = bm.session != null;
    return InkWell(
      onTap: () => _openBookmark(org.org, repo.repo, bm.branch, bm.session?.sessionId),
      onLongPress: bound
          ? () => _forkDialog(bm.session!.sessionId)
          : null,
      child: Padding(
        padding: EdgeInsets.only(
            left: AppSpacing.md + (indent ? 56 : 40),
            right: AppSpacing.sm,
            top: 2,
            bottom: 2),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bound ? colors.success : colors.mutedForeground,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
                child: Text(bm.branch,
                    overflow: TextOverflow.ellipsis,
                    style: text.meta.copyWith(
                        color: bound ? null : colors.mutedForeground))),
            if (!bound)
              Icon(Icons.add_rounded, size: 15, color: colors.mutedForeground)
            else
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 14, color: colors.mutedForeground),
          ],
        ),
      ),
    );
  }

  Future<void> _openBookmark(
      String org, String repo, String branch, String? sessionId) async {
    if (sessionId != null) {
      store.pickSession(sessionId);
      Navigator.of(context).pop();
      return;
    }
    await _adopt(org, repo, branch);
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
