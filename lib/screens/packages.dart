import 'package:flutter/material.dart';

import '../i18n.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../store.dart';
import '../theme/app_theme.dart';

const _typeLabels = {
  'cargo': 'Cargo (Rust)',
  'composer': 'Composer (PHP)',
  'conan': 'Conan (C/C++)',
  'generic': 'Generic',
  'go': 'Go',
  'helm': 'Helm Charts',
  'hex': 'Hex (Elixir)',
  'maven': 'Maven (Java)',
  'npm': 'npm (Node)',
  'nuget': 'NuGet (.NET)',
  'oci': 'OCI (Containers)',
  'pub': 'Pub (Dart)',
  'pypi': 'PyPI (Python)',
  'rubygems': 'RubyGems',
  'swift': 'Swift',
};

/// Recreates PackagesPage.svelte (registries tab + packages tab).
class PackagesScreen extends StatefulWidget {
  final AppStore store;
  const PackagesScreen({super.key, required this.store});

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  AppStore get store => widget.store;
  int _tab = 0;
  List<PackageTypeEntry> _types = [];
  List<String> _repositories = [];
  bool _loading = false;
  String _error = '';
  String _query = '';

  List<UnifiedPackageEntry> _pkgs = [];
  bool _pkgLoading = false;
  String _pkgError = '';
  String _pkgQuery = '';
  String _typeFilter = '';
  int _total = 0;
  int _offset = 0;
  String? _expandedKey;
  List<PackageVersion> _versionDetail = [];

  static const _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      _types = await store.api.listPackageTypes();
    } catch (e) {
      _error = '$e';
    }
    try {
      final repos = await store.api.ociCatalog();
      if (mounted) _repositories = repos;
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _loadPackages() async {
    setState(() {
      _pkgLoading = true;
      _pkgError = '';
    });
    try {
      final r = await store.api.listAllPackages(
        type: _typeFilter.isEmpty ? null : _typeFilter,
        q: _pkgQuery.isEmpty ? null : _pkgQuery,
        limit: _pageSize,
        offset: _offset,
      );
      final data = (r['data'] as Map?)?.cast<String, dynamic>() ?? {};
      _pkgs = ((data['packages'] as List?) ?? [])
          .map((e) => UnifiedPackageEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      _total = data['total'] as int? ?? 0;
    } catch (e) {
      _pkgError = '$e';
    }
    setState(() => _pkgLoading = false);
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
      final info = await store.api.packageVersions(p.type, p.name);
      if (mounted) setState(() => _versionDetail = info.versions);
    } catch (_) {}
  }

  String _endpointFor(String type) =>
      type == 'oci' ? '/v2/' : '/pkgs/$type/';

  /// The externally usable registry host (jj-lab serves every protocol
  /// under `/pkgs/<type>` plus OCI `/v2`). This is what a tool config
  /// would point at.
  static const _registryHost = 'https://jj-lab.temp.10.199.64.20.nip.io';

  String _endpointUrl(String type) => '$_registryHost${_endpointFor(type)}';

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.packagesTitle),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _tab == 0 ? _loadAll() : _loadPackages()),
        ],
      ),
      body: Column(
        children: [
          // Mobile-conventional in-content segmented control instead of an
          // AppBar TabBar — the two views are siblings, not pages.
          Padding(
            padding:
                const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md,
                    AppSpacing.lg, AppSpacing.sm),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(context.l10n.registries)),
                ButtonSegment(value: 1, label: Text(context.l10n.packagesTab)),
              ],
              selected: {_tab},
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                side: WidgetStatePropertyAll(
                    BorderSide(color: colors.border.withValues(alpha: 0.5))),
                backgroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? colors.muted
                        : Colors.transparent),
                foregroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? colors.primary
                        : colors.mutedForeground),
              ),
              onSelectionChanged: (sel) {
                setState(() => _tab = sel.first);
                if (_tab == 1 && _pkgs.isEmpty && !_pkgLoading) {
                  _loadPackages();
                }
              },
            ),
          ),
          Expanded(child: _tab == 0 ? _registries(context) : _packages(context)),
        ],
      ),
    );
  }

  Widget _registries(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    final filtered = _query.trim().isEmpty
        ? _types
        : _types.where((ty) {
            final l = _query.toLowerCase();
            return ty.type.toLowerCase().contains(l) ||
                (_typeLabels[ty.type] ?? '').toLowerCase().contains(l);
          }).toList();
    return _loading && _types.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(_error,
                      style: text.meta.copyWith(color: colors.destructive)),
                ),
              TextField(
                decoration: InputDecoration(
                  hintText: context.l10n.filterEcosystems,
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(context.l10n.proxyRegistries('${filtered.length}'),
                  style: text.meta
                      .copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: AppSpacing.sm),
              for (final ty in filtered)
                Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    title: Text(ty.type,
                        style: text.mono.copyWith(fontSize: 13)),
                    subtitle: Text(
                        '${_typeLabels[ty.type] ?? ty.type} · ${ty.upstream.isEmpty ? context.l10n.noUpstreamLocal : ty.upstream}\n${context.l10n.cachedPackages('${ty.packages}')}',
                        style: text.micro
                            .copyWith(color: colors.mutedForeground)),
                    trailing: IconButton(
                      icon: Icon(Icons.copy_rounded,
                          size: 16, color: colors.mutedForeground),
                      tooltip: context.l10n.endpointCopied,
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: _endpointUrl(ty.type)));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  '${_endpointUrl(ty.type)}  ·  ${context.l10n.endpointCopied}')),
                        );
                      },
                    ),
                    onLongPress: () {
                      Clipboard.setData(
                          ClipboardData(text: _endpointUrl(ty.type)));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text(context.l10n.endpointCopied)),
                      );
                    },
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Text(context.l10n.ociCatalog('${_repositories.length}'),
                  style: text.meta
                      .copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
              if (_repositories.isEmpty)
                Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Text(context.l10n.noImages,
                        style: text.meta
                            .copyWith(color: colors.mutedForeground)))
              else
                for (final repo in _repositories)
                  ListTile(
                    leading: Icon(Icons.inventory_2_outlined,
                        size: 16, color: colors.mutedForeground),
                    title: Text(repo, style: text.mono.copyWith(fontSize: 12)),
                  ),
            ],
          );
  }

  Widget _packages(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    if (_pkgLoading && _pkgs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: context.l10n.searchPackages,
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (v) => _pkgQuery = v,
                  onSubmitted: (_) {
                    _offset = 0;
                    _loadPackages();
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              DropdownButton<String>(
                value: _typeFilter.isEmpty ? null : _typeFilter,
                hint: Text(context.l10n.typeLabel, style: text.meta),
                underline: const SizedBox.shrink(),
                items: [
                  for (final ty in _types.where((e) => e.type.isNotEmpty))
                    DropdownMenuItem(value: ty.type, child: Text(ty.type)),
                ],
                onChanged: (v) {
                  _typeFilter = v ?? '';
                  _offset = 0;
                  _loadPackages();
                },
              ),
              IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () {
                    _offset = 0;
                    _loadPackages();
                  }),
            ],
          ),
        ),
        Expanded(
          child: _pkgs.isEmpty
              ? Center(
                  child: Text(
                      _pkgError.isNotEmpty
                          ? _pkgError
                          : context.l10n.noPackagesYet,
                      style:
                          TextStyle(color: colors.mutedForeground)))
              : ListView.builder(
                  itemCount: _pkgs.length,
                  itemBuilder: (_, i) => _pkgRow(_pkgs[i]),
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.packPageOf(
                  '${_offset + 1}',
                  '${_offset + _pkgs.length}',
                  '$_total'),
                  style: text.micro.copyWith(color: colors.mutedForeground)),
              Row(
                children: [
                  TextButton(
                    onPressed: _offset == 0 || _pkgLoading
                        ? null
                        : () {
                            _offset = (_offset - _pageSize).clamp(0, _offset);
                            _loadPackages();
                          },
                    child: Text(context.l10n.prev),
                  ),
                  TextButton(
                    onPressed: _offset + _pageSize >= _total || _pkgLoading
                        ? null
                        : () {
                            _offset += _pageSize;
                            _loadPackages();
                          },
                    child: Text(context.l10n.next),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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
          trailing: IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                size: 18, color: colors.mutedForeground),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(ctx.l10n.deletePackage),
                  content: Text(
                      ctx.l10n.deletePackageBody(p.name, p.type)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(ctx.l10n.cancel)),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(ctx.l10n.delete)),
                  ],
                ),
              );
              if (confirm == true) {
                await store.api.deletePackage(p.type, p.name);
                setState(() => _expandedKey = null);
                _loadPackages();
              }
            },
          ),
          onTap: () => _toggleExpand(p),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(
                left: 32, bottom: AppSpacing.sm, right: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final v in _versionDetail) _versionRow(p, v),
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

  Widget _versionRow(UnifiedPackageEntry p, PackageVersion v) {
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

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
