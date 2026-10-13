import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ascii_grid.dart';
import 'scene_math.dart';

/// Bảng màu của các cảnh ASCII (lá = màu Focus, táo = màu Break,
/// cát = màu Ending soon).
@immutable
class AsciiSceneColors {
  const AsciiSceneColors({
    required this.leaf,
    required this.apple,
    required this.sand,
    required this.ground,
    required this.frame,
    required this.dark,
  });

  final Color leaf;
  final Color apple;
  final Color sand;
  final Color ground;
  final Color frame;
  final bool dark;

  Color get leafShade => Color.lerp(leaf, Colors.black, 0.3)!;
  Color get trunk => dark ? const Color(0xFFB07B47) : const Color(0xFF7A4E26);
  Color get seed => dark ? const Color(0xFFC89463) : const Color(0xFF6B4226);
  Color get blossom => const Color(0xFFFFC7D6);
  Color get flesh => const Color(0xFFFFEFC8);
}

Color _a(Color c, double alpha) =>
    c.withValues(alpha: c.a * alpha.clamp(0.0, 1.0));

/// Độ rõ của ô ở mép một hình đang lớn: [inside] là khoảng cách (chuẩn hoá)
/// vào trong mép; càng sát mép càng mờ → hình lớn dần mượt, không bật ô.
double _edgeAlpha(double inside, {double ramp = 0.15}) =>
    (inside / ramp).clamp(0.0, 1.0);

// ---------------------------------------------------------------------------
// Cây táo (bước Focus) — lưới 37 × 19, mặt đất ở hàng 17.
// ---------------------------------------------------------------------------

const int sceneWidth = 37;
const int sceneHeight = 19;
const int _ground = 17;
const int _cx = 18;

/// Ký tự tán lá, chọn theo vị trí để tán trông lổn nhổn tự nhiên.
const _leafChars = ['&', '%', '#', '@', '&', '%'];

/// Vị trí quả (so với tâm tán, tính theo ô).
const _appleSpots = <(int, int)>[
  (5, 1),
  (-5, 1),
  (0, -2),
  (-9, -1),
  (9, -1),
  (-2, 2),
  (3, -3),
];

/// (vị trí dọc thân 0–1, hướng -1 trái / 1 phải, chiều dài, lúc bắt đầu mọc).
const _branches = <(double, int, int, double)>[
  (0.5, -1, 4, 0.25),
  (0.6, 1, 4, 0.35),
  (0.75, -1, 3, 0.45),
  (0.82, 1, 3, 0.55),
];

/// Nhiễu cố định theo ô (0–1) để mép tán và ký tự không đều.
double _noise(int x, int y) {
  final v = math.sin(x * 12.9898 + y * 78.233) * 43758.5453;
  return v - v.floorToDouble();
}

/// Mặt đất "___", lớp đất bên dưới, và gò đất "./^\." (độ rõ [mound]).
void _drawGround(AsciiGrid g, AsciiSceneColors c, {double mound = 0}) {
  for (var x = 1; x <= sceneWidth - 2; x++) {
    g.put(x, _ground, '_', c.ground);
  }
  for (var x = 3; x <= sceneWidth - 3; x += 4) {
    g.put(x, _ground + 1, x % 8 == 3 ? "'" : '.', _a(c.ground, 0.6));
  }
  if (mound > 0) g.text(_cx - 2, _ground, './^\\.', _a(c.ground, mound));
}

/// Chiều cao thân (số hàng, có phần lẻ) ở tiến độ lớn [p].
double _trunkRows(double p) {
  final grow = seg(p, 0.05, 0.7);
  return grow <= 0 ? 0 : 1 + easeOut(grow) * 9;
}

/// Vẽ cây táo ở tiến độ lớn [p] (0 = hạt, 1 = đầy quả chín) vào [g].
///
/// [swayPhase] 0–1 lặp: tán lá đung đưa mượt. [seedOnGround]: hạt đã gieo
/// sẵn từ bước Break.
void drawAsciiTree(
  AsciiGrid g,
  AsciiSceneColors c, {
  required double p,
  required double swayPhase,
  bool seedOnGround = false,
}) {
  final sprout = seg(p, 0.015, 0.05);
  final grow = seg(p, 0.05, 0.7);
  final bloom = seg(p, 0.66, 0.86);
  final fruit = seg(p, 0.84, 1.0);

  // Hạt rơi xuống đất (vị trí lẻ ô → rơi mượt), mờ dần khi mầm lên.
  if (sprout < 0.35) {
    final drop = seedOnGround ? 1.0 : easeOutBounce(seg(p, 0, 0.015));
    g.sprite(
      _cx.toDouble(),
      3 + (_ground - 3) * drop,
      'o',
      _a(c.seed, 1 - seg(sprout, 0.1, 0.35)),
    );
  }

  // Mầm hiện dần: "," → "|" + "\|/".
  if (grow <= 0) {
    if (sprout < 0.6) {
      g.put(_cx, _ground, ',', _a(c.leaf, seg(sprout, 0.2, 0.45)));
    } else {
      g.put(_cx, _ground, '|', _a(c.leaf, seg(sprout, 0.55, 0.75)));
    }
    g.text(_cx - 1, _ground - 1, '\\|/', _a(c.leaf, seg(sprout, 0.7, 1)));
    return;
  }

  // Thân: ngọn mới hiện dần theo phần lẻ của chiều cao; dày dần thành
  // "|||", rễ "/|||\" nối liền mặt đất.
  final rowsF = _trunkRows(p);
  final rows = rowsF.ceil();
  final topAlpha = rowsF - (rows - 1);
  final thick = seg(grow, 0.35, 0.45);
  for (var i = 0; i < rows; i++) {
    final y = _ground - i;
    final alpha = i == rows - 1 ? topAlpha : 1.0;
    g.put(_cx, y, '|', _a(c.trunk, alpha));
    if (thick > 0 && i < rows * 0.6) {
      g.put(_cx - 1, y, '|', _a(c.trunk, thick * alpha));
      g.put(_cx + 1, y, '|', _a(c.trunk, thick * alpha));
    }
  }
  final roots = seg(grow, 0.5, 0.6);
  g.put(_cx - 2, _ground, '/', _a(c.trunk, roots));
  g.put(_cx + 2, _ground, '\\', _a(c.trunk, roots));

  // Cành chéo mọc dần; ô cuối hiện dần theo phần lẻ.
  for (final (frac, dir, len, start) in _branches) {
    final lenF = len * easeOut(seg(grow, start, start + 0.3));
    final n = lenF.ceil();
    final y0 = _ground - (rowsF * frac).round();
    for (var k = 1; k <= n; k++) {
      g.put(
        _cx + dir * (k + (thick > 0.5 ? 1 : 0)),
        y0 - k,
        dir < 0 ? '\\' : '/',
        _a(c.trunk, k == n ? lenF - (n - 1) : 1),
      );
    }
  }

  // Tán lá: bầu dục lớn dần, mép hiện dần.
  final e = easeOut(seg(p, 0.2, 0.78));
  if (e <= 0) return;
  final rx = 3 + e * 10;
  final ry = 1.5 + e * 3.6;
  final top = _ground - rowsF + 1;
  final cy = (top - ry * 0.55).round();
  const cx = _cx;

  // Đung đưa: mỗi hàng dịch một khoảng lẻ ô theo sóng sin, ngọn lắc nhiều
  // hơn, các hàng lệch pha nhau → tán uốn lượn mượt.
  for (var y = (cy - ry).floor(); y <= (cy + ry).ceil(); y++) {
    if (y < 0 || y >= sceneHeight) continue;
    final height = ((cy + ry - y) / (2 * ry)).clamp(0.0, 1.0);
    g.rowOffsets[y] =
        math.sin(2 * math.pi * swayPhase - (y - cy) * 0.35) * 0.45 * e * height;
  }

  for (var y = (cy - ry).floor(); y <= (cy + ry).ceil(); y++) {
    for (var x = (cx - rx).floor() - 1; x <= (cx + rx).ceil() + 1; x++) {
      final dx = (x - cx) / rx;
      final dy = (y - cy) / ry;
      final n = _noise(x, y);
      final inside = (1 - 0.18 * n) - (dx * dx + dy * dy);
      if (inside <= 0) continue;
      g.put(
        x,
        y,
        _leafChars[(n * _leafChars.length).floor() % _leafChars.length],
        _a(n < 0.45 ? c.leafShade : c.leaf, _edgeAlpha(inside, ramp: 0.12)),
      );
    }
  }

  // Hoa "*" hiện dần, rồi quả "o" → "O", từ xanh chín dần sang đỏ.
  for (final (i, (dx, dy)) in _appleSpots.indexed) {
    final y = cy + (dy * e).round();
    final x = cx + (dx * e).round();
    final ripe = easeOut(seg(fruit, i * 0.05, i * 0.05 + 0.6));
    if (ripe > 0) {
      g.put(
        x,
        y,
        ripe < 0.45 ? 'o' : 'O',
        _a(
          Color.lerp(c.leaf, c.apple, seg(fruit, 0.25, 1))!,
          ripe < 0.45 ? ripe / 0.2 : 1,
        ),
      );
    } else {
      final flower = seg(bloom, i * 0.06, i * 0.06 + 0.4);
      if (flower > 0) g.put(x, y, '*', _a(c.blossom, flower));
    }
  }
}

/// Cảnh Focus: cây táo lớn từ hạt tới khi chín quả.
AsciiGrid buildGrowScene(
  AsciiSceneColors c, {
  required double progress,
  required double swayPhase,
  required bool seedOnGround,
}) {
  final g = AsciiGrid(sceneWidth, sceneHeight);
  _drawGround(g, c, mound: seedOnGround ? 1 - seg(progress, 0.03, 0.06) : 0);
  drawAsciiTree(
    g,
    c,
    p: progress,
    swayPhase: swayPhase,
    seedOnGround: seedOnGround,
  );
  return g;
}

// ---------------------------------------------------------------------------
// Ăn táo (bước Break) — chỉ có quả táo, không vẽ cây.
// ---------------------------------------------------------------------------

/// Tâm quả to và kích thước (bán kính theo ô).
const _plateX = _cx;
const _plateY = 8;
const _bigRx = 8.0;
const _bigRy = 4.6;

/// Góc 6 miếng cắn, xen kẽ hai bên — ăn hết còn đúng phần lõi ở giữa.
const _biteAngles = [0.0, math.pi, 0.55, math.pi - 0.55, -0.55, math.pi + 0.55];

/// Cảnh Break: quả rơi → bị ăn dần (6 miếng) → lõi → lộ hạt → gieo hạt
/// xuống đất cho lượt Focus kế tiếp.
AsciiGrid buildEatScene(AsciiSceneColors c, {required double progress}) {
  final q = progress;
  final g = AsciiGrid(sceneWidth, sceneHeight);
  _drawGround(g, c, mound: seg(q, 0.985, 1.0));

  // Quả rơi từ trên xuống giữa khung (vị trí lẻ ô, có nảy).
  final fall = seg(q, 0, 0.02);
  if (fall < 1) {
    g.sprite(_plateX.toDouble(), _plateY * easeOutBounce(fall), 'O', c.apple);
    return g;
  }

  // Quả phóng to (mép hiện dần), bị cắn dần; chuyển mờ sang lõi.
  final zoom = easeInOut(seg(q, 0.015, 0.03));
  final rx = 1 + (_bigRx - 1) * zoom;
  final ry = 0.6 + (_bigRy - 0.6) * zoom;
  final toCore = seg(q, 0.95, 0.962);
  if (toCore < 1) {
    _drawBittenApple(g, c, rx, ry, seg(q, 0.03, 0.95), 1 - toCore);
  }
  final core = toCore * (1 - seg(q, 0.966, 0.975));
  if (core > 0) _drawCore(g, c, core);

  // Hạt lộ ra, rồi bay theo đường cong (vị trí lẻ ô) xuống gò đất.
  final seedAlpha = seg(q, 0.96, 0.97);
  if (seedAlpha > 0) {
    final t = easeInOut(seg(q, 0.975, 0.995));
    double quad(double a, double b, double cc) =>
        (1 - t) * (1 - t) * a + 2 * (1 - t) * t * b + t * t * cc;
    g.sprite(
      quad(_plateX.toDouble(), _cx + 9.0, _cx.toDouble()),
      quad(_plateY.toDouble(), 2, _ground.toDouble()),
      'o',
      _a(c.seed, seedAlpha),
    );
  }
  return g;
}

void _drawBittenApple(
  AsciiGrid g,
  AsciiSceneColors c,
  double rx,
  double ry,
  double bites,
  double opacity,
) {
  // Tâm và bán kính từng miếng cắn (toạ độ chuẩn hoá theo quả).
  final now = <(double, double, double)>[];
  for (final (k, angle) in _biteAngles.indexed) {
    final b = easeOut(seg(bites, k / 6, k / 6 + 0.14));
    if (b > 0) {
      now.add((math.cos(angle) * 1.05, math.sin(angle) * 1.05, 0.55 * b));
    }
  }
  for (var y = (_plateY - ry).floor(); y <= (_plateY + ry).ceil(); y++) {
    for (var x = (_plateX - rx).floor(); x <= (_plateX + rx).ceil(); x++) {
      final u = (x - _plateX) / rx;
      final v = (y - _plateY) / ry;
      final inside = 1 - (u * u + v * v);
      if (inside <= 0) continue;
      // Khoảng cách tới miếng cắn gần nhất (âm = đã bị cắn).
      var gap = double.infinity;
      var nearBite = false;
      for (final (bu, bv, br) in now) {
        final d = math.sqrt((u - bu) * (u - bu) + (v - bv) * (v - bv));
        gap = math.min(gap, d - br);
        if (d <= br * 1.35) nearBite = true;
      }
      if (gap <= 0) continue;
      // Mép quả và mép miếng cắn hiện / mất dần.
      final alpha = _edgeAlpha(inside) * _edgeAlpha(gap, ramp: 0.12) * opacity;
      g.put(
        x,
        y,
        nearBite ? ':' : '@',
        _a(nearBite ? c.flesh : c.apple, alpha),
      );
    }
  }
  // Cuống + lá.
  final top = (_plateY - ry).floor() - 1;
  g.put(_plateX, top, '|', _a(c.trunk, opacity));
  g.put(_plateX + 1, top, '~', _a(c.leaf, opacity));
}

/// Lõi táo: cột thịt ":::" với hai đầu còn vỏ "@@@@@", cuống ở trên.
void _drawCore(AsciiGrid g, AsciiSceneColors c, double opacity) {
  for (var dy = -3; dy <= 3; dy++) {
    g.text(_plateX - 1, _plateY + dy, ':::', _a(c.flesh, opacity));
  }
  g.text(_plateX - 2, _plateY - 4, '@@@@@', _a(c.apple, opacity));
  g.text(_plateX - 2, _plateY + 4, '@@@@@', _a(c.apple, opacity));
  g.put(_plateX, _plateY - 5, '|', _a(c.trunk, opacity));
}

// ---------------------------------------------------------------------------
// Đồng hồ cát (bước vô hạn) — lưới 21 × 17.
// ---------------------------------------------------------------------------

const int hourglassWidth = 21;
const int hourglassHeight = 17;
const int _hc = 10;

/// Cột trong của một hàng bầu kính: (từ, đến). Bầu trên hàng 1–8 thắt dần
/// về cổ; bầu dưới hàng 9–15 nở dần ra.
(int, int) _interior(int row) {
  if (row <= 8) return (3 + (row - 1), 17 - (row - 1));
  final k = row - 9;
  return (_hc - k, _hc + k);
}

/// Các ô trong hàng, xếp từ giữa ra hai bên (cát lấp từ giữa trước).
List<int> _centerOut(int a, int b) =>
    [for (var x = a; x <= b; x++) x]
      ..sort((p, q) => (p - _hc).abs().compareTo((q - _hc).abs()));

/// Lấp [amount] ô cát (có phần lẻ) vào [rows] theo thứ tự; ô cuối hiện mờ
/// theo phần lẻ để cát dâng / hạ mượt. [char] nhận true nếu là lớp trên cùng.
void _fillSand(
  AsciiGrid g,
  AsciiSceneColors c,
  Iterable<int> rows,
  double amount,
  String Function(bool topLayer) char,
) {
  var remain = amount;
  for (final r in rows) {
    if (remain <= 0) return;
    final (a, b) = _interior(r);
    final cells = _centerOut(a, b);
    final topLayer = remain < cells.length;
    for (final x in cells) {
      if (remain <= 0) break;
      g.put(x, r, char(topLayer), _a(c.sand, math.min(1, remain)));
      remain -= 1;
    }
  }
}

int _cellsIn(Iterable<int> rows) => rows.fold(0, (sum, r) {
  final (a, b) = _interior(r);
  return sum + b - a + 1;
});

/// Đồng hồ cát: [fill] tỉ lệ cát đã xuống bầu dưới (0–1); [streamPhase]
/// 0–1 lặp: vị trí các hạt cát đang rơi khi [running].
AsciiGrid buildHourglassScene(
  AsciiSceneColors c, {
  required double fill,
  required double streamPhase,
  required bool running,
}) {
  final g = AsciiGrid(hourglassWidth, hourglassHeight);
  final glass = _a(c.frame, 0.7);

  g.text(2, 0, '=================', c.frame);
  g.text(2, 16, '=================', c.frame);
  for (var r = 1; r <= 8; r++) {
    g.put(2 + (r - 1), r, '\\', glass);
    g.put(18 - (r - 1), r, '/', glass);
  }
  for (var r = 9; r <= 15; r++) {
    final k = r - 9;
    g.put(_hc - 1 - k, r, '/', glass);
    g.put(_hc + 1 + k, r, '\\', glass);
  }

  const topRows = [8, 7, 6, 5, 4, 3, 2, 1]; // lấp từ cổ lên
  const bottomRows = [15, 14, 13, 12, 11, 10, 9]; // dồn từ đáy lên
  _fillSand(g, c, topRows, (1 - fill) * _cellsIn(topRows), (_) => ':');
  final pile = fill * _cellsIn(bottomRows);
  _fillSand(g, c, bottomRows, pile, (top) => top ? '.' : ':');

  // Hạt cát rơi liên tục (vị trí lẻ ô) từ cổ xuống mặt ụ cát.
  if (running && fill > 0 && fill < 1) {
    var surface = 15;
    var left = pile;
    for (final r in bottomRows) {
      final (a, b) = _interior(r);
      left -= b - a + 1;
      surface = r;
      if (left <= 0) break;
    }
    final len = surface - 9.0;
    if (len > 0.5) {
      for (var k = 0; k < 3; k++) {
        final t = (streamPhase + k / 3) % 1;
        g.sprite(_hc.toDouble(), 8.6 + len * t, '.', c.sand);
      }
    }
  }
  return g;
}
