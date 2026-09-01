import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Deterministic per-session chat avatar, IM-style.
///
/// Color: hash of the session name over an 8-color palette derived from the
/// shared theme (facts: same session always renders identically).
/// Label: first grapheme of the branch (falls back to org, then '?').
class ChatAvatar extends StatelessWidget {
  final String org;
  final String repo;
  final String branch;
  final double radius;

  const ChatAvatar({
    super.key,
    required this.org,
    required this.repo,
    required this.branch,
    this.radius = 22,
  });

  static const _palette = <Color>[
    Color(0xFF7c9ef7), // blue
    Color(0xFF7fd88f), // green
    Color(0xFFf5a742), // amber
    Color(0xFFe58ea8), // pink
    Color(0xFF9d7cd8), // purple
    Color(0xFF56b6c2), // teal
    Color(0xFFf08e6b), // coral
    Color(0xFF8fae5c), // olive
  ];

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(context);
    final text = textOf(context);
    final name = '$org:$repo:$branch';
    var hash = 0;
    for (final cu in name.codeUnits) {
      hash = (hash * 31 + cu) & 0x7fffffff;
    }
    final bg = _palette[hash % _palette.length];
    final labelSource =
        branch.isNotEmpty ? branch : (org.isNotEmpty ? org : '?');
    final label = labelSource[0].toUpperCase();
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        label,
        style: text.body.copyWith(
          fontSize: radius * 0.82,
          fontWeight: FontWeight.w700,
          color: colors.background,
        ),
      ),
    );
  }
}
