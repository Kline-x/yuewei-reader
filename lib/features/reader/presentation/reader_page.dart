import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/bookmark_dao.dart';
import '../../../core/platform/host_bridge.dart';
import '../../../core/storage/chapter_file_store.dart';
import '../../../design_system/feedback/app_feedback.dart';
import '../engine/page_models.dart';
import 'reader_body_view.dart';
import 'reader_bookmark_helper.dart';
import 'reader_pager_views.dart';
import 'reader_session_controller.dart';
import 'reader_settings_provider.dart';
import 'reader_sheets_launcher.dart';

/// 沉浸纸感阅读器主视图（宿主机控制 + 翻页视口装配，≤ 350 行）
class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({
    super.key,
    required this.bookId,
    this.initialChapterIndex,
  });

  final String bookId;
  final int? initialChapterIndex;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  GlobalKey<ReaderPagerViewsState> _pagerKey = GlobalKey();
  late final ReaderSessionController _session;
  late final Stream<List<Bookmark>> _bookmarksStream;
  StreamSubscription<VolumeKeyEvent>? _volumeSub;

  int _pagerJumpEpoch = 0;
  bool _menuVisible = false;
  bool _sheetOpen = false;
  bool? _lastIntercept;
  bool? _lastKeepOn;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _volumeSub = HostBridge.instance.volumeKeyStream.listen(_onVolumeKey);
    final db = ref.read(appDatabaseProvider);
    _bookmarksStream = db.watchBookmarksByBook(widget.bookId);
    _session = ReaderSessionController(
      bookId: widget.bookId,
      ref: ref,
      db: db,
      onNeedResetScroll: () {
        if (_session.jumpSequence == _pagerJumpEpoch) {
          _pagerKey.currentState?.scrollResetTop();
        }
      },
    )..bootstrap(widget.initialChapterIndex);
  }

  @override
  void dispose() {
    _volumeSub?.cancel();
    HostBridge.instance.setVolumeKeyIntercept(false);
    HostBridge.instance.keepScreenOn(false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _session.dispose();
    super.dispose();
  }

  void _syncHostControls(ReaderSettingsState settings) {
    final allowIntercept =
        settings.volumeKeyPaging && !_menuVisible && !_sheetOpen;
    if (_lastIntercept != allowIntercept) {
      _lastIntercept = allowIntercept;
      HostBridge.instance.setVolumeKeyIntercept(allowIntercept);
    }
    if (_lastKeepOn != settings.keepScreenOn) {
      _lastKeepOn = settings.keepScreenOn;
      HostBridge.instance.keepScreenOn(settings.keepScreenOn);
    }
  }

  void _onVolumeKey(VolumeKeyEvent event) {
    if (!mounted || _session.loading || _menuVisible || _sheetOpen) return;
    event == VolumeKeyEvent.down
        ? _pagerKey.currentState?.turnNextAnimated()
        : _pagerKey.currentState?.turnPrevAnimated();
  }

  void _setMenuVisible(bool visible) {
    if (_menuVisible == visible) return;
    setState(() => _menuVisible = visible);
    SystemChrome.setEnabledSystemUIMode(
      visible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  Future<void> _runWithSheetGuard(Future<void> Function() task) async {
    setState(() => _sheetOpen = true);
    await task();
    if (mounted) setState(() => _sheetOpen = false);
  }

  Future<void> _jumpToBookmarkOrHit(int chapterIndex, int charOffset) async {
    _setMenuVisible(false);
    await _session.jumpToLocation(chapterIndex, charOffset);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    final paper =
        settings.effectiveTheme(MediaQuery.platformBrightnessOf(context));
    _syncHostControls(settings);

    final overlayStyle =
        (paper.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: PopScope(
        canPop: !_menuVisible,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _menuVisible) _setMenuVisible(false);
        },
        child: Scaffold(
          backgroundColor: paper.background,
          body: StreamBuilder<List<Bookmark>>(
            stream: _bookmarksStream,
            builder: (context, bookmarkSnap) {
              final bookmarks = bookmarkSnap.data ?? const <Bookmark>[];
              return AnimatedBuilder(
                animation: _session,
                builder: (context, _) => LayoutBuilder(
                  builder: (context, constraints) {
                    if (_pagerJumpEpoch != _session.jumpSequence) {
                      _pagerJumpEpoch = _session.jumpSequence;
                      if (settings.turnMode == PageTurnMode.scroll) {
                        _pagerKey = GlobalKey<ReaderPagerViewsState>();
                      }
                    }
                    final media = MediaQuery.paddingOf(context);
                    final topSafe = media.top > 0 ? media.top : 24.0;
                    final botSafe = media.bottom > 0 ? media.bottom : 16.0;
                    final config = TypographyConfig(
                      fontSize: settings.fontSize,
                      lineHeightRatio: settings.spacingPreset.ratio,
                      viewportWidth: constraints.maxWidth,
                      viewportHeight: constraints.maxHeight,
                      topPadding: topSafe + 34.0,
                      bottomPadding: botSafe + 28.0,
                    );
                    _session.syncForBuild(config, settings.turnMode);
                    final slots = _session.buildSlots();
                    final isLocalBook =
                        _session.book?.sourceId == kLocalBookSourceId;
                    final isScrollMode =
                        settings.turnMode == PageTurnMode.scroll;
                    final isBookmarked =
                        ReaderBookmarkHelper.findMatchingBookmark(
                              bookmarks: bookmarks,
                              chapterIndex: _session.chapterIndex,
                              currentItem: slots.current,
                              charAnchorOffset: _session.charAnchorOffset,
                              isScrollMode: isScrollMode,
                            ) !=
                            null;

                    return ReaderBodyView(
                      pagerKey: _pagerKey,
                      loading: _session.loading,
                      errorMsg: _session.errorMsg,
                      menuVisible: _menuVisible,
                      turnMode: settings.turnMode,
                      initialCharOffset: _session.charAnchorOffset,
                      paper: paper,
                      config: config,
                      topSafe: topSafe,
                      botSafe: botSafe,
                      currentItem: slots.current,
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
                      onRetry: () => _session.loadChapter(_session.chapterIndex),
                      onToggleMenu: () => _setMenuVisible(!_menuVisible),
                      onCommitNext: _session.commitNext,
                      onCommitPrev: _session.commitPrev,
                      onNeedAppendNextChapter: _session.appendNextScrollChapter,
                      onRequestPrevChapter: () => _session.loadChapter(
                        _session.chapterIndex - 1,
                        landOnLastPage: true,
                      ),
                      onScrollChapterProgress:
                          _session.handleScrollChapterProgress,
                      onBack: () => Navigator.of(context).pop(),
                      onToggleBookmark: () =>
                          ReaderBookmarkHelper.toggleCurrentBookmark(
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
                        onSwitched: ({
                          required updatedBook,
                          required updatedChapters,
                          required jumpIndex,
                          required ruleName,
                        }) async {
                          if (!mounted) return;
                          _session.updateSourceData(updatedBook, updatedChapters);
                          _setMenuVisible(false);
                          await _session.loadChapter(jumpIndex);
                          if (!mounted) return;
                          AppFeedback.showToast(this.context, '已切换至 $ruleName');
                        },
                      ),
                      onOpenDownload: () =>
                          ReaderSheetsLauncher.openDownloadSheet(
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
                      onOpenBookmarks: () =>
                          ReaderSheetsLauncher.openBookmarkSheet(
                        context: context,
                        db: _session.db,
                        bookId: widget.bookId,
                        currentChapterIndex: _session.chapterIndex,
                        onSelectBookmark: _jumpToBookmarkOrHit,
                        runWithGuard: _runWithSheetGuard,
                      ),
                      onOpenSearch: () =>
                          ReaderSheetsLauncher.openInBookSearchSheet(
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
                          .toggleDarkQuick(),
                      onOpenTypography: () =>
                          ReaderSheetsLauncher.openTypographySheet(
                        context: context,
                        runWithGuard: _runWithSheetGuard,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
