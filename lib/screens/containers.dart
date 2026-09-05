import 'package:flutter/material.dart';

import '../i18n.dart';

import '../models.dart';
import '../store.dart';
import '../theme/app_theme.dart';
import 'container_overlay.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/dialogs.dart';

/// Recreates ContainersPage.svelte (sandboxes + deployments; terminal
/// drill-in reuses the container workspace UI).
class ContainersScreen extends StatefulWidget {
  final AppStore store;
  const ContainersScreen({super.key, required this.store});

  @override
  State<ContainersScreen> createState() => _ContainersScreenState();
}

class _ContainersScreenState extends State<ContainersScreen> {
  AppStore get store => widget.store;
  List<Sandbox> _sandboxes = [];
  List<Deployment> _deployments = [];
  bool _loading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      _sandboxes = await store.api.sandboxes();
    } catch (_) {}
    try {
      _deployments = await store.api.deployments();
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _destroySandbox(Sandbox s) async {
    final ok = await confirmDialog(context,
        title: context.l10n.deleteSandboxTitle,
        description: context.l10n.deleteSandboxBody(s.podName));
    if (!ok) return;
    // Always address the worker by its container id (pod short name): it is
    // a stable, non-empty k8s label value that `labelKey` passes through
    // verbatim. The `session` field may be empty (no zergx/session annotation),
    // which would otherwise 404 on `DELETE /sandboxes/`.
    try {
      await store.api.destroySandbox(s.containerId);
    } catch (e) {
      _error = '$e';
      setState(() {});
    }
    await _load();
  }

  Future<void> _destroyDeployment(Deployment d) async {
    final ok = await confirmDialog(context,
        title: context.l10n.deleteDeploymentTitle,
        description: context.l10n.deleteDeploymentBody(d.name));
    if (!ok) return;
    try {
      await store.api.destroyDeployment(d.name);
    } catch (e) {
      _error = '$e';
      setState(() {});
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.tabContainers),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          IconButton(
              icon: const Icon(Icons.public_rounded),
              tooltip: context.l10n.deployService,
              onPressed: () => _deployDialog()),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text(_error,
                          style: text.meta.copyWith(color: colors.destructive)),
                    ),
                  Text(context.l10n.deployments,
                      style: text.meta
                          .copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
                  if (_deployments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Text(context.l10n.noDeployments,
                          style: text.meta
                              .copyWith(color: colors.mutedForeground)),
                    )
                  else
                    for (final d in _deployments) _deploymentCard(d),
                  const SizedBox(height: AppSpacing.lg),
                  Text(context.l10n.sandboxes,
                      style: text.meta
                          .copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
                  if (_sandboxes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Text(context.l10n.noContainers,
                          style: text.meta
                              .copyWith(color: colors.mutedForeground)),
                    )
                  else
                    for (final s in _sandboxes) _sandboxCard(s),
                ],
              ),
            ),
    );
  }

  Widget _deploymentCard(Deployment d) {
    final colors = colorsOf(context);
    final text = textOf(context);
    return Card(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      child: ListTile(
        title: Text(d.name, style: text.mono.copyWith(fontSize: 13)),
        subtitle: Text(d.image,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.micro.copyWith(color: colors.mutedForeground)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: d.ready > 0
                    ? colors.success.withValues(alpha: 0.12)
                    : colors.destructive.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(context.l10n.ready('${d.ready}', '${d.replicas}'),
                  style: text.micro.copyWith(
                      color: d.ready > 0 ? colors.success : colors.destructive)),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  size: 18, color: colors.mutedForeground),
              onPressed: () => _destroyDeployment(d),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sandboxCard(Sandbox s) {
    final colors = colorsOf(context);
    final text = textOf(context);
    // Session names are org:repo:branch — render the human-readable triple
    // with an avatar instead of the hash-suffixed pod name.
    final parts = s.session.split(':');
    final (org, repo, bookmark) = parts.length == 3
        ? (parts[0], parts[1], parts[2])
        : ('', '', '');
    return Card(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      child: ListTile(
        leading: org.isNotEmpty
            ? ChatAvatar(org: org, repo: repo, bookmark: bookmark, radius: 20)
            : null,
        title: Text(bookmark.isNotEmpty ? bookmark : s.session,
            style: text.meta.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(
            org.isNotEmpty ? '$org/$repo\n${s.podName}' : s.podName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.micro.copyWith(color: colors.mutedForeground)),
        isThreeLine: org.isNotEmpty,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: s.status.toLowerCase() == 'running'
                    ? colors.success
                    : s.status.toLowerCase() == 'starting'
                        ? colors.warning
                        : colors.destructive,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: s.status.toLowerCase() != 'running'
                  ? null
                  : () => _openTerminal(s),
              child: Text(context.l10n.terminal),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  size: 18, color: colors.mutedForeground),
              onPressed: () => _destroySandbox(s),
            ),
          ],
        ),
      ),
    );
  }

  void _openTerminal(Sandbox s) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
            title: Text(s.podName.isNotEmpty ? s.podName : s.session,
                style: textOf(context).mono)),
        body: ContainerWorkspace(
            store: store, session: s.session, containerName: s.podName),
      ),
    ));
  }

  Future<void> _deployDialog() async {
    final name = TextEditingController();
    final image = TextEditingController();
    final replicas = TextEditingController(text: '1');
    final port = TextEditingController(text: '8080');
    final session = TextEditingController();
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.deployService),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: name,
                  decoration: InputDecoration(
                      labelText: ctx.l10n.nameLabel)),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                  controller: image,
                  decoration: InputDecoration(
                      labelText: ctx.l10n.imageLabel)),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                  controller: replicas,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: ctx.l10n.replicasLabel)),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                  controller: port,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: ctx.l10n.portLabel)),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                  controller: session,
                  decoration: InputDecoration(
                      labelText: ctx.l10n.sessionOptLabel)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.confirm),
          ),
        ],
      ),
    );
    if (r == true && name.text.trim().isNotEmpty && image.text.trim().isNotEmpty) {
      try {
        await store.api.deploy({
          'name': name.text.trim(),
          'image': image.text.trim(),
          'replicas': int.tryParse(replicas.text) ?? 1,
          'port': int.tryParse(port.text) ?? 8080,
          if (session.text.trim().isNotEmpty) 'session': session.text.trim(),
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
      }
      await _load();
    }
  }
}
