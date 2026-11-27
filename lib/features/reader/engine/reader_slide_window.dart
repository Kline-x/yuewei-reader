import '../../../core/database/app_database.dart';
import 'dual_page_composer.dart';
import 'page_models.dart';
import 'reader_chapter_loader.dart';
import 'reader_page_slot.dart';
import 'typography_engine.dart';

/// 三章滑窗预分页管理器（当前章 + 前后邻居预排版，支撑单/双页 0ms 无感跨章翻页）
class ReaderSlideWindow {
  ReaderSlideWindow({this.engine = const TypographyEngine()});

  final TypographyEngine engine;
  final Map<int, List<TypedPage>> _pagesMap = {};
  TypographyConfig? _lastConfig;
  bool _lastIsDualPage = false;

  TypographyConfig? get lastConfig => _lastConfig;

  void clear() {
    _pagesMap.clear();
    _lastConfig = null;
    _lastIsDualPage = false;
  }

  List<TypedPage>? pagesOf(int chapterIndex) => _pagesMap[chapterIndex];

  /// 排版配置或单双页模式变更/切章后，同步重算中心与已预取邻居的分页结果
  bool syncWindow({
    required TypographyConfig config,
    required int activeChapterIndex,
    required String bookId,
    required List<Chapter> chapters,
    required ReaderChapterLoader loader,
    bool isDualPage = false,
  }) {
    final configChanged = _lastConfig != config;
    final dualChanged = _lastIsDualPage != isDualPage;
    _lastIsDualPage = isDualPage;
    if (configChanged) {
      _pagesMap.clear();
      _lastConfig = config;
    } else {
      _pagesMap.removeWhere(
        (idx, _) =>
            idx < activeChapterIndex - 2 || idx > activeChapterIndex + 2,
      );
    }

    for (final idx in [
      activeChapterIndex - 1,
      activeChapterIndex,
      activeChapterIndex + 1,
    ]) {
      if (idx < 0 || idx >= chapters.length) continue;
      if (_pagesMap.containsKey(idx)) continue;
      final paras = loader.peekMemory(bookId, idx);
      if (paras != null && paras.isNotEmpty) {
        _pagesMap[idx] = engine.paginate(
          paragraphs: paras,
          chapterTitle: chapters[idx].title,
          config: config,
        );
      }
    }
    return configChanged || dualChanged;
  }

  /// 确保指定章节已入窗分页（若无内存段落则按传入段落即时排页）
  List<TypedPage> ensurePaginated({
    required int chapterIndex,
    required String chapterTitle,
    required List<String> paragraphs,
    required TypographyConfig config,
  }) {
    final existing = _pagesMap[chapterIndex];
    if (existing != null && _lastConfig == config) return existing;
    _lastConfig = config;
    final pages = engine.paginate(
      paragraphs: paragraphs,
      chapterTitle: chapterTitle,
      config: config,
    );
    _pagesMap[chapterIndex] = pages;
    return pages;
  }

  int findPageByCharOffset(List<TypedPage> pages, int charOffset) =>
      engine.findPageByCharOffset(pages, charOffset);

  /// 重排或跨页落地后，按字符锚点或末屏规范化起始页码（双页强制偶数对齐）
  int resolveSyncedPageIndex(
    List<TypedPage> pages, {
    required int currentPageIndex,
    required int charAnchorOffset,
    required bool needReanchor,
    required bool landOnLastPage,
    required bool isDualPage,
  }) {
    if (pages.isEmpty) return 0;
    if (landOnLastPage) {
      return DualPageComposer.lastSpreadStartIndex(
        pages.length,
        isDualPage: isDualPage,
      );
    }
    final raw = needReanchor
        ? findPageByCharOffset(pages, charAnchorOffset)
        : currentPageIndex;
    return DualPageComposer.normalizeLeftPageIndex(
      raw,
      pages.length,
      isDualPage: isDualPage,
    );
  }

  /// 构造连续槽位（prev / current / next，支持单页与双页步进 2 及自动跨章衔接）
  ({PageRenderItem? prev, PageRenderItem? current, PageRenderItem? next})
      buildSlots({
    required int chapterIndex,
    required int pageIndex,
    required String bookTitle,
    required List<Chapter> chapters,
    bool isDualPage = false,
    double spineWidth = 0.0,
  }) {
    final curPages = _pagesMap[chapterIndex];
    if (curPages == null || curPages.isEmpty) {
      return (prev: null, current: null, next: null);
    }
    final curTitle = (chapterIndex >= 0 && chapterIndex < chapters.length)
        ? chapters[chapterIndex].title
        : '正文阅读';
    final prevTitle =
        chapterIndex > 0 ? chapters[chapterIndex - 1].title : null;
    final nextTitle = chapterIndex + 1 < chapters.length
        ? chapters[chapterIndex + 1].title
        : null;
    return DualPageComposer.buildSpreadSlots(
      chapterIndex: chapterIndex,
      pageIndex: pageIndex,
      bookTitle: bookTitle,
      currentTitle: curTitle,
      curPages: curPages,
      prevChPages: chapterIndex > 0 ? _pagesMap[chapterIndex - 1] : null,
      prevChTitle: prevTitle,
      nextChPages:
          chapterIndex + 1 < chapters.length ? _pagesMap[chapterIndex + 1] : null,
      nextChTitle: nextTitle,
      isDualPage: isDualPage,
      spineWidth: spineWidth,
      config: _lastConfig,
    );
  }

  /// 计算向前翻页的目标章节与起始页索引（双页步进 2 且规范化偶数，章末跨入下一章首页）
  ({int chapterIndex, int pageIndex, bool crossedChapter})? turnNext({
    required int chapterIndex,
    required int pageIndex,
    required int totalChapters,
    bool isDualPage = false,
  }) {
    final curPages = _pagesMap[chapterIndex];
    if (curPages == null || curPages.isEmpty) {
      return chapterIndex + 1 < totalChapters
          ? (chapterIndex: chapterIndex + 1, pageIndex: 0, crossedChapter: true)
          : null;
    }
    final step = isDualPage ? 2 : 1;
    final safeStart = DualPageComposer.normalizeLeftPageIndex(
      pageIndex,
      curPages.length,
      isDualPage: isDualPage,
    );
    if (safeStart + step < curPages.length) {
      return (chapterIndex: chapterIndex, pageIndex: safeStart + step, crossedChapter: false);
    }
    return chapterIndex + 1 < totalChapters
        ? (chapterIndex: chapterIndex + 1, pageIndex: 0, crossedChapter: true)
        : null;
  }

  /// 计算向后翻页的目标章节与起始页索引（双页步进 2，章首跨至上一章末对开页）
  ({int chapterIndex, int pageIndex, bool crossedChapter, bool landOnLastPage})?
      turnPrev({
    required int chapterIndex,
    required int pageIndex,
    bool isDualPage = false,
  }) {
    final curPages = _pagesMap[chapterIndex];
    if (curPages == null || curPages.isEmpty) {
      return chapterIndex > 0
          ? (chapterIndex: chapterIndex - 1, pageIndex: 0, crossedChapter: true, landOnLastPage: true)
          : null;
    }
    final step = isDualPage ? 2 : 1;
    final safeStart = DualPageComposer.normalizeLeftPageIndex(
      pageIndex,
      curPages.length,
      isDualPage: isDualPage,
    );
    if (safeStart - step >= 0) {
      return (chapterIndex: chapterIndex, pageIndex: safeStart - step, crossedChapter: false, landOnLastPage: false);
    }
    if (chapterIndex > 0) {
      final prevPages = _pagesMap[chapterIndex - 1];
      final targetIdx = (prevPages == null || prevPages.isEmpty)
          ? 0
          : DualPageComposer.lastSpreadStartIndex(prevPages.length, isDualPage: isDualPage);
      return (chapterIndex: chapterIndex - 1, pageIndex: targetIdx, crossedChapter: true, landOnLastPage: true);
    }
    return null;
  }

  /// 按字符锚点估算章内阅读百分比（0.0 ~ 1.0），供跨模式切换精准定位
  static double estimateCharRatio(List<String> paragraphs, int charOffset) {
    if (paragraphs.isEmpty || charOffset <= 0) return 0.0;
    final total = paragraphs.fold<int>(0, (s, p) => s + p.length + 1);
    if (total <= 0) return 0.0;
    return (charOffset / total).clamp(0.0, 1.0);
  }

  /// 构造「上下」连续滚动的初始章块列表（当前章 + 若已预取的下一章）
  List<ChapterBlock> buildInitialScrollBlocks({
    required int chapterIndex,
    required String chapterTitle,
    required List<String> paragraphs,
    required String bookId,
    required List<Chapter> chapters,
    required ReaderChapterLoader loader,
  }) {
    final blocks = <ChapterBlock>[
      ChapterBlock(
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
        paragraphs: paragraphs,
      ),
    ];
    if (chapterIndex + 1 < chapters.length) {
      final nextParas = loader.peekMemory(bookId, chapterIndex + 1);
      if (nextParas != null && nextParas.isNotEmpty) {
        blocks.add(
          ChapterBlock(
            chapterIndex: chapterIndex + 1,
            chapterTitle: chapters[chapterIndex + 1].title,
            paragraphs: nextParas,
          ),
        );
      }
    }
    return blocks;
  }
}
