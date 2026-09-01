import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../store.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs.dart';

/// Recreates ConfigPage.svelte (simplified, without the external
/// models.dev template fetch and PWA install section).
class ConfigScreen extends StatefulWidget {
  final AppStore store;
  final bool darkMode;
  final ValueChanged<bool> onDarkMode;
  final VoidCallback? onLogout;
  const ConfigScreen({
    super.key,
    required this.store,
    this.darkMode = true,
    required this.onDarkMode,
    this.onLogout,
  });

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  AppStore get store => widget.store;
  Map<String, ProviderInfo> _providers = {};
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
      final p = await store.api.providers();
      if (mounted) _providers = p;
    } catch (_) {}
    setState(() => _loading = false);
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
      default:
        return id;
    }
  }

  Widget _listView() {
    return ListView(
      children: [
        const _SectionHeader('App'),
        _listTile(Icons.palette_outlined, 'Appearance', () => _push('appearance')),
        const _SectionHeader('LlM'),
        _listTile(Icons.dns_outlined, 'LLM Providers', () => _push('providers')),
        _listTile(Icons.auto_awesome_outlined, 'Presets', () => _push('presets')),
        const _SectionHeader('Workspace'),
        _listTile(Icons.handyman_outlined, 'Tools', () => _push('tools')),
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
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _appearance() {
    final dark = widget.darkMode;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Dark mode'),
          subtitle: const Text('Toggle light/dark appearance'),
          value: dark,
          onChanged: (v) => widget.onDarkMode(v),
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
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xs),
      child: Text(text.toUpperCase(),
          style: textOf(context).micro.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: colorsOf(context).mutedForeground)),
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
    final colors = colorsOf(context);
    final text = textOf(context);
    final entries = widget.providers.entries.toList();
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        for (final e in entries)
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ListTile(
              title: Text('${e.key} (${e.value.apiType})'),
              subtitle: Text(e.value.baseUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.micro.copyWith(color: colors.mutedForeground)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${e.value.models.length} models',
                      style: text.micro.copyWith(color: colors.mutedForeground)),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 18, color: colors.mutedForeground),
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
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text('No providers. Add one to get started.',
                style: TextStyle(color: colors.mutedForeground)),
          ),
        const SizedBox(height: AppSpacing.sm),
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
            icon: const Icon(Icons.add_rounded, size: 16),
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
    final colors = colorsOf(context);
    final text = textOf(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
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
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _testing ? null : _test,
                  icon: const Icon(Icons.science_outlined, size: 14),
                  label: Text(_testing ? 'Testing...' : 'Test'),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(_testMsg,
                      overflow: TextOverflow.ellipsis,
                      style: text.micro.copyWith(color: colors.mutedForeground)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
                const SizedBox(width: AppSpacing.sm),
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
  bool _showNew = false;
  final _newId = TextEditingController();

  static const _seedPresetIds = {'default', 'build', 'plan'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newId.dispose();
    super.dispose();
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

  Future<void> _create() async {
    final id = _newId.text.trim();
    if (id.isEmpty) return;
    await widget.api.savePreset(
        Preset(id: id, systemPrompt: '', tools: [], maxTurns: 30));
    setState(() => _showNew = false);
    _newId.clear();
    await _load();
  }

  Future<void> _delete(Preset p) async {
    final ok = await confirmDialog(context,
        title: 'Delete preset', description: 'Delete preset ${p.id}?');
    if (ok) {
      await widget.api.deletePreset(p.id);
      await _load();
    }
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
    final colors = colorsOf(context);
    final text = textOf(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (_showNew) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newId,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Preset id...'),
                  onSubmitted: (_) => _create(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                  onPressed: _newId.text.trim().isEmpty ? null : _create,
                  child: const Text('Create')),
              IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => setState(() => _showNew = false)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ] else
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _showNew = true),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('New preset'),
            ),
          ),
        for (final p in _presets)
          Card(
            margin: const EdgeInsets.only(top: AppSpacing.sm),
            child: Column(
              children: [
                ListTile(
                  title: Text(
                      '${p.id} (turns:${p.maxTurns}, tools:${p.tools.length})'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_seedPresetIds.contains(p.id))
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded,
                              size: 18, color: colors.mutedForeground),
                          onPressed: () => _delete(p),
                        ),
                      Icon(Icons.expand_more_rounded,
                          size: 18, color: colors.mutedForeground),
                    ],
                  ),
                  onTap: () => _editingId == p.id
                      ? setState(() => _editingId = null)
                      : _open(p),
                ),
                if (_editingId == p.id)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: [
                        TextField(
                          controller:
                              TextEditingController(text: _edit.systemPrompt),
                          maxLines: 3,
                          decoration:
                              const InputDecoration(labelText: 'System Prompt'),
                          onChanged: (v) => _edit = Preset(
                              id: _edit.id,
                              systemPrompt: v,
                              tools: _edit.tools,
                              maxTurns: _edit.maxTurns),
                        ),
                        TextField(
                          controller: TextEditingController(
                              text: '${_edit.maxTurns}'),
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Max Turns'),
                          onChanged: (v) => _edit = Preset(
                              id: _edit.id,
                              systemPrompt: _edit.systemPrompt,
                              tools: _edit.tools,
                              maxTurns: int.tryParse(v) ?? 30),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            for (final t in _tools.map((t) => t.name).toList())
                              FilterChip(
                                label: Text(t, style: text.micro),
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
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            FilledButton(
                                onPressed: _save, child: const Text('Save')),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (_presets.isEmpty)
          Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child:
                  Text('No presets.', style: TextStyle(color: colors.mutedForeground))),
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        for (final entry in cats.entries) ...[
          Text(entry.key.toUpperCase(),
              style: textOf(context).micro.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: colorsOf(context).mutedForeground)),
          for (final t in entry.value) _toolCard(t),
        ],
      ],
    );
  }

  Widget _toolCard(ToolInfo t) {
    final colors = colorsOf(context);
    final text = textOf(context);
    final fields = t.configFields ?? [];
    final hasConfig = (_config[t.name] ?? {}).isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        children: [
          ListTile(
            title: Text(t.name, style: text.mono.copyWith(fontSize: 12)),
            trailing: fields.isEmpty
                ? Text('no config',
                    style: text.micro.copyWith(color: colors.mutedForeground))
                : Text(hasConfig ? 'configured' : 'needs config',
                    style: text.micro.copyWith(
                        color: hasConfig ? colors.success : colors.warning)),
            onTap: () => setState(
                () => _expanded = _expanded == t.name ? null : t.name),
          ),
          if (_expanded == t.name)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (t.description.isNotEmpty)
                    Text(t.description,
                        style: text.micro
                            .copyWith(color: colors.mutedForeground)),
                  for (final f in fields) ...[
                    _field(t.name, f),
                  ],
                  const SizedBox(height: AppSpacing.sm),
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
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: TextField(
        controller: TextEditingController(text: current == null ? '' : '$current'),
        keyboardType: f.type == 'number' ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: f.label),
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
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: DropdownButtonFormField<String>(
        initialValue: current == null ? null : '$current',
        items: [
          const DropdownMenuItem(value: '', child: Text('None')),
          for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
        ],
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}