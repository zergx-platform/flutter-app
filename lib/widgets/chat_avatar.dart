import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum AvatarLevel { org, repo, branch }

/// Chat avatar with a 3-level hierarchy:
///
///   - [AvatarLevel.org]   → a SOLID circle tinted by the org name (no
///                           pattern). Same org ⇒ same solid color.
///   - [AvatarLevel.repo]  → the org background + a FIXED pattern shared by
///                           every repo (geometry constant; foreground hue
///                           derived from the repo, auto-contrasted).
///   - [AvatarLevel.branch]→ the org background + a UNIQUE pattern per
///                           bookmark (foreground hue from the repo).
///
/// Rendering is circle-native: the pattern is drawn through a circular clip
/// (rim cells end in a smooth arc) and cells outside the rim are dropped, so
/// nothing is ever chopped by an outer mask. Fallbacks: empty org → repo →
/// branch for the color seed.
class ChatAvatar extends StatelessWidget {
  final String org;
  final String repo;
  final String branch;
  final double radius;
  final AvatarLevel level;

  const ChatAvatar({
    super.key,
    required this.org,
    required this.repo,
    required this.branch,
    this.radius = 22,
    this.level = AvatarLevel.branch,
  });

  @override
  Widget build(BuildContext context) {
    final bg = _bgColor();
    final fg = _fgColor(bg);
    final cells = _cells();
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: ClipOval(
        child: CustomPaint(
          painter: _IdenticonPainter(bg: bg, fg: fg, cells: cells),
          size: Size.infinite,
        ),
      ),
    );
  }

  // ---- hierarchy seeds ----

  String get _bgSeed =>
      org.isNotEmpty ? org : (repo.isNotEmpty ? repo : branch);

  /// Foreground comes from the repo (or, at org level, the org itself) so a
  /// single org's repos keep distinct hues on the same background.
  String get _fgSeed =>
      repo.isNotEmpty ? repo : (org.isNotEmpty ? org : branch);

  String get _patternSeed => '$org/$repo/$branch';

  // ---- cells by level ----

  List<bool> _cells() {
    switch (level) {
      case AvatarLevel.org:
        // Solid: no pattern at all — the background is the whole avatar.
        return List.filled(25, false);
      case AvatarLevel.repo:
        // Fixed geometry shared by EVERY repo (a symmetric "plus").
        return _fixedRepoCells;
      case AvatarLevel.branch:
        return identiconCells(_patternSeed);
    }
  }

  /// The one fixed pattern used for every repository row.
  static const List<bool> _fixedRepoCells = [
    false, false, true, false, false,
    false, false, true, false, false,
    true, true, true, true, true,
    false, false, true, false, false,
    false, false, true, false, false,
  ];

  // ---- colors ----

  /// Vivid mid-tone background from the ORG hash.
  Color _bgColor() =>
      HSLColor.fromAHSL(1, _hue(_bgSeed), 0.60, 0.48).toColor();

  /// Foreground keeps the repo hue, with lightness laddered for strong WCAG
  /// contrast against the background (>= 3.5:1 where reachable).
  Color _fgColor(Color bg) {
    const darkRungs = [0.34, 0.28, 0.22, 0.17, 0.12];
    const lightRungs = [0.66, 0.72, 0.78, 0.84, 0.90];
    final hue = _hue(_fgSeed);

    Color best = Colors.white;
    var bestRatio = -1.0;
    for (final l in [...darkRungs, ...lightRungs]) {
      final c = HSLColor.fromAHSL(1, hue, 0.62, l).toColor();
      final r = _contrastRatio(c, bg);
      if (r > bestRatio) {
        bestRatio = r;
        best = c;
      }
      if (bestRatio >= 3.5) break;
    }
    if (bestRatio < 3.0) {
      return _luminance(bg) > 0.35 ? const Color(0xFF17181C) : Colors.white;
    }
    return best;
  }

  // ---- hashing / geometry ----

  static int _fnv(String s) {
    var hash = 0x811c9dc5;
    for (final cu in s.codeUnits) {
      hash ^= cu;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  static double _hue(String source) => _fnv(source) % 360.toDouble();

  /// 25 mirrored cells (row-major, 5x5). Left 3 columns hash; columns 3/4
  /// mirror columns 1/0. Degenerate patterns are rehashed. Density counts
  /// only circle-visible cells so an all-corner seed can't render empty.
  static List<bool> identiconCells(String seed) {
    var h = _fnv(seed);
    for (var attempt = 0; attempt < 8; attempt++) {
      final left = List.generate(15, (i) => ((h >> i) & 1) == 1);
      final visibleOn = _visibleOnCount(left);
      if (visibleOn >= 4 && visibleOn <= 11) {
        return [
          for (var r = 0; r < 5; r++)
            for (var c = 0; c < 5; c++)
              left[r * 3 + (c <= 2 ? c : 4 - c)],
        ];
      }
      h = _fnv('$seed#$attempt');
    }
    bool x(int r, int c) => (r - c).abs() == 2 || r == c;
    return [
      for (var r = 0; r < 5; r++) for (var c = 0; c < 5; c++) x(r, c <= 2 ? c : 4 - c),
    ];
  }

  /// Count 'on' cells that are visible inside the circle (corners never
  /// render — their centers lie outside the inscribed circle).
  static int _visibleOnCount(List<bool> left) {
    var n = 0;
    for (var i = 0; i < left.length; i++) {
      if (i == 0 || i == 12) continue;
      if (left[i]) n++;
    }
    return n;
  }

  // ---- WCAG contrast math ----

  static double _luminance(Color c) {
    double channel(double v) =>
        v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(c.r) +
        0.7152 * channel(c.g) +
        0.0722 * channel(c.b);
  }

  static double _contrastRatio(Color a, Color b) {
    final la = _luminance(a);
    final lb = _luminance(b);
    final hi = max(la, lb);
    final lo = min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }
}

/// Paints the identicon natively in the circle: background fills the whole
/// circle; on-cells are drawn through a circular clip so rim cells finish in
/// a smooth arc. Cells whose center lies outside the circle are skipped.
class _IdenticonPainter extends CustomPainter {
  final Color bg;
  final Color fg;
  final List<bool> cells;
  _IdenticonPainter(
      {required this.bg, required this.fg, required this.cells});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawOval(rect, Paint()..color = bg);
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    final cell = size.shortestSide / 5;
    final center = rect.center;
    final radius = size.shortestSide / 2;
    final paint = Paint()..color = fg;
    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < 5; c++) {
        if (!cells[r * 5 + c]) continue;
        final cellRect = Rect.fromLTWH(c * cell, r * cell, cell, cell);
        if ((cellRect.center - center).distance > radius) continue;
        canvas.drawRect(cellRect, paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IdenticonPainter old) =>
      old.bg != bg || old.fg != fg || !listEquals(old.cells, cells);
}
