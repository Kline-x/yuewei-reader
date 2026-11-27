import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import 'content_pipeline.dart';

/// 阅读器章节内容加载、内存 LRU 缓存与邻居预取协调器
/// 确保相邻跨章翻页 0ms 瞬时响应，消除磁盘重复 I/O 与菊花闪烁。
class ReaderChapterLoader {
  ReaderChapterLoader({
    this.pipeline = const ContentPipeline(),
    this.maxMemoryChapters = 6,
  });

  final ContentPipeline pipeline;
  final int maxMemoryChapters;
  final LinkedHashMap<String, List<String>> _memCache = LinkedHashMap();

  String _key(String bookId, int chapterIndex) => '${bookId}_$chapterIndex';

  /// 同步探测内存缓存（若已预取则直接返回段落列表，零异步等待）
  List<String>? peekMemory(String bookId, int chapterIndex) {
    final k = _key(bookId, chapterIndex);
    final hit = _memCache.remove(k);
    if (hit != null) {
      _memCache[k] = hit;
    }
    return hit;
  }

  /// 清理整本书的内存段落缓存（用于切换书源后防旧源串章）
  void invalidateBook(String bookId) {
    final prefix = '${bookId}_';
    _memCache.removeWhere((k, _) => k.startsWith(prefix));
  }

  void _putMemory(String bookId, int chapterIndex, List<String> paragraphs) {
    if (paragraphs.isEmpty) return;
    final k = _key(bookId, chapterIndex);
    _memCache.remove(k);
    _memCache[k] = paragraphs;
    while (_memCache.length > maxMemoryChapters) {
      _memCache.remove(_memCache.keys.first);
    }
  }

  /// 读取章节正文：内存 LRU -> 磁盘冷缓存 -> 在线抓包清洗落盘
  Future<List<String>> loadChapterParagraphs({
    required WidgetRef ref,
    required Book book,
    required Chapter chapter,
  }) async {
    final memHit = peekMemory(book.id, chapter.chapterIndex);
    if (memHit != null) return memHit;

    final fileStore = ref.read(chapterFileStoreProvider);
    final cached = await fileStore.readChapter(book.id, chapter.chapterIndex);
    if (cached != null) {
      final parsed = pipeline.parseCachedText(cached);
      _putMemory(book.id, chapter.chapterIndex, parsed);
      return parsed;
    }

    final rule = await ref.read(sourceRepositoryProvider).getRuleById(book.sourceId);
    if (rule == null) throw StateError('当前书源配置不存在');

    final paragraphs = await ref.read(crawlerServiceProvider).fetchChapterParagraphs(
          rule,
          chapter.url,
          chapterTitle: chapter.title,
        );

    if (paragraphs.isNotEmpty) {
      final db = ref.read(appDatabaseProvider);
      final latestBook = await db.getBookById(book.id);
      if (latestBook == null ||
          latestBook.sourceId != book.sourceId ||
          latestBook.bookUrl != book.bookUrl) {
        return const [];
      }
      _putMemory(book.id, chapter.chapterIndex, paragraphs);
      final bytes = await fileStore.writeChapter(
        book.id,
        chapter.chapterIndex,
        pipeline.serializeParagraphs(paragraphs),
      );
      final afterWriteBook = await db.getBookById(book.id);
      if (afterWriteBook == null ||
          afterWriteBook.sourceId != book.sourceId ||
          afterWriteBook.bookUrl != book.bookUrl) {
        invalidateBook(book.id);
        return const [];
      }
      await db.markChapterCached(
        bookId: book.id,
        chapterIndex: chapter.chapterIndex,
        isCached: true,
        cachedBytes: bytes,
      );
    }
    return paragraphs;
  }

  /// 静默预取指定章节入文件与内存 LRU，失败时静默忽略
  Future<List<String>?> prefetchToMemory({
    required WidgetRef ref,
    required Book book,
    required Chapter chapter,
  }) async {
    final mem = peekMemory(book.id, chapter.chapterIndex);
    if (mem != null) return mem;
    try {
      final res = await loadChapterParagraphs(ref: ref, book: book, chapter: chapter);
      return res.isEmpty ? null : res;
    } catch (_) {
      return null;
    }
  }
}
