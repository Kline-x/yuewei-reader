import 'package:flutter/material.dart';
import '../engine/page_models.dart';
import '../engine/reader_page_slot.dart';
import '../engine/reader_scroll_layout.dart';

/// 连续滚动视图的布局度量、重排锚定与 clamp 回写保护协调器
class ReaderScrollAnchorTracker {
  static const double prevBtnHeight = 52.0;

  final Map<int, ScrollChapterLayout> layouts = {};
  List<double> blockStartY = const [];
  TypographyConfig? _cachedConfig;
  TextScaler? _cachedScaler;
  bool _cachedHasPrev = false;

  bool didInitialJump = false;
  int handledJumpToken = -1;
  ScrollJumpCommand? pendingJump;
  bool suppressScrollReport = false;
  int programmaticAnimCount = 0;
  bool awaitingRelayoutReanchor = false;
  ({int chapterIndex, int charOffset})? relayoutAnchor;
  ({int chapterIndex, int charOffset, double scrollY})? clampedAnchor;
  int lastAnchorChapterIdx = 0;
  int lastAnchorCharOffset = 0;

  bool get shouldIgnoreScrollEvent =>
      suppressScrollReport ||
      programmaticAnimCount > 0 ||
      awaitingRelayoutReanchor ||
      pendingJump != null;

  bool get cachedHasPrev => _cachedHasPrev;

  void initAnchor(List<ChapterBlock> blocks, int initialCharOffset) {
    if (blocks.isNotEmpty) {
      lastAnchorChapterIdx = blocks.first.chapterIndex;
      lastAnchorCharOffset = initialCharOffset;
    }
  }

  /// 确保所有章块布局最新；若排版配置/缩放/上一章按钮变化则先捕获旧锚点并返回 true 提示重锚定
  bool ensureLayouts({
    required List<ChapterBlock> blocks,
    required TypographyConfig config,
    required TextScaler scaler,
    required bool hasPrevChapter,
    required double? currentScrollOffset,
  }) {
    final configChanged = _cachedConfig != config ||
        _cachedScaler != scaler ||
        (didInitialJump && _cachedHasPrev != hasPrevChapter);
    var needScheduleReanchor = false;
    if (configChanged) {
      if (didInitialJump && pendingJump == null && !awaitingRelayoutReanchor) {
        relayoutAnchor = captureCurrentAnchor(
          blocks: blocks,
          currentScrollOffset: currentScrollOffset,
        );
        awaitingRelayoutReanchor = true;
        needScheduleReanchor = true;
      }
      layouts.clear();
      _cachedConfig = config;
      _cachedScaler = scaler;
    }
    _cachedHasPrev = hasPrevChapter;

    final activeSet = {for (final b in blocks) b.chapterIndex};
    layouts.removeWhere((k, _) => !activeSet.contains(k));

    var cursor = hasPrevChapter ? prevBtnHeight : 0.0;
    final starts = <double>[];
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final showDiv = i > 0;
      final existing = layouts[block.chapterIndex];
      final layout = (existing != null &&
              existing.showDivider == showDiv &&
              existing.itemExtents.length == block.paragraphs.length)
          ? existing
          : (layouts[block.chapterIndex] = ReaderScrollLayout.measureChapter(
              block: block,
              config: config,
              showDivider: showDiv,
              textScaler: scaler,
            ));
      starts.add(cursor);
      cursor += layout.totalHeight;
    }
    blockStartY = starts;
    return needScheduleReanchor;
  }

  ({int chapterIndex, int charOffset}) captureCurrentAnchor({
    required List<ChapterBlock> blocks,
    required double? currentScrollOffset,
  }) {
    if (clampedAnchor != null) {
      return (
        chapterIndex: clampedAnchor!.chapterIndex,
        charOffset: clampedAnchor!.charOffset,
      );
    }
    if (currentScrollOffset != null &&
        blockStartY.isNotEmpty &&
        layouts.isNotEmpty) {
      final resolved = ReaderScrollLayout.resolveAnchorAtScrollY(
        scrollY: currentScrollOffset,
        blocks: blocks,
        blockStartY: blockStartY,
        layouts: layouts,
      );
      if (resolved != null) {
        return (
          chapterIndex: resolved.chapterIndex,
          charOffset: resolved.charOffset,
        );
      }
    }
    return (
      chapterIndex: lastAnchorChapterIdx,
      charOffset: lastAnchorCharOffset,
    );
  }

  /// 校验是否因末页切入被 maxScrollExtent 截断而应禁止回写偏小 charOffset
  bool checkAllowReport({
    required int chapterIndex,
    required int charOffset,
    required double scrollY,
    required bool requestedReport,
  }) {
    var allow = requestedReport;
    final clamped = clampedAnchor;
    if (clamped != null) {
      final movedAway = chapterIndex != clamped.chapterIndex ||
          scrollY < clamped.scrollY - 24.0 ||
          charOffset >= clamped.charOffset;
      if (movedAway) {
        clampedAnchor = null;
      } else {
        allow = false;
      }
    }
    if (clampedAnchor == null) {
      lastAnchorChapterIdx = chapterIndex;
      lastAnchorCharOffset = charOffset;
    }
    return allow;
  }
}
