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
import '../../tts/tts_controller.dart';
import '../engine/page_models.dart';
import 'reader_body_view.dart';
import 'reader_bookmark_helper.dart';
import 'reader_pager_views.dart';
import 'reader_session_controller.dart';
import 'reader_settings_provider.dart';
import 'reader_sheets_launcher.dart';
import 'reader_tts_binding.dart';

part 'reader_page_body_builder.dart';

/// 沉浸纸感阅读器主视图（宿主机控制 + 生命周期计时 + 翻页视口装配，≤ 350 行）
class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({super.key, required this.bookId, this.initialChapterIndex});

  final String bookId;
  final int? initialChapterIndex;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage>
    with WidgetsBindingObserver {
  final GlobalKey<ReaderPagerViewsState> _pagerKey = GlobalKey();
  late final ReaderSessionController _session;
  late final TtsController _ttsNotifier;
  late final Stream<List<Bookmark>> _bookmarksStream;
  late final ProviderSubscription<TtsState> _ttsSub;
  StreamSubscription<VolumeKeyEvent>? _volumeSub;

  bool _menuVisible = false, _sheetOpen = false;
  bool? _lastIntercept, _lastKeepOn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _volumeSub = HostBridge.instance.volumeKeyStream.listen(_onVolumeKey);
    _ttsNotifier = ref.read(ttsControllerProvider.notifier);
    final db = ref.read(appDatabaseProvider);
    _bookmarksStream = db.watchBookmarksByBook(widget.bookId);
    _session = ReaderSessionController(bookId: widget.bookId, ref: ref, db: db);
    _ttsSub = ref.listenManual<TtsState>(ttsControllerProvider, (_, next) {
      if (!mounted) return;
      if (next.isActive &&
          next.bookId == widget.bookId &&
          !next.isReaderAttached) {
        ReaderTtsBinding.attach(
          owner: this,
          tts: _ttsNotifier,
          session: _session,
          onLocate: (chIdx, offset) =>
              _locateReader(chIdx, offset, animate: true),
        );
      }
    });
    final initialTts = ref.read(ttsControllerProvider);
    if (!initialTts.isActive || initialTts.bookId == widget.bookId) {
      ReaderTtsBinding.attach(
        owner: this,
        tts: _ttsNotifier,
        session: _session,
        onLocate: (chIdx, offset) => _locateReader(chIdx, offset, animate: true),
        deferStateNotify: true,
      );
    }
    unawaited(_bootstrapAndSyncTts());
  }

  Future<void> _bootstrapAndSyncTts() async {
    await _session.bootstrap(widget.initialChapterIndex);
    if (!mounted) return;
    final tts = ref.read(ttsControllerProvider);
    if (!tts.isActive || tts.bookId != widget.bookId) return;
    ReaderTtsBinding.attach(
      owner: this,
      tts: _ttsNotifier,
      session: _session,
      onLocate: (chIdx, offset) => _locateReader(chIdx, offset, animate: true),
    );
    final shouldFollowActiveTts = widget.initialChapterIndex == null ||
        widget.initialChapterIndex == tts.chapterIndex;
    if (shouldFollowActiveTts &&
        _session.chapters.isNotEmpty &&
        tts.paragraphs.isNotEmpty) {
      final targetOffset = TtsController.charOffsetOfParagraph(
        tts.paragraphs,
        tts.paragraphIndex,
      );
      if (_session.chapterIndex != tts.chapterIndex ||
          _session.charAnchorOffset != targetOffset) {
        await _locateReader(tts.chapterIndex, targetOffset, animate: false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ttsSub.close();
    // 退出阅读器仅脱离回调，若当前处于活跃听书态绝不调用 ttsStop，实现后台无缝续播
    _ttsNotifier.detachReader(this, deferStateNotify: true);
    _volumeSub?.cancel();
    HostBridge.instance.setVolumeKeyIntercept(false);
    HostBridge.instance.keepScreenOn(false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _session.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    state == AppLifecycleState.resumed
        ? _session.resumeReadingTimer()
        : _session.pauseReadingTimer();
  }

  void _syncHostControls(
    ReaderSettingsState settings, {
    required bool isTtsActive,
  }) {
    final allowIntercept = settings.volumeKeyPaging &&
        !_menuVisible &&
        !_sheetOpen &&
        !isTtsActive &&
        !_session.loading &&
        _session.errorMsg == null;
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
    final tts = ref.read(ttsControllerProvider);
    final isTtsActive = tts.isActive && tts.bookId == widget.bookId;
    if (!mounted ||
        _session.loading ||
        _session.errorMsg != null ||
        _menuVisible ||
        _sheetOpen ||
        isTtsActive) {
      return;
    }
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

  Future<void> _locateReader(
    int chapterIndex,
    int charOffset, {
    bool animate = false,
  }) async {
    final isScroll =
        ref.read(readerSettingsProvider).turnMode == PageTurnMode.scroll;
    final inLoadedBlocks = isScroll &&
        !_session.loading &&
        _session.errorMsg == null &&
        _session.scrollBlocks.any((b) => b.chapterIndex == chapterIndex);
    await _session.jumpToLocation(
      chapterIndex,
      charOffset,
      animateScroll: animate,
      emitScrollCommand: !inLoadedBlocks,
    );
    if (inLoadedBlocks && mounted) {
      _pagerKey.currentState
          ?.scrollToLocation(chapterIndex, charOffset, animate: animate);
    }
  }

  Future<void> _jumpToBookmarkOrHit(int chapterIndex, int charOffset) async {
    _setMenuVisible(false);
    await _locateReader(chapterIndex, charOffset);
  }

  Future<void> _handleSourceSwitched({
    required Book? updatedBook,
    required List<Chapter> updatedChapters,
    required int jumpIndex,
    required String ruleName,
  }) async {
    final curTts = ref.read(ttsControllerProvider);
    if (curTts.isActive && curTts.bookId == widget.bookId) {
      await _ttsNotifier.stop();
    }
    if (!mounted) return;
    _pagerKey.currentState?.clearPictureCache();
    _session.updateSourceData(updatedBook, updatedChapters);
    _setMenuVisible(false);
    await _session.loadChapter(jumpIndex);
    if (!mounted) return;
    AppFeedback.showToast(context, '已切换至 $ruleName');
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    final tts = ref.watch(ttsControllerProvider);
    final ttsForBook = tts.isActive && tts.bookId == widget.bookId;
    final systemBrightness = MediaQuery.platformBrightnessOf(context);
    final paper = settings.effectiveTheme(systemBrightness);
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
                builder: (context, _) {
                  _syncHostControls(settings, isTtsActive: ttsForBook);
                  return LayoutBuilder(
                    builder: (context, constraints) => _buildBody(
                      context: context,
                      constraints: constraints,
                      settings: settings,
                      tts: tts,
                      ttsForBook: ttsForBook,
                      systemBrightness: systemBrightness,
                      paper: paper,
                      bookmarks: bookmarks,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
