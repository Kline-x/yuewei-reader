import 'package:drift/drift.dart';
import 'package:lpinyin/lpinyin.dart';
import '../../../core/database/app_database.dart';
import '../../../core/storage/chapter_file_store.dart';
import '../../download/download_manager.dart';
import '../../sources/domain/book_match_models.dart';
import '../../sources/engine/source_crawler_service.dart';

enum ShelfSortMode {
  lastRead('最近阅读'),
  pinyin('书名拼音'),
  progress('阅读进度');

  const ShelfSortMode(this.label);
  final String label;

  static ShelfSortMode fromName(String? raw) {
    return ShelfSortMode.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => ShelfSortMode.lastRead,
    );
  }
}

/// 书架与书籍全生命周期仓库（ACID 事务 + 延迟真撤销 + 换源强制清缓存）
class ShelfRepository {
  ShelfRepository({
    required this.db,
    required this.fileStore,
    required this.downloadManager,
  });

  final AppDatabase db;
  final ChapterFileStore fileStore;
  final DownloadManager downloadManager;

  static const _prefSortMode = 'shelf_sort_mode';
  static const _prefGridView = 'shelf_grid_view';

  Stream<List<Book>> watchShelfBooks() => db.watchShelfBooks();

  /// 精准计算单本书阅读进度（未读过严格返回 0.0）
  static double computeProgress(Book book) {
    if (!book.hasEverRead) return 0.0;
    if (book.totalChapters <= 0) return 0.0;
    return ((book.currentChapterIndex + 1) / book.totalChapters).clamp(0.0, 1.0);
  }

  static String formatProgressLabel(Book book) {
    if (!book.hasEverRead) return '未读 · 0%';
    final ratio = computeProgress(book);
    final pct = (ratio * 100).round();
    if (pct == 0 && ratio > 0) return '已读 <1%';
    return '已读 $pct%';
  }

  static List<Book> sortBooks(List<Book> input, ShelfSortMode mode) {
    final list = List<Book>.from(input);
    final pinyinCache = <String, String>{};
    String pinyinOf(Book b) => pinyinCache.putIfAbsent(
          b.id,
          () => PinyinHelper.getShortPinyin(b.title).toLowerCase(),
        );

    list.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      switch (mode) {
        case ShelfSortMode.lastRead:
          final at = a.lastReadAt ?? a.addedAt ?? a.updatedAt;
          final bt = b.lastReadAt ?? b.addedAt ?? b.updatedAt;
          return bt.compareTo(at);
        case ShelfSortMode.pinyin:
          return pinyinOf(a).compareTo(pinyinOf(b));
        case ShelfSortMode.progress:
          return computeProgress(b).compareTo(computeProgress(a));
      }
    });
    return list;
  }

  Future<ShelfSortMode> getSortMode() async {
    return ShelfSortMode.fromName(await db.getPreference(_prefSortMode));
  }

  Future<void> saveSortMode(ShelfSortMode mode) async {
    await db.setPreference(_prefSortMode, mode.name);
  }

  Future<bool> getIsGridView() async {
    return (await db.getPreference(_prefGridView)) == 'true';
  }

  Future<void> saveIsGridView(bool isGrid) async {
    await db.setPreference(_prefGridView, isGrid.toString());
  }

  /// 确保书籍记录存在并存入目录（尚未放入书架时保留 isInShelf = false 仅作浏览缓存）
  Future<Book> ensureBookWithChapters({
    required String bookId,
    required String title,
    required String author,
    required String coverUrl,
    required String intro,
    required String category,
    required String statusText,
    String latestChapterTitle = '',
    String lastUpdateTime = '',
    required String sourceId,
    required String bookUrl,
    required String tocUrl,
    required List<ParsedChapterEntry> chapters,
    bool putInShelf = false,
  }) async {
    final existing = await db.getBookById(bookId);
    final now = DateTime.now();
    final cleanTitle = SourceSearchHit.normalizeBookKey(title);

    final cleanNewIntro = SourceCrawlerService.cleanSeoIntro(intro);
    final cleanOldIntro = SourceCrawlerService.cleanSeoIntro(existing?.intro ?? '');
    final cleanNewCat = SourceCrawlerService.sanitizeBadge(category);
    final cleanOldCat = SourceCrawlerService.sanitizeBadge(existing?.category ?? '');
    final cleanNewStatus = SourceCrawlerService.sanitizeBadge(statusText);
    final cleanOldStatus = SourceCrawlerService.sanitizeBadge(existing?.statusText ?? '');
    final cleanNewLatest = SourceCrawlerService.sanitizeLatestChapter(latestChapterTitle);
    final fallbackLatest = chapters.isNotEmpty ? chapters.last.title : '';
    final resolvedLatest = cleanNewLatest.isNotEmpty
        ? cleanNewLatest
        : (fallbackLatest.isNotEmpty
            ? fallbackLatest
            : (existing?.latestChapterTitle ?? ''));
    final cleanNewUpdate = SourceCrawlerService.sanitizeUpdateTime(lastUpdateTime);
    final cleanOldUpdate =
        SourceCrawlerService.sanitizeUpdateTime(existing?.lastUpdateTime ?? '');

    await db.upsertBook(
      BooksCompanion(
        id: Value(bookId),
        title: Value(title),
        cleanTitle: Value(cleanTitle),
        author: Value(author),
        coverUrl: Value(coverUrl.isNotEmpty ? coverUrl : (existing?.coverUrl ?? '')),
        intro: Value(cleanNewIntro.isNotEmpty ? cleanNewIntro : cleanOldIntro),
        category: Value(cleanNewCat.isNotEmpty ? cleanNewCat : cleanOldCat),
        statusText: Value(
          cleanNewStatus.isNotEmpty
              ? cleanNewStatus
              : (cleanOldStatus.isNotEmpty ? cleanOldStatus : '连载中'),
        ),
        latestChapterTitle: Value(resolvedLatest),
        lastUpdateTime: Value(
          cleanNewUpdate.isNotEmpty ? cleanNewUpdate : cleanOldUpdate,
        ),
        sourceId: Value(sourceId),
        bookUrl: Value(bookUrl),
        tocUrl: Value(tocUrl),
        totalChapters: Value(chapters.isNotEmpty ? chapters.length : (existing?.totalChapters ?? 0)),
        currentChapterIndex: Value(existing?.currentChapterIndex ?? 0),
        currentChapterTitle: Value(
          existing?.currentChapterTitle.isNotEmpty == true
              ? existing!.currentChapterTitle
              : (chapters.isNotEmpty ? chapters.first.title : ''),
        ),
        currentCharOffset: Value(existing?.currentCharOffset ?? 0),
        hasEverRead: Value(existing?.hasEverRead ?? false),
        isPinned: Value(existing?.isPinned ?? false),
        isInShelf: Value((existing?.isInShelf ?? false) || putInShelf),
        lastReadAt: Value(existing?.lastReadAt),
        addedAt: Value(existing?.addedAt ?? (putInShelf ? now : null)),
        updatedAt: Value(now),
      ),
    );

    if (chapters.isNotEmpty) {
      final rows = chapters
          .map(
            (c) => ChaptersCompanion.insert(
              bookId: bookId,
              chapterIndex: c.index,
              title: c.title,
              url: c.url,
            ),
          )
          .toList();
      await db.replaceBookChapters(bookId, rows);
    }

    return (await db.getBookById(bookId))!;
  }

  /// 加入或移出书架（移出先改标志位，撤销超时后再真正提交物理删除）
  Future<void> setInShelf(String bookId, bool inShelf) async {
    final now = DateTime.now();
    await (db.update(db.books)..where((t) => t.id.equals(bookId))).write(
      BooksCompanion(
        isInShelf: Value(inShelf),
        addedAt: inShelf ? Value(now) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> togglePin(String bookId, bool pinned) async {
    await (db.update(db.books)..where((t) => t.id.equals(bookId))).write(
      BooksCompanion(isPinned: Value(pinned), updatedAt: Value(DateTime.now())),
    );
  }

  /// 彻底物理清理单本书（严格按主键 bookId 删除，绝不误伤同名他书）
  Future<void> purgeBookData(String bookId) async {
    downloadManager.cancelDownload(bookId);
    await fileStore.clearBookCache(bookId);
    await db.transaction(() async {
      await (db.delete(db.chapters)..where((t) => t.bookId.equals(bookId))).go();
      await (db.delete(db.downloadTasks)..where((t) => t.bookId.equals(bookId)))
          .go();
      await (db.delete(db.books)..where((t) => t.id.equals(bookId))).go();
    });
  }

  /// 清空单本书离线章节文件（保留书架记录与进度）
  Future<void> clearBookChapterFiles(String bookId) async {
    downloadManager.cancelDownload(bookId);
    await fileStore.clearBookCache(bookId);
    await (db.update(db.chapters)..where((t) => t.bookId.equals(bookId))).write(
      const ChaptersCompanion(
        isCached: Value(false),
        cachedBytes: Value(0),
      ),
    );
  }

  /// 清空全库全部书籍的离线缓存文件与数据库索引（停止一切在途下载，确保统计实时归零）
  Future<void> clearAllCaches() async {
    downloadManager.cancelAll();
    await fileStore.clearAllCaches();
    await db.update(db.chapters).write(
      const ChaptersCompanion(
        isCached: Value(false),
        cachedBytes: Value(0),
      ),
    );
  }

  /// 无感换源：停掉在途下载 → 强制清空旧源章节缓存 → 替换目录 → 按章名相似度对齐新章节下标
  Future<int> switchBookSource({
    required String bookId,
    required String newSourceId,
    required String newBookUrl,
    required String newTocUrl,
    required List<ParsedChapterEntry> newChapters,
    String? preferredChapterTitle,
    int? fallbackChapterIndex,
    String? newIntro,
    String? newCategory,
    String? newStatusText,
    String? newLatestChapterTitle,
    String? newLastUpdateTime,
  }) async {
    downloadManager.cancelDownload(bookId);
    await fileStore.clearBookCache(bookId);

    var targetIdx = fallbackChapterIndex ?? 0;
    if (preferredChapterTitle != null && preferredChapterTitle.isNotEmpty) {
      final matchedIdx =
          _matchChapterIndex(newChapters, preferredChapterTitle, targetIdx);
      targetIdx = matchedIdx;
    }
    targetIdx = newChapters.isEmpty
        ? 0
        : targetIdx.clamp(0, newChapters.length - 1);

    final targetTitle =
        newChapters.isNotEmpty ? newChapters[targetIdx].title : '';
    final cleanIntro = SourceCrawlerService.cleanSeoIntro(newIntro ?? '');
    final cleanCat = SourceCrawlerService.sanitizeBadge(newCategory ?? '');
    final cleanStatus = SourceCrawlerService.sanitizeBadge(newStatusText ?? '');
    final cleanLatest = SourceCrawlerService.sanitizeLatestChapter(
      newLatestChapterTitle ?? '',
    );
    final resolvedLatest = cleanLatest.isNotEmpty
        ? cleanLatest
        : (newChapters.isNotEmpty ? newChapters.last.title : '');
    final cleanUpdate =
        SourceCrawlerService.sanitizeUpdateTime(newLastUpdateTime ?? '');

    await db.replaceBookChapters(
      bookId,
      newChapters
          .map(
            (c) => ChaptersCompanion.insert(
              bookId: bookId,
              chapterIndex: c.index,
              title: c.title,
              url: c.url,
            ),
          )
          .toList(),
    );

    await (db.update(db.books)..where((t) => t.id.equals(bookId))).write(
      BooksCompanion(
        sourceId: Value(newSourceId),
        bookUrl: Value(newBookUrl),
        tocUrl: Value(newTocUrl),
        totalChapters: Value(newChapters.length),
        currentChapterIndex: Value(targetIdx),
        currentChapterTitle: Value(targetTitle),
        currentCharOffset: const Value(0),
        intro: cleanIntro.isNotEmpty ? Value(cleanIntro) : const Value.absent(),
        category: cleanCat.isNotEmpty ? Value(cleanCat) : const Value.absent(),
        statusText:
            cleanStatus.isNotEmpty ? Value(cleanStatus) : const Value.absent(),
        latestChapterTitle: resolvedLatest.isNotEmpty
            ? Value(resolvedLatest)
            : const Value.absent(),
        lastUpdateTime:
            cleanUpdate.isNotEmpty ? Value(cleanUpdate) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return targetIdx;
  }

  static int _matchChapterIndex(
    List<ParsedChapterEntry> chapters,
    String targetTitle,
    int fallbackIndex,
  ) {
    if (chapters.isEmpty) return 0;
    String norm(String s) => s.replaceAll(RegExp(r'[\s：:【】\[\]]'), '');
    final cleanTarget = norm(targetTitle);
    for (var i = 0; i < chapters.length; i++) {
      if (norm(chapters[i].title) == cleanTarget) return i;
    }
    for (var i = 0; i < chapters.length; i++) {
      final cand = norm(chapters[i].title);
      if (cand.contains(cleanTarget) || cleanTarget.contains(cand)) return i;
    }
    return fallbackIndex.clamp(0, chapters.length - 1);
  }
}
