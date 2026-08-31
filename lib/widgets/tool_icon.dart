import 'dart:convert';

import 'package:flutter/material.dart';

/// Recreates ToolIcon.svelte: picks an icon + color by tool name.
class ToolIcon extends StatelessWidget {
  final String name;
  const ToolIcon(this.name, {super.key});

  @override
  Widget build(BuildContext context) {
    final n = name.toLowerCase();
    IconData icon;
    Color color;
    if (n.contains('sandbox-run') || n.contains('shell') || n.contains('exec')) {
      icon = Icons.terminal;
      color = Colors.amber;
    } else if (n.contains('read')) {
      icon = Icons.description_outlined;
      color = Colors.lightBlue;
    } else if (n.contains('grep')) {
      icon = Icons.manage_search;
      color = Colors.lightBlue;
    } else if (n.contains('glob') ||
        n.contains('ls') ||
        n.contains('explore')) {
      icon = Icons.folder_open;
      color = Colors.lightBlue;
    } else if (n.contains('write') || n.contains('edit')) {
      icon = Icons.edit_outlined;
      color = Colors.green;
    } else if (n.contains('delete')) {
      icon = Icons.delete_outline;
      color = Colors.redAccent;
    } else if (n.contains('web') || n.contains('fetch')) {
      icon = Icons.public;
      color = Colors.purpleAccent;
    } else if (n.contains('todo') || n.contains('job') || n.contains('task')) {
      icon = Icons.checklist;
      color = Colors.pinkAccent;
    } else if (n.contains('git') ||
        n.contains('diff') ||
        n.contains('commit')) {
      icon = Icons.code;
      color = Colors.blueGrey;
    } else {
      icon = Icons.build_outlined;
      color = Colors.blueGrey;
    }
    return Icon(icon, size: 14, color: color);
  }
}

String toolDisplayName(String t) {
  const map = {'todowrite': 'todo'};
  return map[t] ?? t;
}

String fmtOutput(Object? raw) {
  if (raw == null) return '';
  return raw is String ? raw : _pretty(raw);
}

String _pretty(Object o) {
  if (o is Map || o is List) {
    const enc = JsonEncoder.withIndent('  ');
    return enc.convert(o);
  }
  return o.toString();
}