import 'dart:async';
import 'package:flutter/material.dart';
import '../engine/page_models.dart';
import '../engine/reader_page_slot.dart';
import '../engine/reader_scroll_layout.dart';
import '../engine/typography_engine.dart';
import 'reader_scroll_anchor_tracker.dart';
import 'reader_scroll_chrome.dart';

/// QQ 阅读级「上下连续无缝滚动」视口（精确段高 SliverVariedExtentList + 零误差字符锚定）
class ReaderContinuousScrollView extends StatefulWidget {
  const ReaderContinuousScrollView({
    super.key,
    required this.blocks,
    required this.bookTitle,
    required this.initialCharOffset,
    this.scrollJumpCommand = const ScrollJumpCommand(token: 0, chapterIndex: 0),
    required this.config,
    required this.theme,
    required this.hasPrevChapter,
    required this.hasNextChapter,
    required this.onNeedAppendNextChapter,
    required this.onRequestPrevChapter,
    required this.onTapCenterMenu,
    required this.onScrollChapterProgress,
  });

  final List<ChapterBlock> blocks;
  final String bookTitle;
  final int initialCharOffset;
  final ScrollJumpCommand scrollJumpCommand;
  final TypographyConfig config;
  final ReaderPaperTheme theme;
  final bool hasPrevChapter, hasNextChapter;
  final VoidCallback onNeedAppendNextChapter, onRequestPrevChapter, onTapCenterMenu;
  final void Function(int chapterIndex, int charOffset) onScrollChapterProgress;

  @override
  State<ReaderContinuousScrollView> createState() =>
      ReaderContinuousScrollViewState();
}

class ReaderContinuousScrollViewState extends State<ReaderContinuousScrollView> {
  final ScrollController _ctrl = ScrollController();
  final ReaderScrollAnchorTracker _tracker = ReaderScrollAnchorTracker();

  int _activeChapterIdx = 0;
  String _activeChapterTitle = '';
  double _activeChapterProgress = 0.08;
  int _lastSentCharReportMs = 0;

  @override
  void initState() {
    super.initState();
    if (widget.blocks.isNotEmpty) {
      _activeChapterIdx = widget.blocks.first.chapterIndex;
      _activeChapterTitle = widget.blocks.first.chapterTitle;
    }
    _tracker.initAnchor(widget.blocks, widget.initialCharOffset);
    _ctrl.addListener(_handleScroll);
    final cmd = widget.scrollJumpCommand;
    _tracker.pendingJump = cmd.landOnEnd
        ? cmd
        : ScrollJumpCommand(
            token: cmd.token,
            chapterIndex: widget.blocks.isNotEmpty
                ? widget.blocks.first.chapterIndex
                : cmd.chapterIndex,
            charOffset: widget.initialCharOffset,
          );
    WidgetsBinding.instance.addPostFrameCallback((_) => _flushPendingJump());
  }

  @override
  void didUpdateWidget(covariant ReaderContinuousScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.blocks.isNotEmpty) {
      final first = widget.blocks.first;
      final missing = !widget.blocks.any((b) => b.chapterIndex == _activeChapterIdx);
      if (_activeChapterTitle.isEmpty || missing) {
        _activeChapterIdx = first.chapterIndex;
        _activeChapterTitle = first.chapterTitle;
        _tracker.layouts.clear();
      }
    }
    if (widget.scrollJumpCommand.token != _tracker.handledJumpToken) {
      _tracker.pendingJump = widget.scrollJumpCommand;
      _tracker.awaitingRelayoutReanchor = false;
      _tracker.relayoutAnchor = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _flushPendingJump());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _ensureLayouts(TextScaler scaler) {
    final needReanchor = _tracker.ensureLayouts(
      blocks: widget.blocks,
      config: widget.config,
      scaler: scaler,
      hasPrevChapter: widget.hasPrevChapter,
      currentScrollOffset: _ctrl.hasClients ? _ctrl.offset : null,
    );
    if (needReanchor) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyRelayoutReanchor());
    }
    if (!_tracker.didInitialJump && widget.blocks.isNotEmpty) {
      final first = widget.blocks.first;
      final layout = _tracker.layouts[first.chapterIndex];
      if (layout != null) {
        final localY = widget.scrollJumpCommand.landOnEnd
            ? ReaderScrollLayout.computeLandOnEndLocalY(layout, widget.config)
            : ReaderScrollLayout.offsetForChar(layout, first.paragraphs, widget.initialCharOffset);
        _activeChapterProgress =
            ReaderScrollLayout.displayProgressAtLocalY(layout, localY, widget.config);
      }
    }
  }

  Future<void> scrollByStep(bool forward) async {
    if (!_ctrl.hasClients) return;
    final step = widget.config.viewportHeight * 0.82;
    final target = (_ctrl.offset + (forward ? step : -step))
        .clamp(0.0, _ctrl.position.maxScrollExtent);
    await _ctrl.animateTo(target, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  /// 平滑或瞬时定位到指定章节与字符偏移（供书签、搜书、TTS 跟随与切章复用，零重建闪烁）
  void scrollToLocation(
    int chapterIndex,
    int charOffset, {
    bool landOnEnd = false,
    bool animate = false,
  }) {
    if (!mounted || !_ctrl.hasClients || _tracker.blockStartY.isEmpty) {
      _tracker.pendingJump = ScrollJumpCommand(
        token: widget.scrollJumpCommand.token,
        chapterIndex: chapterIndex,
        charOffset: charOffset,
        landOnEnd: landOnEnd,
        animate: animate,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => _flushPendingJump());
      return;
    }
    _tracker.handledJumpToken = widget.scrollJumpCommand.token;
    _tracker.pendingJump = null;
    _performJump(chapterIndex: chapterIndex, charOffset: charOffset, landOnEnd: landOnEnd, animate: animate);
  }

  void _flushPendingJump() {
    final cmd = _tracker.pendingJump;
    if (cmd == null || !mounted || !_ctrl.hasClients) return;
    if (widget.blocks.isEmpty || _tracker.blockStartY.isEmpty) return;
    _tracker.pendingJump = null;
    _tracker.handledJumpToken = cmd.token;
    _tracker.didInitialJump = true;
    _performJump(chapterIndex: cmd.chapterIndex, charOffset: cmd.charOffset, landOnEnd: cmd.landOnEnd, animate: cmd.animate);
  }

  void _applyRelayoutReanchor() {
    final anchor = _tracker.relayoutAnchor;
    _tracker.relayoutAnchor = null;
    try {
      if (!mounted || !_ctrl.hasClients || anchor == null || _tracker.pendingJump != null) return;
      _performJump(chapterIndex: anchor.chapterIndex, charOffset: anchor.charOffset, landOnEnd: false, animate: false);
    } finally {
      _tracker.awaitingRelayoutReanchor = false;
    }
  }

  void _performJump({
    required int chapterIndex,
    required int charOffset,
    required bool landOnEnd,
    required bool animate,
  }) {
    final rawTargetY = ReaderScrollLayout.computeTargetYForLocation(
      blocks: widget.blocks,
      blockStartY: _tracker.blockStartY,
      layouts: _tracker.layouts,
      config: widget.config,
      chapterIndex: chapterIndex,
      charOffset: charOffset,
      landOnEnd: landOnEnd,
    );
    if (rawTargetY == null) return;
    final maxExtent = _ctrl.position.maxScrollExtent;
    final clampedY = rawTargetY.clamp(0.0, maxExtent);
    final wasClamped = !landOnEnd && rawTargetY > maxExtent + 1.0;
    _tracker.clampedAnchor = wasClamped
        ? (chapterIndex: chapterIndex, charOffset: charOffset, scrollY: clampedY)
        : null;
    _tracker.lastAnchorChapterIdx = chapterIndex;
    _tracker.lastAnchorCharOffset = charOffset;

    _tracker.suppressScrollReport = true;
    try {
      final dist = (_ctrl.offset - clampedY).abs();
      if (animate && dist > 1.0 && dist < widget.config.viewportHeight * 3.0) {
        _tracker.programmaticAnimCount++;
        unawaited(
          _ctrl
              .animateTo(clampedY, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic)
              .catchError((_) {})
              .whenComplete(() {
            if (_tracker.programmaticAnimCount > 0) _tracker.programmaticAnimCount--;
            if (mounted && _ctrl.hasClients) _syncStateFromScrollY(_ctrl.offset, report: false);
          }),
        );
        _syncStateFromScrollY(clampedY, report: false);
      } else {
        if (dist > 0.5) _ctrl.jumpTo(clampedY);
        _syncStateFromScrollY(_ctrl.offset, report: false);
      }
    } finally {
      _tracker.suppressScrollReport = false;
    }
  }

  void _handleScroll() {
    if (!_ctrl.hasClients || _tracker.shouldIgnoreScrollEvent) return;
    final pos = _ctrl.position;
    if (pos.maxScrollExtent - pos.pixels < widget.config.viewportHeight * 1.5) {
      widget.onNeedAppendNextChapter();
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final shouldReport = nowMs - _lastSentCharReportMs >= 120;
    if (shouldReport) _lastSentCharReportMs = nowMs;
    _syncStateFromScrollY(pos.pixels, report: shouldReport);
  }

  void _syncStateFromScrollY(double scrollY, {required bool report}) {
    if (!mounted || widget.blocks.isEmpty || _tracker.blockStartY.isEmpty) return;
    final anchor = ReaderScrollLayout.resolveAnchorAtScrollY(
      scrollY: scrollY,
      blocks: widget.blocks,
      blockStartY: _tracker.blockStartY,
      layouts: _tracker.layouts,
    );
    if (anchor == null) return;
    final block = widget.blocks[anchor.blockPos];
    final layout = _tracker.layouts[block.chapterIndex]!;
    final progress = ReaderScrollLayout.displayProgressAtLocalY(layout, anchor.localY, widget.config);
    final chapterChanged = block.chapterIndex != _activeChapterIdx;
    if (chapterChanged || (progress - _activeChapterProgress).abs() >= 0.008) {
      setState(() {
        _activeChapterIdx = block.chapterIndex;
        _activeChapterTitle = block.chapterTitle;
        _activeChapterProgress = progress;
      });
    }
    final allowReport = _tracker.checkAllowReport(
      chapterIndex: block.chapterIndex,
      charOffset: anchor.charOffset,
      scrollY: scrollY,
      requestedReport: report || chapterChanged,
    );
    if (allowReport) widget.onScrollChapterProgress(block.chapterIndex, anchor.charOffset);
  }

  void _handleTap(TapUpDetails details) {
    final h = widget.config.viewportHeight;
    final y = details.localPosition.dy;
    if (y < h * 0.25) {
      scrollByStep(false);
    } else if (y > h * 0.75) {
      scrollByStep(true);
    } else {
      widget.onTapCenterMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensureLayouts(MediaQuery.textScalerOf(context));
    final topPad = widget.config.topPadding;
    final style = TypographyEngine.bodyStyle(widget.config, widget.theme.textColor);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: _handleTap,
      child: Container(
        color: widget.theme.background,
        child: Stack(children: [
          CustomScrollView(
            controller: _ctrl,
            slivers: [
              ReaderScrollMetrics.buildPrevChapterSliver(
                topPadding: topPad,
                hasPrevChapter: _tracker.cachedHasPrev,
                buttonHeight: ReaderScrollAnchorTracker.prevBtnHeight,
                theme: widget.theme,
                onRequestPrevChapter: widget.onRequestPrevChapter,
              ),
              for (final block in widget.blocks)
                ...ReaderScrollMetrics.buildChapterBlockSlivers(
                  block: block,
                  layout: _tracker.layouts[block.chapterIndex]!,
                  config: widget.config,
                  theme: widget.theme,
                  bodyStyle: style,
                ),
              ReaderScrollMetrics.buildBottomHintSliver(
                config: widget.config,
                theme: widget.theme,
                hasNextChapter: widget.hasNextChapter,
              ),
            ],
          ),
          ReaderScrollTopHeader(topPadding: topPad, horizontalPadding: widget.config.horizontalPadding, chapterTitle: _activeChapterTitle, theme: widget.theme),
          ReaderScrollBottomFooter(bottomPadding: widget.config.bottomPadding, horizontalPadding: widget.config.horizontalPadding, bookTitle: widget.bookTitle, chapterProgress: _activeChapterProgress, theme: widget.theme),
        ]),
      ),
    );
  }
}
