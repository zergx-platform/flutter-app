import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';

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
    return '${s.org}:${s.repo}:${s.branch}';
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
      return const Center(child: Text('No session'));
    }
    if (_sandbox == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No worker container yet — it starts automatically when the agent runs bash.',
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: _create,
              child: const Text('Create container now'),
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
              const Tab(text: 'Terminal'),
              Tab(text: containerName.isEmpty ? 'Jobs' : '$containerName · Jobs'),
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
  final List<String> _history = [];
  final List<String> _cmdHistory = [];
  bool _running = false;

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

  Future<void> _execute() async {
    final cmd = _cmd.text.trim();
    if (cmd.isEmpty) return;
    final lines = cmd.split('\n');
    setState(() {
      _history.addAll([for (var i = 0; i < lines.length; i++) '${i == 0 ? '\$' : '>'} ${lines[i]}']);
      _cmdHistory.insert(0, cmd);
      if (_cmdHistory.length > 200) _cmdHistory.removeLast();
      _running = true;
    });
    try {
      final r = await widget.store.api.exec(widget.session, cmd);
      if (r.error != null) {
        _history.add('[error] ${r.error}');
      } else if (r.backgrounded && r.jobId != null) {
        _history.add('[${r.jobId}] backgrounded (see Jobs tab)');
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
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _history.length,
              itemBuilder: (_, i) {
                final line = _history[i];
                Color? color;
                if (line.startsWith('[error]')) color = Colors.redAccent;
                else if (line.startsWith('\$') || line.startsWith('>')) color = Theme.of(context).colorScheme.outline;
                return Text(line,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: color));
              },
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _cmd,
                enabled: !_running,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'command...',
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                onSubmitted: (_) {
                  if (!_isIncomplete(_cmd.text)) _execute();
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, size: 16),
              onPressed: _running || _cmd.text.trim().isEmpty ? null : _execute,
            ),
          ],
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
    if (_jobs.isEmpty) {
      return const Center(child: Text('No jobs'));
    }
    return ListView.builder(
      itemCount: _jobs.length,
      itemBuilder: (_, i) {
        final j = _jobs[i];
        return ListTile(
          dense: true,
          title: Text(j.command,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
          subtitle: Text('${j.id} · ${j.state}',
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
          trailing: j.state == 'running'
              ? IconButton(
                  icon: const Icon(Icons.stop, size: 16), onPressed: () => _kill(j))
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
            child: SelectableText(j.stdout ?? 'No output',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}