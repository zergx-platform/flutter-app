import 'package:flutter/material.dart';

import 'mdi_icons.dart';

/// Icon for a file/dir entry based on the file name/extension, so the tree
/// shows a meaningful language/framework glyph instead of a generic file.
///
/// Uses vendored MDI monochrome icons ([MdiIcon]) for language/framework/type
/// semantics; falls back to Material [Icons] when MDI has no good match.
IconData fileIconFor(String name, {required bool isDir}) {
  if (isDir) return Icons.folder_rounded;
  final lower = name.toLowerCase();
  final dot = lower.lastIndexOf('.');
  final ext = dot == -1 ? '' : lower.substring(dot);

  // ---- Well-known build / framework files (by name) ----
  if (lower == 'dockerfile' || lower == 'containerfile') return MdiIcon.docker;
  if (lower == 'dockerfile.desktop') return MdiIcon.docker;
  if (lower == 'makefile' || lower == 'gnumakefile') return MdiIcon.tools;
  if (lower == 'cmakelists.txt') return MdiIcon.tools;
  if (lower == 'build.gradle' || lower == 'build.gradle.kts') return MdiIcon.androidStudio;
  if (lower == 'pubspec.yaml' || lower == 'pubspec.lock') return MdiIcon.androidStudio;
  if (lower == 'package.json' || lower == 'package-lock.json' || lower == 'npm-shrinkwrap.json') {
    return MdiIcon.nodejs;
  }
  if (lower == 'go.mod' || lower == 'go.sum') return MdiIcon.languageGo;
  if (lower == 'cargo.toml' || lower == 'cargo.lock') return MdiIcon.languageRust;
  if (lower.endsWith('.csproj') || lower == 'app.config' || lower == 'web.config') {
    return MdiIcon.dotNet;
  }
  if (lower == 'readme.md' || lower == 'readme.txt' || lower == 'readme.rst') {
    return MdiIcon.fileDocument;
  }
  if (lower == 'license' || lower == 'license.md') return MdiIcon.fileDocument;
  if (lower == 'docker-compose.yml' || lower == 'docker-compose.yaml') return MdiIcon.docker;

  // ---- Language logos ----
  switch (ext) {
    case '.dart':
      return MdiIcon.fileCode;
    case '.go':
      return MdiIcon.languageGo;
    case '.rs':
      return MdiIcon.languageRust;
    case '.py':
    case '.pyi':
      return MdiIcon.languagePython;
    case '.ts':
    case '.tsx':
    case '.mts':
    case '.cts':
      return MdiIcon.languageTypescript;
    case '.js':
    case '.jsx':
    case '.mjs':
    case '.cjs':
      return MdiIcon.languageJavascript;
    case '.java':
      return MdiIcon.languageJava;
    case '.kt':
    case '.kts':
      return MdiIcon.languageKotlin;
    case '.swift':
      return MdiIcon.languageSwift;
    case '.lua':
      return MdiIcon.languageLua;
    case '.rb':
      return MdiIcon.languageRuby;
    case '.php':
      return MdiIcon.languagePhp;
    case '.hs':
      return MdiIcon.languageHaskell;
    case '.c':
    case '.h':
      return MdiIcon.languageC;
    case '.cpp':
    case '.cc':
    case '.cxx':
    case '.hpp':
    case '.hh':
    case '.c++':
      return MdiIcon.languageCpp;
    case '.cs':
    case '.fs':
      return MdiIcon.languageCsharp;
    case '.scala':
      return MdiIcon.languageJava;
    case '.mm':
    case '.m':
      return MdiIcon.languageCpp;
    case '.clj':
    case '.cljs':
      return MdiIcon.functionVariant;
    case '.ex':
    case '.exs':
      return MdiIcon.languageRuby;
    case '.erl':
      return MdiIcon.functionVariant;
    case '.sql':
      return MdiIcon.database;
    // Web / frontend
    case '.vue':
      return MdiIcon.vuejs;
    case '.html':
    case '.htm':
      return MdiIcon.languageHtml5;
    case '.css':
    case '.scss':
    case '.less':
    case '.sass':
      return MdiIcon.languageCss3;
    case '.svelte':
      return MdiIcon.codeBraces;
    case '.mdx':
    case '.md':
    case '.markdown':
      return MdiIcon.languageMarkdown;
    case '.rst':
      return MdiIcon.fileDocument;
    case '.tex':
      return MdiIcon.fileDocument;
    case '.json':
    case '.json5':
      return MdiIcon.fileXmlBox;
    case '.yaml':
    case '.yml':
    case '.toml':
    case '.ini':
    case '.cfg':
    case '.conf':
    case '.properties':
      return MdiIcon.fileCode;
    case '.env':
      return MdiIcon.fileCode;
    case '.graphql':
    case '.gql':
      return MdiIcon.graphql;
    case '.proto':
      return MdiIcon.protocol;
    case '.xml':
    case '.svg':
      return MdiIcon.fileXmlBox;
    case '.sh':
    case '.bash':
    case '.zsh':
    case '.ps1':
      return MdiIcon.console;
    case '.tf':
      return MdiIcon.terraform;
    case '.hcl':
      return MdiIcon.terraform;
    case '.k8s':
    case '.kube':
      return MdiIcon.kubernetes;
    // Documents / data
    case '.txt':
    case '.log':
      return MdiIcon.fileDocument;
    case '.csv':
    case '.tsv':
      return MdiIcon.fileTable;
    case '.xls':
    case '.xlsx':
      return MdiIcon.fileExcel;
    case '.doc':
    case '.docx':
      return MdiIcon.fileWord;
    case '.ppt':
    case '.pptx':
      return MdiIcon.filePowerpoint;
    case '.pdf':
      return MdiIcon.filePdfBox;
    case '.png':
    case '.jpg':
    case '.jpeg':
    case '.gif':
    case '.webp':
    case '.ico':
    case '.bmp':
      return MdiIcon.fileImage;
    case '.mp3':
    case '.wav':
    case '.ogg':
    case '.flac':
      return MdiIcon.fileMusic;
    case '.mp4':
    case '.mov':
    case '.avi':
    case '.mkv':
    case '.webm':
      return MdiIcon.fileVideo;
    case '.zip':
    case '.gz':
    case '.tar':
    case '.bz2':
    case '.7z':
    case '.xz':
      return MdiIcon.folderZip;
    default:
      return MdiIcon.fileOutline;
  }
}
