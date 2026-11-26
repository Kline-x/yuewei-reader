import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuewei_reader/core/database/app_database.dart';
import 'package:yuewei_reader/core/database/bookmark_dao.dart';
import 'package:yuewei_reader/core/network/app_http_client.dart';
import 'package:yuewei_reader/core/storage/chapter_file_store.dart';
import 'package:yuewei_reader/features/download/download_manager.dart';
import 'package:yuewei_reader/features/shelf/data/shelf_repository.dart';
import 'package:yuewei_reader/features/sources/data/source_repository.dart';
import 'package:yuewei_reader/features/sources/domain/book_match_models.dart';
import 'package:yuewei_reader/features/sources/domain/book_source_rule.dart';
import 'package:yuewei_reader/features/sources/engine/source_crawler_service.dart';

class _ControlledCrawler extends SourceCrawlerService {
  _ControlledCrawler({required super.httpClient});
  Completer<List<String>>? gate;
  int fetchCalls = 0;

  @override
  Future<List<String>> fetchChapterParagraphs(
    BookSourceRule src,
    String chapterUrl, {
    String? chapterTitle,
    CancelToken? cancelToken,
  }) async {
    fetchCalls++;
    if (gate != null) return gate!.future;
    return ['\u3000\u3000真实抓取正文：$chapterUrl'];
  }
}

class _HookFileStore extends ChapterFileStore {
  _HookFileStore({required super.rootDirProvider});
  void Function()? onAfterWrite;

  @override
  Future<int> writeChapter(String bookId, int chapterIndex, String content) async {
    final bytes = await super.writeChapter(bookId, chapterIndex, content);
    onAfterWrite?.call();
    return bytes;
  }
}

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late _HookFileStore fileStore;
  late DownloadManager downloadMgr;
  late ShelfRepository shelfRepo;
  late SourceRepository sourceRepo;
  late _ControlledCrawler crawler;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('yuewei_test_');
    db = AppDatabase(NativeDatabase.memory());
    fileStore = _HookFileStore(rootDirProvider: () async => tempDir);
    final httpClient = AppHttpClient();
    sourceRepo = SourceRepository(db: db, httpClient: httpClient);
    crawler = _ControlledCrawler(httpClient: httpClient);
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
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('存储隔离、书架逻辑、清缓存与换源事务测试', () {
    test('ChapterFileStore 阻断路径穿越、支持 local_cover:// 相对解析与 v4 索引/跨午夜统计', () async {
      final safeName = ChapterFileStore.safeBookDirName('../../etc/passwd');
      expect(safeName.contains('..'), isFalse);
      expect(safeName.contains('/'), isFalse);

      final bytes = await fileStore.writeChapter('book/..//1', 0, '第一页测试正文');
      expect(bytes, greaterThan(0));
      expect(await fileStore.readChapter('book/..//1', 0), '第一页测试正文');

      // local_cover:// 相对路径保存与同步/异步解析 + 路径穿越拦截
      final coverRel = await fileStore.saveBookCoverBytes('local_cov_1', [1, 2, 3, 4], ext: '.png');
      expect(coverRel, startsWith(kLocalCoverScheme));
      final syncFile = ChapterFileStore.resolveLocalCoverFileSync(coverRel);
      final asyncFile = await fileStore.resolveLocalCoverFile(coverRel);
      expect(syncFile, isNotNull);
      expect(asyncFile?.path, syncFile!.path);
      expect(syncFile.existsSync(), isTrue);
      expect(ChapterFileStore.resolveLocalCoverFileSync('local_cover://../../etc/passwd'), isNull);

      // 数据库 v4 索引核验
      expect(db.schemaVersion, 4);
      final idxRows = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
          .get();
      final idxNames = idxRows.map((r) => r.read<String>('name')).toSet();
      expect(idxNames, containsAll(['idx_bookmarks_book_id', 'idx_reading_sessions_date_key']));

      // watchTodayReadingMinutes 跨午夜自动归零验证
      final fakeStart = DateTime(2026, 11, 26, 23, 59, 59, 500);
      await db.into(db.readingSessions).insert(ReadingSessionsCompanion.insert(
        bookId: 'b_clock',
        dateKey: '2026-11-26',
        durationSeconds: 120,
        createdAt: fakeStart,
      ));
      final baseReal = DateTime.now();
      DateTime fakeClock() => fakeStart.add(DateTime.now().difference(baseReal));
      final emitted = <int>[];
      final sub = db.watchTodayReadingMinutes(nowProvider: fakeClock).listen(emitted.add);
      await Future<void>.delayed(const Duration(milliseconds: 750));
      await sub.cancel();
      expect(emitted, containsAllInOrder([2, 0]));
    });

    test('未读进度、换源单事务重映射书签、清缓存、撤销移出与脏元数据自愈', () async {
      final book = await shelfRepo.ensureBookWithChapters(
        bookId: 'book_alpha', title: '雪夜钟声', author: '唐宁',
        coverUrl: '', intro: '测试简介', category: '奇幻', statusText: '连载中',
        sourceId: 'src_1', bookUrl: 'https://a.test/1', tocUrl: 'https://a.test/1',
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

      final b0 = await fileStore.writeChapter('book_alpha', 0, '测试缓存内容');
      await db.markChapterCached(bookId: 'book_alpha', chapterIndex: 0, isCached: true, cachedBytes: b0);
      expect(await db.watchTotalCachedBytes().first, b0);

      // 添加两条书签，换源后应在同一事务内按章名自动重映射到新下标
      await db.addBookmark(bookId: 'book_alpha', chapterIndex: 0, chapterTitle: '第一章 启程', charOffset: 10);
      await db.addBookmark(bookId: 'book_alpha', chapterIndex: 1, chapterTitle: '第二章 雾港', charOffset: 42);

      final mappedIdx = await shelfRepo.switchBookSource(
        bookId: 'book_alpha', newSourceId: 'src_2',
        newBookUrl: 'https://b.test/1', newTocUrl: 'https://b.test/toc',
        preferredChapterTitle: '第二章 雾港', fallbackChapterIndex: 0,
        newChapters: const [
          ParsedChapterEntry(index: 0, title: '序幕', url: 'https://b.test/c0'),
          ParsedChapterEntry(index: 1, title: '第一章 启程', url: 'https://b.test/c1'),
          ParsedChapterEntry(index: 2, title: '第二章：雾港', url: 'https://b.test/c2'),
        ],
      );
      expect(mappedIdx, 2);
      expect(await fileStore.readChapter('book_alpha', 0), isNull);
      final remappedBms = await db.getBookmarksByBook('book_alpha');
      final bmByTitle = {for (final bm in remappedBms) bm.chapterTitle: bm.chapterIndex};
      expect(bmByTitle['第一章 启程'], 1);
      expect(bmByTitle['第二章 雾港'], 2);

      final b1 = await fileStore.writeChapter('book_alpha', 2, '新源缓存');
      await db.markChapterCached(bookId: 'book_alpha', chapterIndex: 2, isCached: true, cachedBytes: b1);
      expect(await db.watchTotalCachedBytes().first, b1);
      await shelfRepo.clearAllCaches();
      expect(await db.watchTotalCachedBytes().first, 0);
      expect(await fileStore.readChapter('book_alpha', 2), isNull);

      // 延迟撤销与二次核验防误删
      await shelfRepo.setInShelf('book_alpha', false);
      expect(await db.getShelfBooks(), isEmpty);
      await shelfRepo.setInShelf('book_alpha', true);
      await shelfRepo.purgeBookDataIfNotInShelf('book_alpha');
      expect((await db.getShelfBooks()).length, 1);

      // 1/500 章返回 '已读 <1%'
      await shelfRepo.ensureBookWithChapters(
        bookId: 'book_long', title: '长篇测试', author: '作者',
        coverUrl: '', intro: '', category: '', statusText: '连载中',
        sourceId: 'src_1', bookUrl: 'https://a.test/long', tocUrl: 'https://a.test/long',
        putInShelf: true,
        chapters: List.generate(500, (i) => ParsedChapterEntry(index: i, title: '第${i + 1}章', url: 'https://a.test/c$i')),
      );
      await db.updateReadingProgress(bookId: 'book_long', chapterIndex: 0, chapterTitle: '第1章', charOffset: 100);
      expect(ShelfRepository.formatProgressLabel((await db.getBookById('book_long'))!), '已读 <1%');

      // 历史脏元数据自愈
      await db.upsertBook(BooksCompanion.insert(
        id: 'book_dirty', title: '待自愈旧书', cleanTitle: '待自愈旧书',
        sourceId: 'src_1', bookUrl: 'https://a.test/dirty', updatedAt: DateTime.now(),
      ));
      await (db.update(db.books)..where((t) => t.id.equals('book_dirty'))).write(
        const BooksCompanion(
          category: drift.Value('斗破苍穹(作者)-思兔阅读...window.dataLayer'),
          intro: drift.Value('斗破苍穹(作者)-思兔阅读-最新章节无错字免费阅读\nwindow.__CF=1'),
          statusText: drift.Value('function(){return;}超过十六字的超大乱码状态串'),
        ),
      );
      final healed = await shelfRepo.ensureBookWithChapters(
        bookId: 'book_dirty', title: '待自愈旧书', author: '作者',
        coverUrl: '', intro: '', category: '', statusText: '连载中',
        sourceId: 'src_1', bookUrl: 'https://a.test/dirty', tocUrl: 'https://a.test/dirty',
        chapters: const [],
      );
      expect(healed.category, isEmpty);
      expect(healed.intro, isEmpty);
      expect(healed.statusText, '连载中');

      await shelfRepo.purgeBookData('book_alpha');
      await shelfRepo.purgeBookData('book_long');
      await shelfRepo.purgeBookData('book_dirty');
      expect(await db.getBookById('book_alpha'), isNull);
    });

    test('ensureBookWithChapters 非空目录刷新保留 isCached 且偏移时安全迁移正文', () async {
      await shelfRepo.ensureBookWithChapters(
        bookId: 'book_heal_meta', title: '斗破苍穹', author: '天蚕土豆',
        coverUrl: '', intro: '', category: '', statusText: '连载中',
        sourceId: 'builtin_biqugezwx', bookUrl: 'https://www.biqugezwx.com/605/',
        tocUrl: 'https://www.biqugezwx.com/605/', putInShelf: true,
        chapters: const [
          ParsedChapterEntry(index: 0, title: '第一章', url: 'https://b/c1'),
          ParsedChapterEntry(index: 1, title: '第二章', url: 'https://b/c2'),
        ],
      );
      final len0 = await fileStore.writeChapter('book_heal_meta', 0, '第一章原始缓存');
      final len1 = await fileStore.writeChapter('book_heal_meta', 1, '第二章原始缓存');
      await db.markChapterCached(bookId: 'book_heal_meta', chapterIndex: 0, isCached: true, cachedBytes: len0);
      await db.markChapterCached(bookId: 'book_heal_meta', chapterIndex: 1, isCached: true, cachedBytes: len1);
      await db.updateReadingProgress(bookId: 'book_heal_meta', chapterIndex: 1, chapterTitle: '第二章', charOffset: 180);

      // 详情页非空刷新且前部插入楔子：旧缓存标记与正文必须准确迁移不丢失
      final healed = await shelfRepo.ensureBookWithChapters(
        bookId: 'book_heal_meta', title: '斗破苍穹', author: '天蚕土豆',
        coverUrl: 'https://img.example/605.jpg', intro: '这里是属于斗气的世界，没有花俏艳丽的魔法！',
        category: '玄幻小说', statusText: '已完结', latestChapterTitle: '第1661章 萧炎云韵篇',
        lastUpdateTime: '更新时间：2026-01-22 22:43', sourceId: 'builtin_biqugezwx',
        bookUrl: 'https://www.biqugezwx.com/605/', tocUrl: 'https://www.biqugezwx.com/605/',
        chapters: const [
          ParsedChapterEntry(index: 0, title: '楔子', url: 'https://b/c0'),
          ParsedChapterEntry(index: 1, title: '第一章', url: 'https://b/c1'),
          ParsedChapterEntry(index: 2, title: '第二章', url: 'https://b/c2'),
        ],
      );

      expect(healed.intro, '这里是属于斗气的世界，没有花俏艳丽的魔法！');
      expect(healed.latestChapterTitle, '第1661章 萧炎云韵篇');
      expect(healed.lastUpdateTime, '2026-01-22 22:43');
      expect(healed.currentCharOffset, 180);
      final chs = await db.getChaptersByBook('book_heal_meta');
      expect(chs[0].isCached, isFalse);
      expect(chs[1].isCached, isTrue);
      expect(chs[1].cachedBytes, len0);
      expect(chs[2].isCached, isTrue);
      expect(chs[2].cachedBytes, len1);
      expect(await fileStore.readChapter('book_heal_meta', 0), isNull);
      expect(await fileStore.readChapter('book_heal_meta', 1), '第一章原始缓存');
      expect(await fileStore.readChapter('book_heal_meta', 2), '第二章原始缓存');
    });

    test('DownloadManager startDownload / cancelDownload 并发世代守卫与写盘后取消拦截', () async {
      await sourceRepo.importLegadoJson(jsonEncode([{
        'bookSourceName': '下载测试源', 'bookSourceUrl': 'https://dl.example.com',
        'searchUrl': 'https://dl.example.com/s?q={{key}}',
        'ruleSearch': {'bookList': '.b', 'name': 'a', 'bookUrl': 'a@href'},
        'ruleToc': {'chapterList': '.c a', 'chapterName': 'text', 'chapterUrl': 'href'},
        'ruleContent': {'content': '#txt'},
      }]));
      final rule = (await sourceRepo.getEnabledRules()).first;
      await shelfRepo.ensureBookWithChapters(
        bookId: 'dl_book', title: '并发下载测试', author: '作者',
        coverUrl: '', intro: '', category: '', statusText: '连载中',
        sourceId: rule.id, bookUrl: 'https://dl.example.com/b/1',
        tocUrl: 'https://dl.example.com/b/1', putInShelf: true,
        chapters: const [
          ParsedChapterEntry(index: 0, title: '第一章', url: 'https://dl.example.com/c0'),
          ParsedChapterEntry(index: 1, title: '第二章', url: 'https://dl.example.com/c1'),
        ],
      );

      // 1. 启动中立刻 cancelDownload：旧世代在途请求返回后不得标已缓存或覆盖状态
      final gate1 = Completer<List<String>>();
      crawler.gate = gate1;
      final f1 = downloadMgr.startDownload(bookId: 'dl_book', startIndex: 0, maxCount: 1);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      downloadMgr.cancelDownload('dl_book');
      gate1.complete(['旧世代延迟返回正文']);
      await f1;
      expect(downloadMgr.currentOf('dl_book')?.status, DownloadTaskStatus.cancelled);
      expect((await db.getChaptersByBook('dl_book')).first.isCached, isFalse);

      // 2. 写盘后、markChapterCached 前触发取消：世代复检应阻止写库标记
      crawler.gate = null;
      fileStore.onAfterWrite = () => downloadMgr.cancelDownload('dl_book');
      await downloadMgr.startDownload(bookId: 'dl_book', startIndex: 0, maxCount: 1);
      fileStore.onAfterWrite = null;
      expect(downloadMgr.currentOf('dl_book')?.status, DownloadTaskStatus.cancelled);
      expect((await db.getChaptersByBook('dl_book')).first.isCached, isFalse);

      // 3. 正常全本下载完成
      await downloadMgr.startDownload(bookId: 'dl_book', startIndex: 0);
      expect(downloadMgr.currentOf('dl_book')?.status, DownloadTaskStatus.completed);
      final afterChs = await db.getChaptersByBook('dl_book');
      expect(afterChs.every((c) => c.isCached), isTrue);
      expect(await fileStore.readChapter('dl_book', 1), contains('https://dl.example.com/c1'));
    });
  });
}
