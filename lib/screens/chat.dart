import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
import 'change_diff.dart';

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
    if (text.isEmpty && _pendingAttachments.isEmpty) return;
    // Never send while an attachment is still uploading.
    if (_pendingAttachments.any((a) => a.isUploading)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.waitUpload)));
      }
      return;
    }
    // Drop errored attachments from the outgoing batch.
    final attachments =
        _pendingAttachments.where((a) => !a.hasError).toList();
    _pendingAttachments = [];
    _input.clear();
    setState(() {});
    await _msg?.send(text, attachments);
    _inputFocus.requestFocus();
  }

  List<UploadedFile> _pendingAttachments = [];
  final ImagePicker _picker = ImagePicker();

  /// Open the attach bottom sheet: camera / gallery / files. A selected item
  /// is uploaded immediately and shown (with an uploading state) above the
  /// composer.
  Future<void> _openAttachSheet() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: Text(ctx.l10n.takePhoto),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(ctx.l10n.chooseImage),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: Text(ctx.l10n.chooseFile),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );
    switch (action) {
      case 'camera':
        await _pickImage(ImageSource.camera);
      case 'gallery':
        await _pickImage(ImageSource.gallery);
      case 'file':
        await _pickFiles();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? x;
    try {
      x = await _picker.pickImage(source: source);
    } catch (_) {
      return;
    }
    if (x == null) return;
    _uploadOne(UploadedFileSource(
      path: x.path,
      name: x.name,
      mimeType: _mimeOf(x.name),
    ));
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result.isEmpty) return;
    for (final f in result) {
      final path = f.path;
      if (path == null) continue;
      _uploadOne(UploadedFileSource(
        path: path,
        name: f.name,
        mimeType: _mimeOf(f.name),
      ));
    }
  }

  /// Upload a single file and append it to the pending list. The local path
  /// is kept so an image can render a thumbnail while uploading (and before
  /// the bytes are ever needed).
  Future<void> _uploadOne(UploadedFileSource src) async {
    setState(() {
      _pendingAttachments = [
        ..._pendingAttachments,
        UploadedFile(code: '', name: src.name, mime: src.mimeType)
            .uploading(src.path),
      ];
    });
    try {
      final uploaded = await store.api.uploadFile(src);
      if (!mounted) return;
      setState(() {
        _pendingAttachments = [
          for (final a in _pendingAttachments)
            if (a.code == '' && a.name == src.name) uploaded else a,
        ];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pendingAttachments = [
          for (final a in _pendingAttachments)
            if (a.code == '' && a.name == src.name) a.uploadError('$e') else a,
        ];
      });
    }
  }

  static String _mimeOf(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.txt') || lower.endsWith('.md')) return 'text/plain';
    return 'application/octet-stream';
  }

  Widget _attachmentRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final a in _pendingAttachments) _attachmentChip(context, a),
        ],
      ),
    );
  }

  Widget _attachmentChip(BuildContext context, UploadedFile a) {
    final colors = colorsOf(context);
    final text = textOf(context);
    final isImg = (a.mime ?? '').startsWith('image/');
    // Local thumbnails render straight from disk; remote images preview only
    // after upload (code set) via the bubble; here we show the offline thumb.
    Widget leading;
    if (isImg && a.localPath.isNotEmpty) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(a.localPath),
          width: 34,
          height: 34,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox(
              width: 34,
              height: 34,
              child: Icon(Icons.broken_image_outlined, size: 16)),
        ),
      );
    } else {
      leading = Icon(Icons.attach_file_rounded,
          size: 14, color: colors.mutedForeground);
    }
    Widget trailing;
    if (a.isUploading) {
      trailing = const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2));
    } else if (a.hasError) {
      trailing = InkWell(
        onTap: () => _uploadOne(UploadedFileSource(
            path: a.localPath, name: a.name ?? '', mimeType: a.mime ?? '')),
        child: Icon(Icons.refresh_rounded, size: 16, color: colors.warning),
      );
    } else {
      trailing = InkWell(
        onTap: () {
          setState(() {
            _pendingAttachments =
                _pendingAttachments.where((x) => x != a).toList();
          });
        },
        child: Icon(Icons.cancel_rounded, size: 16, color: colors.mutedForeground),
      );
    }
    return Material(
      color: colors.muted.withValues(alpha: 0.5),
      borderRadius: AppRadius.rSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: AppSpacing.xs),
            Text(a.name ?? a.code,
                style: text.micro.copyWith(color: colors.foreground)),
            const SizedBox(width: AppSpacing.xs),
            trailing,
          ],
        ),
      ),
    );
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
    return PopScope(
      // System back inside a conversation returns to the session list (or
      // closes the desktop overlay panel) instead of backgrounding the app.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (store.sessionOverlay != null) {
          store.closeOverlay();
        } else {
          store.closeSession();
        }
      },
      child: Scaffold(
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
      SessionOverlay.timeline => context.l10n.timeline,
      SessionOverlay.files => context.l10n.files,
      SessionOverlay.mailbox => context.l10n.mailbox,
      SessionOverlay.container => context.l10n.container,
      SessionOverlay.todos => context.l10n.todos,
      null => '',
    };
    // ignore: unused_local_variable
    final _ = overlayTitle;
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
                          '${s.branch.isNotEmpty ? '/${s.branch}' : ''}'
                      : context.l10n.chatTitle,
                  overflow: TextOverflow.ellipsis,
                  style: text.meta.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.mutedForeground),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) => _menuAction(v),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'settings', child: Text(context.l10n.sessionSettings)),
                  PopupMenuItem(value: 'compact', child: Text(context.l10n.compactHistory)),
                  PopupMenuItem(value: 'timeline', child: Text(context.l10n.timeline)),
                  PopupMenuItem(value: 'files', child: Text(context.l10n.files)),
                  PopupMenuItem(value: 'mailbox', child: Text(context.l10n.mailbox)),
                  PopupMenuItem(value: 'container', child: Text(context.l10n.container)),
                  PopupMenuItem(value: 'todos', child: Text(context.l10n.todos)),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(context.l10n.deleteSession,
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
        title: Text(context.l10n.deleteSessionTitle),
        content: Text(context.l10n.deleteSessionBody(label)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: colorsOf(ctx).destructive,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.delete),
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
            .showSnackBar(SnackBar(content: Text(context.l10n.historyCompacted)));
        await _setup();
      } else {
        // Nothing to fold (the agent returns {ok:false}); the current
        // conversation is unchanged.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.l10n.nothingToCompact)));
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
    maxTurns.addListener(() {});
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          String model = store.activeSession?.model ?? '';
          String preset = store.activeSession?.preset ?? '';
          String locale = store.activeSession?.locale ?? '';
          // Include the session's current value even if it is not among the
          // registered options, otherwise the dropdown asserts.
          final modelOptions = [
            ..._models.map((m) => m.id),
            if (model.isNotEmpty && !_models.any((m) => m.id == model)) model,
          ];
          final presetOptions = [
            ..._presets.map((p) => p.id),
            if (preset.isNotEmpty && !_presets.any((p) => p.id == preset))
              preset,
          ];
          final localeOptions = [
            for (final (code, label) in [
              ('', ctx.l10n.agentLocaleFollow),
              ('zh', '中文'),
              ('en', 'English'),
            ])
              DropdownMenuItem(value: code, child: Text(label)),
          ];
          return AlertDialog(
            title: Text(ctx.l10n.settingsTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Model is the session's current model; the picker lists
                  // registered provider models.
                  DropdownButtonFormField<String>(
                    initialValue: model.isEmpty ? null : model,
                    items: [
                      for (final id in modelOptions)
                        DropdownMenuItem(value: id, child: Text(id)),
                    ],
                    onChanged: (v) => setState(() => model = v ?? ''),
                    decoration: InputDecoration(labelText: ctx.l10n.modelLabel),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: preset.isEmpty ? null : preset,
                    items: [
                      for (final id in presetOptions)
                        DropdownMenuItem(value: id, child: Text(id)),
                    ],
                    onChanged: (v) => setState(() => preset = v ?? ''),
                    decoration: InputDecoration(labelText: ctx.l10n.presetLabel),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Per-session language override. '' = follow the global
                  // agent locale (written by the config 'Agent language'
                  // setting); zh/en pin this session's prompt language.
                  DropdownButtonFormField<String>(
                    initialValue: locale.isEmpty ? '' : locale,
                    items: localeOptions,
                    onChanged: (v) => setState(() => locale = v ?? ''),
                    decoration: InputDecoration(labelText: ctx.l10n.agentLocale),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: maxTurns,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: ctx.l10n.maxTurnsLabel),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // System prompt is governed by the selected preset — we no
                  // longer let the user set it directly per session.
                  Text(
                    ctx.l10n.sysPromptByPreset,
                    style: textOf(ctx)
                        .micro
                        .copyWith(color: colorsOf(ctx).mutedForeground),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(ctx.l10n.cancel),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final updates = <String, dynamic>{};
                  if (model.isNotEmpty) updates['model'] = model;
                  if (preset.isNotEmpty) updates['preset'] = preset;
                  // Only send the per-session locale when explicitly chosen;
                  // '' (follow) is sent as empty to clear any override.
                  updates['locale'] = locale;
                  if (maxTurns.text.isNotEmpty) {
                    updates['max_turns'] = int.tryParse(maxTurns.text);
                  }
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
                child: Text(ctx.l10n.apply),
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
              child: Text(m.loading
                  ? context.l10n.loading
                  : context.l10n.loadEarlier),
            ),
          );
        }
        final msg = m.sorted[i - (m.hasMore ? 1 : 0)];
        return MessageBubble(
          key: ValueKey(msg.id),
          msg: msg,
          onUndo: (id) => m.revert(id),
          onOpenChange: (changeId) => store.openChange(changeId),
          api: store.api,
          org: store.activeSession?.org ?? '',
          repo: store.activeSession?.repo ?? '',
          branch: store.activeSession?.branch ?? '',
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
              if (_pendingAttachments.isNotEmpty)
                _attachmentRow(context),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: context.l10n.attach,
                    onPressed: sending ? null : _openAttachSheet,
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _inputFocus,
                      // Keep typing while the agent works (IM convention);
                      // only the send button becomes a stop button.
                      minLines: 1,
                      maxLines: 6,
                      textInputAction: TextInputAction.newline,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText:
                            _pendingAttachments.isEmpty ? context.l10n.typeMessage : '',
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
                          onPressed:
                              (_input.text.trim().isEmpty && _pendingAttachments.isEmpty)
                                  ? null
                                  : _send,
                          icon: const Icon(Icons.send_rounded, size: 20),
                        ),
                ],
              ),
              const SizedBox(height: 4),
              // Footer: right-aligned context token total (last turn's
              // request context), shown as e.g. "上下文 13.2K / Context 13.2K".
              Row(
                children: [
                  const Spacer(),
                  if (last > 0)
                    Text(
                      '${context.l10n.contextTokens} ${_k(last)}',
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

  String _overlayLabel(SessionOverlay ov) {
    switch (ov) {
      case SessionOverlay.timeline:
        return context.l10n.timeline;
      case SessionOverlay.files:
        return context.l10n.files;
      case SessionOverlay.mailbox:
        return context.l10n.mailbox;
      case SessionOverlay.container:
        return context.l10n.container;
      case SessionOverlay.todos:
        return context.l10n.todos;
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
/// overlay state so the side panel (wide screens) stays in sync. The body
/// listens to the store so switching between the list and a diff inside the
/// page (e.g. tapping a change, then "Back") rebuilds correctly.
class _OverlayPage extends StatelessWidget {
  final AppStore store;
  final SessionOverlay overlay;
  const _OverlayPage({required this.store, required this.overlay});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Sync store state when the system back pops this route.
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) store.closeOverlay();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              store.closeOverlay();
              Navigator.of(context).pop();
            },
          ),
          title: Text(switch (overlay) {
            SessionOverlay.timeline => context.l10n.timeline,
            SessionOverlay.files => context.l10n.files,
            SessionOverlay.mailbox => context.l10n.mailbox,
            SessionOverlay.container => context.l10n.container,
            SessionOverlay.todos => context.l10n.todos,
          }),
        ),
        body: ListenableBuilder(
          listenable: store,
          builder: (context, _) => _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (overlay) {
      case SessionOverlay.timeline:
        if (store.diffChangeId != null) {
          return TimelineDiffScreen(
              store: store, changeId: store.diffChangeId!);
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
  String _diff = '';
  String _error = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = widget.store.activeSession;
    if (s == null) return;
    try {
      // change_id → current commit_id → unified diff (rebase-safe). Old
      // code called /repos/{o}/{r}/diff/{change_id} which no longer exists
      // on the jjlab that dropped that route (404 "not a git endpoint").
      final d = await widget.store.api.changeDiff(
          s.org, s.repo, widget.changeId,
          branch: s.branch);
      setState(() {
        _diff = d;
        if (d.isEmpty) _error = context.l10n.noChanges;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _openFullScreen() async {
    final s = widget.store.activeSession;
    if (s == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChangeDiffScreen(
        api: widget.store.api,
        org: s.org,
        repo: s.repo,
        changeId: widget.changeId,
        branch: s.branch,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.commit_rounded),
          title: Text('${widget.changeId.substring(0, 12)}…',
              style: textOf(context).mono),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                tooltip: context.l10n.changeDiff,
                onPressed: _openFullScreen,
              ),
              TextButton(
                  // Go back to the change list (notifies the store so both
                  // the desktop panel and the mobile overlay page rebuild).
                  onPressed: () => store.closeDiff(),
                  child: Text(context.l10n.back)),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error.isNotEmpty
                  ? Center(
                      child: Text(_error,
                          style:
                              TextStyle(color: colors.mutedForeground)))
                  : _diff.isEmpty
                      ? Center(
                          child: Text(context.l10n.noChanges,
                              style: TextStyle(
                                  color: colors.mutedForeground)))
                      : DiffView(diffText: _diff),
        ),
      ],
    );
  }
}

