import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/bookmark_dao.dart';
import '../../../core/storage/chapter_file_store.dart';
import '../../download/download_manager.dart';
import '../../sources/domain/book_match_models.dart';
import '../../sources/engine/source_crawler_service.dart';
import 'chapter_cache_migrator.dart';
import 'shelf_book_sorter.dart';

export 'shelf_book_sorter.dart' show ShelfSortMode;

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
  static double computeProgress(Book book) =>
      ShelfBookSorter.computeProgress(book);

  static String formatProgressLabel(Book book) =>
      ShelfBookSorter.formatProgressLabel(book);

  static List<Book> sortBooks(List<Book> input, ShelfSortMode mode) =>
      ShelfBookSorter.sortBooks(input, mode);

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

    final isSameSource = existing != null && existing.sourceId == sourceId;
    List<ChaptersCompanion>? chapterRows;
    if (chapters.isNotEmpty) {
      if (isSameSource) {
        final oldChapters = await db.getChaptersByBook(bookId);
        chapterRows = await ChapterCacheMigrator.prepareMergedChapterRows(
          bookId: bookId,
          oldChapters: oldChapters,
          newChapters: chapters,
          fileStore: fileStore,
        );
      } else {
        chapterRows = chapters
            .map((c) => ChaptersCompanion.insert(
                  bookId: bookId, chapterIndex: c.index, title: c.title, url: c.url))
            .toList();
      }
    }

    await db.transaction(() async {
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
          totalChapters: Value(
            chapters.isNotEmpty ? chapters.length : (existing?.totalChapters ?? 0),
          ),
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

      if (chapterRows != null) {
        await (db.delete(db.chapters)..where((t) => t.bookId.equals(bookId))).go();
        await db.batch((b) {
          b.insertAll(db.chapters, chapterRows!, mode: InsertMode.insertOrReplace);
        });
      }
    });

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

  /// 彻底物理清理单本书（严格按主键 bookId 删除，同步清理书签与本地封面）
  Future<void> purgeBookData(String bookId) async {
    downloadManager.cancelDownload(bookId);
    await fileStore.clearBookCache(bookId);
    await fileStore.deleteBookCover(bookId);
    await db.transaction(() async {
      await (db.delete(db.chapters)..where((t) => t.bookId.equals(bookId))).go();
      await (db.delete(db.downloadTasks)..where((t) => t.bookId.equals(bookId))).go();
      await db.deleteBookmarksByBook(bookId);
      await (db.delete(db.books)..where((t) => t.id.equals(bookId))).go();
    });
  }

  /// 仅当书籍仍处于非书架状态时才执行物理清理（供 4 秒撤销条提交前二次核验）
  Future<void> purgeBookDataIfNotInShelf(String bookId) async {
    final current = await db.getBookById(bookId);
    if (current == null || current.isInShelf) return;
    await purgeBookData(bookId);
  }

  /// 清空单本书离线章节文件（本地导入书籍正文绝对保留，不予清理）
  Future<void> clearBookChapterFiles(String bookId) async {
    final book = await db.getBookById(bookId);
    if (book?.sourceId == kLocalBookSourceId) return;
    downloadManager.cancelDownload(bookId);
    await fileStore.clearBookCache(bookId);
    await (db.update(db.chapters)..where((t) => t.bookId.equals(bookId))).write(
      const ChaptersCompanion(isCached: Value(false), cachedBytes: Value(0)),
    );
  }

  /// 清空非本地在架书籍的离线缓存与孤儿目录（仅在架本地书正文与封面严格保留）
  Future<void> clearAllCaches() async {
    downloadManager.cancelAll();
    final localRows = await (db.select(db.books)
          ..where(
            (t) =>
                t.sourceId.equals(kLocalBookSourceId) &
                t.isInShelf.equals(true),
          ))
        .get();
    final localIds = localRows.map((b) => b.id).toSet();
    await fileStore.clearNonLocalCaches(localIds);
    await fileStore.clearOrphanCovers(localIds);
    final stmt = localIds.isEmpty
        ? db.update(db.chapters)
        : (db.update(db.chapters)..where((t) => t.bookId.isNotIn(localIds)));
    await stmt.write(
      const ChaptersCompanion(isCached: Value(false), cachedBytes: Value(0)),
    );
  }

  /// 无感换源：停掉在途下载 → 清空旧源缓存 → 单事务替换目录、更新书源与重映射书签下标
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
      targetIdx = _matchChapterIndex(newChapters, preferredChapterTitle, targetIdx);
    }
    targetIdx = newChapters.isEmpty ? 0 : targetIdx.clamp(0, newChapters.length - 1);

    final targetTitle = newChapters.isNotEmpty ? newChapters[targetIdx].title : '';
    final cleanIntro = SourceCrawlerService.cleanSeoIntro(newIntro ?? '');
    final cleanCat = SourceCrawlerService.sanitizeBadge(newCategory ?? '');
    final cleanStatus = SourceCrawlerService.sanitizeBadge(newStatusText ?? '');
    final cleanLatest = SourceCrawlerService.sanitizeLatestChapter(newLatestChapterTitle ?? '');
    final resolvedLatest = cleanLatest.isNotEmpty
        ? cleanLatest
        : (newChapters.isNotEmpty ? newChapters.last.title : '');
    final cleanUpdate = SourceCrawlerService.sanitizeUpdateTime(newLastUpdateTime ?? '');
    final chapterRows = newChapters
        .map((c) => ChaptersCompanion.insert(
              bookId: bookId, chapterIndex: c.index, title: c.title, url: c.url))
        .toList();

    await db.transaction(() async {
      await (db.delete(db.chapters)..where((t) => t.bookId.equals(bookId))).go();
      if (chapterRows.isNotEmpty) {
        await db.batch((b) {
          b.insertAll(db.chapters, chapterRows, mode: InsertMode.insertOrReplace);
        });
      }
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
          statusText: cleanStatus.isNotEmpty ? Value(cleanStatus) : const Value.absent(),
          latestChapterTitle:
              resolvedLatest.isNotEmpty ? Value(resolvedLatest) : const Value.absent(),
          lastUpdateTime: cleanUpdate.isNotEmpty ? Value(cleanUpdate) : const Value.absent(),
          updatedAt: Value(DateTime.now()),
        ),
      );
      if (newChapters.isNotEmpty) {
        final existingBookmarks = await db.getBookmarksByBook(bookId);
        for (final bm in existingBookmarks) {
          final remapped = _matchChapterIndex(newChapters, bm.chapterTitle, bm.chapterIndex);
          if (remapped != bm.chapterIndex) {
            await (db.update(db.bookmarks)..where((t) => t.id.equals(bm.id))).write(
              BookmarksCompanion(chapterIndex: Value(remapped)),
            );
          }
        }
      }
    });
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
    if (cleanTarget.isEmpty) return fallbackIndex.clamp(0, chapters.length - 1);
    for (var i = 0; i < chapters.length; i++) {
      if (norm(chapters[i].title) == cleanTarget) return i;
    }
    for (var i = 0; i < chapters.length; i++) {
      final cand = norm(chapters[i].title);
      if (cand.isNotEmpty && (cand.contains(cleanTarget) || cleanTarget.contains(cand))) {
        return i;
      }
    }
    return fallbackIndex.clamp(0, chapters.length - 1);
  }
}
