import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/dialogs.dart';

/// Recreates ConfigPage.svelte (simplified, without the external
/// models.dev template fetch and PWA install section).
class ConfigScreen extends StatefulWidget {
  final AppStore store;
  final VoidCallback? onLogout;
  const ConfigScreen({super.key, required this.store, this.onLogout});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  AppStore get store => widget.store;
  Map<String, String> _values = {};
  Map<String, ProviderInfo> _providers = {};
  List<ModelInfo> _models = [];
  Map<String, dynamic>? _k8s;
  bool _loading = true;

  final List<String> _stack = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _values = await store.api.config();
    } catch (_) {}
    try {
      final p = await store.api.providers();
      if (mounted) _providers = p;
    } catch (_) {}
    try {
      final m = await store.api.models();
      if (mounted) _models = m;
    } catch (_) {}
    try {
      final k = await store.api.k8sConfig();
      if (mounted) _k8s = k;
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    await store.api.setConfig(_values);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved')));
    }
  }

  void _push(String id) => setState(() => _stack.add(id));
  void _pop() => setState(() => _stack.removeLast());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _stack.isNotEmpty
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _pop)
            : null,
        title: Text(_stack.isNotEmpty ? _titleOf(_stack.last) : 'Settings'),
        actions: [
          if (widget.onLogout != null)
            TextButton(onPressed: widget.onLogout, child: const Text('Logout')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stack.isEmpty
              ? _listView()
              : _detail(_stack.last),
    );
  }

  String _titleOf(String id) {
    switch (id) {
      case 'providers':
        return 'LLM Providers';
      case 'presets':
        return 'Presets';
      case 'appearance':
        return 'Appearance';
      case 'tools':
        return 'Tools';
      case 'model':
        return 'Default Model';
      case 'container':
        return 'Container Backend';
      case 'base-image':
        return 'Worker Base Image';
      case 'advanced':
        return 'Advanced';
      default:
        return id;
    }
  }

  Widget _listView() {
    return ListView(
      children: [
        const _SectionHeader('App'),
        _listTile(Icons.palette_outlined, 'Appearance', () => _push('appearance')),
        _listTile(Icons.dns_outlined, 'LLM Providers', () => _push('providers')),
        _listTile(Icons.auto_awesome_outlined, 'Presets', () => _push('presets')),
        const _SectionHeader('Workspace'),
        _listTile(Icons.handyman_outlined, 'Tools', () => _push('tools')),
        _listTile(Icons.memory, 'Default Model', () => _push('model')),
        _listTile(Icons.inbox_outlined, 'Container Backend', () => _push('container')),
        _listTile(Icons.image_outlined, 'Worker Base Image', () => _push('base-image')),
        _listTile(Icons.tune, 'Advanced', () => _push('advanced')),
      ],
    );
  }

  Widget _listTile(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }

  Widget _detail(String id) {
    switch (id) {
      case 'appearance':
        return _appearance();
      case 'providers':
        return _providersDetail();
      case 'presets':
        return _presetsDetail();
      case 'tools':
        return _toolsDetail();
      case 'model':
        return _modelDetail();
      case 'container':
        return _containerDetail();
      case 'base-image':
        return _baseImageDetail();
      case 'advanced':
        return _advancedDetail();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _appearance() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Dark mode'),
          subtitle: const Text('Toggle light/dark appearance'),
          value: dark,
          onChanged: (_) {
            // Full theme switching is out of scope; note in UI.
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Theme switching available via system settings')));
          },
        ),
      ],
    );
  }

  Widget _providersDetail() {
    return _ProvidersDetail(
      providers: _providers,
      onChanged: _load,
      api: store.api,
    );
  }

  Widget _presetsDetail() {
    return _PresetsDetail(api: store.api);
  }

  Widget _toolsDetail() {
    return _ToolsDetail(api: store.api, providers: _providers);
  }

  Widget _modelDetail() {
    final current = _values['llm_model'] ?? '';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_models.isEmpty)
          TextField(
            controller: TextEditingController(text: current),
            decoration: const InputDecoration(
                labelText: 'Model (e.g. deepseek-v4-pro)',
                border: OutlineInputBorder()),
            onChanged: (v) => _values['llm_model'] = v,
          )
        else
          DropdownButtonFormField<String>(
            initialValue: current.isEmpty ? null : current,
            items: [
              for (final m in _models)
                DropdownMenuItem(
                    value: m.id,
                    child: Text('${m.providerId}: ${m.name}',
                        style: const TextStyle(fontSize: 13))),
            ],
            onChanged: (v) => setState(() => _values['llm_model'] = v ?? ''),
            decoration: const InputDecoration(labelText: 'Default Model'),
          ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  Widget _containerDetail() {
    final backend = _values['container_backend'] ?? 'kubernetes';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        RadioListTile<String>(
          title: const Text('Kubernetes'),
          value: 'kubernetes',
          groupValue: backend,
          onChanged: (v) => setState(() => _values['container_backend'] = v!),
        ),
        RadioListTile<String>(
          title: const Text('Docker'),
          value: 'docker',
          groupValue: backend,
          onChanged: (v) => setState(() => _values['container_backend'] = v!),
        ),
        const SizedBox(height: 12),
        if (backend == 'kubernetes') ...[
          if (_k8s != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Namespace: ${_k8s!['namespace']}',
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                    Text('Worker Image: ${_k8s!['worker_image']}',
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                  ],
                ),
              ),
            ),
          _tf('worker_base_image', 'Worker Image'),
          _tf('k8s_namespace', 'Namespace'),
        ] else ...[
          _tf('worker_image', 'Worker Image'),
          _tf('docker_api_url', 'Docker API URL'),
        ],
        const SizedBox(height: 16),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  Widget _baseImageDetail() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _tf('worker_base_image', 'Default Sandbox Base'),
        const SizedBox(height: 16),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  Widget _advancedDetail() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _tf('repos_root', 'Repos Root'),
        _tf('server_url', 'Server URL'),
        const SizedBox(height: 16),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  Widget _tf(String key, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextField(
        controller: TextEditingController(text: _values[key] ?? ''),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        onChanged: (v) => _values[key] = v,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: Theme.of(context).colorScheme.outline)),
    );
  }
}

/// Providers detail (recreates ProviderSection without models.dev template).
class _ProvidersDetail extends StatefulWidget {
  final Map<String, ProviderInfo> providers;
  final VoidCallback onChanged;
  final ZergxApi api;
  const _ProvidersDetail(
      {required this.providers, required this.onChanged, required this.api});

  @override
  State<_ProvidersDetail> createState() => _ProvidersDetailState();
}

class _ProvidersDetailState extends State<_ProvidersDetail> {
  bool _showAdd = false;

  @override
  Widget build(BuildContext context) {
    final entries = widget.providers.entries.toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final e in entries)
          Card(
            child: ListTile(
              title: Text('${e.key} (${e.value.apiType})'),
              subtitle: Text(e.value.baseUrl,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${e.value.models.length} models',
                      style: const TextStyle(fontSize: 10)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () async {
                      final ok = await confirmDialog(context,
                          title: 'Delete provider',
                          description: 'Delete provider ${e.key}?');
                      if (ok) {
                        await widget.api.deleteProvider(e.key);
                        widget.onChanged();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        if (widget.providers.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('No providers. Add one to get started.'),
          ),
        const SizedBox(height: 8),
        if (_showAdd)
          _AddProviderForm(
            api: widget.api,
            onRegistered: () {
              setState(() => _showAdd = false);
              widget.onChanged();
            },
            onCancel: () => setState(() => _showAdd = false),
          )
        else
          OutlinedButton.icon(
            onPressed: () => setState(() => _showAdd = true),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Provider'),
          ),
      ],
    );
  }
}

class _AddProviderForm extends StatefulWidget {
  final ZergxApi api;
  final VoidCallback onRegistered;
  final VoidCallback onCancel;
  const _AddProviderForm(
      {required this.api,
      required this.onRegistered,
      required this.onCancel});

  @override
  State<_AddProviderForm> createState() => _AddProviderFormState();
}

class _AddProviderFormState extends State<_AddProviderForm> {
  final _id = TextEditingController();
  final _url = TextEditingController();
  final _key = TextEditingController();
  final _models = TextEditingController();
  String _apiType = 'openai-compatible';
  String _testMsg = '';
  bool _testing = false;
  bool _registering = false;

  @override
  void dispose() {
    _id.dispose();
    _url.dispose();
    _key.dispose();
    _models.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testMsg = '';
    });
    try {
      final r = await widget.api.testProvider(
          apiType: _apiType, baseUrl: _url.text, apiKey: _key.text);
      setState(() {
        _testing = false;
        _testMsg = r['ok'] == true ? (r['detail'] ?? 'OK') : (r['error'] ?? 'Failed');
      });
    } catch (e) {
      setState(() {
        _testing = false;
        _testMsg = '$e';
      });
    }
  }

  Future<void> _register() async {
    setState(() => _registering = true);
    final modelList = _models.text
        .split(',')
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .map((id) => ProviderModel(id: id, name: id))
        .toList();
    try {
      await widget.api.registerProvider(ProviderInfo(
        providerId: _id.text.trim(),
        apiType: _apiType,
        baseUrl: _url.text.trim(),
        apiKey: _key.text,
        models: modelList,
      ));
      widget.onRegistered();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    setState(() => _registering = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
                controller: _id,
                decoration: const InputDecoration(labelText: 'Provider ID *')),
            DropdownButtonFormField<String>(
              initialValue: _apiType,
              items: const [
                DropdownMenuItem(value: 'openai-compatible', child: Text('openai-compatible')),
                DropdownMenuItem(value: 'openai', child: Text('openai')),
                DropdownMenuItem(value: 'anthropic', child: Text('anthropic')),
                DropdownMenuItem(value: 'gemini', child: Text('gemini')),
              ],
              onChanged: (v) => setState(() => _apiType = v!),
              decoration: const InputDecoration(labelText: 'API Type'),
            ),
            TextField(
                controller: _url,
                decoration: const InputDecoration(labelText: 'Base URL *')),
            TextField(
                controller: _key,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'API Key *')),
            TextField(
                controller: _models,
                decoration: const InputDecoration(
                    labelText: 'Models (comma-separated IDs)')),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _testing ? null : _test,
                  icon: const Icon(Icons.science_outlined, size: 14),
                  label: Text(_testing ? 'Testing...' : 'Test'),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(_testMsg,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: (_id.text.isEmpty || _url.text.isEmpty || _registering)
                      ? null
                      : _register,
                  child: Text(_registering ? 'Registering...' : 'Register'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetsDetail extends StatefulWidget {
  final ZergxApi api;
  const _PresetsDetail({required this.api});

  @override
  State<_PresetsDetail> createState() => _PresetsDetailState();
}

class _PresetsDetailState extends State<_PresetsDetail> {
  List<Preset> _presets = [];
  List<ToolInfo> _tools = [];
  bool _loading = true;
  String? _editingId;
  late Preset _edit;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _presets = await widget.api.presets();
    } catch (_) {}
    try {
      _tools = await widget.api.tools();
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _open(Preset p) {
    setState(() {
      _editingId = p.id;
      _edit = Preset(
          id: p.id,
          systemPrompt: p.systemPrompt,
          tools: [...p.tools],
          maxTurns: p.maxTurns);
    });
  }

  Future<void> _save() async {
    await widget.api.savePreset(_edit);
    await _load();
    setState(() => _editingId = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final p in _presets)
          Card(
            child: Column(
              children: [
                ListTile(
                  title: Text('${p.id} (turns:${p.maxTurns}, tools:${p.tools.length})'),
                  trailing: const Icon(Icons.expand_more, size: 18),
                  onTap: () => _editingId == p.id
                      ? setState(() => _editingId = null)
                      : _open(p),
                ),
                if (_editingId == p.id)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        TextField(
                          controller: TextEditingController(text: _edit.systemPrompt),
                          maxLines: 3,
                          decoration: const InputDecoration(labelText: 'System Prompt'),
                          onChanged: (v) => _edit = Preset(
                              id: _edit.id,
                              systemPrompt: v,
                              tools: _edit.tools,
                              maxTurns: _edit.maxTurns),
                        ),
                        TextField(
                          controller: TextEditingController(text: '${_edit.maxTurns}'),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Max Turns'),
                          onChanged: (v) => _edit = Preset(
                              id: _edit.id,
                              systemPrompt: _edit.systemPrompt,
                              tools: _edit.tools,
                              maxTurns: int.tryParse(v) ?? 30),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final t in _tools.map((t) => t.name).toList())
                              FilterChip(
                                label: Text(t, style: const TextStyle(fontSize: 11)),
                                selected: _edit.tools.contains(t),
                                onSelected: (sel) {
                                  final tools = [..._edit.tools];
                                  if (sel) {
                                    tools.add(t);
                                  } else {
                                    tools.remove(t);
                                  }
                                  setState(() => _edit = Preset(
                                      id: _edit.id,
                                      systemPrompt: _edit.systemPrompt,
                                      tools: tools,
                                      maxTurns: _edit.maxTurns));
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            FilledButton(onPressed: _save, child: const Text('Save')),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (_presets.isEmpty)
          const Padding(padding: EdgeInsets.all(8), child: Text('No presets.')),
      ],
    );
  }
}

class _ToolsDetail extends StatefulWidget {
  final ZergxApi api;
  final Map<String, ProviderInfo> providers;
  const _ToolsDetail({required this.api, required this.providers});

  @override
  State<_ToolsDetail> createState() => _ToolsDetailState();
}

class _ToolsDetailState extends State<_ToolsDetail> {
  List<ToolInfo> _tools = [];
  Map<String, dynamic> _config = {};
  String? _expanded;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _tools = await widget.api.tools();
    } catch (_) {}
    try {
      _config = await widget.api.toolConfig();
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _save(String name) async {
    try {
      _config = await widget.api.setToolConfig(
          {name: _config[name] ?? const <String, dynamic>{}});
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_tools.isEmpty) return const Center(child: Text('No tools registered.'));
    final cats = <String, List<ToolInfo>>{};
    for (final t in _tools) {
      (cats[t.category.isNotEmpty ? t.category : 'other'] ??= []).add(t);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final entry in cats.entries) ...[
          Text(entry.key.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: Theme.of(context).colorScheme.outline)),
          for (final t in entry.value) _toolCard(t),
        ],
      ],
    );
  }

  Widget _toolCard(ToolInfo t) {
    final fields = t.configFields ?? [];
    final hasConfig = (_config[t.name] ?? {}).isNotEmpty;
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(t.name,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            trailing: fields.isEmpty
                ? const Text('no config', style: TextStyle(fontSize: 10))
                : Text(hasConfig ? 'configured' : 'needs config',
                    style: TextStyle(
                        fontSize: 10,
                        color: hasConfig ? Colors.green : Colors.amber)),
            onTap: () => setState(
                () => _expanded = _expanded == t.name ? null : t.name),
          ),
          if (_expanded == t.name)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (t.description.isNotEmpty)
                    Text(t.description, style: const TextStyle(fontSize: 11)),
                  for (final f in fields) ...[
                    _field(t.name, f),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                        onPressed: () => _save(t.name),
                        child: const Text('Save')),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(String toolName, ToolConfigField f) {
    final cfg = _config[toolName] ?? const <String, dynamic>{};
    final current = cfg[f.key];
    if (f.type == 'select-provider') {
      return _dropdown(
          f.label,
          current,
          [for (final e in widget.providers.entries) e.key],
          (v) => _set(toolName, f.key, v));
    }
    if (f.type == 'select-model') {
      final providerId = cfg[f.dependsOnProvider ?? 'provider_id'] ?? '';
      final models = (providerId is String && widget.providers.containsKey(providerId))
          ? widget.providers[providerId]!.models
          : <ProviderModel>[];
      return _dropdown(
          f.label,
          current,
          [for (final m in models) m.id],
          (v) => _set(toolName, f.key, v));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: TextEditingController(text: current == null ? '' : '$current'),
        keyboardType: f.type == 'number' ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: f.label, border: const OutlineInputBorder()),
        onChanged: (v) => _set(toolName, f.key,
            f.type == 'number' ? (num.tryParse(v) ?? 0) : v),
      ),
    );
  }

  void _set(String tool, String key, Object? value) {
    setState(() {
      _config = {
        ..._config,
        tool: {...(_config[tool] ?? const <String, dynamic>{}), key: value},
      };
    });
  }

  Widget _dropdown(String label, Object? current, List<String> options,
      void Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DropdownButtonFormField<String>(
        initialValue: current == null ? null : '$current',
        items: [
          const DropdownMenuItem(value: '', child: Text('None')),
          for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
        ],
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}