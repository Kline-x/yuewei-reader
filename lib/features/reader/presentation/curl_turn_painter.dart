import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../engine/curl_geometry.dart';
import '../engine/page_models.dart';

/// QQ 阅读级 3D 光学仿真卷页画布：
/// 第1层：当前页基底 -> 第2层：裁剪暴露的目标页+折痕页背阴影 -> 第3层：对称镜像透字纸背+立体圆柱高光。
class CurlTurnPainter extends CustomPainter {
  const CurlTurnPainter({
    required this.currentPicture,
    required this.targetPicture,
    required this.geometry,
    required this.theme,
    required this.isTurningPrev,
    required this.progress,
  });

  final ui.Picture currentPicture;
  final ui.Picture? targetPicture;
  final CurlGeometry? geometry;
  final ReaderPaperTheme theme;
  final bool isTurningPrev;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 静止态或无目标页时仅绘制当前页
    if (targetPicture == null ||
        (isTurningPrev && progress <= 0.002) ||
        (!isTurningPrev && (geometry == null || geometry!.isIdle))) {
      canvas.drawPicture(currentPicture);
      return;
    }

    // 2. 翻上一页时：上页从左平滑归位覆盖，附带双层柔和立体边影（仿真实体书左页合拢感）
    if (isTurningPrev) {
      _paintPrevReturn(canvas, size);
      return;
    }

    final g = geometry!;
    // 第1层：当前页铺底，抗锯齿接缝零透黑线
    canvas.drawPicture(currentPicture);

    // 第2层：裁剪至被揭开的暴露区域并绘制目标页 + 柔和折痕投影
    canvas.save();
    canvas.clipPath(g.nextRevealPath);
    canvas.drawPicture(targetPicture!);
    _paintUnderShadow(canvas, size, g);
    canvas.restore();

    // 第3层：绘制翻起书页背面（调和纸背色 + 15% 镜像透纸反字 + 立体圆柱高光弧线）
    _paintBackFold(canvas, g);
  }

  void _paintPrevReturn(Canvas canvas, Size size) {
    canvas.drawPicture(currentPicture);
    final p = progress.clamp(0.0, 1.0);
    final dx = -size.width * (1.0 - p);
    final edgeFade = (1.0 - p * 0.6).clamp(0.15, 1.0);

    canvas.save();
    canvas.translate(dx, 0);
    canvas.drawPicture(targetPicture!);

    // 归位书页右侧装订级立体阴影
    final shadowRect = Rect.fromLTWH(size.width, 0, 26.0, size.height);
    final shadowPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width, 0),
        Offset(size.width + 26.0, 0),
        [
          Colors.black.withValues(alpha: (theme.isDark ? 0.42 : 0.22) * edgeFade),
          Colors.black.withValues(alpha: (theme.isDark ? 0.14 : 0.07) * edgeFade),
          Colors.transparent,
        ],
        const [0.0, 0.32, 1.0],
      );
    canvas.drawRect(shadowRect, shadowPaint);
    canvas.restore();
  }

  void _paintUnderShadow(Canvas canvas, Size size, CurlGeometry g) {
    final fade = (1.0 - g.diagonalRatio * 0.55).clamp(0.18, 1.0);
    final shadowOrigin = Offset(
      (g.foldLineStart.dx + g.foldLineEnd.dx) * 0.5,
      (g.foldLineStart.dy + g.foldLineEnd.dy) * 0.5,
    );
    final dir = g.corner - g.effectiveTouch;
    final len = dir.distance;
    if (len < 1.0) return;
    final unit = dir / len;
    // 在折脊负半侧极短距离内快速归零，消除 C/J 外弧底缘阴影拖尾
    final backBleed = (len * 0.038).clamp(3.0, 10.0);
    final shadowDepth = (len * 0.18).clamp(14.0, 42.0);
    final startPt = shadowOrigin - unit * backBleed;
    final endPt = shadowOrigin + unit * shadowDepth;
    final peakStop = (backBleed / (backBleed + shadowDepth)).clamp(0.08, 0.25);

    final maxAlpha = (theme.isDark ? 0.44 : 0.22) * fade;
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        startPt,
        endPt,
        [
          Colors.transparent,
          Colors.black.withValues(alpha: maxAlpha),
          Colors.black.withValues(alpha: maxAlpha * 0.32),
          Colors.transparent,
        ],
        [0.0, peakStop, peakStop + (1.0 - peakStop) * 0.42, 1.0],
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _paintBackFold(Canvas canvas, CurlGeometry g) {
    canvas.save();
    canvas.clipPath(g.backFoldPath);

    // 纸背调和底色（浅纸微深营造厚度，深色纸面微亮呈现书页反光质感）
    final backColor = theme.isDark
        ? Color.lerp(theme.background, Colors.white, 0.075)!
        : Color.lerp(theme.background, const Color(0xFFD6CEC0), 0.14)!;
    canvas.drawColor(backColor, BlendMode.srcOver);

    // 对称镜像透纸反字（QQ 阅读标志性纸感细节）
    canvas.save();
    canvas.transform(g.buildMirrorMatrix());
    canvas.saveLayer(
      Offset.zero & g.size,
      Paint()
        ..color = Color.fromRGBO(
          255,
          255,
          255,
          theme.isDark ? 0.12 : 0.16,
        ),
    );
    canvas.drawPicture(currentPicture);
    canvas.restore();
    canvas.restore();

    // 折起书页立体圆柱光照渐变：折脊微亮 -> 中段柔和弧光 -> 边角微暗
    final spineMid = Offset(
      (g.foldLineStart.dx + g.foldLineEnd.dx) * 0.5,
      (g.foldLineStart.dy + g.foldLineEnd.dy) * 0.5,
    );
    final dirToTouch = g.effectiveTouch - spineMid;
    if (dirToTouch.distance > 1.0) {
      final cylinderPaint = Paint()
        ..shader = ui.Gradient.linear(
          spineMid,
          g.effectiveTouch,
          [
            Colors.black.withValues(alpha: theme.isDark ? 0.22 : 0.11),
            Colors.white.withValues(alpha: theme.isDark ? 0.08 : 0.28),
            Colors.black.withValues(alpha: theme.isDark ? 0.14 : 0.06),
          ],
          const [0.0, 0.35, 1.0],
        );
      canvas.drawRect(Offset.zero & g.size, cylinderPaint);
    }

    canvas.restore();

    // 沿 D-I 折脊绘制极细边缘投影线勾勒纸页弧度轮廓
    final creasePaint = Paint()
      ..color = Colors.black.withValues(alpha: theme.isDark ? 0.24 : 0.08)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(g.foldLineStart, g.foldLineEnd, creasePaint);
  }

  @override
  bool shouldRepaint(covariant CurlTurnPainter oldDelegate) {
    return oldDelegate.currentPicture != currentPicture ||
        oldDelegate.targetPicture != targetPicture ||
        oldDelegate.geometry?.effectiveTouch != geometry?.effectiveTouch ||
        oldDelegate.geometry?.corner != geometry?.corner ||
        oldDelegate.isTurningPrev != isTurningPrev ||
        oldDelegate.progress != progress ||
        oldDelegate.theme.id != theme.id;
  }
}
