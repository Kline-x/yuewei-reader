import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/storage/chapter_file_store.dart';

/// 阅读器前台活跃时长计时器（退后台暂停、回前台恢复，杜绝后台挂机计入阅读时长）
class ForegroundReadingTimer {
  ForegroundReadingTimer({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    _startedAt = _clock();
  }

  final DateTime Function() _clock;
  DateTime? _startedAt;
  int _accumulatedSeconds = 0;

  bool get isRunning => _startedAt != null;

  void pause() {
    final start = _startedAt;
    if (start == null) return;
    final delta = _clock().difference(start).inSeconds;
    if (delta > 0) _accumulatedSeconds += delta;
    _startedAt = null;
  }

  void resume() {
    if (_startedAt != null) return;
    _startedAt = _clock();
  }

  int finishAndCollectSeconds() {
    pause();
    final total = _accumulatedSeconds;
    _accumulatedSeconds = 0;
    return total;
  }
}

/// 阅读器启动目录补拉协调器（云端恢复书籍无本地目录时自动联网拉取并写库）
class ReaderSessionBootstrap {
  const ReaderSessionBootstrap._();

  static bool needsRemoteTocRepair(Book? book, List<Chapter> chapters) {
    return book != null &&
        chapters.isEmpty &&
        book.sourceId != kLocalBookSourceId &&
        book.bookUrl.isNotEmpty;
  }

  static Future<({Book book, List<Chapter> chapters})?> tryRepairMissingToc({
    required WidgetRef ref,
    required AppDatabase db,
    required Book book,
  }) async {
    try {
      final rule =
          await ref.read(sourceRepositoryProvider).getRuleById(book.sourceId);
      if (rule == null) return null;
      final res = await ref
          .read(crawlerServiceProvider)
          .fetchBookDetailAndToc(rule, book.bookUrl);
      if (res.chapters.isEmpty) return null;

      await ref.read(shelfRepositoryProvider).ensureBookWithChapters(
            bookId: book.id,
            title: book.title.isNotEmpty ? book.title : res.detail.title,
            author: book.author.isNotEmpty ? book.author : res.detail.author,
            coverUrl:
                book.coverUrl.isNotEmpty ? book.coverUrl : res.detail.coverUrl,
            intro: res.detail.intro.isNotEmpty ? res.detail.intro : book.intro,
            category: res.detail.category.isNotEmpty
                ? res.detail.category
                : book.category,
            statusText: res.detail.statusText.isNotEmpty
                ? res.detail.statusText
                : book.statusText,
            latestChapterTitle: res.detail.latestChapter.isNotEmpty
                ? res.detail.latestChapter
                : res.chapters.last.title,
            lastUpdateTime: res.detail.lastUpdateTime.isNotEmpty
                ? res.detail.lastUpdateTime
                : book.lastUpdateTime,
            sourceId: book.sourceId,
            bookUrl: book.bookUrl,
            tocUrl: res.detail.tocUrl.isNotEmpty
                ? res.detail.tocUrl
                : (book.tocUrl.isNotEmpty ? book.tocUrl : book.bookUrl),
            chapters: res.chapters,
            putInShelf: book.isInShelf,
          );

      final refreshedBook = await db.getBookById(book.id);
      final refreshedChapters = await db.getChaptersByBook(book.id);
      if (refreshedBook == null || refreshedChapters.isEmpty) return null;
      return (book: refreshedBook, chapters: refreshedChapters);
    } catch (_) {
      return null;
    }
  }
}
