import 'package:flutter/material.dart';

import '../store.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs.dart';

/// The single "create" entry point. WeChat/Telegram place the "+" only on
/// the session-list page, never inside a conversation. It offers the three
/// workspace creation actions and resolves the target org (0/1/n).
class CreateMenu extends StatelessWidget {
  final AppStore store;
  final Color iconColor;
  final Color? backgroundColor;
  const CreateMenu({
    super.key,
    required this.store,
    this.iconColor = Colors.white,
    this.backgroundColor,
  });

  Future<void> _newOrg(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = await promptDialog(context,
        title: 'New organization', label: 'Organization name');
    if (name != null && name.trim().isNotEmpty) {
      try {
        await store.api.ensureOrg(name.trim());
        await store.refreshRepos();
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  /// Resolve which org an org-scoped action (new repo / clone) applies to.
  /// Empty → snackbar; exactly one → use it; several → bottom sheet picker.
  Future<String?> _resolveOrg(BuildContext context) async {
    final orgs = store.orgs.map((o) => o.org).toList();
    if (orgs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create an organization first')));
      return null;
    }
    if (orgs.length == 1) return orgs.first;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text('Choose organization',
                  style: textOf(ctx)
                      .meta
                      .copyWith(fontWeight: FontWeight.w600)),
            ),
            for (final o in orgs)
              ListTile(
                leading: const Icon(Icons.business_rounded),
                title: Text(o),
                onTap: () => Navigator.pop(ctx, o),
              ),
          ],
        ),
      ),
    );
    return picked;
  }

  Future<void> _newRepo(BuildContext context) async {
    final org = await _resolveOrg(context);
    if (org == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final name = await promptDialog(context,
        title: 'New repo in $org', label: 'Repo name');
    if (name != null && name.trim().isNotEmpty) {
      try {
        await store.api.ensureRepo(org, name.trim());
        await store.refreshRepos();
        await store.refreshSessions();
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _cloneRepo(BuildContext context) async {
    final org = await _resolveOrg(context);
    if (org == null || !context.mounted) return;
    await showCloneDialog(context, store, org);
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Create',
      icon: Icon(Icons.add_rounded, color: iconColor, size: 22),
      onSelected: (v) {
        switch (v) {
          case 'org':
            _newOrg(context);
          case 'repo':
            _newRepo(context);
          case 'clone':
            _cloneRepo(context);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'org', child: Text('New organization')),
        PopupMenuItem(value: 'repo', child: Text('New repo…')),
        PopupMenuItem(value: 'clone', child: Text('Clone repo…')),
      ],
    );
  }
}

/// Clone dialogs live here (shared by CreateMenu) so ChatSidebar no longer
/// needs its own. Kept in this file to give CreateMenu a single home.
Future<void> showCloneDialog(BuildContext context, AppStore store, String org) async {
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
            const SizedBox(height: AppSpacing.sm),
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Repo name')),
            const SizedBox(height: AppSpacing.sm),
            TextField(
                controller: tokenCtrl,
                decoration:
                    const InputDecoration(labelText: 'Access token (optional)')),
            const SizedBox(height: AppSpacing.sm),
            TextField(
                controller: revCtrl,
                decoration: const InputDecoration(
                    labelText: 'Branch / tag / commit (optional)')),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
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
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Clone failed: $e')));
        }
      }
    }
  }
}
