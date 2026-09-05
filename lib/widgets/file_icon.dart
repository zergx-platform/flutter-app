import 'package:flutter/material.dart';

/// Icon for a file/dir entry based on the file name/extension, so the tree
/// shows a meaningful glyph (language/framework) instead of a generic file.
IconData fileIconFor(String name, {required bool isDir}) {
  if (isDir) return Icons.folder_rounded;
  final lower = name.toLowerCase();
  final dot = lower.lastIndexOf('.');
  final ext = dot == -1 ? '' : lower.substring(dot);
  // Special-case well-known build/config files first.
  if (lower == 'dockerfile' || lower == 'containerfile') return Icons.rocket_launch_rounded;
  if (lower == 'makefile') return Icons.build_rounded;
  if (lower == 'cmakelists.txt') return Icons.build_rounded;
  if (lower == 'pubspec.yaml' || lower == 'pubspec.lock') return Icons.terminal_rounded;
  if (lower == 'package.json') return Icons.code_rounded;
  if (lower == 'go.mod' || lower == 'go.sum') return Icons.terminal_rounded;
  if (lower == 'cargo.toml') return Icons.terminal_rounded;
  if (lower == 'readme.md' || lower == 'license') return Icons.description_rounded;
  switch (ext) {
    case '.dart':
      return Icons.code_rounded;
    case '.go':
      return Icons.code_rounded;
    case '.rs':
      return Icons.code_rounded;
    case '.py':
      return Icons.code_rounded;
    case '.ts':
    case '.tsx':
    case '.js':
    case '.jsx':
    case '.mjs':
    case '.cjs':
      return Icons.code_rounded;
    case '.html':
    case '.htm':
    case '.xml':
    case '.svelte':
    case '.vue':
    case '.css':
    case '.scss':
    case '.less':
    case '.sass':
      return Icons.language_rounded;
    case '.json':
    case '.yaml':
    case '.yml':
    case '.toml':
    case '.ini':
    case '.cfg':
    case '.conf':
    case '.env':
    case '.properties':
      return Icons.settings_rounded;
    case '.md':
    case '.mdx':
    case '.markdown':
    case '.txt':
    case '.log':
    case '.rst':
      return Icons.article_rounded;
    case '.sh':
    case '.bash':
    case '.zsh':
    case '.ps1':
      return Icons.terminal_rounded;
    case '.sql':
      return Icons.storage_rounded;
    case '.svg':
    case '.png':
    case '.jpg':
    case '.jpeg':
    case '.gif':
    case '.webp':
    case '.ico':
      return Icons.image_rounded;
    case '.pdf':
      return Icons.picture_as_pdf_rounded;
    case '.zip':
    case '.gz':
    case '.tar':
      return Icons.folder_zip_rounded;
    case '.csv':
    case '.tsv':
      return Icons.table_rows_rounded;
    default:
      return Icons.insert_drive_file_outlined;
  }
}
