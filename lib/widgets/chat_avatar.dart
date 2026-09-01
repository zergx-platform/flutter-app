import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// WeChat-style two-tone chat avatar.
///
/// The circle is split horizontally: top half = org's color, bottom half =
/// repo's color, with the bookmark name's first letters shown uppercase in
/// the middle (falls back down the org/repo/'?' ladder when a part is empty).
///
/// Color assignment is **purely deterministic** (hash of the name, no mutable
/// registry), so it always renders a color and is stable across rebuilds and
/// across the web build. Org and repo use complementary hue rotations — repo
/// is shifted +170° from org — so the two halves are always visibly distinct
/// even when a name string happens to share a raw hash. Saturation/lightness
/// are pinned high so small icons stay vivid in both themes.
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
    final orgColor = _color(org.isNotEmpty ? org : (repo.isNotEmpty ? repo : branch), 0);
    // Repo hue is rotated ~170° away from the org hue so the two halves never
    // read as the same colour, regardless of the name content.
    final repoColor = _color(repo.isNotEmpty ? repo : branch, 170);
    final label = _label(branch, org, repo);
    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                Expanded(child: ColoredBox(color: orgColor)),
                Expanded(child: ColoredBox(color: repoColor)),
              ],
            ),
            Center(
              child: Text(
                label,
                style: text.body.copyWith(
                  fontSize: radius * 0.72,
                  fontWeight: FontWeight.w700,
                  // White over a fixed-hue mid-lightness background; shadow
                  // keeps it legible on the lighter repo half too.
                  color: Colors.white,
                  shadows: const [Shadow(color: Colors.black38, blurRadius: 2)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Deterministic vivid color for a role+deltahue. A 3-length rolling hash
  /// spreads nearby names across the wheel; the fixed saturation/lightness
  /// guarantee a saturated, theme-independent fill.
  static Color _color(String source, double hueShift) {
    var s = source;
    if (s.isEmpty) {
      // A neutral slate for the empty fallback — still a colour, not white.
      return const Color(0xFF7f8c94);
    }
    var hash = 0x811c9dc5;
    for (final cu in s.codeUnits) {
      hash ^= cu;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    final hue = ((hash % 360) + hueShift) % 360;
    // Saturation 0.6, lightness 0.5 → mid, vivid, distinct halves.
    return HSLColor.fromAHSL(1, hue, 0.60, 0.50).toColor();
  }

  /// First few letters of the bookmark name, uppercase. 2 letters reads best
  /// in a small circle (WeChat convention); empty → org, then repo, then '?'.
  static String _label(String branch, String org, String repo) {
    final source = branch.isNotEmpty
        ? branch
        : org.isNotEmpty
            ? org
            : repo.isNotEmpty
                ? repo
                : '?';
    return source.characters.take(2).join().toUpperCase();
  }
}
