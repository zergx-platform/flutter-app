import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Chat avatar, IM-style.
///
/// Simple deterministic layout:
///   - background = a vivid color derived from the ORG name
///   - text color = pure white or near-black, picked by measuring the
///     background's relative luminance (WCAG) so the label is ALWAYS
///     clearly readable — never a same-brightness clash
///   - label      = first 2 letters of the bookmark (branch) name,
///                  first uppercase + second lowercase
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
    final fg = _contrastForeground(bg);
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

  /// Pick white or near-black text by WCAG relative luminance so the label
  /// always has strong contrast against the background.
  static Color _contrastForeground(Color bg) {
    double channel(double c) =>
        c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();

    final lum = 0.2126 * channel(bg.r) +
        0.7152 * channel(bg.g) +
        0.0722 * channel(bg.b);
    // L_white=1.0 vs L_black≈0.0127; pick whichever yields the larger ratio.
    final whiteRatio = (1.0 + 0.05) / (lum + 0.05);
    final darkRatio = (lum + 0.05) / (0.0127 + 0.05);
    return whiteRatio >= darkRatio ? Colors.white : const Color(0xFF17181C);
  }

  /// First two letters of the bookmark name: first uppercase, second
  /// lowercase. Empty → org, then repo, then '?'.
  static String _label(String branch, String org, String repo) {
    final source = branch.isNotEmpty
        ? branch
        : org.isNotEmpty
            ? org
            : repo.isNotEmpty
                ? repo
                : '?';
    final chars = source.characters.take(2).toList();
    if (chars.isEmpty) return '?';
    if (chars.length == 1) return chars[0].toUpperCase();
    return '${chars[0].toUpperCase()}${chars[1].toLowerCase()}';
  }
}
