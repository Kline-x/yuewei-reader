import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../engine/curl_geometry.dart';
import '../engine/page_models.dart';
import '../engine/reader_page_slot.dart';
import 'curl_turn_painter.dart';
import 'dual_page_painter.dart';
import 'page_picture_cache.dart';
import 'slide_cover_painter.dart';

/// 翻页画布 Painter 装配工厂（支持单页/双页矢量录制，并在双页自动平滑降级仿真卷页为覆盖动效）
class ReaderPagerPainterFactory {
  const ReaderPagerPainterFactory._();

  static final DualPagePictureCache _fallbackDualCache = DualPagePictureCache();

  /// 计算当前实际生效的翻页动画模式（双页模式下 curl 平滑降级为 cover）
  static PageTurnMode resolveEffectiveTurnMode(
    PageTurnMode turnMode,
    bool isDualPage,
  ) {
    if (isDualPage && turnMode == PageTurnMode.curl) {
      return PageTurnMode.cover;
    }
    return turnMode;
  }

  static CustomPainter build({
    required PageTurnMode turnMode,
    required PagePictureCache picCache,
    DualPagePictureCache? dualPicCache,
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
    final effectiveMode =
        resolveEffectiveTurnMode(turnMode, currentItem.isDualPage);
    ui.Picture obtainPic(PageRenderItem item) {
      if (item.isDualPage) {
        return (dualPicCache ?? _fallbackDualCache)
            .obtain(item, config, theme, size);
      }
      return picCache.obtain(item, config, theme, size);
    }

    final curPic = obtainPic(currentItem);
    final targetSlot = activeDirection > 0
        ? nextItem
        : (activeDirection < 0 ? prevItem : null);
    final ui.Picture? targetPic =
        targetSlot == null ? null : obtainPic(targetSlot);
    if (effectiveMode == PageTurnMode.curl) {
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
      turnMode: effectiveMode,
      currentPicture: curPic,
      targetPicture: targetPic,
      direction: activeDirection,
      progress: linearProgress,
      theme: theme,
    );
  }
}
