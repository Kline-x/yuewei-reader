import 'dart:collection';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../engine/page_models.dart';
import '../engine/reader_page_slot.dart';
import 'page_painter.dart';

/// 出版级对开双页书本绘制器（左栏 + 书脊内凹渐变阴影 + 右栏）
class DualPagePainter extends CustomPainter {
  const DualPagePainter({
    required this.leftPage,
    this.rightPage,
    required this.totalPages,
    required this.chapterTitle,
    required this.bookTitle,
    required this.config,
    required this.theme,
    required this.spineWidth,
  });

  final TypedPage leftPage;
  final TypedPage? rightPage;
  final int totalPages;
  final String chapterTitle;
  final String bookTitle;
  final TypographyConfig config;
  final ReaderPaperTheme theme;
  final double spineWidth;

  /// 计算实际画布绘制尺寸（双页总宽 = 单栏宽 * 2 + 中缝书脊宽）
  static Size resolveViewportSize(
    PageRenderItem item,
    TypographyConfig config,
  ) {
    if (!item.isDualPage) {
      return Size(config.viewportWidth, config.viewportHeight);
    }
    return Size(
      config.viewportWidth * 2.0 + item.spineWidth,
      config.viewportHeight,
    );
  }

  /// 将双页左右内容与中缝书脊 1:1 绘制到任意 Canvas（用于实时渲染与 ui.Picture 录制）
  static void drawSpread(
    Canvas canvas,
    Size fullSize, {
    required TypedPage leftPage,
    required TypedPage? rightPage,
    required int totalPages,
    required String chapterTitle,
    required String bookTitle,
    required TypographyConfig config,
    required ReaderPaperTheme theme,
    double? spineWidth,
  }) {
    if (fullSize.width <= 0 || fullSize.height <= 0) return;

    // 1. 铺满整屏纸张背景
    canvas.drawRect(Offset.zero & fullSize, Paint()..color = theme.background);

    final rawSpine =
        spineWidth ?? (fullSize.width - config.viewportWidth * 2.0);
    final effectiveSpine = rawSpine.clamp(0.0, fullSize.width);
    final columnWidth = (config.viewportWidth > 0 &&
            config.viewportWidth * 2.0 + effectiveSpine <= fullSize.width + 0.5)
        ? config.viewportWidth
        : (fullSize.width - effectiveSpine) / 2.0;

    // 2. 绘制左栏 [0, columnWidth]
    final leftRect = Rect.fromLTWH(0.0, 0.0, columnWidth, fullSize.height);
    canvas.save();
    canvas.clipRect(leftRect);
    PagePainter.drawPage(
      canvas,
      Size(columnWidth, fullSize.height),
      page: leftPage,
      totalPages: totalPages,
      chapterTitle: chapterTitle,
      bookTitle: bookTitle,
      config: config,
      theme: theme,
      drawBackground: false,
    );
    canvas.restore();

    // 3. 绘制右栏 [columnWidth + effectiveSpine, fullSize.width]
    final rightStart = columnWidth + effectiveSpine;
    final rightWidth = (fullSize.width - rightStart).clamp(0.0, fullSize.width);
    if (rightPage != null && rightWidth > 0) {
      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(rightStart, 0.0, rightWidth, fullSize.height),
      );
      canvas.translate(rightStart, 0.0);
      PagePainter.drawPage(
        canvas,
        Size(rightWidth, fullSize.height),
        page: rightPage,
        totalPages: totalPages,
        chapterTitle: chapterTitle,
        bookTitle: bookTitle,
        config: config,
        theme: theme,
        drawBackground: false,
      );
      canvas.restore();
    }

    // 4. 绘制中缝书脊内凹渐变阴影与微弱中轴线
    if (effectiveSpine > 0.0) {
      _drawSpineCrease(
        canvas,
        columnWidth: columnWidth,
        spineWidth: effectiveSpine,
        height: fullSize.height,
        theme: theme,
      );
    }
  }

  static void _drawSpineCrease(
    Canvas canvas, {
    required double columnWidth,
    required double spineWidth,
    required double height,
    required ReaderPaperTheme theme,
  }) {
    final spineRect = Rect.fromLTWH(columnWidth, 0.0, spineWidth, height);
    final peakAlpha = theme.isDark ? 0.34 : 0.13;
    final sideAlpha = theme.isDark ? 0.14 : 0.05;

    final shadePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(columnWidth, 0.0),
        Offset(columnWidth + spineWidth, 0.0),
        [
          Colors.transparent,
          Colors.black.withValues(alpha: sideAlpha),
          Colors.black.withValues(alpha: peakAlpha),
          Colors.black.withValues(alpha: sideAlpha),
          Colors.transparent,
        ],
        const [0.0, 0.34, 0.5, 0.66, 1.0],
      );
    canvas.drawRect(spineRect, shadePaint);

    final centerX = columnWidth + spineWidth * 0.5;
    final axisPaint = Paint()
      ..color = Colors.black.withValues(alpha: theme.isDark ? 0.30 : 0.09)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(centerX, 0.0),
      Offset(centerX, height),
      axisPaint,
    );

    if (spineWidth >= 6.0) {
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: theme.isDark ? 0.04 : 0.24)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(centerX + 0.9, 0.0),
        Offset(centerX + 0.9, height),
        highlightPaint,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    drawSpread(
      canvas,
      size,
      leftPage: leftPage,
      rightPage: rightPage,
      totalPages: totalPages,
      chapterTitle: chapterTitle,
      bookTitle: bookTitle,
      config: config,
      theme: theme,
      spineWidth: spineWidth,
    );
  }

  @override
  bool shouldRepaint(covariant DualPagePainter oldDelegate) {
    return oldDelegate.leftPage != leftPage ||
        oldDelegate.rightPage != rightPage ||
        oldDelegate.totalPages != totalPages ||
        oldDelegate.chapterTitle != chapterTitle ||
        oldDelegate.bookTitle != bookTitle ||
        oldDelegate.config != config ||
        oldDelegate.theme.id != theme.id ||
        oldDelegate.spineWidth != spineWidth;
  }
}

/// 双页 ui.Picture 矢量录制 LRU 缓存（供双页模式下跨翻页模式共享零卡顿渲染）
class DualPagePictureCache {
  DualPagePictureCache({this.maxEntries = 10});

  final int maxEntries;
  final LinkedHashMap<String, ui.Picture> _cache = LinkedHashMap();

  ui.Picture obtain(
    PageRenderItem item,
    TypographyConfig config,
    ReaderPaperTheme theme,
    Size size,
  ) {
    final fullKey =
        '${item.cacheKey}_${config.hashCode}_${theme.id}_${size.width.round()}x${size.height.round()}';
    final existing = _cache.remove(fullKey);
    if (existing != null) {
      _cache[fullKey] = existing;
      return existing;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    if (item.isDualPage) {
      DualPagePainter.drawSpread(
        canvas,
        size,
        leftPage: item.page,
        rightPage: item.rightPage,
        totalPages: item.totalPagesInChapter,
        chapterTitle: item.chapterTitle,
        bookTitle: item.bookTitle,
        config: config,
        theme: theme,
        spineWidth: item.spineWidth,
      );
    } else {
      PagePainter.drawPage(
        canvas,
        size,
        page: item.page,
        totalPages: item.totalPagesInChapter,
        chapterTitle: item.chapterTitle,
        bookTitle: item.bookTitle,
        config: config,
        theme: theme,
      );
    }

    final picture = recorder.endRecording();
    _cache[fullKey] = picture;
    while (_cache.length > maxEntries) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey)?.dispose();
    }
    return picture;
  }

  void clear() {
    for (final pic in _cache.values) {
      pic.dispose();
    }
    _cache.clear();
  }
}
