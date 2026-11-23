import 'package:flutter/material.dart';
import '../engine/page_models.dart';
import '../engine/reader_page_slot.dart';
import '../engine/reader_scroll_layout.dart';
import '../engine/typography_engine.dart';
import 'reader_scroll_chrome.dart';

/// QQ 阅读级「上下连续无缝滚动」视口（精确段高 SliverVariedExtentList + 零误差字符锚定）
class ReaderContinuousScrollView extends StatefulWidget {
  const ReaderContinuousScrollView({
    super.key,
    required this.blocks,
    required this.bookTitle,
    required this.initialCharOffset,
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
  final TypographyConfig config;
  final ReaderPaperTheme theme;
  final bool hasPrevChapter;
  final bool hasNextChapter;
  final VoidCallback onNeedAppendNextChapter;
  final VoidCallback onRequestPrevChapter;
  final VoidCallback onTapCenterMenu;
  final void Function(int chapterIndex, int charOffset) onScrollChapterProgress;

  @override
  State<ReaderContinuousScrollView> createState() =>
      ReaderContinuousScrollViewState();
}

class ReaderContinuousScrollViewState
    extends State<ReaderContinuousScrollView> {
  static const double _prevBtnHeight = 52.0;

  final ScrollController _ctrl = ScrollController();
  final Map<int, ScrollChapterLayout> _layouts = {};
  List<double> _blockStartY = const [];
  TypographyConfig? _cachedConfig;
  TextScaler? _cachedScaler;
  bool _cachedHasPrev = false;

  int _activeChapterIdx = 0;
  String _activeChapterTitle = '';
  double _activeChapterProgress = 0.08;
  int _lastSentCharReportMs = 0;
  bool _didInitialJump = false;

  @override
  void initState() {
    super.initState();
    if (widget.blocks.isNotEmpty) {
      _activeChapterIdx = widget.blocks.first.chapterIndex;
      _activeChapterTitle = widget.blocks.first.chapterTitle;
    }
    _ctrl.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyInitialCharJump());
  }

  @override
  void didUpdateWidget(covariant ReaderContinuousScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.blocks.isNotEmpty) {
      final first = widget.blocks.first;
      final missing =
          !widget.blocks.any((b) => b.chapterIndex == _activeChapterIdx);
      if (_activeChapterTitle.isEmpty || missing) {
        _activeChapterIdx = first.chapterIndex;
        _activeChapterTitle = first.chapterTitle;
        _layouts.clear();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _ensureLayouts(TextScaler scaler) {
    final configChanged =
        _cachedConfig != widget.config || _cachedScaler != scaler;
    if (configChanged) {
      _layouts.clear();
      _cachedConfig = widget.config;
      _cachedScaler = scaler;
    }
    _cachedHasPrev = widget.hasPrevChapter;

    var cursor = widget.hasPrevChapter ? _prevBtnHeight : 0.0;
    final starts = <double>[];
    for (var i = 0; i < widget.blocks.length; i++) {
      final block = widget.blocks[i];
      final showDiv = i > 0;
      final existing = _layouts[block.chapterIndex];
      final layout = (existing != null &&
              existing.showDivider == showDiv &&
              existing.itemExtents.length == block.paragraphs.length)
          ? existing
          : (_layouts[block.chapterIndex] = ReaderScrollLayout.measureChapter(
              block: block,
              config: widget.config,
              showDivider: showDiv,
              textScaler: scaler,
            ));
      starts.add(cursor);
      cursor += layout.totalHeight;
    }
    _blockStartY = starts;
    if (!_didInitialJump && widget.blocks.isNotEmpty && _layouts.isNotEmpty) {
      final first = widget.blocks.first;
      final layout = _layouts[first.chapterIndex];
      if (layout != null) {
        final localY = ReaderScrollLayout.offsetForChar(
          layout,
          first.paragraphs,
          widget.initialCharOffset,
        );
        _activeChapterProgress = ReaderScrollLayout.displayProgressAtLocalY(
          layout,
          localY,
          widget.config,
        );
      }
    }
  }

  Future<void> scrollByStep(bool forward) async {
    if (!_ctrl.hasClients) return;
    final step = widget.config.viewportHeight * 0.82;
    final target = (_ctrl.offset + (forward ? step : -step))
        .clamp(0.0, _ctrl.position.maxScrollExtent);
    await _ctrl.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void jumpToTop() {
    if (_ctrl.hasClients) _ctrl.jumpTo(0.0);
    _syncStateFromScrollY(0.0, report: false);
  }

  void _applyInitialCharJump() {
    if (_didInitialJump || !mounted || !_ctrl.hasClients) return;
    _didInitialJump = true;
    if (widget.blocks.isEmpty || _blockStartY.isEmpty) return;

    final firstBlock = widget.blocks.first;
    final firstLayout = _layouts[firstBlock.chapterIndex];
    if (firstLayout == null) return;

    final localOffset = ReaderScrollLayout.offsetForChar(
      firstLayout,
      firstBlock.paragraphs,
      widget.initialCharOffset,
    );
    final target = (_blockStartY.first + localOffset)
        .clamp(0.0, _ctrl.position.maxScrollExtent);
    if (target > 1.0) {
      _ctrl.jumpTo(target);
    }
    _syncStateFromScrollY(_ctrl.offset, report: false);
  }

  void _handleScroll() {
    if (!_ctrl.hasClients) return;
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
    if (!mounted || widget.blocks.isEmpty || _blockStartY.isEmpty) return;
    var activePos = 0;
    for (var i = 1; i < _blockStartY.length; i++) {
      if (scrollY >= _blockStartY[i]) {
        activePos = i;
      } else {
        break;
      }
    }

    final block = widget.blocks[activePos];
    final layout = _layouts[block.chapterIndex];
    if (layout == null) return;
    final localY =
        (scrollY - _blockStartY[activePos]).clamp(0.0, layout.totalHeight);
    final progress = ReaderScrollLayout.displayProgressAtLocalY(
      layout,
      localY,
      widget.config,
    );

    if (block.chapterIndex != _activeChapterIdx ||
        (progress - _activeChapterProgress).abs() >= 0.008) {
      setState(() {
        _activeChapterIdx = block.chapterIndex;
        _activeChapterTitle = block.chapterTitle;
        _activeChapterProgress = progress;
      });
    }
    if (report) {
      final charOffset = ReaderScrollLayout.charOffsetAtLocalY(
        layout,
        block.paragraphs,
        localY,
      );
      widget.onScrollChapterProgress(block.chapterIndex, charOffset);
    }
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
    final style =
        TypographyEngine.bodyStyle(widget.config, widget.theme.textColor);
    final metaStyle = TextStyle(
      fontSize: 11.5,
      color: widget.theme.secondaryText,
      fontWeight: FontWeight.w500,
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: _handleTap,
      child: Container(
        color: widget.theme.background,
        child: Stack(
          children: [
            CustomScrollView(
              controller: _ctrl,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.only(top: topPad + 10.0),
                  sliver: SliverToBoxAdapter(
                    child: _cachedHasPrev
                        ? SizedBox(
                            height: _prevBtnHeight,
                            child: Center(
                              child: TextButton(
                                onPressed: widget.onRequestPrevChapter,
                                child: Text(
                                  '点击加载上一章',
                                  style: metaStyle.copyWith(
                                      color: widget.theme.accent),
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                for (final block in widget.blocks)
                  ...ReaderScrollMetrics.buildChapterBlockSlivers(
                    block: block,
                    layout: _layouts[block.chapterIndex]!,
                    config: widget.config,
                    theme: widget.theme,
                    bodyStyle: style,
                  ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    widget.config.horizontalPadding,
                    16.0,
                    widget.config.horizontalPadding,
                    widget.config.bottomPadding + 56.0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: Text(
                        widget.hasNextChapter ? '上滑继续无缝阅读下一章' : '本章已是全书最后一章',
                        style: metaStyle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ReaderScrollTopHeader(
              topPadding: topPad,
              horizontalPadding: widget.config.horizontalPadding,
              chapterTitle: _activeChapterTitle,
              theme: widget.theme,
            ),
            ReaderScrollBottomFooter(
              bottomPadding: widget.config.bottomPadding,
              horizontalPadding: widget.config.horizontalPadding,
              bookTitle: widget.bookTitle,
              chapterProgress: _activeChapterProgress,
              theme: widget.theme,
            ),
          ],
        ),
      ),
    );
  }
}
