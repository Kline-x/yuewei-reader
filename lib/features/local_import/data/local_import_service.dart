import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import '../../../core/database/app_database.dart';
import '../../../core/storage/chapter_file_store.dart';
import '../../sources/domain/book_match_models.dart';
import '../engine/charset_and_txt_parser.dart';
import '../engine/epub_book_parser.dart';

/// 本地 TXT / EPUB 书籍导入服务（幂等防重入 + 120MB OOM 防护 + 临时副本回收）
class LocalImportService {
  LocalImportService({
    required this.db,
    required this.fileStore,
    this.maxFileBytes = maxImportFileBytes,
  });

  static const int maxImportFileBytes = 120 * 1024 * 1024;

  final AppDatabase db;
  final ChapterFileStore fileStore;
  final int maxFileBytes;

  /// 根据文件字节生成幂等 `local_<shortHash>` 主键，防止重复导入产生多条书架记录
  static String computeBookId(List<int> bytes) {
    var h1 = 0x811c9dc5;
    var h2 = 0x9e3779b9;
    for (final b in bytes) {
      h1 ^= b;
      h1 = (h1 * 0x01000193) & 0xFFFFFFFF;
      h2 = ((h2 << 5) | (h2 >>> 27)) & 0xFFFFFFFF;
      h2 ^= (b + 0x517cc1b7) & 0xFFFFFFFF;
    }
    h1 ^= bytes.length & 0xFFFFFFFF;
    h2 ^= (bytes.length * 0x85ebca6b) & 0xFFFFFFFF;
    final hex1 = h1.toRadixString(16).padLeft(8, '0');
    final hex2 = h2.toRadixString(16).padLeft(8, '0');
    return 'local_$hex1$hex2';
  }

  /// 从本地沙盒临时路径读取并导入 TXT / EPUB（超 120MB 拦截，结束后自动清理 picked_books/ 副本）
  Future<Book> importFromFile(
    String filePath, {
    String? originalFileName,
  }) async {
    final file = File(filePath);
    try {
      if (!await file.exists()) {
        throw FileSystemException('本地书籍文件不存在', filePath);
      }
      final fileSize = await file.length();
      if (fileSize > maxFileBytes) {
        throw const FormatException('所选书籍文件超过 120MB 上限，暂不支持导入');
      }
      final bytes = await file.readAsBytes();
      final name = (originalFileName != null && originalFileName.trim().isNotEmpty)
          ? originalFileName.trim()
          : p.basename(filePath);
      return await importFromBytes(name, bytes);
    } finally {
      await _cleanupPickedTempCopy(file);
    }
  }

  /// 仅清理位于沙盒临时目录 picked_books/ 路径段下的源拷贝副本，杜绝沙盒磁盘泄漏
  static Future<void> _cleanupPickedTempCopy(File file) async {
    try {
      final segments = p.split(file.path);
      if (!segments.contains('picked_books')) return;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// 从原始字节流解析并导入本地书籍（同时供原生选择器与 Wi-Fi 传书复用）
  Future<Book> importFromBytes(String fileName, List<int> bytes) async {
    if (bytes.isEmpty) {
      throw const FormatException('所选文件为空，无法导入');
    }
    if (bytes.length > maxFileBytes) {
      throw const FormatException('所选书籍文件超过 120MB 上限，暂不支持导入');
    }

    final isEpub = _looksLikeEpub(fileName, bytes);
    final parsed = isEpub
        ? await EpubBookParser.parseInIsolate(bytes: bytes, fileName: fileName)
        : await CharsetAndTxtParser.parseInIsolate(
            bytes: bytes,
            fileName: fileName,
          );

    if (parsed.chapters.isEmpty) {
      throw const FormatException('未能从文件中解析出可读章节正文');
    }

    final bookId = computeBookId(bytes);
    String? savedCoverPath;
    if (parsed.coverBytes != null && parsed.coverBytes!.isNotEmpty) {
      savedCoverPath = await fileStore.saveBookCoverBytes(
        bookId,
        parsed.coverBytes!,
        ext: parsed.coverExt,
      );
    }

    // 清理同 ID 旧章节文件后再分批落盘，避免章节数缩减后遗留孤立文件
    await fileStore.clearBookCache(bookId);
    final chapterRows = <ChaptersCompanion>[];
    const batchSize = 16;
    for (var i = 0; i < parsed.chapters.length; i += batchSize) {
      final slice = parsed.chapters.sublist(
        i,
        (i + batchSize).clamp(0, parsed.chapters.length),
      );
      final writtenBytes = await Future.wait(
        slice.map(
          (ch) => fileStore.writeChapter(bookId, ch.index, ch.serializedContent),
        ),
      );
      for (var j = 0; j < slice.length; j++) {
        final ch = slice[j];
        chapterRows.add(
          ChaptersCompanion.insert(
            bookId: bookId,
            chapterIndex: ch.index,
            title: ch.title,
            url: 'local://$bookId/${ch.index}',
            isCached: const Value(true),
            cachedBytes: Value(writtenBytes[j]),
          ),
        );
      }
    }

    final now = DateTime.now();
    await db.transaction(() async {
      final existing = await db.getBookById(bookId);
      final total = parsed.chapters.length;
      final keptIndex = existing != null
          ? existing.currentChapterIndex.clamp(0, total - 1)
          : 0;
      final keptTitle = existing != null && existing.hasEverRead
          ? parsed.chapters[keptIndex].title
          : parsed.chapters.first.title;

      await db.into(db.books).insertOnConflictUpdate(
            BooksCompanion(
              id: Value(bookId),
              title: Value(parsed.title),
              cleanTitle: Value(SourceSearchHit.normalizeBookKey(parsed.title)),
              author: Value(
                parsed.author.isNotEmpty ? parsed.author : '本地文档',
              ),
              coverUrl: Value(savedCoverPath ?? existing?.coverUrl ?? ''),
              intro: Value(
                parsed.intro.isNotEmpty
                    ? parsed.intro
                    : (existing?.intro ?? ''),
              ),
              category: Value(
                parsed.format == 'epub' ? 'EPUB 藏书' : 'TXT 藏书',
              ),
              statusText: const Value('本地藏书'),
              latestChapterTitle: Value(parsed.chapters.last.title),
              lastUpdateTime: const Value('本地导入'),
              sourceId: const Value(kLocalBookSourceId),
              bookUrl: Value('local://$bookId'),
              tocUrl: Value('local://$bookId/toc'),
              totalChapters: Value(total),
              currentChapterIndex: Value(keptIndex),
              currentChapterTitle: Value(keptTitle),
              currentCharOffset: Value(existing?.currentCharOffset ?? 0),
              hasEverRead: Value(existing?.hasEverRead ?? false),
              isPinned: Value(existing?.isPinned ?? false),
              isInShelf: const Value(true),
              hasUnreadUpdate: const Value(false),
              lastReadAt: Value(existing?.lastReadAt),
              addedAt: Value(existing?.addedAt ?? now),
              updatedAt: Value(now),
            ),
          );

      await (db.delete(db.chapters)..where((t) => t.bookId.equals(bookId))).go();
      await db.batch((b) {
        b.insertAll(db.chapters, chapterRows, mode: InsertMode.insertOrReplace);
      });
    });

    return (await db.getBookById(bookId))!;
  }

  static bool _looksLikeEpub(String fileName, List<int> bytes) {
    final ext = p.extension(fileName).toLowerCase();
    if (ext == '.epub') return true;
    if (ext == '.txt') return false;
    // 无扩展名时检测 ZIP 魔数 PK\x03\x04
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
  }
}
