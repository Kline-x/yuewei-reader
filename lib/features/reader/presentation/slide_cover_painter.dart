import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../engine/page_models.dart';

/// 覆盖 / 平移 / 无动画 高帧率矢量画布渲染器
/// - 覆盖模式：下层微缩放景深 + 线性消散暗幕，上层带双层物理书页阴影
/// - 平移模式：双页无缝并排推进，接缝处带柔和过渡影
class SlideCoverPainter extends CustomPainter {
  const SlideCoverPainter({
    required this.turnMode,
    required this.currentPicture,
    required this.targetPicture,
    required this.direction, // -1=上一页, 0=静止, 1=下一页
    required this.progress,
    required this.theme,
  });

  final PageTurnMode turnMode;
  final ui.Picture currentPicture;
  final ui.Picture? targetPicture;
  final int direction;
  final double progress;
  final ReaderPaperTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.clamp(0.0, 1.0);
    if (turnMode == PageTurnMode.none ||
        targetPicture == null ||
        direction == 0 ||
        p <= 0.001) {
      canvas.drawPicture(currentPicture);
      return;
    }

    if (turnMode == PageTurnMode.cover) {
      _paintCover(canvas, size, p);
    } else {
      _paintSlide(canvas, size, p);
    }
  }

  void _paintCover(Canvas canvas, Size size, double p) {
    final w = size.width;
    final h = size.height;

    if (direction > 0) {
      // 去下一页：下层目标页带微缩放景深 + 渐渐消散暗幕；上层当前页向左抽离
      _drawDepthTarget(canvas, size, targetPicture!, p);

      final slideX = -w * p;
      final fade = (1.0 - p * 0.45).clamp(0.2, 1.0);
      canvas.save();
      canvas.translate(slideX, 0);
      canvas.drawPicture(currentPicture);
      _drawDualRightShadow(canvas, w, h, fade);
      canvas.restore();
    } else {
      // 去上一页：下层当前页渐暗微退，上层前一页从左平滑覆盖回来
      _drawDepthTarget(canvas, size, currentPicture, 1.0 - p);

      final slideX = -w * (1.0 - p);
      final fade = (1.0 - p * 0.55).clamp(0.2, 1.0);
      canvas.save();
      canvas.translate(slideX, 0);
      canvas.drawPicture(targetPicture!);
      _drawDualRightShadow(canvas, w, h, fade);
      canvas.restore();
    }
  }

  void _drawDepthTarget(
    Canvas canvas,
    Size size,
    ui.Picture pic,
    double revealProgress,
  ) {
    final scale = 0.985 + 0.015 * revealProgress;
    final cx = size.width * 0.5;
    final cy = size.height * 0.5;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scale, scale);
    canvas.translate(-cx, -cy);
    canvas.drawPicture(pic);
    canvas.restore();

    final dimAlpha = (theme.isDark ? 0.24 : 0.11) * (1.0 - revealProgress);
    if (dimAlpha > 0.002) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.black.withValues(alpha: dimAlpha),
      );
    }
  }

  void _drawDualRightShadow(Canvas canvas, double w, double h, double fade) {
    final baseAlpha = theme.isDark ? 0.44 : 0.24;
    // 宽层柔漫射投影（28dp）+ 贴边锐影（6dp）
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(w, 0),
        Offset(w + 28.0, 0),
        [
          Colors.black.withValues(alpha: baseAlpha * fade),
          Colors.black.withValues(alpha: baseAlpha * 0.42 * fade),
          Colors.transparent,
        ],
        const [0.0, 0.22, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(w, 0, 28.0, h), paint);
  }

  void _paintSlide(Canvas canvas, Size size, double p) {
    final w = size.width;
    final h = size.height;
    final currDx = direction > 0 ? -w * p : w * p;
    final targetDx = direction > 0 ? w * (1.0 - p) : -w * (1.0 - p);

    canvas.save();
    canvas.translate(currDx, 0);
    canvas.drawPicture(currentPicture);
    canvas.restore();

    canvas.save();
    canvas.translate(targetDx, 0);
    canvas.drawPicture(targetPicture!);
    canvas.restore();

    // 接缝柔和微影增强书页分界质感
    final seamX = direction > 0 ? targetDx : currDx;
    final seamPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(seamX - 6.0, 0),
        Offset(seamX + 6.0, 0),
        [
          Colors.transparent,
          Colors.black.withValues(alpha: theme.isDark ? 0.28 : 0.10),
          Colors.transparent,
        ],
        const [0.0, 0.5, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(seamX - 6.0, 0, 12.0, h), seamPaint);
  }

  @override
  bool shouldRepaint(covariant SlideCoverPainter oldDelegate) {
    return oldDelegate.turnMode != turnMode ||
        oldDelegate.currentPicture != currentPicture ||
        oldDelegate.targetPicture != targetPicture ||
        oldDelegate.direction != direction ||
        oldDelegate.progress != progress ||
        oldDelegate.theme.id != theme.id;
  }
}
