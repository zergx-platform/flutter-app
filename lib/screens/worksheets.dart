import 'package:flutter/material.dart';

import '../api.dart';
import '../i18n.dart';
import '../models.dart';
import '../store.dart';
import '../theme/app_theme.dart';

/// Worksheets (工单) — global approval inbox. Extensions surface side-effecting
/// actions here (file writes, image_read, deployments…) and the user approves
/// / rejects before the agent proceeds.
class WorksheetsScreen extends StatefulWidget {
  final AppStore store;
  const WorksheetsScreen({super.key, required this.store});

  @override
  State<WorksheetsScreen> createState() => _WorksheetsScreenState();
}

class _WorksheetsScreenState extends State<WorksheetsScreen> {
  AppStore get store => widget.store;
  List<Worksheet> _items = [];
  bool _loading = true;
  String _error = '';
  String _status = ''; // '' = all

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = '';
    });
    try {
      _items = await store.api.worksheets(status: _status.isEmpty ? null : _status);
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _decide(Worksheet w, String decision) async {
    final messenger = ScaffoldMessenger.of(context);
    final label = decision == 'approve'
        ? context.l10n.approve
        : context.l10n.reject;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: Text(context.l10n.worksheetDecideBody(
            label, w.action, w.sessionName)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: decision == 'reject'
                    ? colorsOf(ctx).destructive
                    : colorsOf(ctx).primary,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(label),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await store.api.decide(w.sessionName, w.id, decision);
      messenger.showSnackBar(SnackBar(content: Text(context.l10n.worksheetDecided)));
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('$e', style: TextStyle(color: colorsOf(context).destructive))));
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return context.l10n.pending;
      case 'dispatched':
        return context.l10n.dispatched;
      case 'rejected':
        return context.l10n.rejected;
      default:
        return s;
    }
  }

  Color _statusColor(String s, AppColors colors) {
    switch (s) {
      case 'pending':
        return colors.warning;
      case 'dispatched':
        return colors.success;
      case 'rejected':
        return colors.destructive;
      default:
        return colors.mutedForeground;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.tabWorksheets),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: '', label: Text(context.l10n.allWorksheets)),
                ButtonSegment(value: 'pending', label: Text(context.l10n.pending)),
                ButtonSegment(value: 'dispatched', label: Text(context.l10n.dispatched)),
                ButtonSegment(value: 'rejected', label: Text(context.l10n.rejected)),
              ],
              selected: {_status},
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                side: WidgetStatePropertyAll(
                    BorderSide(color: colors.border.withValues(alpha: 0.5))),
                backgroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? colors.muted
                        : Colors.transparent),
                foregroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? colors.primary
                        : colors.mutedForeground),
              ),
              onSelectionChanged: (sel) {
                _status = sel.first;
                _load();
              },
            ),
          ),
          Expanded(
            child: _loading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty && _items.isEmpty
                    ? Center(
                        child: Text(_error,
                            style: TextStyle(color: colors.destructive)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _items.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(AppSpacing.lg),
                                    child: Center(
                                        child: Text(context.l10n.noWorksheets,
                                            style: TextStyle(
                                                color: colors.mutedForeground))),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(AppSpacing.md),
                                itemCount: _items.length,
                                itemBuilder: (_, i) => _card(_items[i]),
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _card(Worksheet w) {
    final colors = colorsOf(context);
    final text = textOf(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ExpansionTile(
        title: Text(w.title.isNotEmpty ? w.title : w.action,
            style: text.meta.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${w.action} · ${w.sessionName}',
          overflow: TextOverflow.ellipsis,
          style: text.micro.copyWith(color: colors.mutedForeground),
        ),
        leading: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _statusColor(w.status, colors),
          ),
        ),
        trailing: _statusChip(w, colors, text),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.worksheetArgs,
                    style: text.micro.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.mutedForeground)),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.muted.withValues(alpha: 0.4),
                    borderRadius: AppRadius.rSm,
                  ),
                  child: SelectableText(
                    w.args.isEmpty ? '{}' : w.args,
                    style: text.mono.copyWith(fontSize: 11),
                  ),
                ),
                if (w.isPending) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _decide(w, 'reject'),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: Text(context.l10n.reject,
                            style: TextStyle(color: colors.destructive)),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      FilledButton.icon(
                        onPressed: () => _decide(w, 'approve'),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: Text(context.l10n.approve),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(Worksheet w, AppColors colors, AppTypography text) {
    // ExpansionTile uses `trailing` for its own chevron — put the status chip
    // into the title row instead via a leading-less inline. Here return a
    // small label next to the chevron.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: _statusColor(w.status, colors).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(_statusLabel(w.status),
              style: text.micro.copyWith(
                  color: _statusColor(w.status, colors), fontSize: 9)),
        ),
      ],
    );
  }
}
