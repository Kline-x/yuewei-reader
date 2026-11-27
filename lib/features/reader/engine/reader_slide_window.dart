import '../../../core/database/app_database.dart';
import 'page_models.dart';
import 'reader_chapter_loader.dart';
import 'reader_page_slot.dart';
import 'typography_engine.dart';

/// 三章滑窗预分页管理器（当前章 + 前后邻居预排版，支撑 0ms 无感跨章翻页）
class ReaderSlideWindow {
  ReaderSlideWindow({this.engine = const TypographyEngine()});

  final TypographyEngine engine;
  final Map<int, List<TypedPage>> _pagesMap = {};
  TypographyConfig? _lastConfig;

  TypographyConfig? get lastConfig => _lastConfig;

  void clear() {
    _pagesMap.clear();
    _lastConfig = null;
  }

  List<TypedPage>? pagesOf(int chapterIndex) => _pagesMap[chapterIndex];

  /// 排版配置变更或切换章节后，同步重算中心与已预取邻居的分页结果
  bool syncWindow({
    required TypographyConfig config,
    required int activeChapterIndex,
    required String bookId,
    required List<Chapter> chapters,
    required ReaderChapterLoader loader,
  }) {
    final configChanged = _lastConfig != config;
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
    return configChanged;
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

  /// 构造三页连续槽位（prev / current / next，自动跨章衔接上一章末页与下一章首页）
  ({PageRenderItem? prev, PageRenderItem? current, PageRenderItem? next})
      buildSlots({
    required int chapterIndex,
    required int pageIndex,
    required String bookTitle,
    required List<Chapter> chapters,
  }) {
    final curPages = _pagesMap[chapterIndex];
    if (curPages == null || curPages.isEmpty) {
      return (prev: null, current: null, next: null);
    }

    final safeIdx = pageIndex.clamp(0, curPages.length - 1);
    final curTitle =
        (chapterIndex >= 0 && chapterIndex < chapters.length)
            ? chapters[chapterIndex].title
            : '正文阅读';

    final current = PageRenderItem(
      chapterIndex: chapterIndex,
      chapterTitle: curTitle,
      page: curPages[safeIdx],
      totalPagesInChapter: curPages.length,
      bookTitle: bookTitle,
    );

    PageRenderItem? prev;
    if (safeIdx > 0) {
      prev = PageRenderItem(
        chapterIndex: chapterIndex,
        chapterTitle: curTitle,
        page: curPages[safeIdx - 1],
        totalPagesInChapter: curPages.length,
        bookTitle: bookTitle,
      );
    } else if (chapterIndex > 0) {
      final prevChPages = _pagesMap[chapterIndex - 1];
      if (prevChPages != null && prevChPages.isNotEmpty) {
        prev = PageRenderItem(
          chapterIndex: chapterIndex - 1,
          chapterTitle: chapters[chapterIndex - 1].title,
          page: prevChPages.last,
          totalPagesInChapter: prevChPages.length,
          bookTitle: bookTitle,
        );
      }
    }

    PageRenderItem? next;
    if (safeIdx + 1 < curPages.length) {
      next = PageRenderItem(
        chapterIndex: chapterIndex,
        chapterTitle: curTitle,
        page: curPages[safeIdx + 1],
        totalPagesInChapter: curPages.length,
        bookTitle: bookTitle,
      );
    } else if (chapterIndex + 1 < chapters.length) {
      final nextChPages = _pagesMap[chapterIndex + 1];
      if (nextChPages != null && nextChPages.isNotEmpty) {
        next = PageRenderItem(
          chapterIndex: chapterIndex + 1,
          chapterTitle: chapters[chapterIndex + 1].title,
          page: nextChPages.first,
          totalPagesInChapter: nextChPages.length,
          bookTitle: bookTitle,
        );
      }
    }

    return (prev: prev, current: current, next: next);
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
