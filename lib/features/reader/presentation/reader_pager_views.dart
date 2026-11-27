import 'package:flutter/material.dart';
import '../engine/page_models.dart';
import '../engine/reader_page_slot.dart';
import '../engine/reader_turn_gesture_math.dart';
import 'dual_page_painter.dart';
import 'page_picture_cache.dart';
import 'reader_continuous_scroll_view.dart';
import 'reader_pager_painter_factory.dart';

/// QQ 阅读级统一五模式翻页视口物理控制器（仿真 / 覆盖 / 平移 / 上下 / 无，≤ 350 行）
class ReaderPagerViews extends StatefulWidget {
  const ReaderPagerViews({
    super.key,
    required this.turnMode,
    required this.bookTitle,
    required this.initialCharOffset,
    this.scrollJumpCommand = const ScrollJumpCommand(token: 0, chapterIndex: 0),
    required this.currentItem,
    required this.prevItem,
    required this.nextItem,
    required this.scrollBlocks,
    required this.config,
    required this.theme,
    required this.hasPrevChapter,
    required this.hasNextChapter,
    required this.onCommitNext,
    required this.onCommitPrev,
    required this.onTapCenterMenu,
    required this.onNeedAppendNextChapter,
    required this.onRequestPrevChapter,
    required this.onScrollChapterProgress,
  });

  final PageTurnMode turnMode;
  final String bookTitle;
  final int initialCharOffset;
  final ScrollJumpCommand scrollJumpCommand;
  final PageRenderItem currentItem;
  final PageRenderItem? prevItem, nextItem;
  final List<ChapterBlock> scrollBlocks;
  final TypographyConfig config;
  final ReaderPaperTheme theme;
  final bool hasPrevChapter, hasNextChapter;
  final VoidCallback onCommitNext, onCommitPrev, onTapCenterMenu;
  final VoidCallback onNeedAppendNextChapter, onRequestPrevChapter;
  final void Function(int chapterIndex, int charOffset) onScrollChapterProgress;

  @override
  State<ReaderPagerViews> createState() => ReaderPagerViewsState();
}

class ReaderPagerViewsState extends State<ReaderPagerViews>
    with SingleTickerProviderStateMixin {
  final PagePictureCache _picCache = PagePictureCache();
  final DualPagePictureCache _dualPicCache = DualPagePictureCache();
  final GlobalKey<ReaderContinuousScrollViewState> _scrollKey = GlobalKey();
  late final AnimationController _animCtrl;

  int _activeDirection = 0;
  bool _pendingCommit = false;
  double _linearProgress = 0.0, _animFromProgress = 0.0, _animToProgress = 0.0;
  Offset _dragStartPos = Offset.zero, _curlCorner = Offset.zero;
  Offset _curlTouch = Offset.zero, _animFromTouch = Offset.zero, _animToTouch = Offset.zero;

  Size get _viewportSize =>
      DualPagePainter.resolveViewportSize(widget.currentItem, widget.config);

  PageTurnMode get _effectiveTurnMode =>
      ReaderPagerPainterFactory.resolveEffectiveTurnMode(
        widget.turnMode,
        widget.currentItem.isDualPage,
      );

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250))
      ..addListener(_onAnimTick)
      ..addStatusListener((s) { if (s == AnimationStatus.completed) _finalizeCompletedTurn(); });
  }

  @override
  void didUpdateWidget(covariant ReaderPagerViews oldWidget) {
    super.didUpdateWidget(oldWidget);
    final dualChanged = oldWidget.currentItem.isDualPage != widget.currentItem.isDualPage ||
        oldWidget.currentItem.spineWidth != widget.currentItem.spineWidth;
    if (oldWidget.turnMode != widget.turnMode || dualChanged) {
      _resetGestureState();
      if (widget.turnMode == PageTurnMode.scroll) clearPictureCache();
    }
    if (oldWidget.theme.id != widget.theme.id || oldWidget.config != widget.config || dualChanged) {
      clearPictureCache();
    }
  }

  @override
  void dispose() { _animCtrl.dispose(); clearPictureCache(); super.dispose(); }
  void clearPictureCache() { _picCache.clear(); _dualPicCache.clear(); }

  void scrollToLocation(int ch, int off, {bool landOnEnd = false, bool animate = false}) =>
      _scrollKey.currentState?.scrollToLocation(ch, off, landOnEnd: landOnEnd, animate: animate);

  void turnNextAnimated() => _triggerAnimatedTurn(true);
  void turnPrevAnimated() => _triggerAnimatedTurn(false);

  void _triggerAnimatedTurn(bool forward) {
    if (widget.turnMode == PageTurnMode.scroll) {
      _scrollKey.currentState?.scrollByStep(forward);
      return;
    }
    // 先冲刷进行中动画再读取最新槽位，避免快速连点捕获过期槽位多提交
    if (_flushActiveAnimation()) return;
    final target = forward ? widget.nextItem : widget.prevItem;
    final hasMoreChapter = forward ? widget.hasNextChapter : widget.hasPrevChapter;
    final commit = forward ? widget.onCommitNext : widget.onCommitPrev;
    if (target == null) {
      if (hasMoreChapter) commit();
      return;
    }
    if (_effectiveTurnMode == PageTurnMode.none) {
      commit();
      return;
    }
    final size = _viewportSize;
    final fromTouch =
        forward ? ReaderTurnGestureMath.clickCurlStart(size) : Offset.zero;
    final toTouch =
        forward ? ReaderTurnGestureMath.clickCurlEnd(size) : Offset.zero;
    setState(() {
      _activeDirection = forward ? 1 : -1;
      _pendingCommit = true;
      _curlCorner = forward ? Offset(size.width, size.height) : Offset.zero;
      _animFromTouch = fromTouch;
      _animToTouch = toTouch;
      _curlTouch = fromTouch;
      _animFromProgress = 0.0;
      _animToProgress = 1.0;
      _linearProgress = 0.0;
    });
    _animCtrl.duration = Duration(milliseconds: forward ? 270 : 250);
    _animCtrl.forward(from: 0.0);
  }

  void _onAnimTick() {
    final t = Curves.easeOutCubic.transform(_animCtrl.value);
    setState(() {
      _linearProgress =
          _animFromProgress + (_animToProgress - _animFromProgress) * t;
      if (_effectiveTurnMode == PageTurnMode.curl && _activeDirection == 1) {
        _curlTouch = Offset.lerp(_animFromTouch, _animToTouch, t)!;
      }
    });
  }

  bool _flushActiveAnimation() {
    if (_animCtrl.isAnimating) {
      _animCtrl.stop();
      return _finalizeCompletedTurn();
    }
    if (_activeDirection != 0) _resetGestureState();
    return false;
  }

  bool _finalizeCompletedTurn() {
    final dir = _activeDirection;
    final commit = _pendingCommit;
    _resetGestureState();
    if (commit && dir != 0) {
      dir > 0 ? widget.onCommitNext() : widget.onCommitPrev();
      return true;
    }
    return false;
  }

  void _resetGestureState() {
    _animCtrl.reset();
    if (!mounted) return;
    setState(() {
      _activeDirection = 0;
      _pendingCommit = false;
      _linearProgress = 0.0;
      _curlTouch = Offset.zero;
    });
  }

  void _handleTapUp(TapUpDetails details) {
    final w = _viewportSize.width;
    final x = details.localPosition.dx;
    if (x < w * 0.30) {
      turnPrevAnimated();
    } else if (x > w * 0.70) {
      turnNextAnimated();
    } else {
      _flushActiveAnimation();
      widget.onTapCenterMenu();
    }
  }

  void _onPanStart(DragStartDetails details) {
    _flushActiveAnimation();
    _dragStartPos = details.localPosition;
    _curlCorner =
        ReaderTurnGestureMath.resolveCurlCorner(_viewportSize, _dragStartPos);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final size = _viewportSize;
    if (size.width <= 0 || size.height <= 0) return;
    final dx = details.localPosition.dx - _dragStartPos.dx;
    var dir = _activeDirection;
    if (dir == 0) {
      if (dx < -4.0 && (widget.nextItem != null || widget.hasNextChapter)) {
        dir = 1;
      } else if (dx > 4.0 && (widget.prevItem != null || widget.hasPrevChapter)) {
        dir = -1;
      }
      if (dir == 0) return;
    }
    final directed = dir > 0 ? -dx : dx;
    final progress = (directed / size.width).clamp(0.0, 1.0);
    setState(() {
      _activeDirection = dir;
      _linearProgress = progress;
      if (_effectiveTurnMode == PageTurnMode.curl &&
          dir == 1 &&
          widget.nextItem != null) {
        _curlTouch = directed <= 0.0
            ? _curlCorner
            : ReaderTurnGestureMath.resolveDragTouch(
                size: size,
                startPos: _dragStartPos,
                currentPos: details.localPosition,
                corner: _curlCorner,
              );
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_activeDirection == 0) return;
    final size = _viewportSize;
    final dir = _activeDirection;
    final targetSlot = dir > 0 ? widget.nextItem : widget.prevItem;
    final commit = ReaderTurnGestureMath.shouldCommitDrag(
      direction: dir,
      progress: _linearProgress,
      velocityX: details.velocity.pixelsPerSecond.dx,
    );
    if (_effectiveTurnMode == PageTurnMode.none || targetSlot == null) {
      _resetGestureState();
      if (commit) dir > 0 ? widget.onCommitNext() : widget.onCommitPrev();
      return;
    }
    _animCtrl.duration = Duration(
      milliseconds: ReaderTurnGestureMath.computeSettleDurationMs(
        progress: _linearProgress,
        commit: commit,
      ),
    );
    _pendingCommit = commit;
    _animFromProgress = _linearProgress;
    _animToProgress = commit ? 1.0 : 0.0;
    _animFromTouch = _curlTouch;
    _animToTouch = commit
        ? ReaderTurnGestureMath.dragCommitCurlEnd(size, _curlCorner)
        : _curlCorner;
    _animCtrl.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.turnMode == PageTurnMode.scroll) {
      return ReaderContinuousScrollView(
        key: _scrollKey,
        blocks: widget.scrollBlocks,
        bookTitle: widget.bookTitle,
        initialCharOffset: widget.initialCharOffset,
        scrollJumpCommand: widget.scrollJumpCommand,
        config: widget.config,
        theme: widget.theme,
        hasPrevChapter: widget.hasPrevChapter,
        hasNextChapter: widget.hasNextChapter,
        onNeedAppendNextChapter: widget.onNeedAppendNextChapter,
        onRequestPrevChapter: widget.onRequestPrevChapter,
        onTapCenterMenu: widget.onTapCenterMenu,
        onScrollChapterProgress: widget.onScrollChapterProgress,
      );
    }
    final size = _viewportSize;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: _handleTapUp, onPanStart: _onPanStart, onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd, onPanCancel: () => _onPanEnd(DragEndDetails()),
      child: RepaintBoundary(
        child: CustomPaint(
          size: size,
          painter: ReaderPagerPainterFactory.build(
            turnMode: widget.turnMode, picCache: _picCache, dualPicCache: _dualPicCache,
            currentItem: widget.currentItem, prevItem: widget.prevItem, nextItem: widget.nextItem,
            config: widget.config, theme: widget.theme, size: size,
            activeDirection: _activeDirection, linearProgress: _linearProgress,
            curlTouch: _curlTouch, curlCorner: _curlCorner,
          ),
        ),
      ),
    );
  }
}
