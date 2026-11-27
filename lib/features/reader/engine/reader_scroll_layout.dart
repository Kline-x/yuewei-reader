import 'package:flutter/material.dart';
import 'page_models.dart';
import 'reader_page_slot.dart';
import 'typography_engine.dart';

/// 单章「上下」滚动精确像素度量结果（供 SliverVariedExtentList 与字符锚点双向 O(1)/O(N) 映射）
class ScrollChapterLayout {
  const ScrollChapterLayout({
    required this.chapterIndex,
    required this.showDivider,
    required this.headerHeight,
    required this.paragraphGap,
    required this.itemExtents,
    required this.paraTopOffsets,
    required this.totalHeight,
  });

  final int chapterIndex;
  final bool showDivider;
  final double headerHeight;
  final double paragraphGap;
  final List<double> itemExtents;
  final List<double> paraTopOffsets;
  final double totalHeight;
}

/// 「上下」滚动模式精确布局测量器与字符/偏移双向映射器
class ReaderScrollLayout {
  const ReaderScrollLayout._();

  /// 使用与页面渲染完全一致的 TextStyle 与排版宽度精确测量单章头部与全部段落高
  static ScrollChapterLayout measureChapter({
    required ChapterBlock block,
    required TypographyConfig config,
    required bool showDivider,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final dividerH = showDivider ? 36.0 : 0.0;
    final titleTp = TextPainter(
      text: TextSpan(
        text: block.chapterTitle,
        style: TextStyle(
          fontSize: config.fontSize * 1.32,
          fontWeight: FontWeight.w800,
          height: 1.32,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: config.contentWidth);
    final headerHeight = 32.0 + dividerH + titleTp.height.ceilToDouble() + 2.0;
    titleTp.dispose();

    final bodyStyle = TypographyEngine.bodyStyle(config, Colors.black);
    final bodyTp = TextPainter(
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    );

    final itemExtents = <double>[];
    final paraTopOffsets = <double>[];
    var cursorY = 0.0;

    for (final para in block.paragraphs) {
      paraTopOffsets.add(cursorY);
      bodyTp.text = TextSpan(text: para, style: bodyStyle);
      bodyTp.layout(maxWidth: config.contentWidth);
      final extent = bodyTp.height.ceilToDouble() + config.paragraphGap + 1.0;
      itemExtents.add(extent);
      cursorY += extent;
    }
    bodyTp.dispose();

    return ScrollChapterLayout(
      chapterIndex: block.chapterIndex,
      showDivider: showDivider,
      headerHeight: headerHeight,
      paragraphGap: config.paragraphGap,
      itemExtents: itemExtents,
      paraTopOffsets: paraTopOffsets,
      totalHeight: headerHeight + cursorY,
    );
  }

  /// 将章节内字符偏移转换为相对于本章顶部的精准滚动局部纵坐标
  static double offsetForChar(
    ScrollChapterLayout layout,
    List<String> paragraphs,
    int charOffset,
  ) {
    if (charOffset <= 0 ||
        paragraphs.isEmpty ||
        layout.paraTopOffsets.isEmpty) {
      return 0.0;
    }
    var acc = 0;
    for (var i = 0; i < paragraphs.length; i++) {
      final pLen = paragraphs[i].length + 1;
      if (charOffset < acc + pLen) {
        final frac = ((charOffset - acc) / pLen).clamp(0.0, 0.99);
        final textH =
            (layout.itemExtents[i] - layout.paragraphGap).clamp(0.0, 1e6);
        return layout.headerHeight + layout.paraTopOffsets[i] + textH * frac;
      }
      acc += pLen;
    }
    return (layout.totalHeight - 24.0).clamp(0.0, layout.totalHeight);
  }

  /// 根据相对于本章顶部的滚动局部纵坐标反算最贴合的字符锚点偏移
  static int charOffsetAtLocalY(
    ScrollChapterLayout layout,
    List<String> paragraphs,
    double localY,
  ) {
    if (localY <= layout.headerHeight ||
        paragraphs.isEmpty ||
        layout.paraTopOffsets.isEmpty) {
      return 0;
    }
    final paraY = localY - layout.headerHeight;
    var acc = 0;
    for (var i = 0; i < paragraphs.length; i++) {
      final top = layout.paraTopOffsets[i];
      final ext = layout.itemExtents[i];
      if (paraY < top + ext) {
        final frac = ((paraY - top) / ext).clamp(0.0, 1.0);
        return acc + (paragraphs[i].length * frac).round();
      }
      acc += paragraphs[i].length + 1;
    }
    return acc > 0 ? acc - 1 : 0;
  }

  /// 计算用于底栏展示的章内阅读百分比（0.0 ~ 1.0，首屏对齐约 1 页比例、章尾达 100%）
  static double displayProgressAtLocalY(
    ScrollChapterLayout layout,
    double localY,
    TypographyConfig config,
  ) {
    if (layout.totalHeight <= 0.0) return 0.0;
    final readableH = (config.viewportHeight -
            config.topPadding -
            config.bottomPadding)
        .clamp(120.0, config.viewportHeight);
    return ((localY + readableH * 0.85) / layout.totalHeight).clamp(0.0, 1.0);
  }

  /// 计算「加载上一章并落至章末」的精准章内局部纵坐标（始终位于本章末尾且不越界到下一章）
  static double computeLandOnEndLocalY(
    ScrollChapterLayout layout,
    TypographyConfig config,
  ) {
    if (layout.totalHeight <= 0.0) return 0.0;
    final readableH = (config.viewportHeight -
            config.topPadding -
            config.bottomPadding)
        .clamp(120.0, config.viewportHeight);
    final maxLocal = (layout.totalHeight - 1.0).clamp(0.0, layout.totalHeight);
    return (layout.totalHeight - readableH * 0.85).clamp(0.0, maxLocal);
  }

  /// 根据当前全局 scrollY 反查活跃章块索引、章内局部纵坐标与字符锚点
  static ({int blockPos, int chapterIndex, double localY, int charOffset})?
      resolveAnchorAtScrollY({
    required double scrollY,
    required List<ChapterBlock> blocks,
    required List<double> blockStartY,
    required Map<int, ScrollChapterLayout> layouts,
  }) {
    if (blocks.isEmpty || blockStartY.isEmpty) return null;
    final limit =
        blocks.length < blockStartY.length ? blocks.length : blockStartY.length;
    var activePos = 0;
    for (var i = 1; i < limit; i++) {
      if (scrollY >= blockStartY[i]) {
        activePos = i;
      } else {
        break;
      }
    }
    final block = blocks[activePos];
    final layout = layouts[block.chapterIndex];
    if (layout == null) return null;
    final localY =
        (scrollY - blockStartY[activePos]).clamp(0.0, layout.totalHeight);
    final charOffset = charOffsetAtLocalY(layout, block.paragraphs, localY);
    return (
      blockPos: activePos,
      chapterIndex: block.chapterIndex,
      localY: localY,
      charOffset: charOffset,
    );
  }

  /// 计算目标章节与字符偏移（或章末）在当前连续滚动列表中的原始像素纵坐标
  static double? computeTargetYForLocation({
    required List<ChapterBlock> blocks,
    required List<double> blockStartY,
    required Map<int, ScrollChapterLayout> layouts,
    required TypographyConfig config,
    required int chapterIndex,
    required int charOffset,
    bool landOnEnd = false,
  }) {
    final limit =
        blocks.length < blockStartY.length ? blocks.length : blockStartY.length;
    var targetPos = -1;
    for (var i = 0; i < limit; i++) {
      if (blocks[i].chapterIndex == chapterIndex) {
        targetPos = i;
        break;
      }
    }
    if (targetPos < 0) return null;
    final block = blocks[targetPos];
    final layout = layouts[block.chapterIndex];
    if (layout == null) return null;
    final localY = landOnEnd
        ? computeLandOnEndLocalY(layout, config)
        : offsetForChar(layout, block.paragraphs, charOffset);
    return blockStartY[targetPos] + localY;
  }
}
