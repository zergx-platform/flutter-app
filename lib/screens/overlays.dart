import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';

class TimelineOverlay extends StatefulWidget {
  final AppStore store;
  final void Function(String changeId)? onSelectDiff;
  const TimelineOverlay({super.key, required this.store, this.onSelectDiff});

  @override
  State<TimelineOverlay> createState() => _TimelineOverlayState();
}

class _TimelineOverlayState extends State<TimelineOverlay> {
  AppStore get store => widget.store;
  List<ChangeEntry>? _changes;
  int _rev = -1;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    _load();
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (store.sessionRevision != _rev) {
      _rev = store.sessionRevision;
      _load();
    }
  }

  Future<void> _load() async {
    final sid = store.activeSessionId;
    if (sid == null) {
      setState(() => _changes = []);
      return;
    }
    try {
      final c = await store.api.changes(sid);
      if (mounted) setState(() => _changes = c);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final changes = _changes ?? [];
    if (changes.isEmpty) {
      return Center(
          child: Text('No changes yet',
              style:
                  TextStyle(color: Theme.of(context).colorScheme.outline)));
    }
    return ListView.separated(
      itemCount: changes.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final c = changes[i];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.call_split, size: 16),
          title: Text(c.message,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          subtitle: Text('${c.author} · ${c.changeId.substring(0, 16)}',
              style: const TextStyle(fontSize: 10)),
          onTap: () => widget.onSelectDiff?.call(c.changeId),
        );
      },
    );
  }
}

class MailboxOverlay extends StatefulWidget {
  final AppStore store;
  const MailboxOverlay({super.key, required this.store});

  @override
  State<MailboxOverlay> createState() => _MailboxOverlayState();
}

class _MailboxOverlayState extends State<MailboxOverlay> {
  AppStore get store => widget.store;
  List<MailboxEntry> _entries = [];
  int _rev = -1;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    _load();
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (store.sessionRevision != _rev) {
      _rev = store.sessionRevision;
      _load();
    }
  }

  Future<void> _load() async {
    final sid = store.activeSessionId;
    if (sid == null) return;
    try {
      final e = await store.api.mailbox(sid);
      if (mounted) setState(() => _entries = e);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_entries.isEmpty) {
      return Center(
          child: Text('No messages',
              style: TextStyle(color: Theme.of(context).colorScheme.outline)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _entries.length,
      itemBuilder: (_, i) {
        final e = _entries[i];
        final consumed = e.consumedAt != null;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(e.msgType,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary)),
                    const Spacer(),
                    Text(
                      consumed
                          ? 'consumed'
                          : 'pending',
                      style: TextStyle(
                          fontSize: 10,
                          color: consumed ? Colors.green : Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(e.payload.length > 500 ? '${e.payload.substring(0, 500)}…' : e.payload,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              ],
            ),
          ),
        );
      },
    );
  }
}