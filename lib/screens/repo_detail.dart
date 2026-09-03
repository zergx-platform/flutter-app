import 'package:flutter/material.dart';

import '../api.dart';
import '../i18n.dart';
import '../models.dart';
import '../services/download_service.dart';
import '../store.dart';
import '../theme/app_theme.dart';
import '../widgets/commit_diff_page.dart';
import '../widgets/dialogs.dart';

/// Repository detail with a TabBar: Overview (branches + recent commits),
/// Releases (assets with downloads + source tarball), Branches.
class RepoDetailScreen extends StatefulWidget {
  final AppStore store;
  final String org;
  final String repo;
  const RepoDetailScreen({
    super.key,
    required this.store,
    required this.org,
    required this.repo,
  });

  @override
  State<RepoDetailScreen> createState() => _RepoDetailScreenState();
}

class _RepoDetailScreenState extends State<RepoDetailScreen>
    with SingleTickerProviderStateMixin {
  AppStore get store => widget.store;
  late final TabController _tabs = TabController(length: 4, vsync: this);
  late final DownloadService _dl = DownloadService(store.api);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.org}/${widget.repo}',
            overflow: TextOverflow.ellipsis),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: context.l10n.overview),
            Tab(text: context.l10n.releasesTab),
            Tab(text: context.l10n.packagesTab),
            Tab(text: context.l10n.branchesTab),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sync_rounded, size: 20),
            tooltip: context.l10n.syncRepo,
            onSelected: (v) => _syncAction(v),
            itemBuilder: (context) => [
              PopupMenuItem(
                  value: 'pull',
                  child: Text(context.l10n.pullFromRemote)),
              PopupMenuItem(
                  value: 'push',
                  child: Text(context.l10n.pushToRemote)),
              const PopupMenuDivider(),
              PopupMenuItem(
                  value: 'settings',
                  child: Text(context.l10n.mirrorSettings)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: context.l10n.deleteRepoTitle,
            onPressed: _deleteRepo,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _OverviewTab(store: store, org: widget.org, repo: widget.repo),
          _ReleasesTab(
              api: store.api,
              dl: _dl,
              org: widget.org,
              repo: widget.repo),
          _PackagesTab(store: store, org: widget.org, repo: widget.repo),
          _BranchesTab(store: store, org: widget.org, repo: widget.repo),
        ],
      ),
    );
  }

  Future<void> _deleteRepo() async {
    final ok = await confirmDialog(context,
        title: context.l10n.deleteRepoTitle,
        description: context.l10n.deleteRepoBody(widget.org, widget.repo));
    if (ok) {
      await store.deleteRepo(widget.org, widget.repo);
      if (mounted) Navigator.of(context).pop();
    }
  }

  /// Sync a remote Git mirror into/out of this repo via jjlab.
  Future<void> _syncAction(String kind) async {
    final messenger = ScaffoldMessenger.of(context);
    if (kind == 'settings') {
      await _mirrorSettings();
      return;
    }
    final okMsg = kind == 'pull'
        ? context.l10n.pullDone
        : context.l10n.pushDone;
    // Pull/push default the URL to the stored config so the user only needs
    // to type it once; the secret lives on the platform (never client-side).
    MirrorCfg stored;
    try {
      stored = await store.api.getMirror(widget.org, widget.repo);
    } catch (_) {
      stored = MirrorCfg();
    }
    final prefill = kind == 'pull' ? stored.pullUrl : stored.pushUrl;
    String? url = await promptDialog(context,
        title: kind == 'pull'
            ? context.l10n.pullFromRemote
            : context.l10n.pushToRemote,
        label: context.l10n.gitUrlLabel,
        confirmText: kind == 'pull'
            ? context.l10n.pullConfirm
            : context.l10n.pushConfirm);
    if (url == null || url.trim().isEmpty) return;
    if (url.trim() == context.l10n.gitUrlLabel) url = prefill;
    final body = <String, dynamic>{'url': url.trim()};
    if (kind == 'push') {
      final secret = await promptDialog(context,
          title: context.l10n.secretLabel,
          label: context.l10n.accessTokenOpt,
          confirmText: context.l10n.pushConfirm);
      if (secret != null && secret.trim().isNotEmpty) {
        body['secret'] = secret.trim();
      }
    }
    try {
      final r = await store.api.mirrorSync(
          widget.org, widget.repo, '${kind}-mirror', body);
      messenger.showSnackBar(SnackBar(
          content: Text(okMsg +
              (r['updated_bookmarks'] != null
                  ? ' (${r['updated_bookmarks']})'
                  : ''))));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.syncFailed('$e'))));
    }
  }

  /// Save pull/push URLs + an optional push secret on the platform (NATS KV,
  /// secret encrypted server-side, never returned to the client).
  Future<void> _mirrorSettings() async {
    final messenger = ScaffoldMessenger.of(context);
    MirrorCfg stored;
    try {
      stored = await store.api.getMirror(widget.org, widget.repo);
    } catch (_) {
      stored = MirrorCfg();
    }
    final pullCtrl = TextEditingController(text: stored.pullUrl);
    final pushCtrl = TextEditingController(text: stored.pushUrl);
    final secretCtrl = TextEditingController(
        text: stored.pushSecretSet ? context.l10n.secretSetPlaceholder : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.mirrorSettings),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: pullCtrl,
                  decoration: InputDecoration(
                      labelText: context.l10n.pullUrlLabel)),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                  controller: pushCtrl,
                  decoration: InputDecoration(
                      labelText: context.l10n.pushUrlLabel)),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                  controller: secretCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                      helperText: stored.pushSecretSet
                          ? context.l10n.secretKeepToUpdate
                          : null,
                      labelText: context.l10n.secretLabel)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.cancel)),
          if (stored.pullUrl.isNotEmpty || stored.pushUrl.isNotEmpty)
            TextButton(
              onPressed: () async {
                await store.api.delMirror(widget.org, widget.repo);
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: Text(context.l10n.clearMirror,
                  style: TextStyle(color: colorsOf(ctx).destructive)),
            ),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.save)),
        ],
      ),
    );
    if (ok == true) {
      try {
        final secret = secretCtrl.text.trim();
        await store.api.setMirror(widget.org, widget.repo,
            pullUrl: pullCtrl.text.trim(),
            pushUrl: pushCtrl.text.trim(),
            // If the user left the placeholder (already-set secret) and
            // changed nothing, send null so the stored secret is preserved.
            pushSecret: secret.isEmpty || secret == context.l10n.secretSetPlaceholder
                ? null
                : secret);
        messenger.showSnackBar(
            SnackBar(content: Text(context.l10n.savedMirror)));
      } catch (e) {
        messenger.showSnackBar(
            SnackBar(content: Text(context.l10n.syncFailed('$e'))));
      }
    }
    pullCtrl.dispose();
    pushCtrl.dispose();
    secretCtrl.dispose();
  }
}

// ---- Overview: branches summary + recent commits ----

class _OverviewTab extends StatefulWidget {
  final AppStore store;
  final String org;
  final String repo;
  const _OverviewTab(
      {required this.store, required this.org, required this.repo});

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  List<BranchInfo> _branches = [];
  List<FileCommit> _commits = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.store.api.branches(widget.org, widget.repo),
        widget.store.api.log(widget.org, widget.repo, limit: 20),
      ]);
      _branches = results[0] as List<BranchInfo>;
      _commits = results[1] as List<FileCommit>;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(context.l10n.branchesTab,
              style: text.meta.copyWith(
                  fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: AppSpacing.sm),
          if (_branches.isEmpty)
            Text(context.l10n.noBranches,
                style: TextStyle(color: colors.mutedForeground))
          else
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final b in _branches)
                  Chip(
                    label: Text(b.name,
                        style: text.mono.copyWith(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.lg),
          Text(context.l10n.recentCommits,
              style: text.meta.copyWith(
                  fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: AppSpacing.xs),
          if (_commits.isEmpty)
            Text(context.l10n.noCommits,
                style: TextStyle(color: colors.mutedForeground))
          else
            for (final c in _commits)
              InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CommitDiffPage(
                      api: widget.store.api,
                      org: widget.org,
                      repo: widget.repo,
                      commit: c),
                )),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      Icon(Icons.commit_rounded,
                          size: 14, color: colors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.message,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.meta),
                            Text(
                                '${c.commitId.substring(0, 8)} · ${c.author}',
                                style: text.micro.copyWith(
                                    color: colors.mutedForeground)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

// ---- Releases: list + expandable assets + downloads ----

class _ReleasesTab extends StatefulWidget {
  final ZergxApi api;
  final DownloadService dl;
  final String org;
  final String repo;
  const _ReleasesTab({
    required this.api,
    required this.dl,
    required this.org,
    required this.repo,
  });

  @override
  State<_ReleasesTab> createState() => _ReleasesTabState();
}

class _ReleasesTabState extends State<_ReleasesTab> {
  List<Release> _releases = [];
  bool _loading = true;
  String? _expandedTag;
  String? _downloading; // asset/tag currently downloading

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _releases = await widget.api.releases(widget.org, widget.repo);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _download(String path, String displayName, String mime) async {
    if (_downloading != null) return;
    setState(() => _downloading = displayName);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final where = await widget.dl.download(
        path: path,
        displayName: displayName,
        mimeType: mime,
      );
      messenger.showSnackBar(SnackBar(
          content: Text(I18n.now.savedToDownloads(where))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(I18n.now.downloadFailed('$e'))));
    }
    if (mounted) setState(() => _downloading = null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: _releases.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                      child: Text(context.l10n.noReleases,
                          style: TextStyle(color: colors.mutedForeground))),
                ),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                for (final r in _releases) _releaseCard(context, r),
              ],
            ),
    );
  }

  Widget _releaseCard(BuildContext context, Release r) {
    final colors = colorsOf(context);
    final text = textOf(context);
    final expanded = _expandedTag == r.tagName;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Row(
              children: [
                Flexible(
                    child: Text(r.name.isNotEmpty ? r.name : r.tagName,
                        overflow: TextOverflow.ellipsis,
                        style: text.meta.copyWith(fontWeight: FontWeight.w600))),
                if (r.draft) ...[
                  const SizedBox(width: AppSpacing.xs),
                  _badge(context.l10n.draftBadge, colors.mutedForeground),
                ],
                if (r.prerelease) ...[
                  const SizedBox(width: AppSpacing.xs),
                  _badge(context.l10n.prereleaseBadge, colors.warning),
                ],
              ],
            ),
            subtitle: Text(
                '${r.tagName} · ${context.l10n.assetsCount('${r.assets.length}')}',
                style:
                    text.micro.copyWith(color: colors.mutedForeground)),
            trailing: _downloading == r.tagName
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    icon: Icon(Icons.download_rounded,
                        size: 18, color: colors.primary),
                    tooltip: context.l10n.downloadSource,
                    onPressed: () => _download(
                        widget.api.archivePath(
                            widget.org, widget.repo, r.tagName),
                        '${widget.repo}-${r.tagName}.tar.gz',
                        'application/gzip'),
                  ),
            onTap: () =>
                setState(() => _expandedTag = expanded ? null : r.tagName),
          ),
          if (r.body.isNotEmpty && expanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: SelectableText(r.body,
                  style: text.meta
                      .copyWith(color: colors.mutedForeground)),
            ),
          if (expanded) ...[
            for (final a in r.assets)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.insert_drive_file_outlined,
                        size: 14, color: colors.mutedForeground),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                        child: Text(a.name,
                            overflow: TextOverflow.ellipsis,
                            style: text.mono.copyWith(fontSize: 12))),
                    Text(_fmtSize(a.size),
                        style: text.micro
                            .copyWith(color: colors.mutedForeground)),
                    const SizedBox(width: AppSpacing.xs),
                    _downloading == a.name
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(
                            icon: Icon(Icons.download_rounded,
                                size: 16, color: colors.primary),
                            onPressed: () => _download(
                                widget.api.assetPath(widget.org,
                                    widget.repo, r.tagName, a.name),
                                a.name,
                                a.contentType.isEmpty
                                    ? 'application/octet-stream'
                                    : a.contentType),
                          ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: textOf(context)
              .micro
              .copyWith(color: color, fontSize: 9)),
    );
  }

  static String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

// ---- Branches list ----

class _BranchesTab extends StatefulWidget {
  final AppStore store;
  final String org;
  final String repo;
  const _BranchesTab(
      {required this.store, required this.org, required this.repo});

  @override
  State<_BranchesTab> createState() => _BranchesTabState();
}

class _BranchesTabState extends State<_BranchesTab> {
  List<BranchInfo> _branches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _branches = await widget.store.api.branches(widget.org, widget.repo);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: _branches.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                      child: Text(context.l10n.noBranches,
                          style: TextStyle(color: colors.mutedForeground))),
                ),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                for (final b in _branches)
                  ListTile(
                    leading: Icon(Icons.call_split_rounded,
                        size: 16, color: colors.primary),
                    title: Text(b.name, style: text.mono.copyWith(fontSize: 13)),
                    subtitle: Text(b.sha.length > 8 ? b.sha.substring(0, 8) : b.sha,
                        style: text.micro.copyWith(
                            color: colors.mutedForeground)),
                    onTap: () {
                      widget.store.openRepo(widget.org, widget.repo, b.name);
                      widget.store.switchTab(SiderTab.code);
                      // Return one level (back to the repo/org/browser stack)
                      // rather than exploding to the first route, which would
                      // skip the enclosing Browser/Org context.
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
              ],
            ),
    );
  }
}

/// Repo-scoped packages: list packages published under this org/repo and
/// their versions (metadata only — no download button here). Mirrors the
/// Packages tab but filtered to the current repository.
class _PackagesTab extends StatefulWidget {
  final AppStore store;
  final String org;
  final String repo;
  const _PackagesTab(
      {required this.store, required this.org, required this.repo});

  @override
  State<_PackagesTab> createState() => _PackagesTabState();
}

class _PackagesTabState extends State<_PackagesTab> {
  List<UnifiedPackageEntry> _pkgs = [];
  bool _loading = true;
  String? _expandedKey;
  List<PackageVersion> _versionDetail = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // listAllPackages filters by type/q; we want this org/repo. The
      // package name convention is <repo>-<...>; we fetch a broad page and
      // filter by name prefix <repo>-.
      final r = await widget.store.api.listAllPackages(limit: 200, offset: 0);
      final data = (r['data'] as Map?)?.cast<String, dynamic>() ?? {};
      final all = ((data['packages'] as List?) ?? [])
          .map((e) => UnifiedPackageEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      _pkgs = all.where((p) => p.name.startsWith('${widget.repo}-')).toList();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleExpand(UnifiedPackageEntry p) async {
    final key = '${p.type}/${p.name}';
    if (_expandedKey == key) {
      setState(() {
        _expandedKey = null;
        _versionDetail = [];
      });
      return;
    }
    setState(() {
      _expandedKey = key;
      _versionDetail = [];
    });
    try {
      final info = await widget.store.api.packageVersions(p.type, p.name);
      if (mounted) setState(() => _versionDetail = info.versions);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: _pkgs.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                      child: Text(context.l10n.noPackagesYet,
                          style: TextStyle(color: colors.mutedForeground))),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _pkgs.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: colors.border.withValues(alpha: 0.4)),
              itemBuilder: (_, i) => _pkgRow(_pkgs[i]),
            ),
    );
  }

  Widget _pkgRow(UnifiedPackageEntry p) {
    final colors = colorsOf(context);
    final text = textOf(context);
    final key = '${p.type}/${p.name}';
    final expanded = _expandedKey == key;
    return Column(
      children: [
        ListTile(
          leading: Icon(
              expanded
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.chevron_right_rounded,
              size: 18,
              color: colors.mutedForeground),
          title: Text(p.name, style: text.mono.copyWith(fontSize: 13)),
          subtitle: Text(
              '${p.type}${p.latestVersion != null ? ' · v${p.latestVersion}' : ''} · ${context.l10n.versionsCount('${p.versions}')}',
              style: text.micro.copyWith(color: colors.mutedForeground)),
          onTap: () => _toggleExpand(p),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(
                left: 32, bottom: AppSpacing.sm, right: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final v in _versionDetail) _versionRow(v),
                if (_versionDetail.isEmpty)
                  Text(context.l10n.noVersions,
                      style: text.micro.copyWith(color: colors.mutedForeground)),
              ],
            ),
          ),
        Divider(height: 1, color: colors.border.withValues(alpha: 0.4)),
      ],
    );
  }

  Widget _versionRow(PackageVersion v) {
    final colors = colorsOf(context);
    final text = textOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(v.version, style: text.mono.copyWith(fontSize: 12)),
              const SizedBox(width: AppSpacing.sm),
              Text(context.l10n.downloads('${v.downloadCount}'),
                  style: text.micro.copyWith(color: colors.mutedForeground)),
            ],
          ),
          for (final f in v.files)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm, top: 2),
              child: Row(
                children: [
                  Icon(Icons.insert_drive_file_outlined,
                      size: 12, color: colors.mutedForeground),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                      child: Text(f.name,
                          overflow: TextOverflow.ellipsis,
                          style: text.mono.copyWith(fontSize: 11))),
                  Text(_fmtSize(f.size),
                      style:
                          text.micro.copyWith(color: colors.mutedForeground)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
