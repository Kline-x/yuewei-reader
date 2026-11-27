import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../engine/dual_page_composer.dart';
import '../engine/page_models.dart';
import '../engine/reader_chapter_loader.dart';
import '../engine/reader_page_slot.dart';
import '../engine/reader_slide_window.dart';
import 'reader_session_bootstrap.dart';

export '../engine/dual_page_composer.dart';

part 'reader_session_scroll_ops.dart';

/// 阅读器章节加载、三章滑窗分页与跨模式进度同步控制器
class ReaderSessionController extends ChangeNotifier {
  ReaderSessionController({
    required this.bookId,
    required this.ref,
    required this.db,
    this.onNeedResetScroll,
    DateTime Function()? clock,
  }) : _readingTimer = ForegroundReadingTimer(clock: clock);

  final String bookId;
  final WidgetRef ref;
  final AppDatabase db;
  final VoidCallback? onNeedResetScroll;

  final ReaderChapterLoader loader = ReaderChapterLoader();
  final ReaderSlideWindow window = ReaderSlideWindow();
  final ForegroundReadingTimer _readingTimer;

  Book? book;
  List<Chapter> chapters = const [];
  List<String> paragraphs = const [];
  List<ChapterBlock> scrollBlocks = const [];

  int chapterIndex = 0;
  int pageIndex = 0;
  int charAnchorOffset = 0;
  int jumpSequence = 0;
  int _scrollJumpToken = 0;
  ScrollJumpCommand scrollJumpCommand =
      const ScrollJumpCommand(token: 0, chapterIndex: 0);

  int _loadEpoch = 0;
  bool loading = true;
  String? errorMsg;
  bool isDualPage = false;
  double spineWidth = 0.0;
  bool _jumpToLastPageOnLoad = false;
  bool _appendingScrollNext = false;
  bool _disposed = false;

  String get currentChapterTitle =>
      (chapterIndex >= 0 && chapterIndex < chapters.length)
          ? chapters[chapterIndex].title
          : '正文阅读';

  List<String> get chapterTitles => chapters.map((e) => e.title).toList();

  PageRenderItem? get currentRenderItem => buildSlots().current;

  void pauseReadingTimer() => _readingTimer.pause();

  void resumeReadingTimer() {
    if (!_disposed) _readingTimer.resume();
  }

  @override
  void dispose() {
    _disposed = true;
    final sec = _readingTimer.finishAndCollectSeconds();
    if (sec > 0) db.recordReadingSeconds(bookId, sec);
    super.dispose();
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> bootstrap(int? initialChapterIndex) async {
    final loadedBook = await db.getBookById(bookId);
    var loadedChapters = await db.getChaptersByBook(bookId);
    if (_disposed) return;
    if (loadedBook != null && loadedBook.hasUnreadUpdate) {
      unawaited(db.setBookUnreadUpdate(bookId, false));
    }
    var syncedBook = loadedBook?.hasUnreadUpdate == true
        ? loadedBook!.copyWith(hasUnreadUpdate: false)
        : loadedBook;

    if (ReaderSessionBootstrap.needsRemoteTocRepair(
      syncedBook,
      loadedChapters,
    )) {
      book = syncedBook;
      loading = true;
      errorMsg = null;
      _emit();
      final repaired = await ReaderSessionBootstrap.tryRepairMissingToc(
        ref: ref,
        db: db,
        book: syncedBook!,
      );
      if (_disposed) return;
      if (repaired != null) {
        syncedBook = repaired.book;
        loadedChapters = repaired.chapters;
      }
    }

    if (syncedBook == null || loadedChapters.isEmpty) {
      book = syncedBook;
      chapters = loadedChapters;
      loading = false;
      errorMsg = '暂无目录数据，请返回书籍详情刷新后重试';
      _emit();
      return;
    }

    final startIdx = (initialChapterIndex ?? syncedBook.currentChapterIndex)
        .clamp(0, loadedChapters.length - 1);
    final startOffset =
        initialChapterIndex != null ? 0 : syncedBook.currentCharOffset;

    book = syncedBook;
    chapters = loadedChapters;
    chapterIndex = startIdx;
    charAnchorOffset = startOffset;
    _emit();
    await loadChapter(startIdx, charOffset: startOffset);
  }

  Future<void> retryCurrent() async {
    if (chapters.isEmpty) {
      await bootstrap(null);
    } else {
      await loadChapter(chapterIndex);
    }
  }

  Future<void> loadChapter(
    int index, {
    int charOffset = 0,
    bool landOnLastPage = false,
  }) async {
    if (index < 0 || index >= chapters.length || book == null || _disposed) {
      return;
    }
    final reqId = ++_loadEpoch;
    var loaded = loader.peekMemory(bookId, index);
    if (loaded == null || loaded.isEmpty) {
      chapterIndex = index;
      paragraphs = const [];
      scrollBlocks = const [];
      loading = true;
      errorMsg = null;
      _jumpToLastPageOnLoad = landOnLastPage;
      charAnchorOffset = charOffset;
      _emit();
      try {
        loaded = await loader.loadChapterParagraphs(
          ref: ref,
          book: book!,
          chapter: chapters[index],
        );
      } catch (_) {
        if (_disposed || reqId != _loadEpoch) return;
        loading = false;
        errorMsg = '网络异常或当前书源解析失败，请重试或换源';
        _emit();
        return;
      }
      if (_disposed || reqId != _loadEpoch) return;
      if (loaded.isEmpty) {
        loading = false;
        errorMsg = '本章正文为空，可尝试切换书源或稍后重试';
        _emit();
        return;
      }
    }
    _applyLoadedChapter(
      index: index,
      chapterTitle: chapters[index].title,
      loadedParas: loaded,
      charOffset: charOffset,
      landOnLastPage: landOnLastPage,
    );
    _prefetchNeighbors(index, reqId);
  }

  /// 精确跳转至指定章节与字符偏移（同章瞬时重算页码/滚动锚点，跨章自动加载）
  Future<void> jumpToLocation(
    int targetChapterIndex,
    int targetCharOffset, {
    bool animateScroll = false,
    bool emitScrollCommand = true,
  }) async {
    if (_disposed || chapters.isEmpty) return;
    final targetIdx = targetChapterIndex.clamp(0, chapters.length - 1);
    final safeOffset = targetCharOffset < 0 ? 0 : targetCharOffset;
    jumpSequence++;
    if (targetIdx == chapterIndex && !loading && errorMsg == null && paragraphs.isNotEmpty) {
      charAnchorOffset = safeOffset;
      final cfg = window.lastConfig;
      if (cfg != null) {
        final pages = window.ensurePaginated(
          chapterIndex: targetIdx, chapterTitle: currentChapterTitle, paragraphs: paragraphs, config: cfg,
        );
        pageIndex = DualPageComposer.normalizeLeftPageIndex(
          window.findPageByCharOffset(pages, safeOffset), pages.length, isDualPage: isDualPage,
        );
      }
      _ensureScrollBlocksAligned(targetIdx);
      if (emitScrollCommand) {
        scrollJumpCommand = ScrollJumpCommand(
          token: ++_scrollJumpToken, chapterIndex: targetIdx, charOffset: safeOffset, animate: animateScroll,
        );
      }
      _emit();
      _persistProgress(targetIdx, currentChapterTitle, safeOffset);
      return;
    }
    await loadChapter(targetIdx, charOffset: safeOffset);
  }

  void _ensureScrollBlocksAligned(int targetIdx) {
    if (scrollBlocks.isEmpty || !scrollBlocks.any((b) => b.chapterIndex == targetIdx)) {
      scrollBlocks = window.buildInitialScrollBlocks(
        chapterIndex: targetIdx, chapterTitle: currentChapterTitle, paragraphs: paragraphs,
        bookId: bookId, chapters: chapters, loader: loader,
      );
    }
  }

  void syncForBuild(TypographyConfig config, PageTurnMode turnMode, {bool isDualPage = false, double spineWidth = 0.0}) {
    if (loading || errorMsg != null || paragraphs.isEmpty) return;
    this.isDualPage = isDualPage;
    this.spineWidth = spineWidth;
    final cfgChanged = window.syncWindow(
      config: config, activeChapterIndex: chapterIndex, bookId: bookId,
      chapters: chapters, loader: loader, isDualPage: isDualPage,
    );
    final curPages = window.ensurePaginated(
      chapterIndex: chapterIndex, chapterTitle: currentChapterTitle, paragraphs: paragraphs, config: config,
    );
    pageIndex = window.resolveSyncedPageIndex(
      curPages, currentPageIndex: pageIndex, charAnchorOffset: charAnchorOffset,
      needReanchor: cfgChanged, landOnLastPage: _jumpToLastPageOnLoad, isDualPage: isDualPage,
    );
    if (_jumpToLastPageOnLoad && curPages.isNotEmpty) charAnchorOffset = curPages[pageIndex].charStart;
    _jumpToLastPageOnLoad = false;
    if (turnMode != PageTurnMode.scroll && (scrollBlocks.isEmpty || scrollBlocks.first.chapterIndex != chapterIndex)) {
      _ensureScrollBlocksAligned(chapterIndex);
    }
  }

  ({PageRenderItem? prev, PageRenderItem? current, PageRenderItem? next})
      buildSlots({bool? isDualPage, double? spineWidth}) => window.buildSlots(
            chapterIndex: chapterIndex, pageIndex: pageIndex, bookTitle: book?.title ?? '',
            chapters: chapters, isDualPage: isDualPage ?? this.isDualPage, spineWidth: spineWidth ?? this.spineWidth,
          );

  void commitNext() {
    final next = window.turnNext(
      chapterIndex: chapterIndex, pageIndex: pageIndex, totalChapters: chapters.length, isDualPage: isDualPage,
    );
    if (next != null) _commitTurnStep(next.chapterIndex, next.pageIndex, next.crossedChapter, false);
  }

  void commitPrev() {
    final prev = window.turnPrev(chapterIndex: chapterIndex, pageIndex: pageIndex, isDualPage: isDualPage);
    if (prev != null) _commitTurnStep(prev.chapterIndex, prev.pageIndex, prev.crossedChapter, prev.landOnLastPage);
  }

  void _commitTurnStep(int targetCh, int targetPg, bool crossed, bool landLast) {
    if (crossed) {
      loadChapter(targetCh, landOnLastPage: landLast);
    } else {
      final cur = window.pagesOf(chapterIndex) ?? const [];
      if (cur.isNotEmpty) _applyPageIndex(targetPg, cur);
    }
  }

  void updateBook(Book? updated) {
    book = updated;
    _emit();
  }

  void updateSourceData(Book? b, List<Chapter> c) {
    book = b;
    chapters = c;
    _emit();
  }

  void _applyPageIndex(int newIdx, List<TypedPage> pages) {
    final clamped = newIdx.clamp(0, pages.length - 1);
    final offset = pages[clamped].charStart;
    pageIndex = clamped;
    charAnchorOffset = offset;
    _emit();
    _persistProgress(chapterIndex, currentChapterTitle, offset);
  }

  void _persistProgress(int chIdx, String chTitle, int offset) =>
      db.updateReadingProgress(
        bookId: bookId,
        chapterIndex: chIdx,
        chapterTitle: chTitle,
        charOffset: offset,
      );
}
