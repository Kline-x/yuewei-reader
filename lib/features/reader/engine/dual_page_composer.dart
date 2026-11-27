import 'dart:math' as math;
import 'dart:ui' as ui show DisplayFeature, DisplayFeatureType;
import 'package:flutter/widgets.dart';
import 'page_models.dart';
import 'reader_page_slot.dart';

/// 平板/折叠屏双页书本排版几何描述
@immutable
class DualPageGeometry {
  const DualPageGeometry({
    required this.isDualPage,
    required this.spineWidth,
    required this.columnWidth,
    required this.viewportWidth,
    required this.viewportHeight,
  });

  final bool isDualPage;
  final double spineWidth;
  final double columnWidth;
  final double viewportWidth;
  final double viewportHeight;

  double get spreadWidth =>
      isDualPage ? (columnWidth * 2.0 + spineWidth) : columnWidth;

  @override
  bool operator ==(Object other) {
    return other is DualPageGeometry &&
        other.isDualPage == isDualPage &&
        other.spineWidth == spineWidth &&
        other.columnWidth == columnWidth &&
        other.viewportWidth == viewportWidth &&
        other.viewportHeight == viewportHeight;
  }

  @override
  int get hashCode => Object.hash(
        isDualPage,
        spineWidth,
        columnWidth,
        viewportWidth,
        viewportHeight,
      );
}

/// 书本对开双页配对切片（奇数页章末时 right 为 null）
@immutable
class SpreadPagePair {
  const SpreadPagePair({
    required this.left,
    this.right,
  });

  final TypedPage left;
  final TypedPage? right;
}

/// 自适应双页几何解析、折叠屏铰链避让与字符锚点偶数对齐协调器
class DualPageComposer {
  const DualPageComposer._();

  static const double autoThresholdWidth = 680.0;
  static const double forcedDualMinWidth = 520.0;
  static const double defaultSpineWidth = 28.0;

  /// 解析当前视口几何：决定单/双页、避让竖向折叠屏铰链并给出单栏排版宽度
  static DualPageGeometry resolveDualPageGeometry({
    required BoxConstraints constraints,
    required ReaderLayoutMode layoutMode,
    required PageTurnMode turnMode,
    required List<ui.DisplayFeature> displayFeatures,
  }) {
    final maxWidth = constraints.maxWidth;
    final maxHeight = constraints.maxHeight;
    final safeW = maxWidth.isFinite && maxWidth > 0 ? maxWidth : 0.0;
    final safeH = maxHeight.isFinite && maxHeight > 0 ? maxHeight : 0.0;

    if (turnMode == PageTurnMode.scroll ||
        layoutMode == ReaderLayoutMode.single ||
        safeW <= 0.0 ||
        safeH <= 0.0) {
      return DualPageGeometry(
        isDualPage: false,
        spineWidth: 0.0,
        columnWidth: safeW,
        viewportWidth: safeW,
        viewportHeight: safeH,
      );
    }

    final shouldEnableDual =
        (layoutMode == ReaderLayoutMode.dual && safeW >= forcedDualMinWidth) ||
            (layoutMode == ReaderLayoutMode.auto && safeW >= autoThresholdWidth);

    if (!shouldEnableDual) {
      return DualPageGeometry(
        isDualPage: false,
        spineWidth: 0.0,
        columnWidth: safeW,
        viewportWidth: safeW,
        viewportHeight: safeH,
      );
    }

    final hinge = _findVerticalHinge(displayFeatures, safeW, safeH);
    final rawSpine = hinge == null
        ? defaultSpineWidth
        : math.max(defaultSpineWidth, hinge.bounds.width + 16.0);
    final spineWidth = rawSpine
        .clamp(defaultSpineWidth, math.max(defaultSpineWidth, safeW - 240.0))
        .toDouble();
    final columnWidth = (safeW - spineWidth) / 2.0;

    return DualPageGeometry(
      isDualPage: true,
      spineWidth: spineWidth,
      columnWidth: columnWidth,
      viewportWidth: safeW,
      viewportHeight: safeH,
    );
  }

  static ui.DisplayFeature? _findVerticalHinge(
    List<ui.DisplayFeature> features,
    double maxWidth,
    double maxHeight,
  ) {
    ui.DisplayFeature? best;
    for (final feature in features) {
      if (feature.type == ui.DisplayFeatureType.cutout) continue;
      final b = feature.bounds;
      final isVerticalHinge =
          b.left > 0 && b.right < maxWidth && b.height >= maxHeight * 0.6;
      if (!isVerticalHinge) continue;
      if (best == null || b.height > best.bounds.height) {
        best = feature;
      }
    }
    return best;
  }

  /// 规范化左页下标：双页模式下恒取偶数（pageIdx & ~1），单页模式原样 clamp
  static int normalizeLeftPageIndex(
    int pageIndex,
    int totalPages, {
    required bool isDualPage,
  }) {
    if (totalPages <= 0) return 0;
    final clamped = pageIndex.clamp(0, totalPages - 1);
    return isDualPage ? (clamped & ~1) : clamped;
  }

  /// 计算上一章落地末屏时的起始页索引（双页奇数 N -> N-1，偶数 N -> N-2）
  static int lastSpreadStartIndex(int totalPages, {required bool isDualPage}) {
    if (totalPages <= 0) return 0;
    final lastIdx = totalPages - 1;
    return isDualPage ? (lastIdx & ~1) : lastIdx;
  }

  /// 按步进 2 对整章分页结果进行对开页配对（总页数为奇数时末页 right 为 null）
  static List<SpreadPagePair> pairPages(List<TypedPage> pages) {
    if (pages.isEmpty) return const [];
    final pairs = <SpreadPagePair>[];
    for (var i = 0; i < pages.length; i += 2) {
      pairs.add(
        SpreadPagePair(
          left: pages[i],
          right: i + 1 < pages.length ? pages[i + 1] : null,
        ),
      );
    }
    return pairs;
  }

  /// 根据字符偏移量计算重排后的对齐起始页索引（确保单双页切换与旋屏零漂移）
  static int resolveAlignedPageForCharOffset(
    List<TypedPage> pages,
    int charOffset, {
    required bool isDualPage,
  }) {
    if (pages.isEmpty) return 0;
    final rawIdx = findRawPageIndex(pages, charOffset);
    return normalizeLeftPageIndex(rawIdx, pages.length, isDualPage: isDualPage);
  }

  /// 二分查找字符偏移量所属原始页索引
  static int findRawPageIndex(List<TypedPage> pages, int charOffset) {
    if (pages.isEmpty || charOffset <= 0) return 0;
    if (charOffset >= pages.last.charEnd) return pages.length - 1;
    var lo = 0;
    var hi = pages.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >>> 1;
      final p = pages[mid];
      if (charOffset < p.charStart) {
        hi = mid - 1;
      } else if (charOffset >= p.charEnd) {
        lo = mid + 1;
      } else {
        return mid;
      }
    }
    return lo.clamp(0, pages.length - 1);
  }

  static PageRenderItem buildSlotItem({
    required int chapterIndex,
    required String chapterTitle,
    required List<TypedPage> pages,
    required int startIndex,
    required String bookTitle,
    required bool isDualPage,
    required double spineWidth,
    TypographyConfig? config,
  }) {
    final safeStart =
        normalizeLeftPageIndex(startIndex, pages.length, isDualPage: isDualPage);
    final right = isDualPage && (safeStart + 1 < pages.length)
        ? pages[safeStart + 1]
        : null;
    return PageRenderItem(
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      page: pages[safeStart],
      rightPage: right,
      totalPagesInChapter: pages.length,
      bookTitle: bookTitle,
      isDualPage: isDualPage,
      spineWidth: isDualPage ? spineWidth : 0.0,
      config: config,
    );
  }

  /// 构造单/双页三连槽位（含跨章无缝衔接）
  static ({PageRenderItem? prev, PageRenderItem? current, PageRenderItem? next})
      buildSpreadSlots({
    required int chapterIndex,
    required int pageIndex,
    required String bookTitle,
    required String currentTitle,
    required List<TypedPage> curPages,
    List<TypedPage>? prevChPages,
    String? prevChTitle,
    List<TypedPage>? nextChPages,
    String? nextChTitle,
    required bool isDualPage,
    required double spineWidth,
    TypographyConfig? config,
  }) {
    final step = isDualPage ? 2 : 1;
    final safeStart = normalizeLeftPageIndex(
      pageIndex,
      curPages.length,
      isDualPage: isDualPage,
    );
    PageRenderItem make(int ch, String t, List<TypedPage> p, int s) =>
        buildSlotItem(
          chapterIndex: ch,
          chapterTitle: t,
          pages: p,
          startIndex: s,
          bookTitle: bookTitle,
          isDualPage: isDualPage,
          spineWidth: spineWidth,
          config: config,
        );

    final current = make(chapterIndex, currentTitle, curPages, safeStart);
    PageRenderItem? prev;
    if (safeStart - step >= 0) {
      prev = make(chapterIndex, currentTitle, curPages, safeStart - step);
    } else if (chapterIndex > 0 && prevChPages != null && prevChPages.isNotEmpty) {
      prev = make(
        chapterIndex - 1,
        prevChTitle ?? '正文阅读',
        prevChPages,
        lastSpreadStartIndex(prevChPages.length, isDualPage: isDualPage),
      );
    }

    PageRenderItem? next;
    if (safeStart + step < curPages.length) {
      next = make(chapterIndex, currentTitle, curPages, safeStart + step);
    } else if (nextChPages != null && nextChPages.isNotEmpty) {
      next = make(chapterIndex + 1, nextChTitle ?? '正文阅读', nextChPages, 0);
    }
    return (prev: prev, current: current, next: next);
  }
}
