import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../widgets/dialogs.dart';

/// Recreates ChatSidebar.svelte: recent sessions + org/repo/bookmark tree.
class ChatSidebar extends StatefulWidget {
  final AppStore store;
  const ChatSidebar({super.key, required this.store});

  @override
  State<ChatSidebar> createState() => _ChatSidebarState();
}

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
      final at = DateTime.tryParse(a.updatedAt)?.millisecondsSinceEpoch ?? 0;
      final bt = DateTime.tryParse(b.updatedAt)?.millisecondsSinceEpoch ?? 0;
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
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: OutlinedButton.icon(
            onPressed: () async {
              final name = await promptDialog(context,
                  title: 'New organization', label: 'Organization name');
              if (name != null && name.trim().isNotEmpty) {
                try {
                  await store.api.ensureOrg(name.trim());
                  await store.refreshRepos();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              }
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New organization'),
          ),
        ),
        if (_recent.isNotEmpty) ...[
          const _Header('Recent'),
          for (final s in _recent) _sessionRow(s),
        ],
        const _Header('All repositories'),
        for (final org in store.orgs) _orgNode(org),
        if (store.orgs.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('No repositories. Create a session first.',
                style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          ),
      ],
    );
  }

  Widget _sessionRow(Session s) {
    final isActive = store.activeSessionId == s.id;
    return ListTile(
      dense: true,
      selected: isActive,
      leading: const Icon(Icons.history, size: 16),
      title: Text(
        s.org.isNotEmpty ? '${s.org}/${s.repo}/${s.branch}' : s.id,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: (s.unread ?? 0) > 0 && !isActive
          ? CircleAvatar(
              radius: 9,
              backgroundColor: Colors.red,
              child: Text('${s.unread}', style: const TextStyle(fontSize: 10)),
            )
          : null,
      onTap: () => store.pickSession(s.id),
    );
  }

  Widget _orgNode(OrgNode org) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          dense: true,
          leading: const Icon(Icons.business, size: 16),
          title: Text(org.org,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          trailing: org.repos.isEmpty
              ? IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  onPressed: () async {
                    final ok = await confirmDialog(context,
                        title: 'Delete organization',
                        description:
                            'Delete organization ${org.org}? This removes all its repos and sessions.');
                    if (ok) await store.deleteOrg(org.org);
                  },
                )
              : const SizedBox(width: 16),
        ),
        for (final repo in org.repos) _repoNode(org, repo),
      ],
    );
  }

  Widget _repoNode(OrgNode org, RepoNode repo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 24, right: 8),
          leading: const Icon(Icons.folder_copy_outlined,
              size: 16, color: Colors.lightBlue),
          title: Text(repo.repo, style: const TextStyle(fontSize: 12)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add, size: 14),
                tooltip: 'New repo',
                onPressed: () async {
                  final name = await promptDialog(context,
                      title: 'New repo in ${org.org}', label: 'Repo name');
                  if (name != null && name.trim().isNotEmpty) {
                    await store.api.ensureRepo(org.org, name.trim());
                    await store.refreshRepos();
                    await store.refreshSessions();
                  }
                },
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.download, size: 14),
                tooltip: 'Clone repo',
                onPressed: () => _cloneDialog(org.org),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, size: 14),
                tooltip: 'Delete repo',
                onPressed: () async {
                  final ok = await confirmDialog(context,
                      title: 'Delete repo',
                      description:
                          'Delete repo ${org.org}/${repo.repo}? This removes all its sessions.');
                  if (ok) await store.deleteRepo(org.org, repo.repo);
                },
              ),
            ],
          ),
        ),
        for (final bm in repo.bookmarks)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 40, right: 8),
            leading: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bm.session != null
                    ? Colors.green
                    : Theme.of(context).colorScheme.outline,
              ),
            ),
            title: Text(bm.branch,
                style: TextStyle(
                    fontSize: 12,
                    color: bm.session == null
                        ? Theme.of(context).colorScheme.outline
                        : null)),
            trailing: bm.session != null
                ? IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.call_split, size: 14),
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

  Future<void> _cloneDialog(String org) async {
    final urlCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final tokenCtrl = TextEditingController();
    final revCtrl = TextEditingController();
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clone into $org'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(labelText: 'Git URL')),
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Repo name')),
              TextField(
                  controller: tokenCtrl,
                  decoration: const InputDecoration(labelText: 'Access token (optional)')),
              TextField(
                  controller: revCtrl,
                  decoration: const InputDecoration(labelText: 'Branch / tag / commit (optional)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clone'),
          ),
        ],
      ),
    );
    if (r == true) {
      final url = urlCtrl.text.trim();
      final name = nameCtrl.text.trim();
      if (url.isNotEmpty && name.isNotEmpty) {
        try {
          await store.api.cloneRepo(
            org,
            name,
            url,
            tokenCtrl.text.trim().isEmpty ? null : tokenCtrl.text.trim(),
            revCtrl.text.trim().isEmpty ? null : revCtrl.text.trim(),
          );
          await store.refreshRepos();
          await store.refreshSessions();
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Clone failed: $e')));
        }
      }
    }
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Fork')),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(text.toUpperCase(),
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: Theme.of(context).colorScheme.outline)),
    );
  }
}