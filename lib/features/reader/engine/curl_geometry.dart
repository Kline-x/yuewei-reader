import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// 3D 贝塞尔仿真卷页几何解算器（纯数学零 UI 状态，严格左书脊防撕裂、零 NaN 保证）
class CurlGeometry {
  CurlGeometry._({
    required this.isIdle,
    required this.size,
    required this.corner,
    required this.effectiveTouch,
    required this.bezierCtrlX,
    required this.bezierCtrlY,
    required this.bezierStartX,
    required this.bezierEndX,
    required this.bezierStartY,
    required this.bezierEndY,
    required this.subStartX,
    required this.subStartY,
    required this.nextRevealPath,
    required this.backFoldPath,
    required this.foldLineStart,
    required this.foldLineEnd,
    required this.foldAngleRad,
    required this.diagonalRatio,
  });

  final bool isIdle;
  final Size size;
  final Offset corner;
  final Offset effectiveTouch;
  final Offset bezierCtrlX;
  final Offset bezierCtrlY;
  final Offset bezierStartX;
  final Offset bezierEndX;
  final Offset bezierStartY;
  final Offset bezierEndY;
  final Offset subStartX;
  final Offset subStartY;
  final Path nextRevealPath;
  final Path backFoldPath;
  final Offset foldLineStart;
  final Offset foldLineEnd;
  final double foldAngleRad;
  final double diagonalRatio;

  /// 根据视口尺寸、当前有效触点与翻起角点精确解算贝塞尔卷页几何
  factory CurlGeometry.compute({
    required Size size,
    required Offset touch,
    required Offset corner,
  }) {
    final w = size.width;
    final h = size.height;
    if (w <= 10 || h <= 10 || !touch.dx.isFinite || !touch.dy.isFinite) {
      return _empty(size, corner);
    }

    final fx = corner.dx;
    final fy = corner.dy;

    // 限制触点距离角点过近时退化为空闲帧，避免零尺度折角抖动
    var ax = touch.dx.clamp(-w * 0.9, w - 0.5);
    var ay = touch.dy.clamp(-h * 0.35, h * 1.35);

    // 若水平贴近顶/底边线，保留 ±2.5px 稳定微偏移杜绝斜率除零崩溃
    if ((ay - fy).abs() < 2.5) {
      ay = fy >= h * 0.5 ? (fy - 2.5) : (fy + 2.5);
    }
    if ((ax - fx).abs() < 2.0) {
      return _empty(size, corner);
    }

    // 首次求解底/右边折痕截点并检查左书脊防撕裂约束
    var solved = _solveControlPoints(ax, ay, fx, fy);
    if (solved.cx < 0.0) {
      // 沿角点 F -> A 射线等比收敛，确保左折点 c_x 严格保持在安全边界内不撕裂
      final fullSpan = fx - solved.cx;
      if (fullSpan > 1.0) {
        final scale = ((w * 0.992) / fullSpan).clamp(0.05, 1.0);
        ax = fx - (fx - ax) * scale;
        ay = fy - (fy - ay) * scale;
        if ((ay - fy).abs() < 2.0) {
          ay = fy >= h * 0.5 ? (fy - 2.0) : (fy + 2.0);
        }
        solved = _solveControlPoints(ax, ay, fx, fy);
      }
    }

    final e = Offset(solved.ex, fy);
    final c = Offset(solved.cx, fy);
    final hPt = Offset(fx, solved.hy);
    final j = Offset(fx, solved.jy);
    final a = Offset(ax, ay);

    final b = Offset((a.dx + e.dx) * 0.5, (a.dy + e.dy) * 0.5);
    final k = Offset((a.dx + hPt.dx) * 0.5, (a.dy + hPt.dy) * 0.5);

    // 二次贝塞尔曲线 C -> E -> B 与 J -> H -> K 在 t = 0.5 处的精确切分点 D 与 I
    final d = Offset(
      0.25 * c.dx + 0.5 * e.dx + 0.25 * b.dx,
      0.25 * c.dy + 0.5 * e.dy + 0.25 * b.dy,
    );
    final i = Offset(
      0.25 * j.dx + 0.5 * hPt.dx + 0.25 * k.dx,
      0.25 * j.dy + 0.5 * hPt.dy + 0.25 * k.dy,
    );

    // 下层目标页暴露区完整外轮廓
    final nextPath = Path()
      ..moveTo(c.dx, c.dy)
      ..quadraticBezierTo(e.dx, e.dy, b.dx, b.dy)
      ..lineTo(a.dx, a.dy)
      ..lineTo(k.dx, k.dy)
      ..quadraticBezierTo(hPt.dx, hPt.dy, j.dx, j.dy)
      ..lineTo(fx, fy)
      ..close();

    // de Casteljau 后半段控制点，构造与暴露区 100% 严丝合缝的背面卷曲弧边
    final ctrlSub1 = Offset((e.dx + b.dx) * 0.5, (e.dy + b.dy) * 0.5);
    final ctrlSub2 = Offset((hPt.dx + k.dx) * 0.5, (hPt.dy + k.dy) * 0.5);

    final backPath = Path()
      ..moveTo(d.dx, d.dy)
      ..quadraticBezierTo(ctrlSub1.dx, ctrlSub1.dy, b.dx, b.dy)
      ..lineTo(a.dx, a.dy)
      ..lineTo(k.dx, k.dy)
      ..quadraticBezierTo(ctrlSub2.dx, ctrlSub2.dy, i.dx, i.dy)
      ..close();

    final dist = (a - corner).distance;
    final maxDiag = math.sqrt(w * w + h * h);
    final ratio = maxDiag > 0 ? (dist / maxDiag).clamp(0.0, 1.0) : 0.0;
    final angle = math.atan2(fy - ay, fx - ax);

    return CurlGeometry._(
      isIdle: false,
      size: size,
      corner: corner,
      effectiveTouch: a,
      bezierCtrlX: e,
      bezierCtrlY: hPt,
      bezierStartX: c,
      bezierEndX: b,
      bezierStartY: j,
      bezierEndY: k,
      subStartX: d,
      subStartY: i,
      nextRevealPath: nextPath,
      backFoldPath: backPath,
      foldLineStart: d,
      foldLineEnd: i,
      foldAngleRad: angle,
      diagonalRatio: ratio,
    );
  }

  /// 构建相对于翻折中垂线的 4x4 镜像反射矩阵，用于在书页背面渲染透纸微反字
  Float64List buildMirrorMatrix() {
    final dx = corner.dx - effectiveTouch.dx;
    final dy = corner.dy - effectiveTouch.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1e-4) {
      return Float64List.fromList([
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
      ]);
    }

    // 对称轴法向量 n = (nx, ny)，过中点 M = (A + F) / 2
    final nx = dx / len;
    final ny = dy / len;
    final mx = (corner.dx + effectiveTouch.dx) * 0.5;
    final my = (corner.dy + effectiveTouch.dy) * 0.5;

    // 平面镜面反射 H = I - 2 n n^T，加上平移使得 M 点不动：p' = H p + (p0 - H p0)
    final r00 = 1.0 - 2.0 * nx * nx;
    final r01 = -2.0 * nx * ny;
    final r10 = -2.0 * nx * ny;
    final r11 = 1.0 - 2.0 * ny * ny;

    final tx = mx - (r00 * mx + r01 * my);
    final ty = my - (r10 * mx + r11 * my);

    // 列主序 Column-Major Matrix4
    return Float64List.fromList([
      r00, r10, 0, 0,
      r01, r11, 0, 0,
      0,   0,   1, 0,
      tx,  ty,  0, 1,
    ]);
  }

  static ({double ex, double cx, double hy, double jy}) _solveControlPoints(
    double ax,
    double ay,
    double fx,
    double fy,
  ) {
    final mx = (ax + fx) * 0.5;
    final my = (ay + fy) * 0.5;
    final dx = fx - mx;
    final dy = fy - my;

    final safeDx = dx.abs() < 0.5 ? (dx >= 0 ? 0.5 : -0.5) : dx;
    final safeDy = dy.abs() < 0.5 ? (dy >= 0 ? 0.5 : -0.5) : dy;

    final ex = mx - (dy * dy) / safeDx;
    final hy = my - (dx * dx) / safeDy;

    final cx = ex - (fx - ex) * 0.5;
    final jy = hy - (fy - hy) * 0.5;
    return (ex: ex, cx: cx, hy: hy, jy: jy);
  }

  static CurlGeometry _empty(Size size, Offset corner) {
    return CurlGeometry._(
      isIdle: true,
      size: size,
      corner: corner,
      effectiveTouch: corner,
      bezierCtrlX: corner,
      bezierCtrlY: corner,
      bezierStartX: corner,
      bezierEndX: corner,
      bezierStartY: corner,
      bezierEndY: corner,
      subStartX: corner,
      subStartY: corner,
      nextRevealPath: Path(),
      backFoldPath: Path(),
      foldLineStart: corner,
      foldLineEnd: corner,
      foldAngleRad: 0.0,
      diagonalRatio: 0.0,
    );
  }
}
