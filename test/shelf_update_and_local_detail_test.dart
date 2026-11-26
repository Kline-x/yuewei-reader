import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuewei_reader/core/database/app_database.dart';
import 'package:yuewei_reader/core/database/bookmark_dao.dart';
import 'package:yuewei_reader/core/network/app_http_client.dart';
import 'package:yuewei_reader/core/storage/chapter_file_store.dart';
import 'package:yuewei_reader/design_system/components/single_swipe_tile.dart';
import 'package:yuewei_reader/design_system/tokens/soft_tokens.dart';
import 'package:yuewei_reader/features/book_detail/presentation/book_detail_loader.dart';
import 'package:yuewei_reader/features/book_detail/presentation/book_detail_sections.dart';
import 'package:yuewei_reader/features/download/download_manager.dart';
import 'package:yuewei_reader/features/local_import/data/local_import_service.dart';
import 'package:yuewei_reader/features/shelf/data/shelf_repository.dart';
import 'package:yuewei_reader/features/shelf/data/shelf_update_checker.dart';
import 'package:yuewei_reader/features/shelf/presentation/shelf_book_cards.dart';
import 'package:yuewei_reader/features/sources/data/source_repository.dart';
import 'package:yuewei_reader/features/sources/domain/book_match_models.dart';
import 'package:yuewei_reader/features/sources/domain/book_source_rule.dart';
import 'package:yuewei_reader/features/sources/engine/source_crawler_service.dart';

class _FakeCrawlerService extends SourceCrawlerService {
  _FakeCrawlerService({required super.httpClient, this.prependPrologue = false});
  final List<String> requestedUrls = [];
  final bool prependPrologue;

  @override
  Future<({ParsedBookDetail detail, List<ParsedChapterEntry> chapters, int latencyMs})>
      fetchBookDetailAndToc(BookSourceRule src, String bookUrl, {CancelToken? cancelToken}) async {
    requestedUrls.add(bookUrl);
    final chapters = prependPrologue
        ? [
            ParsedChapterEntry(index: 0, title: '楔子 序幕', url: '$bookUrl/c0'),
            ParsedChapterEntry(index: 1, title: '第一章', url: '$bookUrl/c1'),
            ParsedChapterEntry(index: 2, title: '第二章', url: '$bookUrl/c2'),
            ParsedChapterEntry(index: 3, title: '第三章 黎明', url: '$bookUrl/c3'),
          ]
        : [
            ParsedChapterEntry(index: 0, title: '第一章', url: '$bookUrl/c1'),
            ParsedChapterEntry(index: 1, title: '第二章', url: '$bookUrl/c2'),
            ParsedChapterEntry(index: 2, title: '第三章 黎明', url: '$bookUrl/c3'),
          ];
    return (
      detail: const ParsedBookDetail(
        title: '测试在线书', author: '作者', intro: '', coverUrl: '', tocUrl: '',
        statusText: '连载中', category: '', latestChapter: '第三章 黎明', lastUpdateTime: '2026-11-24',
      ),
      chapters: chapters,
      latencyMs: 12,
    );
  }
}

Book _makeBook({
  required String id,
  required String sourceId,
  bool hasUnreadUpdate = false,
  String category = '小说',
  String lastUpdateTime = '2026-01-01',
}) =>
    Book(
      id: id, title: '测试书名', cleanTitle: '测试书名', author: '测试作者',
      coverUrl: '', intro: '测试简介文本', category: category, statusText: '连载中',
      latestChapterTitle: '第二章', lastUpdateTime: lastUpdateTime,
      sourceId: sourceId, bookUrl: 'https://example.com/$id', tocUrl: 'https://example.com/$id',
      totalChapters: 2, currentChapterIndex: 0, currentChapterTitle: '第一章',
      currentCharOffset: 0, hasEverRead: false, isPinned: false, isInShelf: true,
      hasUnreadUpdate: hasUnreadUpdate, updatedAt: DateTime(2026, 1, 1),
    );

Widget _wrapTestApp(Widget child) => MaterialApp(
      theme: SoftTokens.resolve(SoftPalette.mistyJade, isDark: false).toThemeData(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late ChapterFileStore fileStore;
  late DownloadManager downloadMgr;
  late ShelfRepository shelfRepo;
  late SourceRepository sourceRepo;
  late AppHttpClient httpClient;
  late LocalImportService importService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('yuewei_m2_shelf_');
    db = AppDatabase(NativeDatabase.memory());
    fileStore = ChapterFileStore(rootDirProvider: () async => tempDir);
    httpClient = AppHttpClient();
    sourceRepo = SourceRepository(db: db, httpClient: httpClient);
    final crawler = SourceCrawlerService(httpClient: httpClient);
    downloadMgr = DownloadManager(db: db, fileStore: fileStore, sourceRepo: sourceRepo, crawler: crawler);
    shelfRepo = ShelfRepository(db: db, fileStore: fileStore, downloadManager: downloadMgr);
    importService = LocalImportService(db: db, fileStore: fileStore);
  });

  tearDown(() async {
    downloadMgr.dispose();
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<BookSourceRule> seedSource(String base) async {
    await sourceRepo.importLegadoJson(jsonEncode([{
      'bookSourceName': '本地测试源', 'bookSourceUrl': base, 'searchUrl': '$base/s?q={{key}}',
      'ruleSearch': {'bookList': '.item', 'name': 'a@text', 'bookUrl': 'a@href'},
      'ruleBookInfo': {'name': 'h1', 'lastChapter': '#latest@text', 'lastUpdateTime': '#time@text'},
      'ruleToc': {'chapterList': '#toc li a', 'chapterName': 'text', 'chapterUrl': 'href'},
      'ruleContent': {'content': '#content@html'},
    }]));
    return (await sourceRepo.getEnabledRules()).first;
  }

  group('本地书缓存隔离、物理清理与追更迁移测试', () {
    test('clearBookChapterFiles 与 clearAllCaches 保留在架本地书并清理离线与非在架本地书孤儿缓存', () async {
      final localBook = await importService.importFromBytes(
        '本地测试.txt', utf8.encode('第一章 启程\n本地书籍正文内容足够二十字确保能被正常解析入库。'),
      );
      final removedLocal = await importService.importFromBytes(
        '待清理本地书.txt', utf8.encode('第一章 离别\n另一段移出书架后的本地书籍正文内容用于验证回收。'),
      );
      await shelfRepo.setInShelf(removedLocal.id, false);

      await shelfRepo.ensureBookWithChapters(
        bookId: 'online_1', title: '在线小说', author: '作者',
        coverUrl: '', intro: '', category: '', statusText: '连载中',
        sourceId: 'src_online', bookUrl: 'https://online.test/1', tocUrl: 'https://online.test/1',
        putInShelf: true,
        chapters: const [ParsedChapterEntry(index: 0, title: '第一章', url: 'https://online.test/c0')],
      );
      final onlineBytes = await fileStore.writeChapter('online_1', 0, '在线缓存正文');
      await db.markChapterCached(bookId: 'online_1', chapterIndex: 0, isCached: true, cachedBytes: onlineBytes);
      expect(await db.watchTotalCachedBytes().first, onlineBytes);

      await shelfRepo.clearBookChapterFiles(localBook.id);
      expect(await fileStore.readChapter(localBook.id, 0), contains('本地书籍正文'));
      expect((await db.getChaptersByBook(localBook.id)).first.isCached, isTrue);

      await shelfRepo.clearAllCaches();
      expect(await db.watchTotalCachedBytes().first, 0);
      expect(await fileStore.readChapter('online_1', 0), isNull);
      expect(await fileStore.readChapter(removedLocal.id, 0), isNull);
      expect(await fileStore.readChapter(localBook.id, 0), contains('本地书籍正文'));
      expect((await db.getChaptersByBook(localBook.id)).first.isCached, isTrue);
    });

    test('purgeBookData 移出本地书时同步删除 Bookmarks 记录与本地相对路径封面目录', () async {
      final localBook = await importService.importFromBytes(
        '带封面本地书.txt', utf8.encode('第一章 封面\n这是一段本地书籍的正文内容用于验证清理逻辑。'),
      );
      final coverRel = await fileStore.saveBookCoverBytes(localBook.id, [1, 2, 3, 4], ext: '.jpg');
      expect(coverRel, startsWith(kLocalCoverScheme));
      final coverFile = await fileStore.resolveLocalCoverFile(coverRel);
      expect(coverFile?.existsSync(), isTrue);

      await db.addBookmark(
        bookId: localBook.id, chapterIndex: 0, chapterTitle: '第一章 封面',
        charOffset: 6, excerpt: '本地书籍的正文内容',
      );
      expect((await db.getBookmarksByBook(localBook.id)).length, 1);

      await shelfRepo.purgeBookData(localBook.id);
      expect(await db.getBookById(localBook.id), isNull);
      expect(await db.getBookmarksByBook(localBook.id), isEmpty);
      expect(coverFile!.existsSync(), isFalse);
    });

    test('ShelfUpdateChecker 跳过本地书，发现在线更新后保留进度并置 hasUnreadUpdate', () async {
      const base = 'https://update.example.com';
      final rule = await seedSource(base);
      final localBook = await importService.importFromBytes(
        '本地不检查.txt', utf8.encode('第一章\n本地内容正文超过二十个汉字以确保解析成功。'),
      );
      await shelfRepo.ensureBookWithChapters(
        bookId: 'online_update_1', title: '测试在线书', author: '作者',
        coverUrl: '', intro: '', category: '', statusText: '连载中',
        latestChapterTitle: '第二章', lastUpdateTime: '2026-01-01',
        sourceId: rule.id, bookUrl: '$base/book/1', tocUrl: '$base/book/1', putInShelf: true,
        chapters: const [
          ParsedChapterEntry(index: 0, title: '第一章', url: '$base/book/1/c1'),
          ParsedChapterEntry(index: 1, title: '第二章', url: '$base/book/1/c2'),
        ],
      );
      await db.markChapterCached(bookId: 'online_update_1', chapterIndex: 0, isCached: true, cachedBytes: 128);
      await db.updateReadingProgress(bookId: 'online_update_1', chapterIndex: 1, chapterTitle: '第二章', charOffset: 88);

      final fakeCrawler = _FakeCrawlerService(httpClient: httpClient);
      final checker = ShelfUpdateChecker(db: db, sourceRepo: sourceRepo, crawler: fakeCrawler, fileStore: fileStore);
      final res = await checker.checkAll();
      expect(res.checked, 1);
      expect(res.updated, 1);
      expect(fakeCrawler.requestedUrls, ['$base/book/1']);
      expect((await db.getBookById(localBook.id))!.hasUnreadUpdate, isFalse);

      final updated = (await db.getBookById('online_update_1'))!;
      expect(updated.totalChapters, 3);
      expect(updated.latestChapterTitle, '第三章 黎明');
      expect(updated.hasUnreadUpdate, isTrue);
      expect(updated.currentChapterIndex, 1);
      expect(updated.currentCharOffset, 88);
      expect((await db.getChaptersByBook('online_update_1')).first.isCached, isTrue);

      final res2 = await checker.checkAll();
      expect(res2.checked, 1);
      expect(res2.updated, 0);
    });

    test('源站前部插章导致下标偏移后，经物理缓存迁移且读盘正文与新章严格一致不串章', () async {
      const base = 'https://shift.example.com';
      final rule = await seedSource(base);
      await shelfRepo.ensureBookWithChapters(
        bookId: 'shift_book', title: '插章测试', author: '作者',
        coverUrl: '', intro: '', category: '', statusText: '连载中',
        latestChapterTitle: '第二章', lastUpdateTime: '2026-01-01',
        sourceId: rule.id, bookUrl: '$base/book/9', tocUrl: '$base/book/9', putInShelf: true,
        chapters: const [
          ParsedChapterEntry(index: 0, title: '第一章', url: '$base/book/9/c1'),
          ParsedChapterEntry(index: 1, title: '第二章', url: '$base/book/9/c2'),
        ],
      );
      final b0 = await fileStore.writeChapter('shift_book', 0, '【第一章正文内容】');
      final b1 = await fileStore.writeChapter('shift_book', 1, '【第二章正文内容】');
      await db.markChapterCached(bookId: 'shift_book', chapterIndex: 0, isCached: true, cachedBytes: b0);
      await db.markChapterCached(bookId: 'shift_book', chapterIndex: 1, isCached: true, cachedBytes: b1);

      final checker = ShelfUpdateChecker(
        db: db, sourceRepo: sourceRepo,
        crawler: _FakeCrawlerService(httpClient: httpClient, prependPrologue: true),
        fileStore: fileStore,
      );
      final res = await checker.checkAll();
      expect(res.updated, 1);

      final chs = await db.getChaptersByBook('shift_book');
      expect(chs.length, 4);
      expect(chs[0].title, '楔子 序幕');
      expect(chs[0].isCached, isFalse);
      expect(await fileStore.readChapter('shift_book', 0), isNull);

      expect(chs[1].title, '第一章');
      expect(chs[1].isCached, isTrue);
      expect(chs[1].cachedBytes, b0);
      expect(await fileStore.readChapter('shift_book', 1), '【第一章正文内容】');

      expect(chs[2].title, '第二章');
      expect(chs[2].isCached, isTrue);
      expect(chs[2].cachedBytes, b1);
      expect(await fileStore.readChapter('shift_book', 2), '【第二章正文内容】');

      expect(chs[3].isCached, isFalse);
    });
  });

  group('本地详情与书架更新角标 Widget 测试', () {
    testWidgets('BookDetailHeaderSection 本地书标签与 needsMetaRepair 不因缺更新时间反复自愈', (tester) async {
      final localTxt = _makeBook(id: 'local_1', sourceId: kLocalBookSourceId, category: 'TXT 藏书');
      final localEpub = _makeBook(id: 'local_2', sourceId: kLocalBookSourceId, category: 'EPUB 藏书');
      final onlineNoTime = _makeBook(id: 'online_2', sourceId: 'src_online', lastUpdateTime: '');
      expect(BookDetailLoader.needsMetaRepair(localTxt), isFalse);
      expect(BookDetailLoader.needsMetaRepair(onlineNoTime), isFalse);

      BookDetailHeaderSection buildSection(Book b) => BookDetailHeaderSection(
            book: b, chapterCount: 2,
            sourceName: b.sourceId == kLocalBookSourceId ? '本地导入' : '测试源',
            latestChapterTitle: '第二章', refreshingMeta: false, introExpanded: false,
            descending: false, onToggleShelf: () {}, onOpenDownload: () {},
            onStartReading: () {}, onTapLatestChapter: () {}, onToggleIntro: () {},
            onLocateCurrent: () {}, onToggleOrder: () {},
          );

      await tester.pumpWidget(_wrapTestApp(buildSection(localTxt)));
      expect(find.byTooltip('离线缓存'), findsNothing);
      expect(find.text('TXT 全本'), findsOneWidget);
      expect(find.text('藏书格式'), findsOneWidget);
      expect(find.text('本地导入'), findsOneWidget);
      expect(find.text('书籍来源'), findsOneWidget);

      await tester.pumpWidget(_wrapTestApp(buildSection(localEpub)));
      expect(find.text('EPUB 全本'), findsOneWidget);

      await tester.pumpWidget(_wrapTestApp(buildSection(onlineNoTime)));
      expect(find.byTooltip('离线缓存'), findsOneWidget);
      expect(find.text('连载状态'), findsOneWidget);
      expect(find.text('当前书源'), findsOneWidget);
    });

    testWidgets('ShelfListBookCard 在在线书 hasUnreadUpdate: true 时展示更新角标', (tester) async {
      final coordinator = SwipeCoordinator();
      addTearDown(coordinator.dispose);

      final onlineUpdated = _makeBook(id: 'u1', sourceId: 'src_online', hasUnreadUpdate: true);
      final localCard = _makeBook(id: 'l1', sourceId: kLocalBookSourceId, hasUnreadUpdate: true);

      await tester.pumpWidget(_wrapTestApp(Column(children: [
        ShelfListBookCard(book: onlineUpdated, coordinator: coordinator, onTapRead: () {}, onOpenActions: () {}, onSwipeRemove: () {}),
        ShelfListBookCard(book: localCard, coordinator: coordinator, onTapRead: () {}, onOpenActions: () {}, onSwipeRemove: () {}),
      ])));

      expect(find.text('更新'), findsOneWidget);
      expect(find.textContaining('本地藏书'), findsOneWidget);
    });
  });
}
