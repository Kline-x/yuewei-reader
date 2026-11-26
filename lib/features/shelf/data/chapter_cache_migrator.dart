import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/storage/chapter_file_store.dart';
import '../../sources/domain/book_match_models.dart';

/// 目录刷新与追更时的离线缓存继承及物理文件下标对齐迁移器
class ChapterCacheMigrator {
  const ChapterCacheMigrator._();

  /// 按 chapter.url 匹配旧缓存记录；若存在下标偏移则先调用 fileStore.migrateChapterFiles
  /// 完成磁盘文件对齐，成功迁移的章节才继承 isCached = true 与 cachedBytes，杜绝正文串章。
  static Future<List<ChaptersCompanion>> prepareMergedChapterRows({
    required String bookId,
    required List<Chapter> oldChapters,
    required List<ParsedChapterEntry> newChapters,
    required ChapterFileStore fileStore,
  }) async {
    final cachedByUrl = <String, Chapter>{};
    for (final c in oldChapters) {
      if (c.isCached && c.url.isNotEmpty) {
        cachedByUrl.putIfAbsent(c.url, () => c);
      }
    }

    if (cachedByUrl.isEmpty) {
      return newChapters
          .map(
            (c) => ChaptersCompanion.insert(
              bookId: bookId,
              chapterIndex: c.index,
              title: c.title,
              url: c.url,
            ),
          )
          .toList();
    }

    final matchedByNewIdx = <int, Chapter>{};
    final oldToNew = <int, int>{};
    final usedOldIndices = <int>{};
    var hasIndexShift = false;

    for (final c in newChapters) {
      final prev = cachedByUrl[c.url];
      if (prev != null && usedOldIndices.add(prev.chapterIndex)) {
        matchedByNewIdx[c.index] = prev;
        oldToNew[prev.chapterIndex] = c.index;
        if (prev.chapterIndex != c.index) {
          hasIndexShift = true;
        }
      }
    }

    Set<int>? migratedNewIndices;
    if (hasIndexShift) {
      migratedNewIndices = await fileStore.migrateChapterFiles(
        bookId,
        oldToNew,
        pruneUnlisted: true,
      );
    }

    return newChapters.map((c) {
      final prev = matchedByNewIdx[c.index];
      final keepCached = prev != null &&
          (!hasIndexShift || (migratedNewIndices?.contains(c.index) ?? false));
      return ChaptersCompanion.insert(
        bookId: bookId,
        chapterIndex: c.index,
        title: c.title,
        url: c.url,
        isCached: Value(keepCached),
        cachedBytes: Value(keepCached ? prev.cachedBytes : 0),
      );
    }).toList();
  }
}
