import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Chat avatar, IM-style: a GitHub-style 5x5 mirrored identicon whose
/// hierarchy encodes org → repo → branch affinity:
///
///   - background color  = hue from hash(ORG)     → same org, same底色
///   - pattern color     = hue from hash(REPO), with lightness auto-picked
///                         for strong WCAG contrast against the background
///                         → same org + different repo: same底色, different
///                           pattern color
///   - pattern geometry  = bits from hash(org/repo/BRANCH) → same repo +
///                         different bookmark: same配色, different图案
///
/// The geometry is the classic identicon recipe: a 5x5 grid where the left
/// 3 columns come from hash bits and the right 2 mirror them, giving
/// left-right symmetric figures. Rendering is circle-native: the pattern is
/// drawn through a circular clip (rim cells end in a smooth arc) and cells
/// outside the rim are dropped, so nothing is ever chopped by an outer
/// mask. Degenerate grids (too empty / too full) are deterministically
/// rehashed away. Falls back down the ladder (branch → org → repo) for
/// empty parts.
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
    final bg = _bgColor();
    final fg = _fgColor(bg);
    final cells = identiconCells(_patternSeed);
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

  String get _fgSeed =>
      repo.isNotEmpty ? repo : (org.isNotEmpty ? org : branch);

  String get _patternSeed => '$org/$repo/$branch';

  // ---- colors ----

  /// Vivid mid-tone background from the ORG hash (hue wheel, fixed
  /// saturation + lightness so fills are always solid and stable).
  Color _bgColor() => HSLColor.fromAHSL(1, _hue(_bgSeed), 0.60, 0.48)
      .toColor();

  /// Pattern color keeps the REPO hue but its lightness is picked from a
  /// ladder to maximize contrast against the background (>= 3.5:1 where
  /// reachable; otherwise the extreme rung wins, then pure white/black).
  /// Deterministic: the same repo always yields the same color.
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
      return _luminance(bg) > 0.35
          ? const Color(0xFF17181C)
          : Colors.white;
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

  /// 25 mirrored cells (row-major, 5x5). The left 3 columns are hash bits;
  /// columns 3/4 mirror columns 1/0.
  ///
  /// Degenerate patterns are deterministically rehashed away. The density
  /// check counts only cells VISIBLE inside the circular mask — the four
  /// grid corners always fall outside the circle (see [_IdenticonPainter]),
  /// so a pattern whose "on" bits are all corners would render empty.
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
    // Deterministic fallback: a small mirrored "X" figure.
    bool x(int r, int c) => (r - c).abs() == 2 || r == c;
    return [
      for (var r = 0; r < 5; r++)
        for (var c = 0; c < 5; c++) x(r, c <= 2 ? c : 4 - c),
    ];
  }

  /// Count 'on' cells that are visible inside the circle. The corner cells
  /// (left-column indices 0 and 12) mirror into all four corners, whose
  /// centers lie outside the inscribed circle — they never render.
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

/// Paints the identicon natively in the circle: the background fills the
/// full circle, and on-cells are drawn through a circular clip so rim cells
/// end in a smooth arc instead of being chopped by an outer mask. Cells
/// whose center lies outside the circle (the four corners) are skipped
/// entirely — no dangling slivers.
class _IdenticonPainter extends CustomPainter {
  final Color bg;
  final Color fg;
  final List<bool> cells;
  _IdenticonPainter(
      {required this.bg, required this.fg, required this.cells});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Circular background — nothing square is ever drawn outside the rim.
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
