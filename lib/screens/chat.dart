import 'dart:async';

import 'package:flutter/material.dart';

import '../messages.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/diff_view.dart';
import '../widgets/message_bubble.dart';
import 'chat_sidebar.dart';
import 'container_overlay.dart';
import 'files_overlay.dart';
import 'overlays.dart';

/// Recreates ChatPage.svelte: main chat column + overlay side panel.
class ChatScreen extends StatefulWidget {
  final AppStore store;
  const ChatScreen({super.key, required this.store});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  AppStore get store => widget.store;
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  MessagesController? _msg;
  List<ModelInfo> _models = [];
  List<Preset> _presets = [];
  bool _initialScrollDone = false;

  @override
  void initState() {
    super.initState();
    _setup();
    _loadMeta();
    store.addListener(_onStore);
    store.refreshSessions();
    store.refreshRepos();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    final m = _msg;
    if (m == null || !_scroll.hasClients) return;
    // Near the top and there is more history → auto-load older messages.
    if (_scroll.position.pixels < 80 && m.hasMore && !m.loading) {
      m.loadMore();
    }
  }

  void _onStore() {
    final sid = store.activeSessionId;
    final m = _msg;
    if (m == null || sid == null) return;
    // re-init if session (or identity) changed
    if (m.getSessionId() != sid) {
      _setup();
    }
  }

  Future<void> _loadMeta() async {
    try {
      _models = await widget.store.api.models();
    } catch (_) {}
    try {
      _presets = await widget.store.api.presets();
    } catch (_) {}
    if (mounted) setState(() {});
    final s = store.activeSession;
    if (s != null) {
      store.openRepo(s.org, s.repo, s.branch);
    }
  }

  Future<void> _setup() async {
    final sid = store.activeSessionId;
    if (sid == null) return;
    _msg?.dispose();
    final m = MessagesController(api: store.api, getSessionId: () => store.activeSessionId ?? sid);
    m.onSessionEvent((event, params) {
      if (event == 'todos-updated' || event == 'turn-complete') {
        store.bumpSessionRevision();
      }
      if (event == 'tool-result' && params['change_id'] is String) {
        store.bumpSessionRevision();
      }
      if (event == 'status' && params['type'] == 'busy') {
        store.bumpSessionRevision();
      }
      if (event == 'turn-complete') {
        store.bumpSessionRevision();
      }
    });
    m.addListener(_onMsg);
    m.init();
    setState(() => _msg = m);
  }

  void _onMsg() {
    if (!mounted) return;
    setState(() {});
    _autoScroll();
  }

  void _autoScroll() {
    if (!_scroll.hasClients) return;
    final m = _msg;
    if (m == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      if (!_initialScrollDone) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
        _initialScrollDone = true;
      } else if (m.sending) {
        final nearBottom = _scroll.position.maxScrollExtent -
                _scroll.position.pixels <
            120;
        if (nearBottom) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    store.removeListener(_onStore);
    _msg?.removeListener(_onMsg);
    _msg?.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    await _msg?.send(text);
  }

  Future<void> _switchModel(String modelId) async {
    final sid = store.activeSessionId;
    if (sid == null) return;
    try {
      final updated = await store.api.settings(sid, {'model': modelId});
      _applySession(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _switchPreset(String presetId) async {
    final sid = store.activeSessionId;
    if (sid == null) return;
    try {
      final updated = await store.api.settings(sid, {'preset': presetId});
      _applySession(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _applySession(Session updated) {
    store.sessions =
        store.sessions.map((s) => s.id == updated.id ? updated : s).toList();
    store.notifyObservers();
  }

  String get _modelName {
    final s = store.activeSession;
    final matches = _models.where((m) => m.id == s?.model);
    final m = matches.isEmpty ? null : matches.first;
    return m?.name ?? s?.model ?? 'Select model';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Row(
        children: [
          if (MediaQuery.of(context).size.width >= 1024)
            SizedBox(
              width: 260,
              child: _sidebar(context),
            ),
          Expanded(
            child: Column(
              children: [
                _topBar(theme),
                Expanded(child: _messageList()),
                _composer(theme),
              ],
            ),
          ),
          if (store.sessionOverlay != null &&
              MediaQuery.of(context).size.width >= 1024)
            SizedBox(width: 440, child: _overlayPanel(theme)),
        ],
      ),
    );
  }

  Widget _sidebar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Theme.of(context).dividerColor))),
      child: Column(
        children: [
          Expanded(
            child: ChatSidebar(store: store),
          ),
        ],
      ),
    );
  }

  Widget _topBar(ThemeData theme) {
    final s = store.activeSession;
    final overlayTitle = switch (store.sessionOverlay) {
      SessionOverlay.timeline => 'Timeline',
      SessionOverlay.files => 'Files',
      SessionOverlay.mailbox => 'Mailbox',
      SessionOverlay.container => 'Container',
      SessionOverlay.todos => 'Todos',
      null => '',
    };
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.dividerColor))),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () {
              if (store.sessionOverlay != null) {
                store.closeOverlay();
              } else {
                store.closeSession();
              }
            },
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _msg?.sending == true ? Colors.amber : Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s != null
                  ? '${s.org}/${s.repo}'
                      '${overlayTitle.isNotEmpty ? ' · $overlayTitle' : ''}'
                  : 'Chat',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => _menuAction(v),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'settings', child: Text('Session settings')),
              const PopupMenuItem(value: 'compact', child: Text('Compact history')),
              const PopupMenuItem(value: 'timeline', child: Text('Timeline')),
              const PopupMenuItem(value: 'files', child: Text('Files')),
              const PopupMenuItem(value: 'mailbox', child: Text('Mailbox')),
              const PopupMenuItem(value: 'container', child: Text('Container')),
              const PopupMenuItem(value: 'todos', child: Text('Todos')),
              const PopupMenuItem(value: 'delete', child: Text('Delete session')),
            ],
          ),
        ],
      ),
    );
  }

  void _menuAction(String v) {
    switch (v) {
      case 'settings':
        _showSettings();
        break;
      case 'compact':
        _compact();
        break;
      case 'timeline':
        store.openOverlay(SessionOverlay.timeline);
        break;
      case 'files':
        store.openOverlay(SessionOverlay.files);
        break;
      case 'mailbox':
        store.openOverlay(SessionOverlay.mailbox);
        break;
      case 'container':
        store.openOverlay(SessionOverlay.container);
        break;
      case 'todos':
        store.openOverlay(SessionOverlay.todos);
        break;
      case 'delete':
        _deleteSession();
        break;
    }
  }

  Future<void> _deleteSession() async {
    final sid = store.activeSessionId;
    final s = store.activeSession;
    if (sid == null) return;
    final label = s != null && s.org.isNotEmpty
        ? '${s.org}/${s.repo}/${s.branch}'
        : sid;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session'),
        content: Text('Delete session "$label"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        if (s != null && s.org.isNotEmpty) {
          await store.deleteBookmark(s.org, s.repo, s.branch);
        } else {
          await store.deleteSession(sid);
        }
      } catch (_) {
        await store.deleteSession(sid);
      }
      store.closeSession();
    }
  }

  Future<void> _compact() async {
    final sid = store.activeSessionId;
    if (sid == null) return;
    try {
      await store.api.compact(sid);
      await _setup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _showSettings() {
    final sid = store.activeSessionId;
    if (sid == null) return;
    final maxTurns = TextEditingController(
        text: store.activeSession?.maxTurns?.toString() ?? '');
    final sysPrompt = TextEditingController(
        text: store.activeSession?.systemPrompt ?? '');
    final baseImage = TextEditingController(
        text: store.activeSession?.baseImage ?? '');
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          String preset = store.activeSession?.preset ?? '';
          return AlertDialog(
            title: const Text('Session Settings'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: preset.isEmpty ? null : preset,
                    items: [
                      for (final p in _presets)
                        DropdownMenuItem(value: p.id, child: Text(p.id)),
                    ],
                    onChanged: (v) => setState(() => preset = v ?? ''),
                    decoration: const InputDecoration(labelText: 'Preset'),
                  ),
                  TextField(
                    controller: maxTurns,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Max Turns'),
                  ),
                  TextField(
                    controller: sysPrompt,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'System Prompt (blank = inherit)'),
                  ),
                  TextField(
                    controller: baseImage,
                    decoration: const InputDecoration(labelText: 'Worker Base Image'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final updates = <String, dynamic>{};
                  if (preset.isNotEmpty) updates['preset'] = preset;
                  if (maxTurns.text.isNotEmpty) {
                    updates['max_turns'] = int.tryParse(maxTurns.text);
                  }
                  updates['system_prompt'] = sysPrompt.text;
                  updates['base_image'] =
                      baseImage.text.trim().isEmpty ? null : baseImage.text.trim();
                  try {
                    final updated = await store.api.settings(sid, updates);
                    _applySession(updated);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _messageList() {
    final m = _msg;
    if (m == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(12),
      itemCount: m.sorted.length + (m.hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == 0 && m.hasMore) {
          return Center(
            child: TextButton(
              onPressed: m.loading ? null : () => m.loadMore(),
              child: Text(m.loading ? 'Loading...' : 'Load earlier'),
            ),
          );
        }
        final msg = m.sorted[i - (m.hasMore ? 1 : 0)];
        return MessageBubble(
          msg: msg,
          onUndo: (id) => m.revert(id),
          onOpenChange: (changeId) => store.openChange(changeId),
        );
      },
    );
  }

  Widget _composer(ThemeData theme) {
    final m = _msg;
    final sending = m?.sending ?? false;
    return Container(
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.dividerColor))),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  enabled: !sending,
                  minLines: 1,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              sending
                  ? IconButton.filled(
                      icon: const Icon(Icons.stop, size: 18),
                      onPressed: () => m?.stop(),
                    )
                  : IconButton.filled(
                      onPressed: _input.text.trim().isEmpty ? null : _send,
                      icon: const Icon(Icons.send, size: 18),
                    ),
            ],
          ),
          SizedBox(
            height: 32,
            child: Row(
              children: [
                _pickerBox(
                  label: _modelName,
                  items: [for (final m in _models) m.id],
                  onPick: _switchModel,
                  maxWidth: 200,
                ),
                const SizedBox(width: 8),
                _pickerBox(
                  label: store.activeSession?.preset ?? 'preset',
                  items: [for (final p in _presets) p.id],
                  onPick: _switchPreset,
                  maxWidth: 160,
                ),
                const Spacer(),
                if (sending) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Colors.amber),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pickerBox(
      {required String label,
      required List<String> items,
      required void Function(String) onPick,
      required double maxWidth}) {
    return _Dropdown(
        label: label,
        items: items,
        onSelect: onPick,
        maxWidth: maxWidth);
  }

  Widget _overlayPanel(ThemeData theme) {
    final overlay = store.sessionOverlay;
    return Container(
      decoration: BoxDecoration(
          border: Border(left: BorderSide(color: theme.dividerColor))),
      child: Column(
        children: [
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final t in SessionOverlay.values)
                          TextButton(
                            onPressed: () => store.openOverlay(t),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 30),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text(_overlayLabel(t),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: overlay == t
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.outline,
                                    fontWeight: overlay == t
                                        ? FontWeight.w600
                                        : FontWeight.normal)),
                          ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => store.closeOverlay()),
              ],
            ),
          ),
          Expanded(child: _buildOverlay()),
        ],
      ),
    );
  }

  String _overlayLabel(SessionOverlay t) {
    switch (t) {
      case SessionOverlay.timeline:
        return 'Timeline';
      case SessionOverlay.files:
        return 'Files';
      case SessionOverlay.mailbox:
        return 'Mailbox';
      case SessionOverlay.container:
        return 'Container';
      case SessionOverlay.todos:
        return 'Todos';
    }
  }

  Widget _buildOverlay() {
    switch (store.sessionOverlay) {
      case SessionOverlay.timeline:
        if (store.diffChangeId != null) {
          return TimelineDiffScreen(store: store, changeId: store.diffChangeId!);
        }
        return TimelineOverlay(
            store: store, onSelectDiff: (id) => store.openChange(id));
      case SessionOverlay.files:
        return FilesOverlay(store: store);
      case SessionOverlay.mailbox:
        return MailboxOverlay(store: store);
      case SessionOverlay.container:
        return ContainerOverlay(store: store);
      case SessionOverlay.todos:
        return TodosOverlay(store: store);
      case null:
        return const SizedBox.shrink();
    }
  }
}

class TimelineDiffScreen extends StatefulWidget {
  final AppStore store;
  final String changeId;
  const TimelineDiffScreen(
      {super.key, required this.store, required this.changeId});

  @override
  State<TimelineDiffScreen> createState() => _TimelineDiffScreenState();
}

class _TimelineDiffScreenState extends State<TimelineDiffScreen> {
  AppStore get store => widget.store;
  List<DiffFile> _files = [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = widget.store.activeSession;
    if (s == null) return;
    try {
      final f = await widget.store.api.diffChange(s.org, s.repo, widget.changeId);
      setState(() {
        _files = f;
        if (f.isEmpty) _error = 'No changes found';
      });
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          dense: true,
          leading: const Icon(Icons.commit),
          title: Text('Diff: ${widget.changeId.substring(0, 12)}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          trailing: TextButton(
              onPressed: () {
              if (store.diffChangeId != null) {
                store.diffChangeId = null;
              } else {
                store.sessionOverlay = SessionOverlay.timeline;
              }
            },
              child: const Text('Back')),
        ),
        Expanded(
          child: _error.isNotEmpty
              ? Center(
                  child: Text(_error,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline)))
              : ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (_, i) {
                    final f = _files[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          onTap: () => widget.store.openFile(f.path),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: Text(f.path,
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    fontFamily: 'monospace',
                                    fontSize: 12)),
                          ),
                        ),
                        if (f.diffText != null && f.diffText!.isNotEmpty)
                          DiffView(diffText: f.diffText!),
                        const Divider(height: 1),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String label;
  final List<String> items;
  final void Function(String) onSelect;
  final double maxWidth;
  const _Dropdown(
      {required this.label,
      required this.items,
      required this.onSelect,
      required this.maxWidth});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelect,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12))),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
      itemBuilder: (context) => [
        for (final i in items)
          PopupMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 12))),
      ],
    );
  }
}

