import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/database/app_database.dart';
import '../../core/storage/chapter_file_store.dart';
import '../reader/engine/content_pipeline.dart';
import '../sources/data/source_repository.dart';
import '../sources/engine/source_crawler_service.dart';
import 'tts_models.dart';

/// 后台脱离阅读器时的独立章节加载与阅读进度持久化协调器
class TtsBackgroundChapterLoader {
  TtsBackgroundChapterLoader({
    required this.db,
    required this.fileStore,
    required this.sourceRepo,
    required this.crawler,
    this.pipeline = const ContentPipeline(),
  });

  factory TtsBackgroundChapterLoader.fromRef(Ref ref) {
    return TtsBackgroundChapterLoader(
      db: ref.read(appDatabaseProvider),
      fileStore: ref.read(chapterFileStoreProvider),
      sourceRepo: ref.read(sourceRepositoryProvider),
      crawler: ref.read(crawlerServiceProvider),
    );
  }

  final AppDatabase db;
  final ChapterFileStore fileStore;
  final SourceRepository sourceRepo;
  final SourceCrawlerService crawler;
  final ContentPipeline pipeline;

  /// 按 (bookId, targetChapterIndex) 加载目标章正文段落：
  /// 优先读取沙盒磁盘缓存；未缓存且为在线书时自动抓取、防串章校验并写盘标记 `isCached`。
  Future<TtsChapterPayload?> loadChapter({
    required String bookId,
    required int targetChapterIndex,
  }) async {
    if (bookId.isEmpty || targetChapterIndex < 0) return null;
    try {
      final book = await db.getBookById(bookId);
      if (book == null) return null;

      final chapters = await db.getChaptersByBook(bookId);
      if (chapters.isEmpty) return null;

      Chapter? targetChapter;
      for (final ch in chapters) {
        if (ch.chapterIndex == targetChapterIndex) {
          targetChapter = ch;
          break;
        }
      }
      if (targetChapter == null) return null;

      final cached = await fileStore.readChapter(bookId, targetChapterIndex);
      if (cached != null) {
        final parsed = pipeline.parseCachedText(cached);
        if (parsed.isNotEmpty) {
          return (
            chapterIndex: targetChapterIndex,
            chapterTitle: targetChapter.title,
            paragraphs: parsed,
            totalChapters: chapters.length,
          );
        }
      }

      if (book.sourceId == kLocalBookSourceId) {
        return null;
      }

      final rule = await sourceRepo.getRuleById(book.sourceId);
      if (rule == null) return null;

      final paragraphs = await crawler.fetchChapterParagraphs(
        rule,
        targetChapter.url,
        chapterTitle: targetChapter.title,
      );

      if (paragraphs.isNotEmpty) {
        final latestBook = await db.getBookById(bookId);
        if (latestBook == null ||
            latestBook.sourceId != book.sourceId ||
            latestBook.bookUrl != book.bookUrl) {
          return null;
        }
        final bytes = await fileStore.writeChapter(
          bookId,
          targetChapterIndex,
          pipeline.serializeParagraphs(paragraphs),
        );
        final afterWriteBook = await db.getBookById(bookId);
        if (afterWriteBook == null ||
            afterWriteBook.sourceId != book.sourceId ||
            afterWriteBook.bookUrl != book.bookUrl) {
          return null;
        }
        await db.markChapterCached(
          bookId: bookId,
          chapterIndex: targetChapterIndex,
          isCached: true,
          cachedBytes: bytes,
        );
      }

      return (
        chapterIndex: targetChapterIndex,
        chapterTitle: targetChapter.title,
        paragraphs: paragraphs,
        totalChapters: chapters.length,
      );
    } catch (_) {
      return null;
    }
  }

  /// 原子持久化后台听书的最新章节下标、标题与字符锚点
  Future<void> persistProgress({
    required String bookId,
    required int chapterIndex,
    required String chapterTitle,
    required int charOffset,
  }) {
    return persistProgressToDb(
      db,
      bookId: bookId,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      charOffset: charOffset,
    );
  }

  /// 直接对指定数据库实例执行原子阅读进度持久化
  static Future<void> persistProgressToDb(
    AppDatabase db, {
    required String bookId,
    required int chapterIndex,
    required String chapterTitle,
    required int charOffset,
  }) async {
    if (bookId.isEmpty || chapterIndex < 0) return;
    final safeOffset = charOffset < 0 ? 0 : charOffset;
    try {
      await db.updateReadingProgress(
        bookId: bookId,
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
        charOffset: safeOffset,
      );
    } catch (_) {}
  }
}
