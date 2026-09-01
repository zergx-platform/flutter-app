import 'dart:async';

import 'package:flutter/material.dart';

import '../i18n.dart';
import '../messages.dart';
import '../models.dart';
import '../store.dart';
import '../theme/app_theme.dart';
import '../widgets/diff_view.dart';
import '../widgets/message_bubble.dart';
import 'chat_sidebar.dart';
import 'container_overlay.dart';
import 'files_overlay.dart';
import 'overlays.dart';

/// IM-style chat screen. Mobile-first: full-height conversation, sticky
/// composer with safe-area padding, long-press message actions. Wide
/// screens keep the sidebar + overlay panel layout.
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
  final FocusNode _inputFocus = FocusNode();
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
    // Do NOT hijack store.codeOrg/codeRepo here: the Code tab is an
    // independent workspace the user browses by itself. The active session's
    // repository is only bound into the code view when the user explicitly
    // opens the Files overlay below.
  }

  Future<void> _setup() async {
    final sid = store.activeSessionId;
    if (sid == null) return;
    _msg?.dispose();
    final m = MessagesController(
        api: store.api, getSessionId: () => store.activeSessionId ?? sid);
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
    });
    m.addListener(_onMsg);
    m.init();
    // New conversation: reset scroll so it sticks to the latest message.
    _initialScrollDone = false;
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
      if (!mounted || !_scroll.hasClients) return;
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
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    setState(() {});
    await _msg?.send(text);
    _inputFocus.requestFocus();
  }

  void _applySession(Session updated) {
    store.sessions =
        store.sessions.map((s) => s.id == updated.id ? updated : s).toList();
    store.notifyObservers();
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    return Scaffold(
      body: Column(
        children: [
          _topBar(context),
          Divider(height: 1, color: colors.border.withValues(alpha: 0.5)),
          Expanded(
            child: Row(
              children: [
                if (wide)
                  SizedBox(
                    width: 260,
                    child: _sidebar(context),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: _messageList()),
                      _composer(context),
                    ],
                  ),
                ),
                if (store.sessionOverlay != null && wide)
                  SizedBox(width: 440, child: _overlayPanel(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebar(BuildContext context) {
    final colors = colorsOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
          border: Border(
              right: BorderSide(color: colors.border.withValues(alpha: 0.5)))),
      child: ChatSidebar(store: store),
    );
  }

  Widget _topBar(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    final s = store.activeSession;
    final overlayTitle = switch (store.sessionOverlay) {
      SessionOverlay.timeline => 'Timeline',
      SessionOverlay.files => 'Files',
      SessionOverlay.mailbox => 'Mailbox',
      SessionOverlay.container => 'Container',
      SessionOverlay.todos => 'Todos',
      null => '',
    };
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: AppBars.height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 22),
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
                  color: _msg?.sending == true
                      ? colors.warning
                      : colors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  s != null
                      ? '${s.org}/${s.repo}'
                          '${overlayTitle.isNotEmpty ? ' · $overlayTitle' : ''}'
                      : 'Chat',
                  overflow: TextOverflow.ellipsis,
                  style: text.meta.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.mutedForeground),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) => _menuAction(v),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'settings', child: Text(t(context, 'sessionSettings'))),
                  PopupMenuItem(value: 'compact', child: Text(t(context, 'compactHistory'))),
                  PopupMenuItem(value: 'timeline', child: Text(t(context, 'timeline'))),
                  PopupMenuItem(value: 'files', child: Text(t(context, 'files'))),
                  PopupMenuItem(value: 'mailbox', child: Text(t(context, 'mailbox'))),
                  PopupMenuItem(value: 'container', child: Text(t(context, 'container'))),
                  PopupMenuItem(value: 'todos', child: Text(t(context, 'todos'))),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(t(context, 'deleteSession'),
                        style: TextStyle(color: colors.destructive)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _menuAction(String v) {
    switch (v) {
      case 'settings':
        _showSettings();
      case 'compact':
        _compact();
      case 'timeline':
        _openOverlay(SessionOverlay.timeline);
      case 'files':
        _openOverlay(SessionOverlay.files);
      case 'mailbox':
        _openOverlay(SessionOverlay.mailbox);
      case 'container':
        _openOverlay(SessionOverlay.container);
      case 'todos':
        _openOverlay(SessionOverlay.todos);
      case 'delete':
        _deleteSession();
    }
  }

  /// Open a session sub-page. Wide screens dock it as a right panel; phones
  /// push a full-screen route (the side panel is width-gated at 1024px, so
  /// without this the overlay would be set but never rendered on mobile).
  void _openOverlay(SessionOverlay overlay) {
    store.openOverlay(overlay);
    if (MediaQuery.sizeOf(context).width < 1024) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _OverlayPage(store: store, overlay: overlay),
      ));
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
        title: Text(t(context, 'deleteSessionTitle')),
        content: Text(t(context, 'deleteSessionBody', [label])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t(ctx, 'cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: colorsOf(ctx).destructive,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t(ctx, 'delete')),
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
      final created = await store.api.compact(sid);
      if (!mounted) return;
      if (created) {
        // A compaction checkpoint was created: reopen the conversation so the
        // new "历史已压缩" summary message renders at the top of the tail.
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t(context, 'historyCompacted'))));
        await _setup();
      } else {
        // Nothing to fold (the agent returns {ok:false}); the current
        // conversation is unchanged.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(t(context, 'nothingToCompact'))));
      }
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
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          String model = store.activeSession?.model ?? '';
          String preset = store.activeSession?.preset ?? '';
          return AlertDialog(
            title: Text(t(ctx, 'settingsTitle')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Model is the session's current model; the picker lists
                  // registered provider models.
                  DropdownButtonFormField<String>(
                    initialValue: model.isEmpty ? null : model,
                    items: [
                      for (final mo in _models)
                        DropdownMenuItem(value: mo.id, child: Text(mo.id)),
                    ],
                    onChanged: (v) => setState(() => model = v ?? ''),
                    decoration: InputDecoration(labelText: t(ctx, 'modelLabel')),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: preset.isEmpty ? null : preset,
                    items: [
                      for (final p in _presets)
                        DropdownMenuItem(value: p.id, child: Text(p.id)),
                    ],
                    onChanged: (v) => setState(() => preset = v ?? ''),
                    decoration: InputDecoration(labelText: t(ctx, 'presetLabel')),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: maxTurns,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: t(ctx, 'maxTurnsLabel')),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: sysPrompt,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: t(ctx, 'sysPromptLabel')),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(t(ctx, 'cancel')),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final updates = <String, dynamic>{};
                  if (model.isNotEmpty) updates['model'] = model;
                  if (preset.isNotEmpty) updates['preset'] = preset;
                  if (maxTurns.text.isNotEmpty) {
                    updates['max_turns'] = int.tryParse(maxTurns.text);
                  }
                  updates['system_prompt'] = sysPrompt.text;
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
                child: Text(t(ctx, 'apply')),
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
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
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
          key: ValueKey(msg.id),
          msg: msg,
          onUndo: (id) => m.revert(id),
          onOpenChange: (changeId) => store.openChange(changeId),
        );
      },
    );
  }

  Widget _composer(BuildContext context) {
    final m = _msg;
    final colors = colorsOf(context);
    final text = textOf(context);
    final sending = m?.sending ?? false;
    final last = ((store.activeSession?.lastInputTokens ?? 0) +
        (store.activeSession?.lastOutputTokens ?? 0));
    return Container(
      decoration: BoxDecoration(
          color: colors.card,
          border: Border(
              top: BorderSide(color: colors.border.withValues(alpha: 0.5)))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _inputFocus,
                      enabled: !sending,
                      minLines: 1,
                      maxLines: 6,
                      textInputAction: TextInputAction.newline,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: t(context, 'typeMessage'),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  sending
                      ? IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: colors.destructive,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.stop_rounded, size: 20),
                          onPressed: () => m?.stop(),
                        )
                      : IconButton.filled(
                          onPressed: _input.text.trim().isEmpty ? null : _send,
                          icon: const Icon(Icons.send_rounded, size: 20),
                        ),
                ],
              ),
              const SizedBox(height: 4),
              // Footer: right-aligned context token total (last turn's
              // request context), shown as e.g. "上下文 13.2K".
              Row(
                children: [
                  const Spacer(),
                  if (last > 0)
                    Text(
                      '上下文 ${_k(last)}',
                      style: text.micro.copyWith(
                          color: colors.mutedForeground),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _k(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  Widget _overlayPanel(BuildContext context) {
    final colors = colorsOf(context);
    final overlay = store.sessionOverlay;
    return DecoratedBox(
      decoration: BoxDecoration(
          border: Border(
              left: BorderSide(color: colors.border.withValues(alpha: 0.5)))),
      child: Column(
        children: [
          SizedBox(
            height: AppBars.height,
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    child: Row(
                      children: [
                        for (final t in SessionOverlay.values)
                          _OverlayTab(
                            label: _overlayLabel(t),
                            selected: overlay == t,
                            onTap: () => store.openOverlay(t),
                          ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: () => store.closeOverlay()),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border.withValues(alpha: 0.5)),
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

class _OverlayTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _OverlayTab(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.rSm,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs + 1),
          decoration: BoxDecoration(
            color: selected ? colors.muted : Colors.transparent,
            borderRadius: AppRadius.rSm,
          ),
          child: Text(label,
              style: text.micro.copyWith(
                  color: selected ? colors.primary : colors.mutedForeground,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal)),
        ),
      ),
    );
  }
}

/// Full-screen host for a session overlay on phones. Back button closes the
/// overlay state so the side panel (wide screens) stays in sync.
class _OverlayPage extends StatelessWidget {
  final AppStore store;
  final SessionOverlay overlay;
  const _OverlayPage({required this.store, required this.overlay});

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (overlay) {
      case SessionOverlay.timeline:
        if (store.diffChangeId != null) {
          body = TimelineDiffScreen(
              store: store, changeId: store.diffChangeId!);
        } else {
          body = TimelineOverlay(
              store: store, onSelectDiff: (id) => store.openChange(id));
        }
      case SessionOverlay.files:
        body = FilesOverlay(store: store);
      case SessionOverlay.mailbox:
        body = MailboxOverlay(store: store);
      case SessionOverlay.container:
        body = ContainerOverlay(store: store);
      case SessionOverlay.todos:
        body = TodosOverlay(store: store);
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            store.closeOverlay();
            Navigator.of(context).pop();
          },
        ),
        title: Text(switch (overlay) {
          SessionOverlay.timeline => t(context, 'timeline'),
          SessionOverlay.files => t(context, 'files'),
          SessionOverlay.mailbox => t(context, 'mailbox'),
          SessionOverlay.container => t(context, 'container'),
          SessionOverlay.todos => t(context, 'todos'),
        }),
      ),
      body: body,
    );
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
    final colors = colorsOf(context);
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.commit_rounded),
          title: Text('Diff: ${widget.changeId.substring(0, 12)}',
              style: textOf(context).mono),
          trailing: TextButton(
              onPressed: () {
                if (store.diffChangeId != null) {
                  store.diffChangeId = null;
                } else {
                  store.sessionOverlay = SessionOverlay.timeline;
                }
              },
              child: Text(t(context, 'back')),
              ),
        ),
        Expanded(
          child: _error.isNotEmpty
              ? Center(
                  child: Text(_error,
                      style: TextStyle(color: colors.mutedForeground)))
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
                                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                            child: Text(f.path,
                                style: textOf(context)
                                    .mono
                                    .copyWith(color: colors.primary)),
                          ),
                        ),
                        if (f.diffText != null && f.diffText!.isNotEmpty)
                          DiffView(diffText: f.diffText!),
                        Divider(height: 1, color: colors.border),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

