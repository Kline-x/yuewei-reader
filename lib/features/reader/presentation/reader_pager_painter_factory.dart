import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../engine/curl_geometry.dart';
import '../engine/page_models.dart';
import '../engine/reader_page_slot.dart';
import 'curl_turn_painter.dart';
import 'page_picture_cache.dart';
import 'slide_cover_painter.dart';

/// 翻页画布 Painter 装配工厂（按当前翻页模式与矢量缓存构建仿真/覆盖/平移/无动画绘制器）
class ReaderPagerPainterFactory {
  const ReaderPagerPainterFactory._();

  static CustomPainter build({
    required PageTurnMode turnMode,
    required PagePictureCache picCache,
    required PageRenderItem currentItem,
    required PageRenderItem? prevItem,
    required PageRenderItem? nextItem,
    required TypographyConfig config,
    required ReaderPaperTheme theme,
    required Size size,
    required int activeDirection,
    required double linearProgress,
    required Offset curlTouch,
    required Offset curlCorner,
  }) {
    final curPic = picCache.obtain(currentItem, config, theme, size);
    final targetSlot = activeDirection > 0
        ? nextItem
        : (activeDirection < 0 ? prevItem : null);
    final ui.Picture? targetPic = targetSlot == null
        ? null
        : picCache.obtain(targetSlot, config, theme, size);
    if (turnMode == PageTurnMode.curl) {
      final curlGeom = (activeDirection > 0 && targetPic != null)
          ? CurlGeometry.compute(
              size: size,
              touch: curlTouch,
              corner: curlCorner,
            )
          : null;
      return CurlTurnPainter(
        currentPicture: curPic,
        targetPicture: targetPic,
        geometry: curlGeom,
        theme: theme,
        isTurningPrev: activeDirection < 0,
        progress: linearProgress,
      );
    }
    return SlideCoverPainter(
      turnMode: turnMode,
      currentPicture: curPic,
      targetPicture: targetPic,
      direction: activeDirection,
      progress: linearProgress,
      theme: theme,
    );
  }
}
