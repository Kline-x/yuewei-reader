import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuewei_reader/app/providers.dart';
import 'package:yuewei_reader/core/database/app_database.dart';
import 'package:yuewei_reader/core/database/bookmark_dao.dart';
import 'package:yuewei_reader/core/storage/chapter_file_store.dart';
import 'package:yuewei_reader/design_system/tokens/soft_tokens.dart';
import 'package:yuewei_reader/features/reader/engine/content_pipeline.dart';
import 'package:yuewei_reader/features/reader/engine/page_models.dart';
import 'package:yuewei_reader/features/reader/engine/reader_page_slot.dart';
import 'package:yuewei_reader/features/reader/engine/typography_engine.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_bookmark_helper.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_bookmark_sheet.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_in_book_search_sheet.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_overlay_bars.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_session_controller.dart';

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

  test('ReaderBookmarkHelper 添加/查重/移除、滚动窗口匹配与前 48 字摘录清洗', () async {
    final cleaned = ReaderBookmarkHelper.cleanExcerpt(
      '\u3000\u3000第一行清晨微风吹过古塔石阶。\n\n\u3000\u3000第二行远方的钟声响起，余韵悠长直到深夜灯火通明之时仍未曾真正散去。\n',
    );
    expect(cleaned.contains('\u3000'), isFalse);
    expect(cleaned.contains('\n'), isFalse);
    expect(cleaned.characters.length, ReaderBookmarkHelper.maxExcerptLength);

    const page = TypedPage(
      pageIndex: 1, charStart: 100, charEnd: 185,
      lines: [
        TypedLine(text: '\u3000\u3000山谷间的云雾缓缓散开，', paragraphIndex: 0, charStart: 100, charEnd: 114, isFirstLineOfPara: true, isLastLineOfPara: true),
        TypedLine(text: '\u3000\u3000石阶尽头是一座安静的木屋。', paragraphIndex: 1, charStart: 114, charEnd: 130, isFirstLineOfPara: true, isLastLineOfPara: true),
      ],
    );
    const slot = PageRenderItem(
      chapterIndex: 2, chapterTitle: '第三章 云谷', page: page, totalPagesInChapter: 5, bookTitle: '山居笔记',
    );

    final added = await ReaderBookmarkHelper.toggleCurrentBookmark(
      db: db, bookId: 'book_1', chapterIndex: 2, chapterTitle: '第三章 云谷', currentItem: slot,
    );
    expect(added, isTrue);
    final saved = await db.getBookmarksByBook('book_1');
    expect(saved.length, 1);
    expect(saved.first.charOffset, 100);
    expect(saved.first.excerpt, '山谷间的云雾缓缓散开， 石阶尽头是一座安静的木屋。');

    // 滚动模式 ±120 窗口查重与段落摘录提取
    expect(ReaderBookmarkHelper.findMatchingBookmark(bookmarks: saved, chapterIndex: 2, charAnchorOffset: 180, isScrollMode: true), isNotNull);
    expect(ReaderBookmarkHelper.findMatchingBookmark(bookmarks: saved, chapterIndex: 2, charAnchorOffset: 260, isScrollMode: true), isNull);
    final scrollExcerpt = ReaderBookmarkHelper.extractExcerpt(
      paragraphs: const ['\u3000\u3000第一段略过。', '\u3000\u3000第二段夜灯亮起时，远处的海湾漂浮着银白色的雾霭。'],
      charAnchorOffset: 9, isScrollMode: true,
    );
    expect(scrollExcerpt, '第二段夜灯亮起时，远处的海湾漂浮着银白色的雾霭。');

    // 同一页区间再次切换应执行移除
    final addedAgain = await ReaderBookmarkHelper.toggleCurrentBookmark(
      db: db, bookId: 'book_1', chapterIndex: 2, chapterTitle: '第三章 云谷', currentItem: slot,
    );
    expect(addedAgain, isFalse);
    expect(await db.getBookmarksByBook('book_1'), isEmpty);
  });

  test('书签 charOffset 改变字号重排后精准回落 TypographyEngine 对应页码', () async {
    const engine = TypographyEngine();
    final paras = List<String>.generate(
      18,
      (i) => '\u3000\u3000第${i + 1}段：海风吹拂着灯塔檐角，潮声拍打礁石，远航船队正校准星盘航向。',
    );
    const smallCfg = TypographyConfig(fontSize: 16.0, viewportWidth: 380.0, viewportHeight: 740.0);
    const largeCfg = TypographyConfig(fontSize: 24.0, viewportWidth: 380.0, viewportHeight: 740.0);

    final smallPages = engine.paginate(paragraphs: paras, chapterTitle: '第一章', config: smallCfg);
    final midPage = smallPages[smallPages.length ~/ 2];
    final slot = PageRenderItem(
      chapterIndex: 0, chapterTitle: '第一章', page: midPage, totalPagesInChapter: smallPages.length, bookTitle: '航海志',
    );
    await ReaderBookmarkHelper.toggleCurrentBookmark(
      db: db, bookId: 'nav_book', chapterIndex: 0, chapterTitle: '第一章', currentItem: slot,
    );
    final bookmark = (await db.getBookmarksByBook('nav_book')).single;
    final largePages = engine.paginate(paragraphs: paras, chapterTitle: '第一章', config: largeCfg);
    final targetPageIdx = engine.findPageByCharOffset(largePages, bookmark.charOffset);
    final targetPage = largePages[targetPageIdx];

    expect(bookmark.charOffset, greaterThanOrEqualTo(targetPage.charStart));
    expect(bookmark.charOffset, lessThan(targetPage.charEnd));
  });

  test('InBookSearchEngine 多章检索、精确 charOffset 与分批检索命中上下文', () async {
    const pipeline = ContentPipeline();
    final chapters = <Chapter>[];
    for (var i = 0; i < 24; i++) {
      final title = i == 3 ? '第四章 星盘密匙' : '第${i + 1}章 日常航行';
      chapters.add(Chapter(
        bookId: 's_book', chapterIndex: i, title: title, url: 'local://$i', isCached: true, cachedBytes: 100,
      ));
      final paras = [
        '\u3000\u3000第$i章第一段记录了平静的海面与甲板上的日常整备。',
        if (i == 12) '\u3000\u3000深夜值班水手忽然在旧箱底发现了传说中的星盘密匙与手绘海图。',
      ];
      await fileStore.writeChapter('s_book', i, pipeline.serializeParagraphs(paras));
    }

    final progressBatches = <int>[];
    final hits = await InBookSearchEngine.search(
      bookId: 's_book', chapters: chapters, query: '星盘密匙', fileStore: fileStore,
      onProgress: (scanned, _) => progressBatches.add(scanned),
    );
    expect(progressBatches, contains(20));
    expect(hits.length, 2);
    expect(hits.first.isTitleMatch, isTrue);
    expect(hits.first.chapterIndex, 3);
    expect(hits.first.charOffset, 0);

    final bodyHit = hits.last;
    expect(bodyHit.isTitleMatch, isFalse);
    expect(bodyHit.chapterIndex, 12);
    expect(bodyHit.snippet.substring(bodyHit.matchStartInSnippet, bodyHit.matchStartInSnippet + bodyHit.matchLength), '星盘密匙');

    final ch12Paras = pipeline.parseCachedText((await fileStore.readChapter('s_book', 12))!);
    const engine = TypographyEngine();
    final pages = engine.paginate(
      paragraphs: ch12Paras, chapterTitle: '第13章',
      config: const TypographyConfig(fontSize: 20.0, viewportWidth: 320.0, viewportHeight: 500.0),
    );
    final hitPage = pages[engine.findPageByCharOffset(pages, bodyHit.charOffset)];
    expect(hitPage.lines.map((l) => l.text).join(), contains('星盘密匙'));
  });

  testWidgets('ReaderTopBar 本地书菜单裁剪与 ReaderBottomBar 5 项动作验证', (tester) async {
    var toggled = 0, openedBookmarks = 0, openedSearch = 0;

    await tester.pumpWidget(wrapSoftApp(
      Stack(children: [
        ReaderTopBar(
          paper: ReaderPaperTheme.porcelainWhite, topSafe: 0, bookTitle: '本地测试藏书', chapterTitle: '第一章',
          inShelf: true, isLocalBook: true, isBookmarked: true,
          onBack: () {}, onToggleBookmark: () => toggled++, onOpenSource: () {}, onAddToShelf: () {}, onOpenDownload: () {},
        ),
        ReaderBottomBar(
          paper: ReaderPaperTheme.porcelainWhite, botSafe: 0, chapterIndex: 0, totalChapters: 5,
          chapterTitles: const ['第一章', '第二章', '第三章', '第四章', '第五章'],
          onJumpChapter: (_) {}, onOpenCatalog: () {}, onOpenBookmarks: () => openedBookmarks++,
          onOpenSearch: () => openedSearch++, onToggleDark: () {}, onOpenTypography: () {},
        ),
      ]),
    ));

    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    expect(find.byTooltip('切换书源'), findsNothing);
    expect(find.byTooltip('离线缓存'), findsNothing);
    expect(find.text('换源'), findsNothing);
    for (final label in ['目录', '书签', '搜索', '夜间', '排版']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.byTooltip('移除书签'));
    await tester.tap(find.text('书签'));
    await tester.tap(find.text('搜索'));
    expect(toggled, 1); expect(openedBookmarks, 1); expect(openedSearch, 1);
  });

  testWidgets('ReaderBookmarkSheet.show 与 ReaderInBookSearchSheet.show 完整交互验证', (tester) async {
    (int, int)? jumped;
    (int, int)? searchHit;
    await tester.pumpWidget(wrapSoftApp(
      Builder(builder: (ctx) => Column(children: [
        ElevatedButton(
          onPressed: () => ReaderBookmarkSheet.show(
            ctx, db: db, bookId: 'b_ui', currentChapterIndex: 0,
            onSelectBookmark: (c, o) async => jumped = (c, o),
          ),
          child: const Text('开书签'),
        ),
        ElevatedButton(
          onPressed: () => ReaderInBookSearchSheet.show(
            ctx, bookId: 'b_ui',
            chapters: const [Chapter(bookId: 'b_ui', chapterIndex: 0, title: '序章 初逢青萍', url: 'u0', isCached: false, cachedBytes: 0)],
            fileStore: fileStore, isLocalBook: false, onSelectHit: (c, o) async => searchHit = (c, o),
          ),
          child: const Text('开搜索'),
        ),
      ])),
    ));

    await tester.tap(find.text('开书签'));
    await tester.pumpAndSettle();
    expect(find.text('暂无书签，点击阅读顶栏书签图标即可随手标记'), findsOneWidget);

    await db.addBookmark(bookId: 'b_ui', chapterIndex: 0, chapterTitle: '序章 初逢', charOffset: 42, excerpt: '风起青萍之末');
    await tester.pumpAndSettle();
    expect(find.text('当前章'), findsOneWidget);
    await tester.tap(find.byTooltip('删除书签'));
    await tester.pumpAndSettle();
    expect(find.text('暂无书签，点击阅读顶栏书签图标即可随手标记'), findsOneWidget);

    await db.addBookmark(bookId: 'b_ui', chapterIndex: 0, chapterTitle: '序章 初逢', charOffset: 42, excerpt: '风起青萍之末');
    await tester.pumpAndSettle();
    await tester.tap(find.text('风起青萍之末'));
    await tester.pumpAndSettle();
    expect(jumped, (0, 42));
    expect(find.text('本书书签'), findsNothing);

    await tester.tap(find.text('开搜索'));
    await tester.pumpAndSettle();
    expect(find.text('支持搜索全部章名及已缓存章节正文'), findsNWidgets(2));
    await tester.enterText(find.byType(TextField), '青萍');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    for (var i = 0; i < 6 && find.text('章名').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.tap(find.text('章名'));
    await tester.pumpAndSettle();
    expect(searchHit, (0, 0));
    expect(find.text('书内搜索'), findsNothing);
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('ReaderSessionController 消除更新红点与同章/跨章 jumpToLocation', (tester) async {
    late ReaderSessionController ctrl;
    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db), chapterFileStoreProvider.overrideWithValue(fileStore)],
      child: MaterialApp(home: Consumer(builder: (context, ref, _) {
        ctrl = ReaderSessionController(bookId: 'ctrl_b', ref: ref, db: db, onNeedResetScroll: () {});
        return const SizedBox.shrink();
      })),
    ));
    await tester.runAsync(() async {
      await db.upsertBook(BooksCompanion.insert(
        id: 'ctrl_b', title: '控制器测试', cleanTitle: '控制器测试', sourceId: kLocalBookSourceId,
        bookUrl: 'local://ctrl_b', totalChapters: const Value(2), hasUnreadUpdate: const Value(true), updatedAt: DateTime.now(),
      ));
      await db.replaceBookChapters('ctrl_b', [
        ChaptersCompanion.insert(bookId: 'ctrl_b', chapterIndex: 0, title: '第一章', url: 'l://0', isCached: const Value(true)),
        ChaptersCompanion.insert(bookId: 'ctrl_b', chapterIndex: 1, title: '第二章', url: 'l://1', isCached: const Value(true)),
      ]);
      await fileStore.writeChapter('ctrl_b', 0, '\u3000\u3000第一章第一段。\n\u3000\u3000第一章第二段目标内容在这里。');
      await fileStore.writeChapter('ctrl_b', 1, '\u3000\u3000第二章开篇内容。\n\u3000\u3000第二章结尾锚点。');
      await ctrl.bootstrap(null);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect((await db.getBookById('ctrl_b'))?.hasUnreadUpdate, isFalse);
      ctrl.syncForBuild(const TypographyConfig(fontSize: 20.0, viewportWidth: 320.0, viewportHeight: 500.0), PageTurnMode.slide);
      await ctrl.jumpToLocation(0, 14);
      expect(ctrl.chapterIndex, 0);
      expect(ctrl.charAnchorOffset, 14);
      await ctrl.jumpToLocation(1, 10);
      expect(ctrl.chapterIndex, 1);
      expect(ctrl.charAnchorOffset, 10);
      ctrl.dispose();
    });
  });
}
