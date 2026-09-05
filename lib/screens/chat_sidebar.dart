import 'dart:async';

import 'package:flutter/material.dart';

import '../i18n.dart';
import '../models.dart';
import '../store.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs.dart';
import '../widgets/session_row.dart';

/// IM-style recent-sessions list (the "所有仓库" tree moved to BrowserPage;
/// reachable from the AppBar search button).
class ChatSidebar extends StatefulWidget {
  final AppStore store;
  const ChatSidebar({super.key, required this.store});

  @override
  State<ChatSidebar> createState() => _ChatSidebarState();
}

class _ChatSidebarState extends State<ChatSidebar> {
  AppStore get store => widget.store;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.refreshSessions();
      store.refreshRepos();
    });
    // Keep previews / unread badges fresh while the list is visible.
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) store.refreshSessions();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    await store.refreshSessions();
    await store.refreshRepos();
  }

  List<Session> get _recent {
    final s = [...store.sessions];
    s.sort((a, b) {
      final at =
          DateTime.tryParse(a.lastMessageAt.isNotEmpty ? a.lastMessageAt : a.updatedAt)
                  ?.millisecondsSinceEpoch ??
              0;
      final bt =
          DateTime.tryParse(b.lastMessageAt.isNotEmpty ? b.lastMessageAt : b.updatedAt)
                  ?.millisecondsSinceEpoch ??
              0;
      return bt - at;
    });
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final recent = _recent;
    final connected = store.sessionError.isEmpty;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.md, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(l10nString('recent'),
                    style: textOf(context).micro.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: colors.mutedForeground)),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                if (recent.isNotEmpty)
                  for (final s in recent) _sessionRow(s),
                if (recent.isEmpty && connected)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Center(
                      child: Text(context.l10n.noRepos,
                          style: TextStyle(color: colors.mutedForeground)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sessionRow(Session s) {
    final isActive = store.activeSessionId == s.id;
    final preview = s.lastMessagePreview.isNotEmpty
        ? s.lastMessagePreview
        : (s.org.isNotEmpty ? '${s.org}/${s.repo}/${s.bookmark}' : s.id);
    return SessionRow(
      session: s,
      isActive: isActive,
      subtitle: preview,
      onTap: () => store.pickSession(s.id),
      onLongPress: () => _sessionActions(s),
    );
  }

  /// Long-press bottom sheet: mark-as-read / delete.
  void _sessionActions(Session s) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if ((s.unreadCount ?? 0) > 0)
              ListTile(
                leading: const Icon(Icons.done_all_rounded),
                title: Text(ctx.l10n.markRead),
                onTap: () {
                  store.markSessionRead(s.id);
                  Navigator.pop(ctx);
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded,
                  color: colorsOf(ctx).destructive),
              title: Text(ctx.l10n.deleteSession,
                  style: TextStyle(color: colorsOf(ctx).destructive)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteSessionFlow(s);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSessionFlow(Session s) async {
    final label = s.org.isNotEmpty
        ? '${s.org}/${s.repo}/${s.bookmark}'
        : s.id;
    final ok = await confirmDialog(context,
        title: context.l10n.deleteSessionTitle,
        description: context.l10n.deleteSessionBody(label));
    if (ok != true) return;
    try {
      if (s.org.isNotEmpty) {
        await store.deleteBookmark(s.org, s.repo, s.bookmark);
      } else {
        await store.deleteSession(s.id);
      }
    } catch (_) {
      await store.deleteSession(s.id);
    }
  }
}
