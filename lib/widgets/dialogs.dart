import 'package:flutter/material.dart';

import '../i18n.dart';

/// Shared confirm dialog. [confirmText] defaults to the localized 'Delete'.
Future<bool> confirmDialog(BuildContext context,
    {required String title,
    required String description,
    String? confirmText}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(description),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t(ctx, 'cancel'))),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText ?? t(ctx, 'delete')),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Small text-input dialog (recreates NewItemDialog). [confirmText]
/// defaults to the localized 'Create'.
Future<String?> promptDialog(BuildContext context,
    {required String title,
    String label = '',
    String? confirmText}) async {
  final ctrl = TextEditingController();
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t(ctx, 'cancel'))),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text),
          child: Text(confirmText ?? t(ctx, 'create')),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return r;
}
