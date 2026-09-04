import 'package:flutter/material.dart';

import '../i18n.dart';
import '../models.dart';
import '../store.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/dialogs.dart';
import 'repo_detail.dart';

/// Organization detail: repos list with navigation to repo detail, plus
/// org-scoped actions (new repo / delete org).
class OrgDetailPage extends StatefulWidget {
  final AppStore store;
  final String org;
  const OrgDetailPage({super.key, required this.store, required this.org});

  @override
  State<OrgDetailPage> createState() => _OrgDetailPageState();
}

class _OrgDetailPageState extends State<OrgDetailPage> {
  AppStore get store => widget.store;

  OrgNode? get _node {
    for (final o in store.orgs) {
      if (o.org == widget.org) return o;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    store.refreshRepos();
  }

  Future<void> _newRepo() async {
    final name = await promptDialog(context,
        title: context.l10n.newRepoIn(widget.org),
        label: context.l10n.repoNameLabel);
    if (name != null && name.trim().isNotEmpty) {
      try {
        await store.api.ensureRepo(widget.org, name.trim());
        await store.refreshRepos();
        await store.refreshSessions();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.failed(e.toString()))));
        }
      }
    }
  }

  Future<void> _deleteOrg() async {
    final ok = await confirmDialog(context,
        title: context.l10n.deleteOrgTitle,
        description: context.l10n.deleteOrgBody(widget.org));
    if (ok) {
      await store.deleteOrg(widget.org);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    final node = _node;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.org),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: context.l10n.newRepoInOrg,
            onPressed: _newRepo,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                color: colors.destructive),
            tooltip: context.l10n.deleteOrgTitle,
            onPressed: _deleteOrg,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: store.refreshRepos,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  ChatAvatar(
                      org: widget.org,
                      repo: '',
                      bookmark: widget.org,
                      radius: 28,
                      level: AvatarLevel.org),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.org,
                          style: text.body
                              .copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                          context.l10n.reposCount('${node?.repos.length ?? 0}'),
                          style: text.micro
                              .copyWith(color: colors.mutedForeground)),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.border.withValues(alpha: 0.4)),
            if (node == null || node.repos.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                    child: Text(context.l10n.noRepos,
                        style: TextStyle(color: colors.mutedForeground))),
              )
            else
              for (final repo in node.repos)
                ListTile(
                  leading: ChatAvatar(
                      org: widget.org,
                      repo: repo.repo,
                      bookmark: '',
                      radius: 16,
                      level: AvatarLevel.repo),
                  title: Text(repo.repo, style: text.meta),
                  trailing: Icon(Icons.chevron_right_rounded,
                      size: 18, color: colors.mutedForeground),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => RepoDetailScreen(
                        store: store, org: widget.org, repo: repo.repo),
                  )),
                ),
          ],
        ),
      ),
    );
  }
}
