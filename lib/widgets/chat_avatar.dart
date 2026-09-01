import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Chat avatar, IM-style.
///
/// Simple deterministic layout:
///   - background = a vivid color derived from the ORG name
///   - text color = a vivid color derived from the REPO name
///   - label      = first 4 letters of the bookmark (branch) name, uppercase
/// Falls back down the ladder (branch → org → repo → '?') for empty parts.
/// Colors are hash-derived, always saturated (never transparent), and stable
/// across rebuilds and the web build.
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

  @override
  Widget build(BuildContext context) {
    final text = textOf(context);
    final bg = _color(org.isNotEmpty ? org : (repo.isNotEmpty ? repo : branch));
    final fg = _color(repo.isNotEmpty ? repo : branch, 180);
    final label = _label(branch, org, repo);
    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: ColoredBox(
          color: bg,
          child: Center(
            child: Text(
              label,
              style: text.body.copyWith(
                fontSize: radius * 0.66,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Deterministic vivid color from a name. A linear-congruential hash
  /// spreads names across the hue wheel; fixed high saturation + mid
  /// lightness guarantee a saturated, always-visible fill.
  static Color _color(String source, [double hueShift = 0]) {
    if (source.isEmpty) return const Color(0xFF7f8c94);
    var hash = 0x811c9dc5;
    for (final cu in source.codeUnits) {
      hash ^= cu;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    final hue = ((hash % 360) + hueShift) % 360;
    return HSLColor.fromAHSL(1, hue, 0.60, 0.48).toColor();
  }

  /// First four letters of the bookmark name, uppercase.
  static String _label(String branch, String org, String repo) {
    final source = branch.isNotEmpty
        ? branch
        : org.isNotEmpty
            ? org
            : repo.isNotEmpty
                ? repo
                : '?';
    return source.characters.take(4).join().toUpperCase();
  }
}
