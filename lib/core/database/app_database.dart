import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../storage/chapter_file_store.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// 阅微关系型数据库（ACID 事务 + 原生响应式流）
@DriftDatabase(tables: [
  Books,
  BookSources,
  Chapters,
  DownloadTasks,
  ReadingSessions,
  SearchHistory,
  AppPreferences,
  Bookmarks,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(books, books.latestChapterTitle);
            await m.addColumn(books, books.lastUpdateTime);
          }
          if (from < 3) {
            await m.addColumn(books, books.hasUnreadUpdate);
            await m.createTable(bookmarks);
          }
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'yuewei_v2_db');
  }

  /// 监听书架藏书列表（实时响应进出书架、进度、置顶与排序变更）
  Stream<List<Book>> watchShelfBooks() {
    return (select(books)..where((t) => t.isInShelf.equals(true))).watch();
  }

  /// 获取书架全部书籍
  Future<List<Book>> getShelfBooks() {
    return (select(books)..where((t) => t.isInShelf.equals(true))).get();
  }

  /// 根据主键获取单本书
  Future<Book?> getBookById(String bookId) {
    return (select(books)..where((t) => t.id.equals(bookId))).getSingleOrNull();
  }

  /// 插入或更新书籍元数据（保留已存在的阅读进度）
  Future<void> upsertBook(BooksCompanion entry) async {
    await into(books).insertOnConflictUpdate(entry);
  }

  /// 精准更新阅读进度（原子更新，彻底杜绝并发丢更新）
  Future<void> updateReadingProgress({
    required String bookId,
    required int chapterIndex,
    required String chapterTitle,
    required int charOffset,
  }) async {
    final now = DateTime.now();
    await (update(books)..where((t) => t.id.equals(bookId))).write(
      BooksCompanion(
        currentChapterIndex: Value(chapterIndex),
        currentChapterTitle: Value(chapterTitle),
        currentCharOffset: Value(charOffset),
        hasEverRead: const Value(true),
        lastReadAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// 获取/监听单本书目录
  Future<List<Chapter>> getChaptersByBook(String bookId) {
    return (select(chapters)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([(t) => OrderingTerm.asc(t.chapterIndex)]))
        .get();
  }

  Stream<List<Chapter>> watchChaptersByBook(String bookId) {
    return (select(chapters)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([(t) => OrderingTerm.asc(t.chapterIndex)]))
        .watch();
  }

  /// 原子替换整本书目录并更新总章数
  Future<void> replaceBookChapters(
    String bookId,
    List<ChaptersCompanion> rows,
  ) async {
    await transaction(() async {
      await (delete(chapters)..where((t) => t.bookId.equals(bookId))).go();
      if (rows.isNotEmpty) {
        await batch((b) {
          b.insertAll(chapters, rows, mode: InsertMode.insertOrReplace);
        });
      }
      await (update(books)..where((t) => t.id.equals(bookId))).write(
        BooksCompanion(
          totalChapters: Value(rows.length),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  /// 标记章节本地缓存状态
  Future<void> markChapterCached({
    required String bookId,
    required int chapterIndex,
    required bool isCached,
    required int cachedBytes,
  }) async {
    await (update(chapters)
          ..where(
            (t) =>
                t.bookId.equals(bookId) & t.chapterIndex.equals(chapterIndex),
          ))
        .write(
      ChaptersCompanion(
        isCached: Value(isCached),
        cachedBytes: Value(cachedBytes),
      ),
    );
  }

  /// 记录阅读会话时长
  Future<void> recordReadingSeconds(String bookId, int seconds) async {
    if (seconds <= 0) return;
    final now = DateTime.now();
    final key =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await into(readingSessions).insert(
      ReadingSessionsCompanion.insert(
        bookId: bookId,
        dateKey: key,
        durationSeconds: seconds,
        createdAt: now,
      ),
    );
  }

  /// 实时监听今日阅读分钟数
  Stream<int> watchTodayReadingMinutes() {
    final now = DateTime.now();
    final key =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final query = select(readingSessions)
      ..where((t) => t.dateKey.equals(key));
    return query.watch().map((rows) {
      final totalSec = rows.fold<int>(0, (sum, r) => sum + r.durationSeconds);
      return totalSec ~/ 60;
    });
  }

  /// 实时监听历史总阅读秒数
  Stream<int> watchTotalReadingSeconds() {
    return select(readingSessions).watch().map(
          (rows) => rows.fold<int>(0, (sum, r) => sum + r.durationSeconds),
        );
  }

  /// 更新书籍未读更新徽标状态
  Future<void> setBookUnreadUpdate(String bookId, bool hasUpdate) async {
    await (update(books)..where((t) => t.id.equals(bookId))).write(
      BooksCompanion(hasUnreadUpdate: Value(hasUpdate)),
    );
  }

  /// 实时监听已缓存总字节数（仅统计非本地导入书籍的在线缓存字节）
  Stream<int> watchTotalCachedBytes() {
    final query = select(chapters).join([
      innerJoin(books, books.id.equalsExp(chapters.bookId)),
    ])
      ..where(
        chapters.isCached.equals(true) &
            books.sourceId.equals(kLocalBookSourceId).not(),
      );
    return query.watch().map(
          (rows) => rows.fold<int>(
            0,
            (sum, row) => sum + row.readTable(chapters).cachedBytes,
          ),
        );
  }

  /// 监听单本书已缓存章数及字节数
  Stream<(int cachedCount, int cachedBytes)> watchBookCacheStats(
    String bookId,
  ) {
    return (select(chapters)
          ..where((t) => t.bookId.equals(bookId) & t.isCached.equals(true)))
        .watch()
        .map((rows) {
      final bytes = rows.fold<int>(0, (sum, r) => sum + r.cachedBytes);
      return (rows.length, bytes);
    });
  }

  /// 监听所有书源
  Stream<List<BookSource>> watchAllSources() {
    return (select(bookSources)
          ..orderBy([
            (t) => OrderingTerm.desc(t.enabled),
            (t) => OrderingTerm.desc(t.healthScore),
          ]))
        .watch();
  }

  /// 读写偏好键值对
  Future<String?> getPreference(String key) async {
    final row = await (select(appPreferences)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setPreference(String key, String value) async {
    await into(appPreferences).insertOnConflictUpdate(
      AppPreferencesCompanion.insert(key: key, value: value),
    );
  }

  /// 搜索历史读写
  Stream<List<SearchHistoryData>> watchSearchHistory() {
    return (select(searchHistory)
          ..orderBy([(t) => OrderingTerm.desc(t.searchedAt)])
          ..limit(12))
        .watch();
  }

  Future<void> saveSearchKeyword(String keyword) async {
    final clean = keyword.trim();
    if (clean.isEmpty) return;
    await into(searchHistory).insertOnConflictUpdate(
      SearchHistoryCompanion.insert(
        keyword: clean,
        searchedAt: DateTime.now(),
      ),
    );
  }

  Future<void> clearSearchHistory() async {
    await delete(searchHistory).go();
  }
}
