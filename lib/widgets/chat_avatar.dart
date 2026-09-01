import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// WeChat-style two-tone chat avatar.
///
/// The circle is split horizontally:
///   - top half   = the org's color
///   - bottom half = the repo's color
/// with the bookmark (branch) name's first letters shown uppercase in the
/// middle. Falls back down the org/repo/'?' ladder when a part is empty.
///
/// Color assignment is a **guaranteed-unique** registry: every distinct org
/// gets a distinct palette slot (and every distinct repo likewise, using a
/// second palette) until the palette is exhausted, then it cycles. Org and
/// repo use *different* palettes so the two halves never read as the same
/// color, even for a name shared by both roles.
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
    final orgColor = _AvatarColors.org(org.isNotEmpty ? org : (repo.isNotEmpty ? repo : branch));
    final repoColor = _AvatarColors.repo(repo.isNotEmpty ? repo : branch);
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
                  color: Colors.white,
                  shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

/// Guaranteed-unique per-role color registry (lazy, in-memory).
///
/// `putIfAbsent` assigns `length % palette.length` — the next free slot — so
/// every distinct key maps to a distinct color until the palette is exhausted
/// (then round-robins). Because org and repo use separate palettes, the same
/// name never yields the same color for both roles.
class _AvatarColors {
  static const int _size = 12;

  static final List<Color> _orgPalette = const [
    Color(0xFF4a6fa5), // steel blue
    Color(0xFF3f7d5f), // forest green
    Color(0xFF6b5b95), // violet
    Color(0xFF2f7f8f), // teal
    Color(0xFF8a5a44), // sienna
    Color(0xFF32638a), // indigo blue
    Color(0xFF5a7d4f), // moss
    Color(0xFF7a4f6d), // plum
    Color(0xFF40597e), // navy
    Color(0xFF4f7a63), // sea green
    Color(0xFF6d5a8a), // slate purple
    Color(0xFF3a6e75), // petrol
  ];

  static final List<Color> _repoPalette = const [
    Color(0xFFc0584d), // coral red
    Color(0xFFd19a3a), // amber
    Color(0xFFb06f9e), // orchid
    Color(0xFFc07a4b), // terracotta
    Color(0xFFb3556f), // raspberry
    Color(0xFFc98a2f), // gold
    Color(0xFFd06a6a), // blush
    Color(0xFFa35f5f), // maroon
    Color(0xFFbd7b55), // bronze
    Color(0xFFc9644d), // flame
    Color(0xFFdb923b), // honey
    Color(0xFFa86f8e), // mauve
  ];

  static final Map<String, int> _orgIndex = {};
  static final Map<String, int> _repoIndex = {};

  static Color org(String key) {
    final idx = _orgIndex.putIfAbsent(key, () => _orgIndex.length % _size);
    return _orgPalette[idx];
  }

  static Color repo(String key) {
    final idx = _repoIndex.putIfAbsent(key, () => _repoIndex.length % _size);
    return _repoPalette[idx];
  }
}
