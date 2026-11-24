import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/storage/chapter_file_store.dart';
import '../../sources/data/source_repository.dart';
import '../../sources/engine/source_crawler_service.dart';

/// 书架在线连载追更批量核查器（自动跳过本地藏书，并发度 ≤ 4，≤ 160 行）
class ShelfUpdateChecker {
  ShelfUpdateChecker({
    required this.db,
    required this.sourceRepo,
    required this.crawler,
    this.maxConcurrency = 4,
  }) : assert(maxConcurrency >= 1 && maxConcurrency <= 4);

  final AppDatabase db;
  final SourceRepository sourceRepo;
  final SourceCrawlerService crawler;
  final int maxConcurrency;

  /// 批量检查书架在线书更新并保留原有阅读进度与已缓存章节标记
  Future<({int checked, int updated})> checkAll() async {
    final shelfBooks = await db.getShelfBooks();
    final targets = shelfBooks
        .where(
          (b) =>
              b.sourceId != kLocalBookSourceId &&
              b.bookUrl.trim().isNotEmpty,
        )
        .toList();
    if (targets.isEmpty) return (checked: 0, updated: 0);

    final workerCount =
        targets.length < maxConcurrency ? targets.length : maxConcurrency;
    var cursor = 0;
    var checked = 0;
    var updated = 0;

    Future<void> runWorker() async {
      while (true) {
        final idx = cursor++;
        if (idx >= targets.length) return;
        final res = await _checkSingle(targets[idx]);
        if (res.checked) checked++;
        if (res.updated) updated++;
      }
    }

    await Future.wait(List.generate(workerCount, (_) => runWorker()));
    return (checked: checked, updated: updated);
  }

  Future<({bool checked, bool updated})> _checkSingle(Book book) async {
    try {
      final rule = await sourceRepo.getRuleById(book.sourceId);
      if (rule == null) return (checked: false, updated: false);

      final fetched = await crawler.fetchBookDetailAndToc(rule, book.bookUrl);
      final newChapters = fetched.chapters;
      if (newChapters.isEmpty) return (checked: true, updated: false);

      final cleanedLatest = SourceCrawlerService.sanitizeLatestChapter(
        fetched.detail.latestChapter,
      );
      final resolvedLatest = cleanedLatest.isNotEmpty
          ? cleanedLatest
          : newChapters.last.title.trim();
      final resolvedTime = SourceCrawlerService.sanitizeUpdateTime(
        fetched.detail.lastUpdateTime,
      );

      final hasNewCount = newChapters.length > book.totalChapters;
      final latestChanged = resolvedLatest.isNotEmpty &&
          resolvedLatest != book.latestChapterTitle.trim();
      final timeChanged = resolvedTime.isNotEmpty &&
          resolvedTime != book.lastUpdateTime.trim();

      if (!hasNewCount && !latestChanged && !timeChanged) {
        return (checked: true, updated: false);
      }

      // 尽量保留已离线缓存章节的本地标记，同时严格锁定原阅读进度不被覆盖
      final oldChapters = await db.getChaptersByBook(book.id);
      final cachedByUrl = <String, Chapter>{
        for (final c in oldChapters)
          if (c.isCached && c.url.isNotEmpty) c.url: c,
      };

      final rows = newChapters.map((c) {
        final prev = cachedByUrl[c.url];
        return ChaptersCompanion.insert(
          bookId: book.id,
          chapterIndex: c.index,
          title: c.title,
          url: c.url,
          isCached: Value(prev != null),
          cachedBytes: Value(prev?.cachedBytes ?? 0),
        );
      }).toList();

      await db.replaceBookChapters(book.id, rows);
      await (db.update(db.books)..where((t) => t.id.equals(book.id))).write(
        BooksCompanion(
          totalChapters: Value(newChapters.length),
          latestChapterTitle: resolvedLatest.isNotEmpty
              ? Value(resolvedLatest)
              : const Value.absent(),
          lastUpdateTime: resolvedTime.isNotEmpty
              ? Value(resolvedTime)
              : const Value.absent(),
          hasUnreadUpdate: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return (checked: true, updated: true);
    } catch (_) {
      return (checked: false, updated: false);
    }
  }
}
