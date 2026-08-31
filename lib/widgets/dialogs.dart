import 'package:flutter/material.dart';

/// Shared confirm dialog.
Future<bool> confirmDialog(BuildContext context,
    {required String title,
    required String description,
    String confirmText = 'Delete'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(description),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Small text-input dialog (recreates NewItemDialog).
Future<String?> promptDialog(BuildContext context,
    {required String title,
    String label = '',
    String confirmText = 'Create'}) async {
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
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return r;
}