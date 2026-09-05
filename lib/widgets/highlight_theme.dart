import 'package:flutter/material.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/styles/github.dart';
import 'package:re_highlight/styles/github-dark.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/languages/ini.dart';
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/vue.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/csharp.dart';
import 'package:re_highlight/languages/ruby.dart';
import 'package:re_highlight/languages/php.dart';
import 'package:re_highlight/languages/swift.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/dockerfile.dart';
import 'package:re_highlight/languages/makefile.dart';
import 'package:re_highlight/languages/plaintext.dart';

/// Bundle only the languages the app actually highlights, keyed by the
/// names returned from [languageFor]. Keeping this small avoids shipping all
/// ~190 highlight.js language grammars.
Map<String, Mode> builtinLanguagesFor(String path) {
  final lang = {
    'dart': langDart,
    'go': langGo,
    'rust': langRust,
    'python': langPython,
    'typescript': langTypescript,
    'javascript': langJavascript,
    'json': langJson,
    'yaml': langYaml,
    'ini': langIni,
    'bash': langBash,
    'xml': langXml,
    'vue': langVue,
    'css': langCss,
    'markdown': langMarkdown,
    'java': langJava,
    'kotlin': langKotlin,
    'cpp': langCpp,
    'c': langC,
    'csharp': langCsharp,
    'ruby': langRuby,
    'php': langPhp,
    'swift': langSwift,
    'sql': langSql,
    'dockerfile': langDockerfile,
    'makefile': langMakefile,
    'plaintext': langPlaintext,
  };
  return lang;
}

/// Resolved theme for a dark/light renderer. `scopes` is the highlight.js
/// `{scope: TextStyle}` map keyed on class names such as 'keyword', 'string',
/// 'number', 'title' — re_highlight looks these up against the map.
class HiTheme {
  final TextStyle base;
  final Map<String, TextStyle> scopes;
  const HiTheme(this.base, this.scopes);
}

HiTheme highlightTheme(bool dark, TextStyle codeStyle) {
  // re_highlight returns a TextSpan tree whose styles come from the theme's
  // TextStyle values; they inherit the supplied base style (font + size).
  if (dark) return HiTheme(codeStyle, githubDarkTheme);
  return HiTheme(codeStyle, githubTheme);
}
