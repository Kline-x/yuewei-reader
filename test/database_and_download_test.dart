import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuewei_reader/core/database/app_database.dart';
import 'package:yuewei_reader/core/network/app_http_client.dart';
import 'package:yuewei_reader/core/storage/chapter_file_store.dart';
import 'package:yuewei_reader/features/download/download_manager.dart';
import 'package:yuewei_reader/features/shelf/data/shelf_repository.dart';
import 'package:yuewei_reader/features/sources/data/source_repository.dart';
import 'package:yuewei_reader/features/sources/domain/book_match_models.dart';
import 'package:yuewei_reader/features/sources/engine/source_crawler_service.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late ChapterFileStore fileStore;
  late DownloadManager downloadMgr;
  late ShelfRepository shelfRepo;
  late AppHttpClient httpClient;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('yuewei_test_');
    db = AppDatabase(NativeDatabase.memory());
    fileStore = ChapterFileStore(rootDirProvider: () async => tempDir);
    httpClient = AppHttpClient();
    final sourceRepo = SourceRepository(db: db, httpClient: httpClient);
    final crawler = SourceCrawlerService(httpClient: httpClient);
    downloadMgr = DownloadManager(
      db: db,
      fileStore: fileStore,
      sourceRepo: sourceRepo,
      crawler: crawler,
    );
    shelfRepo = ShelfRepository(
      db: db,
      fileStore: fileStore,
      downloadManager: downloadMgr,
    );
  });

  tearDown(() async {
    downloadMgr.dispose();
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('存储隔离、书架逻辑、清缓存与换源事务测试', () {
    test('ChapterFileStore 严格阻断路径穿越漏洞且读写字节一致', () async {
      final safeName = ChapterFileStore.safeBookDirName('../../etc/passwd');
      expect(safeName.contains('..'), isFalse);
      expect(safeName.contains('/'), isFalse);

      final bytes = await fileStore.writeChapter('book/..//1', 0, '第一页测试正文');
      expect(bytes, greaterThan(0));
      final loaded = await fileStore.readChapter('book/..//1', 0);
      expect(loaded, '第一页测试正文');
    });

    test('未读书籍进度恒为 0%，排序、延迟移出、全库清缓存与无感换源严格一致', () async {
      final book = await shelfRepo.ensureBookWithChapters(
        bookId: 'book_alpha',
        title: '雪夜钟声',
        author: '唐宁',
        coverUrl: '',
        intro: '测试简介',
        category: '奇幻',
        statusText: '连载中',
        sourceId: 'src_1',
        bookUrl: 'https://a.test/1',
        tocUrl: 'https://a.test/1',
        putInShelf: true,
        chapters: const [
          ParsedChapterEntry(index: 0, title: '第一章 启程', url: 'https://a.test/c1'),
          ParsedChapterEntry(index: 1, title: '第二章 雾港', url: 'https://a.test/c2'),
          ParsedChapterEntry(index: 2, title: '第三章 回响', url: 'https://a.test/c3'),
        ],
      );

      expect(book.hasEverRead, isFalse);
      expect(ShelfRepository.computeProgress(book), 0.0);
      expect(ShelfRepository.formatProgressLabel(book), '未读 · 0%');

      // 模拟已缓存章节，测试 watchTotalCachedBytes 与 clearAllCaches 归零
      final b0 = await fileStore.writeChapter('book_alpha', 0, '测试缓存内容');
      await db.markChapterCached(
        bookId: 'book_alpha',
        chapterIndex: 0,
        isCached: true,
        cachedBytes: b0,
      );
      expect(await db.watchTotalCachedBytes().first, b0);

      // 无感换源强清旧源缓存并按章名相似度精确映射章节索引
      final mappedIdx = await shelfRepo.switchBookSource(
        bookId: 'book_alpha',
        newSourceId: 'src_2',
        newBookUrl: 'https://b.test/1',
        newTocUrl: 'https://b.test/1',
        preferredChapterTitle: '第二章 雾港',
        fallbackChapterIndex: 0,
        newChapters: const [
          ParsedChapterEntry(index: 0, title: '序幕', url: 'https://b.test/c0'),
          ParsedChapterEntry(index: 1, title: '第一章 启程', url: 'https://b.test/c1'),
          ParsedChapterEntry(index: 2, title: '第二章：雾港', url: 'https://b.test/c2'),
        ],
      );
      expect(mappedIdx, 2);
      expect(await fileStore.readChapter('book_alpha', 0), isNull);

      // 重新写入缓存，验证 clearAllCaches 全清且归零
      final b1 = await fileStore.writeChapter('book_alpha', 2, '新源缓存');
      await db.markChapterCached(
        bookId: 'book_alpha',
        chapterIndex: 2,
        isCached: true,
        cachedBytes: b1,
      );
      expect(await db.watchTotalCachedBytes().first, b1);
      await shelfRepo.clearAllCaches();
      expect(await db.watchTotalCachedBytes().first, 0);
      expect(await fileStore.readChapter('book_alpha', 2), isNull);

      // 延迟撤销移出与真实物理清除
      await shelfRepo.setInShelf('book_alpha', false);
      expect(await db.getShelfBooks(), isEmpty);
      await shelfRepo.setInShelf('book_alpha', true);
      expect((await db.getShelfBooks()).length, 1);

      // 模拟读至第 1 / 500 章时应返回 '已读 <1%'（区分未读 0%）
      await shelfRepo.ensureBookWithChapters(
        bookId: 'book_long',
        title: '长篇测试',
        author: '作者',
        coverUrl: '',
        intro: '',
        category: '',
        statusText: '连载中',
        sourceId: 'src_1',
        bookUrl: 'https://a.test/long',
        tocUrl: 'https://a.test/long',
        putInShelf: true,
        chapters: List.generate(
          500,
          (i) => ParsedChapterEntry(
            index: i,
            title: '第${i + 1}章',
            url: 'https://a.test/c$i',
          ),
        ),
      );
      await db.updateReadingProgress(
        bookId: 'book_long',
        chapterIndex: 0,
        chapterTitle: '第1章',
        charOffset: 100,
      );
      final readLongBook = (await db.getBookById('book_long'))!;
      expect(ShelfRepository.formatProgressLabel(readLongBook), '已读 <1%');

      // 模拟历史旧版写入的脏 category（含脚本）和脏 intro（含 SEO 模板/JS）
      await db.upsertBook(
        BooksCompanion.insert(
          id: 'book_dirty',
          title: '待自愈旧书',
          cleanTitle: '待自愈旧书',
          sourceId: 'src_1',
          bookUrl: 'https://a.test/dirty',
          updatedAt: DateTime.now(),
        ),
      );
      await (db.update(db.books)..where((t) => t.id.equals('book_dirty'))).write(
        const BooksCompanion(
          category: drift.Value('斗破苍穹(作者)-思兔阅读...window.dataLayer'),
          intro: drift.Value('斗破苍穹(作者)-思兔阅读-最新章节无错字免费阅读\nwindow.__CF=1'),
          statusText: drift.Value('function(){return;}超过十六字的超大乱码状态串'),
        ),
      );

      final healed = await shelfRepo.ensureBookWithChapters(
        bookId: 'book_dirty',
        title: '待自愈旧书',
        author: '作者',
        coverUrl: '',
        intro: '',
        category: '',
        statusText: '连载中',
        sourceId: 'src_1',
        bookUrl: 'https://a.test/dirty',
        tocUrl: 'https://a.test/dirty',
        chapters: const [],
      );
      expect(healed.category, isEmpty);
      expect(healed.intro, isEmpty);
      expect(healed.statusText, '连载中');

      await shelfRepo.purgeBookData('book_alpha');
      await shelfRepo.purgeBookData('book_long');
      await shelfRepo.purgeBookData('book_dirty');
      expect(await db.getBookById('book_alpha'), isNull);
      expect(await db.getChaptersByBook('book_alpha'), isEmpty);
    });

    test('老书缺失简介与更新时间时通过 ensureBookWithChapters 自动补拉且无损保留原阅读进度', () async {
      await shelfRepo.ensureBookWithChapters(
        bookId: 'book_heal_meta',
        title: '斗破苍穹',
        author: '天蚕土豆',
        coverUrl: '',
        intro: '',
        category: '',
        statusText: '连载中',
        sourceId: 'builtin_biqugezwx',
        bookUrl: 'https://www.biqugezwx.com/605/',
        tocUrl: 'https://www.biqugezwx.com/605/',
        putInShelf: true,
        chapters: const [
          ParsedChapterEntry(index: 0, title: '第一章', url: 'https://b/c1'),
          ParsedChapterEntry(index: 1, title: '第二章', url: 'https://b/c2'),
        ],
      );
      await db.updateReadingProgress(
        bookId: 'book_heal_meta',
        chapterIndex: 1,
        chapterTitle: '第二章',
        charOffset: 180,
      );

      final healed = await shelfRepo.ensureBookWithChapters(
        bookId: 'book_heal_meta',
        title: '斗破苍穹',
        author: '天蚕土豆',
        coverUrl: 'https://img.example/605.jpg',
        intro: '这里是属于斗气的世界，没有花俏艳丽的魔法！',
        category: '玄幻小说',
        statusText: '已完结',
        latestChapterTitle: '第1661章 萧炎云韵篇',
        lastUpdateTime: '更新时间：2026-01-22 22:43',
        sourceId: 'builtin_biqugezwx',
        bookUrl: 'https://www.biqugezwx.com/605/',
        tocUrl: 'https://www.biqugezwx.com/605/',
        chapters: const [],
      );

      expect(healed.intro, '这里是属于斗气的世界，没有花俏艳丽的魔法！');
      expect(healed.latestChapterTitle, '第1661章 萧炎云韵篇');
      expect(healed.lastUpdateTime, '2026-01-22 22:43');
      expect(healed.statusText, '已完结');
      expect(healed.isInShelf, isTrue);
      expect(healed.currentChapterIndex, 1);
      expect(healed.currentCharOffset, 180);

      await shelfRepo.purgeBookData('book_heal_meta');
    });
  });
}
