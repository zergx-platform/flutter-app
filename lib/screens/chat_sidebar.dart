import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/dialogs.dart';
import '../widgets/session_row.dart';

/// Recreates ChatSidebar.svelte: recent sessions (IM-style rows with
/// avatars, relative time, preview, unread badge) + the org/repo tree.
class ChatSidebar extends StatefulWidget {
  final AppStore store;
  const ChatSidebar({super.key, required this.store});

  @override
  State<ChatSidebar> createState() => _ChatSidebarState();
}

/// Indent ladder for the repo tree: org=16, repo=32, bookmark=48.
const _treeIndent = <double>[16, 32, 48];

class _ChatSidebarState extends State<ChatSidebar> {
  AppStore get store => widget.store;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.refreshSessions();
      store.refreshRepos();
    });
  }

  List<Session> get _recent {
    final s = [...store.sessions];
    s.sort((a, b) {
      final at =
          DateTime.tryParse(a.lastMessageAt.isNotEmpty ? a.lastMessageAt : a.updatedAt)
                  ?.millisecondsSinceEpoch ??
              0;
      final bt =
          DateTime.tryParse(b.lastMessageAt.isNotEmpty ? b.lastMessageAt : b.updatedAt)
                  ?.millisecondsSinceEpoch ??
              0;
      return bt - at;
    });
    return s;
  }

  Future<void> _openBookmark(
      String org, String repo, String branch, String? sessionId) async {
    if (sessionId != null) {
      store.pickSession(sessionId);
      return;
    }
    try {
      final name = await store.api.adoptSession(org, repo, branch);
      await store.refreshRepos();
      await store.refreshSessions();
      store.pickSession(name);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Adopt failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    return ListView(
      // WeChat-style: remove the flat "New organization" button (creation is
      // the AppBar "+" now); the tree sits flush without side padding.
      padding: EdgeInsets.zero,
      children: [
        if (_recent.isNotEmpty) ...[
          const _Header('Recent'),
          for (final s in _recent) _sessionRow(s),
        ],
        const _Header('All repositories'),
        for (final org in store.orgs) _orgNode(org),
        if (store.orgs.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text('No repositories. Create a session first.',
                style: TextStyle(color: colors.mutedForeground)),
          ),
      ],
    );
  }

  Widget _sessionRow(Session s) {
    final isActive = store.activeSessionId == s.id;
    final preview = s.lastMessagePreview.isNotEmpty
        ? s.lastMessagePreview
        : (s.org.isNotEmpty ? '${s.org}/${s.repo}/${s.branch}' : s.id);
    return SessionRow(
      session: s,
      isActive: isActive,
      subtitle: preview,
      onTap: () => store.pickSession(s.id),
    );
  }

  Widget _orgNode(OrgNode org) {
    final colors = colorsOf(context);
    final text = textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          leading: ChatAvatar(
              org: org.org, repo: '', branch: org.org, radius: 14),
          title: Text(org.org,
              style: text.meta.copyWith(fontWeight: FontWeight.w600)),
          trailing: IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                size: 16, color: colors.mutedForeground),
            tooltip: 'Delete organization',
            onPressed: () async {
              final ok = await confirmDialog(context,
                  title: 'Delete organization',
                  description:
                      'Delete organization ${org.org}? This removes all its repos and sessions.');
              if (ok) await store.deleteOrg(org.org);
            },
          ),
        ),
        for (final repo in org.repos) _repoNode(org, repo),
      ],
    );
  }

  Widget _repoNode(OrgNode org, RepoNode repo) {
    final colors = colorsOf(context);
    final text = textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.only(
              left: AppSpacing.md + _treeIndent[1], right: AppSpacing.sm),
          leading:
              Icon(Icons.folder_copy_outlined, size: 16, color: colors.primary),
          title: Text(repo.repo, style: text.meta),
          trailing:
              // Repo-scoped actions: delete this repo (its branches follow).
              IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                size: 15, color: colors.mutedForeground),
            tooltip: 'Delete repo',
            onPressed: () async {
              final ok = await confirmDialog(context,
                  title: 'Delete repo',
                  description:
                      'Delete repo ${org.org}/${repo.repo}? This removes all its sessions.');
              if (ok) await store.deleteRepo(org.org, repo.repo);
            },
          ),
        ),
        for (final bm in repo.bookmarks)
          ListTile(
            contentPadding: EdgeInsets.only(
                left: AppSpacing.md + _treeIndent[2], right: AppSpacing.sm),
            leading: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bm.session != null
                    ? colors.success
                    : colors.mutedForeground,
              ),
            ),
            title: Text(bm.branch,
                style: text.meta.copyWith(
                    color: bm.session == null ? colors.mutedForeground : null)),
            trailing: bm.session != null
                ? IconButton(
                    icon: const Icon(Icons.call_split_rounded, size: 15),
                    tooltip: 'Fork',
                    onPressed: () => _forkDialog(bm.session!.sessionId),
                  )
                : null,
            onTap: () => _openBookmark(
                org.org, repo.repo, bm.branch, bm.session?.sessionId),
          ),
      ],
    );
  }

  Future<void> _forkDialog(String sessionId) async {
    final ctrl = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fork Session'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Branch name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Fork')),
        ],
      ),
    );
    if (r != null && r.trim().isNotEmpty) {
      final branch = r.trim();
      if (store.existingBookmarks.contains(branch)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Branch already exists')));
        return;
      }
      store.activeSessionId = sessionId;
      await store.forkSession(branch);
    }
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
