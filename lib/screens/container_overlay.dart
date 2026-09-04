import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n.dart';
import '../models.dart';
import '../store.dart';
import '../theme/app_theme.dart';

class ContainerOverlay extends StatefulWidget {
  final AppStore store;
  const ContainerOverlay({super.key, required this.store});

  @override
  State<ContainerOverlay> createState() => _ContainerOverlayState();
}

class _ContainerOverlayState extends State<ContainerOverlay> {
  AppStore get store => widget.store;
  Sandbox? _sandbox;
  bool _loading = false;

  String get sessionWorkerId {
    final s = store.activeSession;
    if (s == null) return '';
    return '${s.org}:${s.repo}:${s.bookmark}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = store.activeSession;
    if (s == null) return;
    setState(() => _loading = true);
    final name = sessionWorkerId;
    if (name.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final list = await store.api.sandboxes();
      final matches = list.where((c) => c.session == name);
      _sandbox = matches.isEmpty ? null : matches.first;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _create() async {
    setState(() => _loading = true);
    try {
      await store.api.exec(sessionWorkerId, 'true');
    } catch (_) {}
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final containerId = _sandbox?.session ?? sessionWorkerId;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_sandbox == null && sessionWorkerId.isEmpty) {
      return Center(child: Text(context.l10n.noSession));
    }
    if (_sandbox == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.noWorker, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: _create,
              child: Text(context.l10n.createContainerNow),
            ),
          ],
        ),
      );
    }
    return ContainerWorkspace(store: store, session: containerId, containerName: _sandbox!.podName);
  }
}

/// Reusable terminal + jobs workspace for a given sandbox session.
class ContainerWorkspace extends StatelessWidget {
  final AppStore store;
  final String session;
  final String containerName;
  const ContainerWorkspace(
      {super.key,
      required this.store,
      required this.session,
      this.containerName = ''});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: context.l10n.terminalTab),
              Tab(
                  text: containerName.isEmpty
                      ? context.l10n.jobsTab
                      : '$containerName · ${context.l10n.jobsTab}'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _Terminal(store: store, session: session),
                _Jobs(store: store, session: session),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _Terminal extends StatefulWidget {
  final AppStore store;
  final String session;
  const _Terminal({required this.store, required this.session});

  @override
  State<_Terminal> createState() => _TerminalState();
}

class _TerminalState extends State<_Terminal> {
  final TextEditingController _cmd = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _cmdFocus = FocusNode();
  final List<String> _history = [];
  final List<String> _cmdHistory = [];
  int _histIndex = -1;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _cmdFocus.requestFocus();
  }

  @override
  void dispose() {
    _cmd.dispose();
    _scroll.dispose();
    _cmdFocus.dispose();
    super.dispose();
  }

  /// Keep the newest output visible: follow the bottom like a real terminal.
  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  bool _isIncomplete(String s) {
    var trailing = 0;
    for (var i = s.length - 1; i >= 0 && s[i] == '\\'; i--) {
      trailing++;
    }
    if (trailing % 2 == 1) return true;
    var inSingle = false, inDouble = false;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '\\') {
        i++;
        continue;
      }
      if (c == '"' && !inSingle) inDouble = !inDouble;
      if (c == "'" && !inDouble) inSingle = !inSingle;
    }
    return inSingle || inDouble;
  }

  /// ↑/↓ walk the executed-command history (only when the caret is in the
  /// command field).
  KeyEventResult _onKey(FocusNode node, KeyEvent ev) {
    if (ev is KeyUpEvent) return KeyEventResult.ignored;
    if (_cmdHistory.isEmpty) return KeyEventResult.ignored;
    if (ev.physicalKey == PhysicalKeyboardKey.arrowUp) {
      setState(() {
        _histIndex = (_histIndex + 1).clamp(0, _cmdHistory.length - 1);
        _cmd.text = _cmdHistory[_histIndex];
        _cmd.selection =
            TextSelection.collapsed(offset: _cmd.text.length);
      });
      return KeyEventResult.handled;
    }
    if (ev.physicalKey == PhysicalKeyboardKey.arrowDown) {
      setState(() {
        if (_histIndex <= 0) {
          _histIndex = -1;
          _cmd.clear();
        } else {
          _histIndex--;
          _cmd.text = _cmdHistory[_histIndex];
          _cmd.selection =
              TextSelection.collapsed(offset: _cmd.text.length);
        }
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _execute() async {
    final cmd = _cmd.text.trim();
    if (cmd.isEmpty) return;
    final lines = cmd.split('\n');
    setState(() {
      _history.addAll([for (var i = 0; i < lines.length; i++) '${i == 0 ? '\$' : '>'} ${lines[i]}']);
      _cmdHistory.insert(0, cmd);
      if (_cmdHistory.length > 200) _cmdHistory.removeLast();
      _histIndex = -1;
      _running = true;
    });
    _autoScroll();
    try {
      final r = await widget.store.api.exec(widget.session, cmd);
      if (r.error != null) {
        _history.add('[error] ${r.error}');
      } else if (r.backgrounded && r.jobId != null) {
        _history.add(I18n.now.backgrounded(r.jobId!));
      } else if (r.exitCode != null) {
        if (r.output != null && r.output!.isNotEmpty) _history.add(r.output!);
        if (r.exitCode != 0) _history.add('[exit: ${r.exitCode}]');
      }
    } catch (e) {
      _history.add('[error] $e');
    }
    setState(() {
      _running = false;
      _cmd.clear();
    });
    _autoScroll();
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    return Column(
      children: [
        Expanded(
          child: Container(
            color: colors.background,
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(AppSpacing.sm),
              itemCount: _history.length,
              itemBuilder: (_, i) {
                final line = _history[i];
                Color? color;
                if (line.startsWith('[error]')) {
                  color = colors.destructive;
                } else if (line.startsWith('\$') || line.startsWith('>')) {
                  color = colors.mutedForeground;
                }
                return SelectableText(line,
                    style: text.mono.copyWith(fontSize: 12, color: color));
              },
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(
                top: BorderSide(color: colors.border.withValues(alpha: 0.5))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Focus(
                  focusNode: _cmdFocus,
                  onKeyEvent: _onKey,
                  child: TextField(
                    controller: _cmd,
                    enabled: !_running,
                    style: text.mono.copyWith(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: context.l10n.commandHint,
                      filled: false,
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) {
                      if (!_isIncomplete(_cmd.text)) _execute();
                    },
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded, size: 16),
                onPressed: _running || _cmd.text.trim().isEmpty ? null : _execute,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Jobs extends StatefulWidget {
  final AppStore store;
  final String session;
  const _Jobs({required this.store, required this.session});

  @override
  State<_Jobs> createState() => _JobsState();
}

class _JobsState extends State<_Jobs> {
  List<JobInfo> _jobs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final j = await widget.store.api.jobs(widget.session);
      if (mounted) setState(() => _jobs = j);
    } catch (_) {}
  }

  Future<void> _kill(JobInfo j) async {
    try {
      await widget.store.api.kill(widget.session, j.id);
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    if (_jobs.isEmpty) {
      return Center(
          child: Text(context.l10n.noJobs,
              style: TextStyle(color: colors.mutedForeground)));
    }
    return ListView.builder(
      itemCount: _jobs.length,
      itemBuilder: (_, i) {
        final j = _jobs[i];
        return ListTile(
          title: Text(j.command,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.meta),
          subtitle: Text('${j.id} · ${j.state}',
              style: text.mono.copyWith(
                  fontSize: 10, color: colors.mutedForeground)),
          trailing: j.state.toLowerCase() == 'running'
              ? IconButton(
                  icon: Icon(Icons.stop_rounded,
                      size: 16, color: colors.destructive),
                  onPressed: () => _kill(j))
              : null,
          onTap: () => _showOutput(j),
        );
      },
    );
  }

  void _showOutput(JobInfo j) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${j.id} — ${j.state}'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: SelectableText(j.stdout ?? ctx.l10n.noOutput,
                style: textOf(ctx).mono.copyWith(fontSize: 11)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.l10n.close)),
        ],
      ),
    );
  }
}
