part of 'reader_session_controller.dart';

/// 阅读器会话控制器的连续滚动拼章、滑窗预取与进度同步子模块
extension ReaderSessionScrollOps on ReaderSessionController {
  void _applyLoadedChapter({
    required int index,
    required String chapterTitle,
    required List<String> loadedParas,
    required int charOffset,
    required bool landOnLastPage,
  }) {
    scrollBlocks = window.buildInitialScrollBlocks(
      chapterIndex: index,
      chapterTitle: chapterTitle,
      paragraphs: loadedParas,
      bookId: bookId,
      chapters: chapters,
      loader: loader,
    );
    chapterIndex = index;
    paragraphs = loadedParas;
    loading = false;
    errorMsg = null;
    var resolvedOffset = charOffset < 0 ? 0 : charOffset;
    _jumpToLastPageOnLoad = landOnLastPage;

    final cfg = window.lastConfig;
    if (cfg != null) {
      final pages = window.ensurePaginated(
        chapterIndex: index,
        chapterTitle: chapterTitle,
        paragraphs: loadedParas,
        config: cfg,
      );
      pageIndex = landOnLastPage
          ? (pages.length - 1).clamp(0, pages.length - 1)
          : window.findPageByCharOffset(pages, resolvedOffset);
      if (landOnLastPage && pages.isNotEmpty) {
        resolvedOffset = pages[pageIndex].charStart;
      }
      _jumpToLastPageOnLoad = false;
    } else if (landOnLastPage && loadedParas.isNotEmpty) {
      resolvedOffset =
          loadedParas.fold<int>(0, (sum, p) => sum + p.length + 1) - 1;
      if (resolvedOffset < 0) resolvedOffset = 0;
    }
    charAnchorOffset = resolvedOffset;
    scrollJumpCommand = ScrollJumpCommand(
      token: ++_scrollJumpToken,
      chapterIndex: index,
      charOffset: resolvedOffset,
      landOnEnd: landOnLastPage,
    );
    _emit();
    _persistProgress(index, chapterTitle, resolvedOffset);
  }

  Future<void> _prefetchNeighbors(int centerIdx, int reqId) async {
    if (book == null || _disposed) return;
    final reqBook = book!;
    for (final idx in [centerIdx + 1, centerIdx - 1]) {
      if (idx < 0 || idx >= chapters.length || _disposed) continue;
      final paras = await loader.prefetchToMemory(
        ref: ref,
        book: reqBook,
        chapter: chapters[idx],
      );
      if (_disposed ||
          reqId != _loadEpoch ||
          book?.sourceId != reqBook.sourceId ||
          paras == null) {
        continue;
      }
      _syncWindowIfReady();
      _emit();
    }
  }

  void _syncWindowIfReady() {
    final cfg = window.lastConfig;
    if (cfg == null) return;
    window.syncWindow(
      config: cfg,
      activeChapterIndex: chapterIndex,
      bookId: bookId,
      chapters: chapters,
      loader: loader,
    );
  }

  Future<void> appendNextScrollChapter() async {
    if (_appendingScrollNext || scrollBlocks.isEmpty || book == null) return;
    final nextIdx = scrollBlocks.last.chapterIndex + 1;
    if (nextIdx >= chapters.length) return;
    final epoch = _loadEpoch;
    final reqBook = book!;
    final reqSourceId = reqBook.sourceId;
    _appendingScrollNext = true;
    try {
      final paras = await loader.prefetchToMemory(
        ref: ref,
        book: reqBook,
        chapter: chapters[nextIdx],
      );
      if (_disposed ||
          epoch != _loadEpoch ||
          book?.sourceId != reqSourceId ||
          paras == null ||
          paras.isEmpty ||
          scrollBlocks.isEmpty ||
          scrollBlocks.last.chapterIndex + 1 != nextIdx ||
          nextIdx >= chapters.length) {
        return;
      }
      scrollBlocks = [
        ...scrollBlocks,
        ChapterBlock(
          chapterIndex: nextIdx,
          chapterTitle: chapters[nextIdx].title,
          paragraphs: paras,
        ),
      ];
      _emit();
    } finally {
      _appendingScrollNext = false;
    }
  }

  void handleScrollChapterProgress(int chIdx, int offset) {
    if (chIdx < 0 || chIdx >= chapters.length || _disposed) return;
    var chParas = loader.peekMemory(bookId, chIdx);
    if (chParas == null || chParas.isEmpty) {
      final match = scrollBlocks.where((b) => b.chapterIndex == chIdx);
      chParas = match.isNotEmpty ? match.first.paragraphs : paragraphs;
    }
    charAnchorOffset = offset;
    _persistProgress(chIdx, chapters[chIdx].title, offset);
    final cfg = window.lastConfig;
    if (chIdx != chapterIndex) {
      chapterIndex = chIdx;
      paragraphs = chParas;
      if (cfg != null) {
        _syncWindowIfReady();
        final pages = window.ensurePaginated(
          chapterIndex: chIdx,
          chapterTitle: chapters[chIdx].title,
          paragraphs: chParas,
          config: cfg,
        );
        pageIndex = window.findPageByCharOffset(pages, offset);
      }
      _emit();
      _prefetchNeighbors(chIdx, _loadEpoch);
    } else if (cfg != null) {
      final pages = window.pagesOf(chIdx);
      if (pages != null && pages.isNotEmpty) {
        pageIndex = window.findPageByCharOffset(pages, offset);
      }
    }
  }
}
