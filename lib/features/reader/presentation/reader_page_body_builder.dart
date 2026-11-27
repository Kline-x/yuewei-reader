part of 'reader_page.dart';

/// 阅读器主视口与功能面板回调装配子模块（确保 reader_page.dart ≤ 350 行）
extension _ReaderPageBodyBuilder on _ReaderPageState {
  Widget _buildBody({
    required BuildContext context,
    required BoxConstraints constraints,
    required ReaderSettingsState settings,
    required TtsState tts,
    required bool ttsForBook,
    required Brightness systemBrightness,
    required ReaderPaperTheme paper,
    required List<Bookmark> bookmarks,
  }) {
    final media = MediaQuery.paddingOf(context);
    final displayFeatures = MediaQuery.displayFeaturesOf(context);
    final geometry = DualPageComposer.resolveDualPageGeometry(
      constraints: constraints,
      layoutMode: settings.layoutMode,
      turnMode: settings.turnMode,
      displayFeatures: displayFeatures,
    );
    final topSafe = media.top > 0 ? media.top : 24.0;
    final botSafe = media.bottom > 0 ? media.bottom : 16.0;
    final config = TypographyConfig(
      fontSize: settings.fontSize,
      lineHeightRatio: settings.spacingPreset.ratio,
      paragraphGap: settings.paragraphGap,
      letterSpacing: settings.letterSpacing,
      viewportWidth: geometry.columnWidth,
      viewportHeight: constraints.maxHeight,
      horizontalPadding: settings.horizontalPadding,
      topPadding: topSafe + 34.0,
      bottomPadding: botSafe + (ttsForBook ? 72.0 : 28.0),
      fontFamily: settings.fontFamily,
      indentFirstLine: settings.indentFirstLine,
    );
    _session.syncForBuild(
      config,
      settings.turnMode,
      isDualPage: geometry.isDualPage,
      spineWidth: geometry.spineWidth,
    );
    final slots = _session.buildSlots(
      isDualPage: geometry.isDualPage,
      spineWidth: geometry.spineWidth,
    );
    final isLocalBook = _session.book?.sourceId == kLocalBookSourceId;
    final isScrollMode = settings.turnMode == PageTurnMode.scroll;
    final currentSlot = slots.current;
    var isBookmarked = ReaderBookmarkHelper.findMatchingBookmark(
          bookmarks: bookmarks,
          chapterIndex: _session.chapterIndex,
          currentItem: currentSlot,
          charAnchorOffset: _session.charAnchorOffset,
          isScrollMode: isScrollMode,
        ) !=
        null;
    if (!isBookmarked &&
        !isScrollMode &&
        currentSlot != null &&
        currentSlot.rightPage != null) {
      isBookmarked = ReaderBookmarkHelper.findMatchingBookmark(
            bookmarks: bookmarks,
            chapterIndex: currentSlot.chapterIndex,
            currentItem: DualPageComposer.buildSlotItem(
              chapterIndex: currentSlot.chapterIndex,
              chapterTitle: currentSlot.chapterTitle,
              pages: [currentSlot.rightPage!],
              startIndex: 0,
              bookTitle: currentSlot.bookTitle,
              isDualPage: false,
              spineWidth: 0.0,
            ),
            charAnchorOffset: _session.charAnchorOffset,
            isScrollMode: false,
          ) !=
          null;
    }

    return ReaderBodyView(
      pagerKey: _pagerKey,
      loading: _session.loading,
      errorMsg: _session.errorMsg,
      menuVisible: _menuVisible,
      turnMode: settings.turnMode,
      initialCharOffset: _session.charAnchorOffset,
      scrollJumpCommand: _session.scrollJumpCommand,
      paper: paper,
      config: config,
      topSafe: topSafe,
      botSafe: botSafe,
      currentItem: currentSlot,
      prevItem: slots.prev,
      nextItem: slots.next,
      scrollBlocks: _session.scrollBlocks,
      chapterIndex: _session.chapterIndex,
      totalChapters: _session.chapters.length,
      chapterTitles: _session.chapterTitles,
      bookTitle: _session.book?.title ?? '',
      chapterTitle: _session.currentChapterTitle,
      inShelf: _session.book?.isInShelf ?? false,
      isBookmarked: isBookmarked,
      isLocalBook: isLocalBook,
      isTtsActive: ttsForBook,
      isTtsPlaying: tts.isPlaying,
      ttsSleepBadge: tts.formattedSleepBadge,
      onRetry: _session.retryCurrent,
      onToggleMenu: () => _setMenuVisible(!_menuVisible),
      onCommitNext: _session.commitNext,
      onCommitPrev: _session.commitPrev,
      onNeedAppendNextChapter: _session.appendNextScrollChapter,
      onRequestPrevChapter: () => _session.loadChapter(
        _session.chapterIndex - 1,
        landOnLastPage: true,
      ),
      onScrollChapterProgress: _session.handleScrollChapterProgress,
      onBack: () => Navigator.of(context).pop(),
      onTapTts: () => ReaderTtsBinding.onTapHeadphone(
        context: context,
        ttsState: tts,
        ttsNotifier: _ttsNotifier,
        session: _session,
        currentItem: slots.current,
        isScrollMode: isScrollMode,
        setMenuVisible: _setMenuVisible,
        runWithGuard: _runWithSheetGuard,
      ),
      onToggleTtsPlayPause: _ttsNotifier.togglePlayPause,
      onToggleBookmark: () => ReaderBookmarkHelper.toggleCurrentBookmark(
        context: context,
        db: _session.db,
        bookId: widget.bookId,
        chapterIndex: _session.chapterIndex,
        chapterTitle: _session.currentChapterTitle,
        existingBookmarks: bookmarks,
        currentItem: slots.current,
        paragraphs: _session.paragraphs,
        charAnchorOffset: _session.charAnchorOffset,
        isScrollMode: isScrollMode,
      ),
      onAddToShelf: () => ReaderSheetsLauncher.addToShelf(
        context: context,
        ref: ref,
        db: _session.db,
        book: _session.book,
        onBookUpdated: _session.updateBook,
      ),
      onOpenSource: () => ReaderSheetsLauncher.openSourceSheet(
        context: context,
        ref: ref,
        db: _session.db,
        book: _session.book,
        currentChapterIndex: _session.chapterIndex,
        currentChapterTitle: _session.currentChapterTitle,
        loader: _session.loader,
        window: _session.window,
        runWithGuard: _runWithSheetGuard,
        onSwitched: _handleSourceSwitched,
      ),
      onOpenDownload: () => ReaderSheetsLauncher.openDownloadSheet(
        context: context,
        bookId: widget.bookId,
        bookTitle: _session.book?.title ?? '',
        totalChapters: _session.chapters.length,
        currentChapterIndex: _session.chapterIndex,
        runWithGuard: _runWithSheetGuard,
      ),
      onJumpChapter: (idx) => _session.loadChapter(idx),
      onOpenCatalog: () => ReaderSheetsLauncher.openCatalogSheet(
        context: context,
        chapters: _session.chapters,
        currentChapterIndex: _session.chapterIndex,
        onSelectChapter: (idx) => _session.loadChapter(idx),
        runWithGuard: _runWithSheetGuard,
      ),
      onOpenBookmarks: () => ReaderSheetsLauncher.openBookmarkSheet(
        context: context,
        db: _session.db,
        bookId: widget.bookId,
        currentChapterIndex: _session.chapterIndex,
        onSelectBookmark: _jumpToBookmarkOrHit,
        runWithGuard: _runWithSheetGuard,
      ),
      onOpenSearch: () => ReaderSheetsLauncher.openInBookSearchSheet(
        context: context,
        bookId: widget.bookId,
        chapters: _session.chapters,
        fileStore: ref.read(chapterFileStoreProvider),
        isLocalBook: isLocalBook,
        onSelectHit: _jumpToBookmarkOrHit,
        runWithGuard: _runWithSheetGuard,
      ),
      onToggleDark: () => ref
          .read(readerSettingsProvider.notifier)
          .toggleDarkQuick(systemBrightness: systemBrightness),
      onOpenTypography: () => ReaderSheetsLauncher.openTypographySheet(
        context: context,
        runWithGuard: _runWithSheetGuard,
      ),
    );
  }
}
