import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../store.dart';

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
  Map<String, dynamic>? _zergxCfg;
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
      final cfg = await store.api.zergxConfig();
      if (mounted) _zergxCfg = cfg;
    } catch (_) {}
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
      type == 'oci' ? '/v2/' : '/api/v1/packages/$type/';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Packages'),
          bottom: TabBar(
            tabs: const [Tab(text: 'Registries'), Tab(text: 'Packages')],
            onTap: (i) {
              setState(() => _tab = i);
              if (i == 1 && _pkgs.isEmpty && !_pkgLoading) _loadPackages();
            },
          ),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _tab == 0 ? _loadAll() : _loadPackages()),
          ],
        ),
        body: _tab == 0 ? _registries(context) : _packages(context),
      ),
    );
  }

  Widget _registries(BuildContext context) {
    final filtered = _query.trim().isEmpty
        ? _types
        : _types.where((t) {
            final l = _query.toLowerCase();
            return t.type.toLowerCase().contains(l) ||
                (_typeLabels[t.type] ?? '').toLowerCase().contains(l);
          }).toList();
    return _loading && _types.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error.isNotEmpty)
                Text(_error, style: const TextStyle(color: Colors.red)),
              TextField(
                decoration: const InputDecoration(
                    hintText: 'Filter ecosystems...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(), isDense: true),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              Text('Proxy Registries (${filtered.length})',
                  style: Theme.of(context).textTheme.titleSmall),
              for (final t in filtered)
                Card(
                  child: ListTile(
                    title: Text(t.type,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                    subtitle: Text(
                        '${_typeLabels[t.type] ?? t.type}\n${t.upstream.isEmpty ? 'no upstream (local only)' : t.upstream}${t.upstream.isEmpty ? '' : '\n${_endpointFor(t.type)}'}',
                        style: const TextStyle(fontSize: 11)),
                    onLongPress: () {
                      Clipboard.setData(
                          ClipboardData(text: _endpointFor(t.type)));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Endpoint copied')));
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Text('OCI Image Catalog (${_repositories.length})',
                  style: Theme.of(context).textTheme.titleSmall),
              if (_repositories.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(8), child: Text('No images stored.'))
              else
                for (final repo in _repositories)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.inventory_2_outlined, size: 16),
                    title: Text(repo, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                  ),
              if (_zergxCfg != null) ...[
                const SizedBox(height: 12),
                Text('Registry Backend Config (read-only)',
                    style: Theme.of(context).textTheme.titleSmall),
                Text(
                    'self_base: ${_zergxCfg!['self_base'] ?? '—'}\nhttp_proxy: ${_zergxCfg!['http_proxy'] ?? '—'}',
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
              ],
            ],
          );
  }

  Widget _packages(BuildContext context) {
    if (_pkgLoading && _pkgs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                      hintText: 'Search packages...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(), isDense: true),
                  onChanged: (v) => _pkgQuery = v,
                  onSubmitted: (_) {
                    _offset = 0;
                    _loadPackages();
                  },
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _typeFilter.isEmpty ? null : _typeFilter,
                hint: const Text('Type'),
                items: [
                  for (final t in _types.where((t) => t.type.isNotEmpty))
                    DropdownMenuItem(value: t.type, child: Text(t.type)),
                ],
                onChanged: (v) {
                  _typeFilter = v ?? '';
                  _offset = 0;
                  _loadPackages();
                },
              ),
              IconButton(
                  icon: const Icon(Icons.search),
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
                  child: Text(_pkgError.isNotEmpty ? _pkgError : 'No packages registered yet.'))
              : ListView.builder(
                  itemCount: _pkgs.length,
                  itemBuilder: (_, i) => _pkgRow(_pkgs[i]),
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_offset + 1}–${_offset + _pkgs.length} of $_total',
                  style: const TextStyle(fontSize: 11)),
              Row(
                children: [
                  TextButton(
                    onPressed: _offset == 0 || _pkgLoading
                        ? null
                        : () {
                            _offset = (_offset - _pageSize).clamp(0, _offset);
                            _loadPackages();
                          },
                    child: const Text('Prev'),
                  ),
                  TextButton(
                    onPressed: _offset + _pageSize >= _total || _pkgLoading
                        ? null
                        : () {
                            _offset += _pageSize;
                            _loadPackages();
                          },
                    child: const Text('Next'),
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
    final key = '${p.type}/${p.name}';
    final expanded = _expandedKey == key;
    return Column(
      children: [
        ListTile(
          dense: true,
          leading: Icon(expanded ? Icons.expand_more : Icons.chevron_right, size: 18),
          title: Text(p.name, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
          subtitle: Text('${p.type}${p.latestVersion != null ? ' · v${p.latestVersion}' : ''} · ${p.versions} versions',
              style: const TextStyle(fontSize: 10)),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete package'),
                  content: Text('Delete package ${p.name} (${p.type})?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete')),
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
            padding: const EdgeInsets.only(left: 32, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final v in _versionDetail)
                  _versionRow(p, v),
                if (_versionDetail.isEmpty)
                  const Text('No versions found.',
                      style: TextStyle(fontSize: 11)),
              ],
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _versionRow(UnifiedPackageEntry p, PackageVersion v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(v.version, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              const SizedBox(width: 8),
              Text('${v.downloadCount} downloads',
                  style: const TextStyle(fontSize: 10)),
            ],
          ),
          for (final f in v.files)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file_outlined, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text(f.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
                  Text(_fmtSize(f.size), style: const TextStyle(fontSize: 10)),
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