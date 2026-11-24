import 'package:drift/drift.dart';
import 'app_database.dart';

/// 书签表 DAO 扩展（基于 AppDatabase 暴露响应式监听与增删查询）
extension BookmarkDaoExt on AppDatabase {
  /// 实时监听单本书的书签列表（最新添加在前）
  Stream<List<Bookmark>> watchBookmarksByBook(String bookId) {
    return (select(bookmarks)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .watch();
  }

  /// 获取单本书全部书签（最新添加在前）
  Future<List<Bookmark>> getBookmarksByBook(String bookId) {
    return (select(bookmarks)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .get();
  }

  /// 新增书签并返回自增主键 ID
  Future<int> addBookmark({
    required String bookId,
    required int chapterIndex,
    required String chapterTitle,
    int charOffset = 0,
    String excerpt = '',
  }) {
    final cleanExcerpt = excerpt.trim();
    return into(bookmarks).insert(
      BookmarksCompanion.insert(
        bookId: bookId,
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
        charOffset: Value(charOffset),
        excerpt: Value(cleanExcerpt),
        createdAt: DateTime.now(),
      ),
    );
  }

  /// 按主键删除单条书签
  Future<int> deleteBookmark(int id) {
    return (delete(bookmarks)..where((t) => t.id.equals(id))).go();
  }

  /// 清空单本书全部书签
  Future<int> deleteBookmarksByBook(String bookId) {
    return (delete(bookmarks)..where((t) => t.bookId.equals(bookId))).go();
  }
}
