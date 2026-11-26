import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;
import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/storage/chapter_file_store.dart';
import '../../../design_system/tokens/soft_tokens.dart';
import '../../sources/domain/book_match_models.dart';
import '../../sources/domain/book_source_rule.dart';
import '../../sources/engine/book_metadata_sanitizer.dart';
import '../../sources/engine/rule_evaluator.dart';
import '../../sources/engine/source_crawler_service.dart';

/// 书籍详情加载与网络自愈补拉协调器（解除 Page 臃肿，严守 ≤ 350 行）
class BookDetailLoader {
  const BookDetailLoader._();

  /// 仅在简介/最新章为空或存在明显污损时才触发自动网络修补，
  /// 避免对不含 lastUpdateTime 的书源每次进详情页反复发无效请求。
  static bool needsMetaRepair(Book b) {
    if (b.sourceId == kLocalBookSourceId) return false;
    return SourceCrawlerService.sanitizeBadge(b.category) != b.category ||
        SourceCrawlerService.cleanSeoIntro(b.intro) != b.intro ||
        SourceCrawlerService.sanitizeLatestChapter(b.latestChapterTitle) !=
            b.latestChapterTitle.trim() ||
        b.statusText.length > 16 ||
        b.intro.trim().isEmpty ||
        b.latestChapterTitle.trim().isEmpty;
  }

  /// 移出本地藏书前的二次确认弹窗，明确告知将释放正文、书签与封面磁盘空间
  static Future<bool> confirmRemoveLocalBook(
    BuildContext context,
    String title,
  ) async {
    final tokens = SoftTokens.of(context);
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.card,
        title: Text('移出并清理本地藏书？', style: TextStyle(color: tokens.textPrimary)),
        content: Text(
          '移出《$title》后，将同步删除本地存储的章节正文、书签与封面文件以释放磁盘空间，后续需重新导入。',
          style: TextStyle(color: tokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('取消', style: TextStyle(color: tokens.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('确认移出', style: TextStyle(color: tokens.danger)),
          ),
        ],
      ),
    );
    return res == true;
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

    var currentBook = existing;
    if (currentBook.hasUnreadUpdate) {
      await db.setBookUnreadUpdate(currentBook.id, false);
      currentBook = currentBook.copyWith(hasUnreadUpdate: false);
    }

    final chapters = await db.getChaptersByBook(currentBook.id);
    if (currentBook.sourceId == kLocalBookSourceId) {
      return (book: currentBook, chapters: chapters, sourceName: '本地导入');
    }

    final rule = await sourceRepo.getRuleById(currentBook.sourceId);
    final aggCover = aggregatedMatch?.bestCoverUrl ?? '';

    if (chapters.isNotEmpty && currentBook.coverUrl.isEmpty && aggCover.isNotEmpty) {
      currentBook = await shelfRepo.ensureBookWithChapters(
        bookId: currentBook.id,
        title: currentBook.title,
        author: currentBook.author,
        coverUrl: aggCover,
        intro: currentBook.intro,
        category: currentBook.category,
        statusText: currentBook.statusText,
        latestChapterTitle: currentBook.latestChapterTitle,
        lastUpdateTime: currentBook.lastUpdateTime,
        sourceId: currentBook.sourceId,
        bookUrl: currentBook.bookUrl,
        tocUrl: currentBook.tocUrl,
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

  /// 仅拉取单页详情元信息（用于换源后补全真实 tocUrl 与简介，绝不重复抓取目录页）
  static Future<ParsedBookDetail?> _fetchDetailMetaOnly(
    WidgetRef ref,
    BookSourceRule rule,
    String bookUrl,
  ) async {
    try {
      final httpClient = ref.read(appHttpClientProvider);
      final res = await httpClient.fetchText(
        bookUrl,
        referer: rule.baseUrl,
        charsetHint: rule.charset,
      );
      final doc = html_parser.parse(res.body);
      final rootEl = doc.documentElement;
      final rootNode =
          rootEl != null ? EvaluatedNode.html(rootEl) : EvaluatedNode.text('');
      const ev = RuleEvaluator();
      String evalOrOg(RuleField f, String og, {String urlBase = ''}) {
        final v = ev.evaluateField(rootNode, f, baseUrl: urlBase);
        return v.isNotEmpty
            ? v
            : BookMetadataSanitizer.extractOgMeta(ev, rootNode, og, baseUrl: urlBase);
      }

      final rawToc = rule.detail.tocUrl.selector.trim().isEmpty
          ? ''
          : ev.evaluateField(rootNode, rule.detail.tocUrl, baseUrl: res.finalUrl);
      final uri = Uri.tryParse(rawToc);
      final validToc = uri != null &&
              (uri.isScheme('http') || uri.isScheme('https')) &&
              uri.host.isNotEmpty
          ? rawToc
          : res.finalUrl;

      return ParsedBookDetail(
        title: evalOrOg(rule.detail.title, 'og:title'),
        author: evalOrOg(rule.detail.author, 'og:novel:author'),
        intro: SourceCrawlerService.cleanSeoIntro(
          evalOrOg(rule.detail.intro, 'og:description'),
        ),
        coverUrl: evalOrOg(rule.detail.coverUrl, 'og:image', urlBase: res.finalUrl),
        tocUrl: validToc,
        statusText: SourceCrawlerService.sanitizeBadge(
          evalOrOg(rule.detail.statusText, 'og:novel:status'),
        ),
        category: SourceCrawlerService.sanitizeBadge(
          evalOrOg(rule.detail.category, 'og:novel:category'),
        ),
        latestChapter: SourceCrawlerService.sanitizeLatestChapter(
          evalOrOg(rule.detail.latestChapter, 'og:novel:latest_chapter_name'),
        ),
        lastUpdateTime: SourceCrawlerService.sanitizeUpdateTime(
          evalOrOg(rule.detail.lastUpdateTime, 'og:novel:update_time'),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// 执行换源写库并复用已拉取章节列表，同时透传真实 tocUrl 避免二次重复拉取目录
  static Future<({Book? book, List<Chapter> chapters, String sourceName})>
      applySwitchedSource({
    required WidgetRef ref,
    required Book oldBook,
    required BookSourceRule rule,
    required SourceSearchHit hit,
    required List<ParsedChapterEntry> chapters,
    String? tocUrl,
  }) async {
    final db = ref.read(appDatabaseProvider);
    ParsedBookDetail? detail;
    final hasExplicitToc = tocUrl != null && tocUrl.trim().isNotEmpty;
    final needDetailMeta = !hasExplicitToc &&
        (rule.detail.tocUrl.selector.trim().isNotEmpty ||
            SourceCrawlerService.cleanSeoIntro(hit.intro).isEmpty);
    if (needDetailMeta) {
      detail = await _fetchDetailMetaOnly(ref, rule, hit.bookUrl);
    }

    final resolvedTocUrl = firstNonEmpty(
      [tocUrl ?? '', detail?.tocUrl ?? '', hit.bookUrl],
      fallback: hit.bookUrl,
    );
    await ref.read(shelfRepositoryProvider).switchBookSource(
          bookId: oldBook.id,
          newSourceId: rule.id,
          newBookUrl: hit.bookUrl,
          newTocUrl: resolvedTocUrl,
          newChapters: chapters,
          preferredChapterTitle: oldBook.currentChapterTitle,
          fallbackChapterIndex: oldBook.currentChapterIndex,
          newIntro: firstNonEmpty([detail?.intro ?? '', hit.intro]),
          newCategory: detail?.category,
          newStatusText: detail?.statusText,
          newLatestChapterTitle: firstNonEmpty([
            detail?.latestChapter ?? '',
            hit.latestChapter,
          ]),
          newLastUpdateTime: detail?.lastUpdateTime,
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
