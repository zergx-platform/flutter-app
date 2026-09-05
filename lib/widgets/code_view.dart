import 'package:flutter/material.dart';
import 'package:re_highlight/re_highlight.dart';

import '../theme/app_theme.dart';
import 'highlight_theme.dart';

/// Line-numbered, syntax-highlighted code viewer. Uses re_highlight to color
/// the code by file extension (via the filename), keeping a line-number gutter
/// and shared horizontal scroll. The code is selectable (copy).
class CodeView extends StatelessWidget {
  final String code;
  final String filepath;
  final Highlight _hl;
  CodeView({super.key, required this.code, required this.filepath})
      : _hl = Highlight()..registerLanguages(builtinLanguagesFor(filepath));

  @override
  Widget build(BuildContext context) {
    final lines = code.split('\n');
    final colors = colorsOf(context);
    final text = textOf(context);
    final codeStyle = text.mono.copyWith(fontSize: 12);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final theme = highlightTheme(dark, codeStyle);
    final base = theme.base;
    final span = _span(dark, codeStyle, base);

    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 36,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 1; i <= lines.length; i++)
                      Text('$i',
                          style: codeStyle.copyWith(color: colors.mutedForeground)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              ConstrainedBox(
                constraints: BoxConstraints(
                    minWidth: MediaQuery.sizeOf(context).width - 80),
                child: SelectionArea(
                  child: Text.rich(span ?? TextSpan(children: [TextSpan(text: code, style: base)]),
                      style: base),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextSpan? _span(bool dark, TextStyle codeStyle, TextStyle base) {
    try {
      final result = _hl.highlight(code: code, language: languageFor(filepath));
      final theme = highlightTheme(dark, codeStyle);
      final renderer = TextSpanRenderer(base, theme.scopes);
      result.render(renderer);
      return renderer.span;
    } catch (_) {
      return null;
    }
  }
}

/// Language name resolved from a file path/extension. Falls back to plaintext.
String languageFor(String path) {
  final lower = path.toLowerCase();
  final dot = lower.lastIndexOf('.');
  final ext = dot == -1 ? '' : lower.substring(dot);
  const map = {
    '.dart': 'dart',
    '.go': 'go',
    '.rs': 'rust',
    '.py': 'python',
    '.ts': 'typescript',
    '.tsx': 'typescript',
    '.js': 'javascript',
    '.jsx': 'javascript',
    '.json': 'json',
    '.yml': 'yaml',
    '.yaml': 'yaml',
    '.toml': 'ini',
    '.sh': 'bash',
    '.bash': 'bash',
    '.zsh': 'bash',
    '.html': 'xml',
    '.htm': 'xml',
    '.xml': 'xml',
    '.svelte': 'xml',
    '.vue': 'vue',
    '.css': 'css',
    '.scss': 'css',
    '.less': 'css',
    '.md': 'markdown',
    '.markdown': 'markdown',
    '.java': 'java',
    '.kt': 'kotlin',
    '.kts': 'kotlin',
    '.cpp': 'cpp',
    '.cc': 'cpp',
    '.cxx': 'cpp',
    '.c': 'c',
    '.h': 'c',
    '.hpp': 'cpp',
    '.cs': 'csharp',
    '.rb': 'ruby',
    '.php': 'php',
    '.swift': 'swift',
    '.sql': 'sql',
    '.ini': 'ini',
    '.cfg': 'ini',
    '.conf': 'ini',
    '.env': 'ini',
    '.dockerfile': 'dockerfile',
    '.make': 'makefile',
    '.mk': 'makefile',
    '.txt': 'plaintext',
  };
  if (lower.endsWith('dockerfile')) return 'dockerfile';
  if (lower.endsWith('makefile')) return 'makefile';
  return map[ext] ?? 'plaintext';
}
