import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme/app_theme.dart';

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
    final colors = colorsOf(context);
    final text = textOf(context);
    final changes = _changes ?? [];
    if (changes.isEmpty) {
      return Center(
          child: Text('No changes yet',
              style: TextStyle(color: colors.mutedForeground)));
    }
    return ListView.separated(
      itemCount: changes.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: colors.border.withValues(alpha: 0.4)),
      itemBuilder: (_, i) {
        final c = changes[i];
        return ListTile(
          leading: Icon(Icons.call_split_rounded,
              size: 16, color: colors.primary),
          title: Text(c.message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.meta),
          subtitle: Text('${c.author} · ${c.changeId.substring(0, 16)}',
              style: text.micro.copyWith(color: colors.mutedForeground)),
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
    final colors = colorsOf(context);
    final text = textOf(context);
    if (_entries.isEmpty) {
      return Center(
          child: Text('No messages',
              style: TextStyle(color: colors.mutedForeground)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _entries.length,
      itemBuilder: (_, i) {
        final e = _entries[i];
        final consumed = e.consumedAt != null;
        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(e.msgType,
                        style: text.meta.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.primary)),
                    const Spacer(),
                    Text(
                      consumed ? 'consumed' : 'pending',
                      style: text.micro.copyWith(
                          color: consumed ? colors.success : colors.mutedForeground),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                SelectableText(
                    e.payload.length > 500
                        ? '${e.payload.substring(0, 500)}…'
                        : e.payload,
                    style: text.mono.copyWith(
                        fontSize: 11, color: colors.mutedForeground)),
              ],
            ),
          ),
        );
      },
    );
  }
}
