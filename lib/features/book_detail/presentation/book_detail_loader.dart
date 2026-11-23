import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../../sources/domain/book_match_models.dart';
import '../../sources/domain/book_source_rule.dart';
import '../../sources/engine/source_crawler_service.dart';

/// 书籍详情加载与网络自愈补拉协调器（解除 Page 臃肿，严守 ≤ 350 行）
class BookDetailLoader {
  const BookDetailLoader._();

  static bool needsMetaRepair(Book b) {
    return SourceCrawlerService.sanitizeBadge(b.category) != b.category ||
        SourceCrawlerService.cleanSeoIntro(b.intro) != b.intro ||
        b.statusText.length > 16 ||
        b.intro.trim().isEmpty ||
        b.lastUpdateTime.trim().isEmpty ||
        b.latestChapterTitle.trim().isEmpty;
  }

  static String firstNonEmpty(List<String> list, {String fallback = ''}) {
    for (final s in list) {
      if (s.trim().isNotEmpty) return s.trim();
    }
    return fallback;
  }

  /// 从本地 Drift 库秒开读取详情，若缺少聚集封面则就地回填
  static Future<({Book? book, List<Chapter> chapters, String sourceName})>
      loadLocal({
    required WidgetRef ref,
    required String bookId,
    required AggregatedBookMatch? aggregatedMatch,
  }) async {
    final db = ref.read(appDatabaseProvider);
    final sourceRepo = ref.read(sourceRepositoryProvider);
    final shelfRepo = ref.read(shelfRepositoryProvider);

    final existing = await db.getBookById(bookId);
    if (existing == null) {
      return (book: null, chapters: const <Chapter>[], sourceName: '');
    }

    final chapters = await db.getChaptersByBook(existing.id);
    final rule = await sourceRepo.getRuleById(existing.sourceId);
    var currentBook = existing;
    final aggCover = aggregatedMatch?.bestCoverUrl ?? '';

    if (chapters.isNotEmpty && existing.coverUrl.isEmpty && aggCover.isNotEmpty) {
      currentBook = await shelfRepo.ensureBookWithChapters(
        bookId: existing.id,
        title: existing.title,
        author: existing.author,
        coverUrl: aggCover,
        intro: existing.intro,
        category: existing.category,
        statusText: existing.statusText,
        latestChapterTitle: existing.latestChapterTitle,
        lastUpdateTime: existing.lastUpdateTime,
        sourceId: existing.sourceId,
        bookUrl: existing.bookUrl,
        tocUrl: existing.tocUrl,
        chapters: const [],
      );
    }

    return (
      book: currentBook,
      chapters: chapters,
      sourceName: rule?.name ?? currentBook.sourceId,
    );
  }

  /// 从当前书源重新抓包解析最新简介、更新时间、最新章节并落库自愈
  static Future<({Book book, List<Chapter> chapters, String sourceName})?>
      fetchAndHealFromNetwork({
    required WidgetRef ref,
    required String bookId,
    required AggregatedBookMatch? aggregatedMatch,
    Book? existing,
  }) async {
    final db = ref.read(appDatabaseProvider);
    final sourceRepo = ref.read(sourceRepositoryProvider);
    final shelfRepo = ref.read(shelfRepositoryProvider);
    final crawler = ref.read(crawlerServiceProvider);

    final hit = aggregatedMatch?.primaryHit;
    final sourceId = existing?.sourceId ?? hit?.sourceId ?? '';
    final bookUrl = existing?.bookUrl ?? hit?.bookUrl ?? '';
    final rule = await sourceRepo.getRuleById(sourceId);
    if (rule == null || bookUrl.isEmpty) return null;

    final fetched = await crawler.fetchBookDetailAndToc(rule, bookUrl);
    final aggCover = aggregatedMatch?.bestCoverUrl ?? '';
    final bestCover = firstNonEmpty([
      fetched.detail.coverUrl,
      aggCover,
      hit?.coverUrl ?? '',
      existing?.coverUrl ?? '',
    ]);
    final bestIntro = firstNonEmpty([
      fetched.detail.intro,
      SourceCrawlerService.cleanSeoIntro(aggregatedMatch?.bestIntro ?? ''),
      SourceCrawlerService.cleanSeoIntro(hit?.intro ?? ''),
      SourceCrawlerService.cleanSeoIntro(existing?.intro ?? ''),
    ]);

    final saved = await shelfRepo.ensureBookWithChapters(
      bookId: bookId,
      title: firstNonEmpty(
        [fetched.detail.title, existing?.title ?? '', hit?.title ?? ''],
        fallback: '未命名',
      ),
      author: firstNonEmpty(
        [fetched.detail.author, existing?.author ?? '', hit?.author ?? ''],
      ),
      coverUrl: bestCover,
      intro: bestIntro,
      category: fetched.detail.category,
      statusText: fetched.detail.statusText,
      latestChapterTitle: fetched.detail.latestChapter,
      lastUpdateTime: fetched.detail.lastUpdateTime,
      sourceId: rule.id,
      bookUrl: bookUrl,
      tocUrl: fetched.detail.tocUrl,
      chapters: fetched.chapters,
    );

    final chRows = await db.getChaptersByBook(saved.id);
    return (book: saved, chapters: chRows, sourceName: rule.name);
  }

  /// 执行换源写库并返回更新后的书籍实体与目录列表
  static Future<({Book? book, List<Chapter> chapters, String sourceName})>
      applySwitchedSource({
    required WidgetRef ref,
    required Book oldBook,
    required BookSourceRule rule,
    required SourceSearchHit hit,
    required List<ParsedChapterEntry> chapters,
  }) async {
    final db = ref.read(appDatabaseProvider);
    await ref.read(shelfRepositoryProvider).switchBookSource(
          bookId: oldBook.id,
          newSourceId: rule.id,
          newBookUrl: hit.bookUrl,
          newTocUrl: hit.bookUrl,
          newChapters: chapters,
          preferredChapterTitle: oldBook.currentChapterTitle,
          fallbackChapterIndex: oldBook.currentChapterIndex,
          newIntro: hit.intro,
          newLatestChapterTitle: hit.latestChapter,
        );
    final updatedBook = await db.getBookById(oldBook.id);
    final updatedChapters = await db.getChaptersByBook(oldBook.id);
    return (
      book: updatedBook,
      chapters: updatedChapters,
      sourceName: rule.name,
    );
  }
}
