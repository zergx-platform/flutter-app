import 'package:flutter/material.dart';

import '../api.dart';
import '../i18n.dart';
import '../models.dart';
import '../store.dart';
import '../theme/app_theme.dart';
import '../services/models_dev.dart';
import '../widgets/dialogs.dart';

/// Recreates ConfigPage.svelte (simplified, without the external
/// models.dev template fetch and PWA install section).
class ConfigScreen extends StatefulWidget {
  final AppStore store;
  final bool darkMode;
  final ValueChanged<bool> onDarkMode;
  final VoidCallback? onSwitchBackend;
  const ConfigScreen({
    super.key,
    required this.store,
    this.darkMode = true,
    required this.onDarkMode,
    this.onSwitchBackend,
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
    // Back-gesture handling for the in-Config sub-pages (providers/presets/
    // tools/appearance), which are NOT Navigator routes — without this the
    // system back on a sub-page would pop the whole route and exit to the
    // launcher instead of returning to the settings list.
    return PopScope(
      canPop: _stack.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_stack.isNotEmpty) _pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _stack.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.arrow_back), onPressed: _pop)
              : null,
          title: Text(_stack.isNotEmpty
              ? _titleOf(_stack.last)
              : context.l10n.settings),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _stack.isEmpty
                ? _listView(context)
                : _detail(_stack.last, context),
      ),
    );
  }

  String _titleOf(String id) {
    switch (id) {
      case 'providers':
        return context.l10n.llmProviders;
      case 'presets':
        return context.l10n.presets;
      case 'appearance':
        return context.l10n.appearance;
      case 'tools':
        return context.l10n.tools;
      default:
        return id;
    }
  }

  Widget _listView(BuildContext context) {
    return ListView(
      children: [
        _SectionHeader(context.l10n.appearance),
        _listTile(context, Icons.palette_outlined, 'appearance',
            () => _push('appearance')),
        _SectionHeader(context.l10n.backendSection),
        // Highlighted as a dangerous action: switching disconnects the
        // active workspace mid-flight.
        ListTile(
          leading: Icon(Icons.swap_horiz_rounded,
              size: 20, color: colorsOf(context).destructive),
          title: Text(context.l10n.switchBackend,
              style: textOf(context).meta.copyWith(
                  color: colorsOf(context).destructive,
                  fontWeight: FontWeight.w600)),
          trailing: Icon(Icons.chevron_right,
              size: 18, color: colorsOf(context).destructive),
          onTap: () => widget.onSwitchBackend?.call(),
        ),
        _SectionHeader(context.l10n.llm),
        _listTile(context, Icons.dns_outlined, 'providers',
            () => _push('providers')),
        _listTile(
            context, Icons.auto_awesome_outlined, 'presets', () => _push('presets')),
        _SectionHeader(context.l10n.workspace),
        _listTile(
            context, Icons.handyman_outlined, 'tools', () => _push('tools')),
        _SectionHeader(context.l10n.language),
        _listTile(context, Icons.language_rounded, 'language', _pickLanguage),
      ],
    );
  }

  Future<void> _pickLanguage() async {
    final cur = I18n.locale.languageCode;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(ctx.l10n.language),
        children: [
          for (final (code, label) in [
            ('zh', '中文'),
            ('en', 'English'),
          ])
            ListTile(
              leading: Icon(
                  I18n.locale.languageCode == code
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: colorsOf(ctx).primary),
              title: Text(label),
              onTap: () => Navigator.pop(ctx, code),
            ),
        ],
      ),
    );
    if (picked != null && picked != cur) {
      await I18n.save(Locale(picked));
    }
  }

  Widget _listTile(
      BuildContext context, IconData icon, String labelKey, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(l10nString(labelKey)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }

  Widget _detail(String id, BuildContext context) {
    switch (id) {
      case 'appearance':
        return _appearance(context);
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

  Widget _appearance(BuildContext context) {
    final dark = widget.darkMode;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: Text(context.l10n.darkMode),
          subtitle: Text(context.l10n.darkModeSub),
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
              title: Text(context.l10n.providerTitle(e.key, e.value.apiType)),
              subtitle: Text(e.value.baseUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.micro.copyWith(color: colors.mutedForeground)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.modelsCount('${e.value.models.length}'),
                      style: text.micro.copyWith(color: colors.mutedForeground)),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 18, color: colors.mutedForeground),
                    onPressed: () async {
                      final ok = await confirmDialog(context,
                          title: context.l10n.deleteProvider,
                          description:
                              context.l10n.deleteProviderBody(e.key));
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
            child: Text(context.l10n.noProviders,
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
            label: Text(context.l10n.addProvider),
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

  // models.dev template prefill (lazy-loaded on first picker open).
  MdProvider? _template;
  final Set<String> _selectedModels = {};
  String _modelQuery = '';

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
    final modelList = _template != null
        ? _template!.models
            .where((m) => _selectedModels.contains(m.id))
            .map((m) => ProviderModel(id: m.id, name: m.name))
            .toList()
        : _models.text
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

  /// Template picker: searchable full-screen sheet over the models.dev
  /// catalogue (lazy load + 1h cache inside [ModelsDev]).
  Future<void> _pickTemplate() async {
    final picked = await Navigator.of(context).push(MaterialPageRoute<MdProvider>(
      builder: (_) => const _TemplatePickerPage(),
    ));
    if (picked == null) return;
    setState(() {
      _template = picked;
      _selectedModels.clear();
      _modelQuery = '';
      _id.text = picked.id;
      if (picked.api.isNotEmpty) _url.text = picked.api;
      _apiType = ModelsDev.npmToType(picked.npm);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    final templateModels = _template?.models ?? <MdModel>[];
    final filteredModels = _modelQuery.isEmpty
        ? templateModels
        : templateModels
            .where((m) =>
                m.id.toLowerCase().contains(_modelQuery.toLowerCase()) ||
                m.name.toLowerCase().contains(_modelQuery.toLowerCase()))
            .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // models.dev template prefill: fills id / base URL / api type
            // and swaps the models CSV for a searchable multi-select.
            InkWell(
              borderRadius: AppRadius.rSm,
              onTap: _pickTemplate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: context.l10n.providerTemplate,
                  prefixIcon: const Icon(Icons.auto_awesome_outlined,
                      size: 18),
                  suffixIcon: _template == null
                      ? const Icon(Icons.chevron_right_rounded, size: 18)
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          tooltip: context.l10n.none,
                          onPressed: () => setState(() {
                            _template = null;
                            _selectedModels.clear();
                          }),
                        ),
                ),
                child: Text(
                  _template == null
                      ? context.l10n.providerTemplateHint
                      : _template!.name,
                  style: text.meta.copyWith(
                      color: _template == null
                          ? colors.mutedForeground
                          : null),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            TextField(
                controller: _id,
                decoration: InputDecoration(
                    labelText: context.l10n.providerIdReq)),
            DropdownButtonFormField<String>(
              initialValue: _apiType,
              items: [
                const DropdownMenuItem(
                    value: 'openai-compatible',
                    child: Text('openai-compatible')),
                DropdownMenuItem(
                    value: 'openai',
                    child: Text(context.l10n.apiTypeOpenai)),
                DropdownMenuItem(
                    value: 'anthropic',
                    child: Text(context.l10n.apiTypeAnthropic)),
                DropdownMenuItem(
                    value: 'gemini',
                    child: Text(context.l10n.apiTypeGemini)),
              ],
              onChanged: (v) => setState(() => _apiType = v!),
              decoration:
                  InputDecoration(labelText: context.l10n.apiType),
            ),
            TextField(
                controller: _url,
                decoration: InputDecoration(
                    labelText: context.l10n.baseUrlReq)),
            TextField(
                controller: _key,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: context.l10n.apiKeyReq)),
            if (_template == null)
              TextField(
                  controller: _models,
                  decoration: InputDecoration(
                      labelText: context.l10n.modelsCsv))
            else ...[
              TextField(
                decoration: InputDecoration(
                  hintText: context.l10n.searchModels,
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _modelQuery = v),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                  context.l10n.modelsSelected('${_selectedModels.length}',
                    '${templateModels.length}'),
                  style: text.micro
                      .copyWith(color: colors.mutedForeground)),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final m in filteredModels)
                        FilterChip(
                          label: Text(m.name.isNotEmpty ? m.name : m.id,
                              style: text.micro),
                          selected: _selectedModels.contains(m.id),
                          onSelected: (sel) => setState(() {
                            if (sel) {
                              _selectedModels.add(m.id);
                            } else {
                              _selectedModels.remove(m.id);
                            }
                          }),
                        ),
                      if (filteredModels.isEmpty)
                        Text(context.l10n.noPackagesYet,
                            style: text.micro
                                .copyWith(color: colors.mutedForeground)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _testing ? null : _test,
                  icon: const Icon(Icons.science_outlined, size: 14),
                  label: Text(_testing ? context.l10n.testing : context.l10n.test),
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
                TextButton(
                    onPressed: widget.onCancel,
                    child: Text(context.l10n.cancel)),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: (_id.text.isEmpty || _url.text.isEmpty || _registering)
                      ? null
                      : _register,
                  child: Text(
                      _registering ? context.l10n.registering : context.l10n.register),
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

  // Persistent editors for the expanded preset so keystrokes never rebuild
  // the TextFields (which would reset the cursor / leak controllers).
  final _sysPromptCtrl = TextEditingController();
  final _maxTurnsCtrl = TextEditingController();

  static const _seedPresetIds = {'default', 'build', 'plan'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newId.dispose();
    _sysPromptCtrl.dispose();
    _maxTurnsCtrl.dispose();
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
        title: context.l10n.deletePreset,
        description: context.l10n.deletePresetBody(p.id));
    if (ok) {
      await widget.api.deletePreset(p.id);
      await _load();
    }
  }

  void _open(Preset p) {
    _sysPromptCtrl.text = p.systemPrompt;
    _maxTurnsCtrl.text = '${p.maxTurns}';
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
                  decoration: InputDecoration(
                      labelText: context.l10n.presetId),
                  onSubmitted: (_) => _create(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                  onPressed: _newId.text.trim().isEmpty ? null : _create,
                  child: Text(context.l10n.create)),
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
              label: Text(context.l10n.newPreset),
            ),
          ),
        for (final p in _presets)
          Card(
            margin: const EdgeInsets.only(top: AppSpacing.sm),
            child: Column(
              children: [
                ListTile(
                  title: Text(p.id),
                  subtitle: Text(context.l10n.presetSummary('${p.maxTurns}',
                        '${p.tools.length}')),
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
                          controller: _sysPromptCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                              labelText: context.l10n.systemPrompt),
                          onChanged: (v) => _edit = Preset(
                              id: _edit.id,
                              systemPrompt: v,
                              tools: _edit.tools,
                              maxTurns: _edit.maxTurns),
                        ),
                        TextField(
                          controller: _maxTurnsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: context.l10n.maxTurns),
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
                                onPressed: _save, child: Text(context.l10n.save)),
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
              child: Text(context.l10n.noPresets,
                  style: TextStyle(color: colors.mutedForeground))),
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

  // Persistent text controllers per "tool.key" field so editing never
  /// rebuilds a TextField with a fresh controller (cursor jump / leak).
  final Map<String, TextEditingController> _ctrls = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(String tool, String key, String initial) {
    return _ctrls.putIfAbsent('$tool.$key', () {
      final c = TextEditingController(text: initial);
      return c;
    });
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
            .showSnackBar(SnackBar(content: Text(context.l10n.saved)));
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
    if (_tools.isEmpty) {
      return Center(child: Text(context.l10n.noTools));
    }
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

  Widget _toolCard(ToolInfo tool) {
    final colors = colorsOf(context);
    final text = textOf(context);
    final fields = tool.configFields ?? [];
    final hasConfig = (_config[tool.name] ?? {}).isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        children: [
          ListTile(
            title: Text(tool.name, style: text.mono.copyWith(fontSize: 12)),
            trailing: fields.isEmpty
                ? Text(context.l10n.noConfig,
                    style: text.micro.copyWith(color: colors.mutedForeground))
                : Text(
                    hasConfig
                        ? context.l10n.configured
                        : context.l10n.needsConfig,
                    style: text.micro.copyWith(
                        color: hasConfig ? colors.success : colors.warning)),
            onTap: () => setState(
                () => _expanded = _expanded == tool.name ? null : tool.name),
          ),
          if (_expanded == tool.name)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (tool.description.isNotEmpty)
                    Text(tool.description,
                        style: text.micro
                            .copyWith(color: colors.mutedForeground)),
                  for (final f in fields) ...[
                    _field(tool.name, f),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                        onPressed: () => _save(tool.name),
                        child: Text(context.l10n.save)),
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
        controller: _ctrl(toolName, f.key, current == null ? '' : '$current'),
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
          DropdownMenuItem(value: '', child: Text(context.l10n.none)),
          for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
        ],
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
/// Searchable models.dev template picker (full-screen page).
class _TemplatePickerPage extends StatefulWidget {
  const _TemplatePickerPage();

  @override
  State<_TemplatePickerPage> createState() => _TemplatePickerPageState();
}

class _TemplatePickerPageState extends State<_TemplatePickerPage> {
  final _q = TextEditingController();
  List<MdProvider> _all = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _all = await ModelsDev.load();
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    final q = _q.text.trim().toLowerCase();
    final list = q.isEmpty
        ? _all
        : _all
            .where((p) =>
                p.name.toLowerCase().contains(q) ||
                p.id.toLowerCase().contains(q))
            .toList();
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _q,
          autofocus: false,
          decoration: InputDecoration(
            hintText: context.l10n.providerTemplateHint,
            border: InputBorder.none,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error,
                          style: TextStyle(color: colors.destructive)),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                          onPressed: () {
                            setState(() {
                              _loading = true;
                              _error = '';
                            });
                            _load();
                          },
                          child: Text(context.l10n.back)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final p = list[i];
                    return ListTile(
                      title: Text(p.name,
                          style: text.meta
                              .copyWith(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '${p.id} · ${context.l10n.modelsCount('${p.models.length}')}',
                          style: text.micro.copyWith(
                              color: colors.mutedForeground)),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          size: 18),
                      onTap: () => Navigator.pop(context, p),
                    );
                  },
                ),
    );
  }
}
