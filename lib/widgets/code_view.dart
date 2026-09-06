import 'package:flutter/material.dart';
import 'package:re_highlight/re_highlight.dart';

import '../theme/app_theme.dart';
import 'highlight_theme.dart';

/// Line-numbered, syntax-highlighted, soft-wrapping code viewer. Uses
/// re_highlight to color the code by file extension. Each logical line is
/// rendered as its own horizontally-stretching widget so long lines wrap
/// (auto-wrap) rather than scroll sideways, and a line-number gutter stays
/// aligned with the start of each logical line. Selectable (copy) via
/// SelectionArea.
class CodeView extends StatelessWidget {
  final String code;
  final String filepath;
  final bool shrinkWrap;
  final bool showLineNumbers;
  final Highlight _hl;
  CodeView({
    super.key,
    required this.code,
    required this.filepath,
    this.shrinkWrap = false,
    this.showLineNumbers = true,
  }) : _hl = Highlight()..registerLanguages(builtinLanguagesFor(filepath));

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    final codeStyle = text.mono.copyWith(fontSize: 12);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final theme = highlightTheme(dark, codeStyle);
    final base = theme.base;
    final lines = code.split('\n');

    return Scrollbar(
      child: ListView(
        shrinkWrap: shrinkWrap,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        children: [
          for (var i = 0; i < lines.length; i++)
            _line(i + 1, lines[i], colors, codeStyle, dark, base,
                showLineNumbers),
        ],
      ),
    );
  }

  /// A single logical line: gutter number + the (possibly wrapped) highlighted
  /// content. Soft-wrap via a stretched Text.rich so long lines wrap. When
  /// [showLineNumbers] is false the gutter is omitted (used when the content
  /// already carries its own "N: " line prefix, e.g. a `read` tool result).
  Widget _line(int num, String raw, AppColors colors, TextStyle codeStyle,
      bool dark, TextStyle base, bool showNumbers) {
    final span = _span(dark, codeStyle, base, raw);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showNumbers)
          SizedBox(
            width: 44,
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Text('$num',
                  textAlign: TextAlign.right,
                  style: codeStyle.copyWith(color: colors.mutedForeground)),
            ),
          ),
        Expanded(
          child: SelectionArea(
            child: Text.rich(
              span ?? TextSpan(children: [TextSpan(text: raw, style: base)]),
              style: base,
            ),
          ),
        ),
      ],
    );
  }

  TextSpan? _span(bool dark, TextStyle codeStyle, TextStyle base, String raw) {
    try {
      final result = _hl.highlight(code: raw, language: languageFor(filepath));
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
  final name = lower.split('/').last;
  final dot = lower.lastIndexOf('.');
  final ext = dot == -1 ? '' : lower.substring(dot);
  const map = {
    // web / frontend
    '.ts': 'typescript',
    '.tsx': 'typescript',
    '.js': 'javascript',
    '.jsx': 'javascript',
    '.mjs': 'javascript',
    '.cjs': 'javascript',
    '.html': 'xml',
    '.htm': 'xml',
    '.svelte': 'xml',
    '.vue': 'vue',
    '.css': 'css',
    '.scss': 'scss',
    '.less': 'less',
    '.sass': 'scss',
    // data / config
    '.json': 'json',
    '.json5': 'json',
    '.yml': 'yaml',
    '.yaml': 'yaml',
    '.toml': 'ini',
    '.ini': 'ini',
    '.cfg': 'ini',
    '.conf': 'ini',
    '.efs': 'ini',
    '.env': 'ini',
    '.properties': 'properties',
    '.xml': 'xml',
    '.graphql': 'graphql',
    '.gql': 'graphql',
    '.proto': 'protobuf',
    '.hcl': 'ini',
    '.tf': 'ini',
    // scripts
    '.sh': 'bash',
    '.bash': 'bash',
    '.zsh': 'bash',
    '.fish': 'bash',
    '.ps1': 'powershell',
    // systems / pl
    '.dart': 'dart',
    '.go': 'go',
    '.rs': 'rust',
    '.py': 'python',
    '.pyi': 'python',
    '.rb': 'ruby',
    '.php': 'php',
    '.java': 'java',
    '.kt': 'kotlin',
    '.kts': 'kotlin',
    '.scala': 'scala',
    '.swift': 'swift',
    '.lua': 'lua',
    '.r': 'r',
    '.jl': 'julia',
    '.ex': 'elixir',
    '.exs': 'elixir',
    '.erl': 'erlang',
    '.hrl': 'erlang',
    '.clj': 'clojure',
    '.cljs': 'clojure',
    '.cs': 'csharp',
    '.fs': 'fsharp',
    '.vb': 'vbnet',
    '.hs': 'haskell',
    '.ml': 'ocaml',
    '.mli': 'ocaml',
    '.nim': 'nim',
    '.zig': 'ini',
    '.cob': 'cobol',
    // c family
    '.c': 'c',
    '.h': 'c',
    '.cpp': 'cpp',
    '.cc': 'cpp',
    '.cxx': 'cpp',
    '.hpp': 'cpp',
    '.hh': 'cpp',
    '.c++': 'cpp',
    '.mm': 'cpp',
    '.m': 'objectivec',
    // docs / markup
    '.md': 'markdown',
    '.mdx': 'markdown',
    '.markdown': 'markdown',
    '.rst': 'markdown',
    '.tex': 'latex',
    '.sql': 'sql',
    // build files (special names handled below)
    '.dockerfile': 'dockerfile',
    '.containerfile': 'dockerfile',
    '.make': 'makefile',
    '.mk': 'makefile',
    '.cmake': 'cmake',
    '.gradle': 'gradle',
    '.nix': 'nix',
    // text fallbacks
    '.txt': 'plaintext',
    '.log': 'plaintext',
    '.csv': 'plaintext',
    '.tsv': 'plaintext',
  };
  // Special-case well-known filenames (case-insensitive).
  for (final d in <String>['dockerfile', 'containerfile']) {
    if (name == d) return 'dockerfile';
  }
  if (name == 'makefile' || name == 'gnumakefile') return 'makefile';
  if (name == 'cmakelists.txt') return 'cmake';
  if (name == 'build.gradle' || name == 'build.gradle.kts') return 'gradle';
  if (name == 'gemspec' || name.endsWith('.gemspec')) return 'ruby';
  return map[ext] ?? 'plaintext';
}
