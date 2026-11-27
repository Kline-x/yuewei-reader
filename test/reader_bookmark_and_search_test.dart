import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuewei_reader/app/providers.dart';
import 'package:yuewei_reader/core/database/app_database.dart';
import 'package:yuewei_reader/core/database/bookmark_dao.dart';
import 'package:yuewei_reader/core/network/app_http_client.dart';
import 'package:yuewei_reader/core/storage/chapter_file_store.dart';
import 'package:yuewei_reader/design_system/tokens/soft_tokens.dart';
import 'package:yuewei_reader/features/reader/engine/content_pipeline.dart';
import 'package:yuewei_reader/features/reader/engine/page_models.dart';
import 'package:yuewei_reader/features/reader/engine/reader_page_slot.dart';
import 'package:yuewei_reader/features/reader/engine/typography_engine.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_body_view.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_bookmark_helper.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_bookmark_sheet.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_in_book_search_sheet.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_overlay_bars.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_pager_views.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_session_bootstrap.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_session_controller.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_settings_provider.dart';
import 'package:yuewei_reader/features/sources/data/builtin_sources.dart';
import 'package:yuewei_reader/features/sources/data/source_repository.dart';
import 'package:yuewei_reader/features/sources/domain/book_match_models.dart';
import 'package:yuewei_reader/features/sources/domain/book_source_rule.dart';
import 'package:yuewei_reader/features/sources/engine/source_crawler_service.dart';

class _FakeSourceRepo extends SourceRepository {
  _FakeSourceRepo(AppDatabase db) : super(db: db, httpClient: AppHttpClient());
  @override
  Future<BookSourceRule?> getRuleById(String sourceId) async => BuiltinSources.all.first;
}

class _FakeCrawler extends SourceCrawlerService {
  _FakeCrawler() : super(httpClient: AppHttpClient());
  @override
  Future<({ParsedBookDetail detail, List<ParsedChapterEntry> chapters, int latencyMs})>
      fetchBookDetailAndToc(BookSourceRule src, String bookUrl, {CancelToken? cancelToken}) async => (
        detail: const ParsedBookDetail(title: '云端恢复测试', author: '作者', intro: '简介', coverUrl: '', tocUrl: 'https://e.test/toc', statusText: '连载', category: '玄幻'),
        chapters: const [
          ParsedChapterEntry(index: 0, title: '第一章', url: 'https://e.test/0'),
          ParsedChapterEntry(index: 1, title: '第二章 补拉目标', url: 'https://e.test/1'),
        ],
        latencyMs: 12,
      );
  @override
  Future<List<String>> fetchChapterParagraphs(BookSourceRule src, String chapterUrl, {String? chapterTitle, CancelToken? cancelToken}) async =>
      ['\u3000\u3000补拉成功后的正文段落内容。'];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late AppDatabase db;
  late ChapterFileStore fileStore;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('yuewei_reader_tools_');
    db = AppDatabase(NativeDatabase.memory());
    fileStore = ChapterFileStore(rootDirProvider: () async => tempDir);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Widget wrapSoftApp(Widget child) => MaterialApp(
        theme: SoftTokens.resolve(SoftPalette.mistyJade, isDark: false).toThemeData(),
        home: Scaffold(body: child),
      );

  test('ReaderBookmarkHelper 添加/查重/移除、滚动窗口匹配与跨页段尾 1 字符换行缝隙', () async {
    final cleaned = ReaderBookmarkHelper.cleanExcerpt(
      '\u3000\u3000第一行清晨微风吹过古塔石阶。\n\n\u3000\u3000第二行远方的钟声响起，余韵悠长直到深夜灯火通明之时仍未曾真正散去。\n',
    );
    expect(cleaned.contains('\u3000') || cleaned.contains('\n'), isFalse);
    expect(cleaned.characters.length, ReaderBookmarkHelper.maxExcerptLength);

    const page = TypedPage(
      pageIndex: 1, charStart: 100, charEnd: 130,
      lines: [
        TypedLine(text: '\u3000\u3000山谷间的云雾缓缓散开，', paragraphIndex: 0, charStart: 100, charEnd: 114, isFirstLineOfPara: true, isLastLineOfPara: true),
        TypedLine(text: '\u3000\u3000石阶尽头是一座安静的木屋。', paragraphIndex: 1, charStart: 115, charEnd: 130, isFirstLineOfPara: true, isLastLineOfPara: true),
      ],
    );
    const slot = PageRenderItem(chapterIndex: 2, chapterTitle: '第三章 云谷', page: page, totalPagesInChapter: 5, bookTitle: '山居笔记');

    expect(await ReaderBookmarkHelper.toggleCurrentBookmark(db: db, bookId: 'book_1', chapterIndex: 2, chapterTitle: '第三章 云谷', currentItem: slot), isTrue);
    final saved = await db.getBookmarksByBook('book_1');
    expect(saved.single.charOffset, 100);
    expect(saved.single.excerpt, '山谷间的云雾缓缓散开， 石阶尽头是一座安静的木屋。');

    // 段尾换行缝隙（charOffset == page.charEnd == 130）当末行 isLastLineOfPara==true 准确点亮；非段尾时不越界误亮
    final paraEndBm = [Bookmark(id: 99, bookId: 'book_1', chapterIndex: 2, chapterTitle: '第三章', charOffset: 130, excerpt: '尾', createdAt: DateTime.now())];
    expect(ReaderBookmarkHelper.findMatchingBookmark(bookmarks: paraEndBm, chapterIndex: 2, currentItem: slot, charAnchorOffset: 100), isNotNull);
    const midParaSlot = PageRenderItem(
      chapterIndex: 2, chapterTitle: '第三章', totalPagesInChapter: 5, bookTitle: '山居笔记',
      page: TypedPage(pageIndex: 1, charStart: 100, charEnd: 130, lines: [
        TypedLine(text: '未完段', paragraphIndex: 1, charStart: 100, charEnd: 130, isFirstLineOfPara: false, isLastLineOfPara: false),
      ]),
    );
    expect(ReaderBookmarkHelper.findMatchingBookmark(bookmarks: paraEndBm, chapterIndex: 2, currentItem: midParaSlot, charAnchorOffset: 100), isNull);

    expect(ReaderBookmarkHelper.findMatchingBookmark(bookmarks: saved, chapterIndex: 2, charAnchorOffset: 180, isScrollMode: true), isNotNull);
    expect(ReaderBookmarkHelper.findMatchingBookmark(bookmarks: saved, chapterIndex: 2, charAnchorOffset: 260, isScrollMode: true), isNull);
    expect(ReaderBookmarkHelper.extractExcerpt(paragraphs: const ['\u3000\u3000第一段略过。', '\u3000\u3000第二段夜灯亮起时，远处的海湾漂浮着银白色的雾霭。'], charAnchorOffset: 9, isScrollMode: true), '第二段夜灯亮起时，远处的海湾漂浮着银白色的雾霭。');
    expect(await ReaderBookmarkHelper.toggleCurrentBookmark(db: db, bookId: 'book_1', chapterIndex: 2, chapterTitle: '第三章 云谷', currentItem: slot), isFalse);
    expect(await db.getBookmarksByBook('book_1'), isEmpty);
  });

  test('书签 charOffset 改变字号重排后精准回落 TypographyEngine 对应页码', () async {
    const engine = TypographyEngine();
    final paras = List<String>.generate(18, (i) => '\u3000\u3000第${i + 1}段：海风吹拂着灯塔檐角，潮声拍打礁石，远航船队正校准星盘航向。');
    final smallPages = engine.paginate(paragraphs: paras, chapterTitle: '第一章', config: const TypographyConfig(fontSize: 16.0, viewportWidth: 380.0, viewportHeight: 740.0));
    final slot = PageRenderItem(chapterIndex: 0, chapterTitle: '第一章', page: smallPages[smallPages.length ~/ 2], totalPagesInChapter: smallPages.length, bookTitle: '航海志');
    await ReaderBookmarkHelper.toggleCurrentBookmark(db: db, bookId: 'nav_book', chapterIndex: 0, chapterTitle: '第一章', currentItem: slot);
    final bm = (await db.getBookmarksByBook('nav_book')).single;
    final largePages = engine.paginate(paragraphs: paras, chapterTitle: '第一章', config: const TypographyConfig(fontSize: 24.0, viewportWidth: 380.0, viewportHeight: 740.0));
    final target = largePages[engine.findPageByCharOffset(largePages, bm.charOffset)];
    expect(bm.charOffset, inInclusiveRange(target.charStart, target.charEnd - 1));
  });

  test('InBookSearchEngine 多章检索、精确 charOffset 与分批检索命中上下文', () async {
    const pipeline = ContentPipeline();
    final chapters = <Chapter>[];
    for (var i = 0; i < 24; i++) {
      chapters.add(Chapter(bookId: 's_book', chapterIndex: i, title: i == 3 ? '第四章 星盘密匙' : '第${i + 1}章 日常航行', url: 'local://$i', isCached: true, cachedBytes: 100));
      final paras = ['\u3000\u3000第$i章第一段记录了平静的海面与甲板上的日常整备。', if (i == 12) '\u3000\u3000深夜值班水手忽然在旧箱底发现了传说中的星盘密匙与手绘海图。'];
      await fileStore.writeChapter('s_book', i, pipeline.serializeParagraphs(paras));
    }
    final batches = <int>[];
    final hits = await InBookSearchEngine.search(bookId: 's_book', chapters: chapters, query: '星盘密匙', fileStore: fileStore, onProgress: (scanned, _) => batches.add(scanned));
    expect(batches, contains(20));
    expect(hits.length, 2);
    expect(hits.first.isTitleMatch && hits.first.chapterIndex == 3 && hits.first.charOffset == 0, isTrue);
    final bodyHit = hits.last;
    expect(bodyHit.chapterIndex, 12);
    expect(bodyHit.snippet.substring(bodyHit.matchStartInSnippet, bodyHit.matchStartInSnippet + bodyHit.matchLength), '星盘密匙');
    final ch12Paras = pipeline.parseCachedText((await fileStore.readChapter('s_book', 12))!);
    const engine = TypographyEngine();
    final pages = engine.paginate(paragraphs: ch12Paras, chapterTitle: '第13章', config: const TypographyConfig(fontSize: 20.0, viewportWidth: 320.0, viewportHeight: 500.0));
    expect(pages[engine.findPageByCharOffset(pages, bodyHit.charOffset)].lines.map((l) => l.text).join(), contains('星盘密匙'));
  });

  testWidgets('ReaderTopBar 本地书菜单裁剪、ReaderBottomBar 动作与 ReaderBodyView 菜单拦截不穿透翻页', (tester) async {
    var toggled = 0, openedBookmarks = 0, openedSearch = 0, menuClicks = 0, nextCommits = 0;
    await tester.pumpWidget(wrapSoftApp(Stack(children: [
      ReaderTopBar(paper: ReaderPaperTheme.porcelainWhite, topSafe: 0, bookTitle: '本地测试藏书', chapterTitle: '第一章', inShelf: true, isLocalBook: true, isBookmarked: true, onBack: () {}, onToggleBookmark: () => toggled++, onOpenSource: () {}, onAddToShelf: () {}, onOpenDownload: () {}),
      ReaderBottomBar(paper: ReaderPaperTheme.porcelainWhite, botSafe: 0, chapterIndex: 0, totalChapters: 5, chapterTitles: const ['第一章', '第二章', '第三章', '第四章', '第五章'], onJumpChapter: (_) {}, onOpenCatalog: () {}, onOpenBookmarks: () => openedBookmarks++, onOpenSearch: () => openedSearch++, onToggleDark: () {}, onOpenTypography: () {}),
    ])));
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    expect(find.byTooltip('切换书源'), findsNothing);
    expect(find.byTooltip('离线缓存'), findsNothing);
    for (final label in ['目录', '书签', '搜索', '夜间', '排版']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.byTooltip('移除书签'));
    await tester.tap(find.text('书签'));
    await tester.tap(find.text('搜索'));
    expect((toggled, openedBookmarks, openedSearch), (1, 1, 1));

    // ReaderBodyView 菜单展开时点击右侧翻页区仅收起菜单不穿透翻页
    const slot = PageRenderItem(chapterIndex: 0, chapterTitle: '第一章', totalPagesInChapter: 2, bookTitle: '拦截测试', page: TypedPage(pageIndex: 0, charStart: 0, charEnd: 10, lines: []));
    await tester.pumpWidget(wrapSoftApp(SizedBox(
      width: 400, height: 700,
      child: ReaderBodyView(
        pagerKey: GlobalKey<ReaderPagerViewsState>(), loading: false, errorMsg: null, menuVisible: true,
        turnMode: PageTurnMode.none, initialCharOffset: 0, paper: ReaderPaperTheme.porcelainWhite,
        config: const TypographyConfig(viewportWidth: 400, viewportHeight: 700), topSafe: 0, botSafe: 0,
        currentItem: slot, prevItem: null, nextItem: slot, scrollBlocks: const [], chapterIndex: 0, totalChapters: 2,
        chapterTitles: const ['第一章', '第二章'], bookTitle: '拦截测试', chapterTitle: '第一章', inShelf: true,
        onRetry: () {}, onToggleMenu: () => menuClicks++, onCommitNext: () => nextCommits++, onCommitPrev: () {},
        onNeedAppendNextChapter: () {}, onRequestPrevChapter: () {}, onScrollChapterProgress: (_, _) {},
        onBack: () {}, onToggleBookmark: () {}, onOpenSource: () {}, onAddToShelf: () {}, onOpenDownload: () {},
        onJumpChapter: (_) {}, onOpenCatalog: () {}, onOpenBookmarks: () {}, onOpenSearch: () {}, onToggleDark: () {}, onOpenTypography: () {},
      ),
    )));
    await tester.tapAt(const Offset(360, 350));
    await tester.pump();
    expect(menuClicks, 1);
    expect(nextCommits, 0);
  });

  testWidgets('ReaderBookmarkSheet.show 与 ReaderInBookSearchSheet.show 完整交互验证', (tester) async {
    (int, int)? jumped, searchHit;
    await tester.pumpWidget(wrapSoftApp(Builder(builder: (ctx) => Column(children: [
      ElevatedButton(onPressed: () => ReaderBookmarkSheet.show(ctx, db: db, bookId: 'b_ui', currentChapterIndex: 0, onSelectBookmark: (c, o) async => jumped = (c, o)), child: const Text('开书签')),
      ElevatedButton(onPressed: () => ReaderInBookSearchSheet.show(ctx, bookId: 'b_ui', chapters: const [Chapter(bookId: 'b_ui', chapterIndex: 0, title: '序章 初逢青萍', url: 'u0', isCached: false, cachedBytes: 0)], fileStore: fileStore, isLocalBook: false, onSelectHit: (c, o) async => searchHit = (c, o)), child: const Text('开搜索')),
    ]))));
    await tester.tap(find.text('开书签'));
    await tester.pumpAndSettle();
    expect(find.text('暂无书签，点击阅读顶栏书签图标即可随手标记'), findsOneWidget);
    await db.addBookmark(bookId: 'b_ui', chapterIndex: 0, chapterTitle: '序章 初逢', charOffset: 42, excerpt: '风起青萍之末');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('删除书签'));
    await tester.pumpAndSettle();
    await db.addBookmark(bookId: 'b_ui', chapterIndex: 0, chapterTitle: '序章 初逢', charOffset: 42, excerpt: '风起青萍之末');
    await tester.pumpAndSettle();
    await tester.tap(find.text('风起青萍之末'));
    await tester.pumpAndSettle();
    expect(jumped, (0, 42));

    await tester.tap(find.text('开搜索'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '青萍');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    for (var i = 0; i < 6 && find.text('章名').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.tap(find.text('章名'));
    await tester.pumpAndSettle();
    expect(searchHit, (0, 0));
  });

  testWidgets('ReaderSessionController 补拉云端缺目录、失败清空旧章、前台计时与日夜切灯守卫', (tester) async {
    late ReaderSessionController ctrl;
    var now = DateTime(2026, 1, 1, 10, 0, 0);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        chapterFileStoreProvider.overrideWithValue(fileStore),
        sourceRepositoryProvider.overrideWithValue(_FakeSourceRepo(db)),
        crawlerServiceProvider.overrideWithValue(_FakeCrawler()),
      ],
      child: MaterialApp(home: Consumer(builder: (context, ref, _) {
        ctrl = ReaderSessionController(bookId: 'cloud_b', ref: ref, db: db, clock: () => now);
        return const SizedBox.shrink();
      })),
    ));
    await tester.runAsync(() async {
      // 1. 云端恢复书籍无本地目录，bootstrap 自动补拉目录并恢复 currentChapterIndex=1 / charOffset=6
      await db.upsertBook(BooksCompanion.insert(
        id: 'cloud_b', title: '云端恢复测试', cleanTitle: '云端恢复测试', sourceId: BuiltinSources.all.first.id,
        bookUrl: 'https://e.test/book', currentChapterIndex: const Value(1), currentCharOffset: const Value(6),
        hasUnreadUpdate: const Value(true), isInShelf: const Value(true), updatedAt: now,
      ));
      await ctrl.bootstrap(null);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect((await db.getBookById('cloud_b'))?.hasUnreadUpdate, isFalse);
      expect(ctrl.chapters.length, 2);
      expect(ctrl.chapterIndex, 1);
      expect(ctrl.charAnchorOffset, 6);
      expect(ctrl.paragraphs.first, contains('补拉成功'));

      // 2. 加载失败时清空 paragraphs，且同章 jumpToLocation 不渲染旧章正文
      ctrl.chapters = [...ctrl.chapters, const Chapter(bookId: 'cloud_b', chapterIndex: 2, title: '坏章', url: '', isCached: false, cachedBytes: 0)];
      ctrl.book = ctrl.book!.copyWith(sourceId: 'missing_src');
      await ctrl.loadChapter(2);
      expect(ctrl.errorMsg, isNotNull);
      expect(ctrl.paragraphs, isEmpty);
      await ctrl.jumpToLocation(2, 5);
      expect(ctrl.paragraphs, isEmpty);

      // 3. 前台阅读计时器：前台 20s + 后台暂停 100s + 回前台 15s = 仅计 35s
      final timer = ForegroundReadingTimer(clock: () => now);
      now = now.add(const Duration(seconds: 20));
      timer.pause();
      now = now.add(const Duration(seconds: 100));
      timer.resume();
      now = now.add(const Duration(seconds: 15));
      expect(timer.finishAndCollectSeconds(), 35);
      ctrl.dispose();

      // 4. ReaderSettingsNotifier 日夜快捷切灯按 effectiveTheme 取反 & _mutationGen 防初始化覆盖
      await db.setPreference('reader_font_size', '15.0');
      final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(container.dispose);
      final settingsNotifier = container.read(readerSettingsProvider.notifier);
      await settingsNotifier.setFontSize(26.0);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(container.read(readerSettingsProvider).fontSize, 26.0);
      await settingsNotifier.setFollowSystem(true);
      await settingsNotifier.toggleDarkQuick(systemBrightness: Brightness.dark);
      expect(container.read(readerSettingsProvider).paperTheme.isDark, isFalse);
    });
  });
}
