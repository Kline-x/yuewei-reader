import 'package:flutter/material.dart';

/// 阅读器手势物理参数与仿真卷角数学计算工具（纯函数零状态）
class ReaderTurnGestureMath {
  const ReaderTurnGestureMath._();

  /// 根据起手触点纵坐标决定仿真卷页锚角（上半屏右上角，下半屏右下角）
  static Offset resolveCurlCorner(Size size, Offset startPos) {
    return startPos.dy < size.height * 0.42
        ? Offset(size.width, 0.0)
        : Offset(size.width, size.height);
  }

  /// 计算拖拽过程中仿真卷角的有效触摸控制点（中部起手柔化垂直偏移）
  static Offset resolveDragTouch({
    required Size size,
    required Offset startPos,
    required Offset currentPos,
    required Offset corner,
  }) {
    final w = size.width;
    final h = size.height;
    final dx = currentPos.dx - startPos.dx;
    final dy = currentPos.dy - startPos.dy;
    final isMiddleBand = startPos.dy >= h * 0.35 && startPos.dy <= h * 0.65;
    final touchX = currentPos.dx.clamp(-w * 0.4, w - 2.0);
    final touchY = isMiddleBand
        ? (h - 22.0 - (dx.abs() * 0.14 - dy * 0.28).clamp(0.0, h * 0.42))
        : (corner.dy <= 1.0
            ? currentPos.dy.clamp(4.0, h * 0.92)
            : currentPos.dy.clamp(h * 0.08, h - 4.0));
    return Offset(touchX, touchY);
  }

  /// 按滑行比例与脱手瞬时速度判定是否提交翻页
  static bool shouldCommitDrag({
    required int direction,
    required double progress,
    required double velocityX,
  }) {
    if (direction > 0) return progress > 0.16 || velocityX < -320.0;
    if (direction < 0) return progress > 0.16 || velocityX > 320.0;
    return false;
  }

  /// 动态结算翻页余程动画时长（150ms ~ 310ms）
  static int computeSettleDurationMs({
    required double progress,
    required bool commit,
  }) {
    final remaining = commit ? (1.0 - progress) : progress;
    return (150.0 + 160.0 * remaining).round().clamp(150, 310);
  }

  static Offset clickCurlStart(Size size) =>
      Offset(size.width - 14.0, size.height - 22.0);

  static Offset clickCurlEnd(Size size) =>
      Offset(-size.width * 0.85, size.height - 18.0);

  static Offset dragCommitCurlEnd(Size size, Offset corner) =>
      Offset(-size.width * 0.85, corner.dy);
}
