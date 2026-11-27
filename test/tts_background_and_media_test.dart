import 'dart:io';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuewei_reader/app/providers.dart';
import 'package:yuewei_reader/app/router.dart';
import 'package:yuewei_reader/core/database/app_database.dart';
import 'package:yuewei_reader/core/network/app_http_client.dart';
import 'package:yuewei_reader/core/platform/host_bridge.dart';
import 'package:yuewei_reader/core/storage/chapter_file_store.dart';
import 'package:yuewei_reader/design_system/components/book_cover.dart';
import 'package:yuewei_reader/design_system/components/sublime_floating_dock.dart';
import 'package:yuewei_reader/design_system/tokens/soft_tokens.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_page.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_pager_views.dart';
import 'package:yuewei_reader/features/sources/domain/book_source_rule.dart';
import 'package:yuewei_reader/features/sources/engine/source_crawler_service.dart';
import 'package:yuewei_reader/features/tts/global_tts_mini_capsule.dart';
import 'package:yuewei_reader/features/tts/tts_controller.dart';

const _channel = MethodChannel('com.kline.yuewei/host_bridge');

Future<void> _sendNativeCall(String method, Map<String, dynamic> args) async {
  final data = const StandardMethodCodec().encodeMethodCall(MethodCall(method, args));
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(_channel.name, data, (_) {});
}

class _StubCrawlerService extends SourceCrawlerService {
  _StubCrawlerService(this._chaptersByUrl) : super(httpClient: AppHttpClient());
  final Map<String, List<String>> _chaptersByUrl;
  final List<String> fetchedUrls = [];

  @override
  Future<List<String>> fetchChapterParagraphs(
    BookSourceRule src,
    String chapterUrl, {
    String? chapterTitle,
    dynamic cancelToken,
  }) async {
    fetchedUrls.add(chapterUrl);
    return _chaptersByUrl[chapterUrl] ?? const [];
  }
}

BookSourceRule _buildTestRule(String id) => BookSourceRule(
      id: id,
      name: '测试书源',
      baseUrl: 'https://example.com',
      search: const SearchRuleSpec(
        urlTemplate: 'https://example.com/s?q={key}',
        item: '.item',
        title: RuleField(selector: '.t'),
        author: RuleField(selector: '.a'),
        detailUrl: RuleField(selector: 'a', attr: 'href'),
      ),
      detail: const DetailRuleSpec(),
      toc: const TocRuleSpec(
        item: '.toc li',
        title: RuleField(selector: 'a'),
        url: RuleField(selector: 'a', attr: 'href'),
      ),
      chapter: const ChapterRuleSpec(content: RuleField(selector: '#content')),
    );

Future<void> _seedBookWith3Chapters({
  required AppDatabase db,
  required ChapterFileStore store,
  required String bookId,
  required String sourceId,
  bool includeSource = true,
}) async {
  if (includeSource) {
    final rule = _buildTestRule(sourceId);
    await db.into(db.bookSources).insertOnConflictUpdate(
          BookSourcesCompanion.insert(
            id: sourceId,
            name: rule.name,
            baseUrl: rule.baseUrl,
            ruleJson: rule.toJsonString(),
          ),
        );
  }
  await db.upsertBook(
    BooksCompanion.insert(
      id: bookId,
      title: '凡人修仙传',
      cleanTitle: '凡人修仙传',
      author: const Value('忘语'),
      sourceId: sourceId,
      bookUrl: 'https://example.com/$bookId',
      totalChapters: const Value(3),
      isInShelf: const Value(true),
      updatedAt: DateTime.now(),
    ),
  );
  await db.replaceBookChapters(bookId, [
    ChaptersCompanion.insert(bookId: bookId, chapterIndex: 0, title: '第一章 七玄门', url: 'https://example.com/c0', isCached: const Value(true)),
    ChaptersCompanion.insert(bookId: bookId, chapterIndex: 1, title: '第二章 墨大夫', url: 'https://example.com/c1', isCached: const Value(true)),
    ChaptersCompanion.insert(bookId: bookId, chapterIndex: 2, title: '第三章 掌天瓶', url: 'https://example.com/c2', isCached: const Value(false)),
  ]);
  await store.writeChapter(bookId, 0, '\u3000\u3000山村少年韩立。\n\u3000\u3000初入七玄门。');
  await store.writeChapter(bookId, 1, '\u3000\u3000墨大夫传授口诀。\n\u3000\u3000第二章第二段。');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  HostBridge.instance;

  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'ttsSpeak' || 'ttsStop' || 'ttsIsAvailable' || 'updateMediaSession' || 'clearMediaSession' || 'setVolumeKeyIntercept' || 'keepScreenOn':
          return true;
        case 'getHostCapabilities':
          return {'platform': 'android', 'supportsVolumeKeyPaging': true, 'versionName': '1.0.1', 'versionCode': 2};
        default:
          return null;
      }
    });
  });

  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null));

  group('后台听书脱离、自主跨章与锁屏媒控联动测试', () {
    test('detachReader 不断播、继续推进段落与后台从磁盘/在线抓取跨章并写回 Books 进度', () async {
      final tempDir = Directory.systemTemp.createTempSync('yuewei_bg_tts_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = ChapterFileStore(rootDirProvider: () async => tempDir);
      final crawler = _StubCrawlerService({'https://example.com/c2': ['\u3000\u3000神秘绿液现世。']});

      await _seedBookWith3Chapters(db: db, store: store, bookId: 'b_bg', sourceId: 'src_test');
      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        chapterFileStoreProvider.overrideWithValue(store),
        crawlerServiceProvider.overrideWithValue(crawler),
      ]);
      addTearDown(container.dispose);

      final notifier = container.read(ttsControllerProvider.notifier);
      notifier.bindReader(owner: 'reader_a', onLocate: (_, _) {}, onRequestChapter: (_) async => null);
      expect(container.read(ttsControllerProvider).isReaderAttached, isTrue);

      final ch0 = ['\u3000\u3000山村少年韩立。', '\u3000\u3000初入七玄门。'];
      expect(await notifier.startReading(bookId: 'b_bg', bookTitle: '凡人修仙传', author: '忘语', chapterIndex: 0, chapterTitle: '第一章 七玄门', paragraphs: ch0, totalChapters: 3), isTrue);

      final stopCountBefore = calls.where((c) => c.method == 'ttsStop').length;
      notifier.detachReader('reader_a');
      expect(container.read(ttsControllerProvider).isReaderAttached, isFalse);
      expect(container.read(ttsControllerProvider).isPlaying, isTrue);
      expect(calls.where((c) => c.method == 'ttsStop').length, stopCountBefore);
      expect(calls.where((c) => c.method == 'clearMediaSession'), isEmpty);

      // 脱离后收到 onTtsDone：章内推进段落并写库
      final uid0 = (calls.last.arguments as Map)['utteranceId'] as String;
      await _sendNativeCall('onTtsDone', {'utteranceId': uid0});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(container.read(ttsControllerProvider).paragraphIndex, 1);
      var savedBook = await db.getBookById('b_bg');
      expect((savedBook?.currentChapterIndex, savedBook?.currentCharOffset), (0, TtsController.charOffsetOfParagraph(ch0, 1)));

      // 章末再收到 onTtsDone：后台从磁盘缓存加载第二章并更新 Books 进度
      final uid1 = (calls.last.arguments as Map)['utteranceId'] as String;
      await _sendNativeCall('onTtsDone', {'utteranceId': uid1});
      await Future<void>.delayed(const Duration(milliseconds: 30));
      var st = container.read(ttsControllerProvider);
      expect((st.chapterIndex, st.chapterTitle, st.paragraphIndex, st.currentParagraphText), (1, '第二章 墨大夫', 0, '墨大夫传授口诀。'));
      savedBook = await db.getBookById('b_bg');
      expect((savedBook?.currentChapterIndex, savedBook?.currentChapterTitle), (1, '第二章 墨大夫'));

      // 跳至第二章末段并播完，触发在线抓取第三章写盘并标记 isCached
      await notifier.nextParagraph();
      final uid2 = (calls.last.arguments as Map)['utteranceId'] as String;
      await _sendNativeCall('onTtsDone', {'utteranceId': uid2});
      await Future<void>.delayed(const Duration(milliseconds: 40));
      st = container.read(ttsControllerProvider);
      expect((st.chapterIndex, st.chapterTitle, st.currentParagraphText), (2, '第三章 掌天瓶', '神秘绿液现世。'));
      expect(crawler.fetchedUrls, ['https://example.com/c2']);
      final chRows = await db.getChaptersByBook('b_bg');
      expect(chRows[2].isCached, isTrue);

      // 最后一章自然播完触发 stop 与 clearMediaSession
      final uid3 = (calls.last.arguments as Map)['utteranceId'] as String;
      await _sendNativeCall('onTtsDone', {'utteranceId': uid3});
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(container.read(ttsControllerProvider).status, TtsPlaybackStatus.idle);
      expect(calls.where((c) => c.method == 'clearMediaSession').length, 1);
    });

    test('HostBridge onMediaCommand (pause/play/next/prev/toggle/stop) 精准驱动与 MediaSession 同步', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(container.dispose);

      final notifier = container.read(ttsControllerProvider.notifier);
      await notifier.startReading(bookId: 'b_mc', bookTitle: '诡秘之主', author: '爱潜水的乌贼', chapterIndex: 0, chapterTitle: '第一章 绯红', paragraphs: ['第一段。', '第二段。', '第三段。'], totalChapters: 2);

      var mediaArgs = calls.where((c) => c.method == 'updateMediaSession').last.arguments as Map;
      expect((mediaArgs['bookTitle'], mediaArgs['author'], mediaArgs['isPlaying'], mediaArgs['canPrev'], mediaArgs['canNext']), ('诡秘之主', '爱潜水的乌贼', true, false, true));

      await _sendNativeCall('onMediaCommand', {'action': 'pause'});
      await Future<void>.delayed(Duration.zero);
      expect(container.read(ttsControllerProvider).isPaused, isTrue);
      mediaArgs = calls.where((c) => c.method == 'updateMediaSession').last.arguments as Map;
      expect(mediaArgs['isPlaying'], isFalse);

      await _sendNativeCall('onMediaCommand', {'action': 'play'});
      await Future<void>.delayed(Duration.zero);
      expect(container.read(ttsControllerProvider).isPlaying, isTrue);

      await _sendNativeCall('onMediaCommand', {'action': 'next'});
      await Future<void>.delayed(Duration.zero);
      expect(container.read(ttsControllerProvider).paragraphIndex, 1);

      await _sendNativeCall('onMediaCommand', {'action': 'prev'});
      await Future<void>.delayed(Duration.zero);
      expect(container.read(ttsControllerProvider).paragraphIndex, 0);

      await _sendNativeCall('onMediaCommand', {'action': 'toggle'});
      await Future<void>.delayed(Duration.zero);
      expect(container.read(ttsControllerProvider).isPaused, isTrue);

      await _sendNativeCall('onMediaCommand', {'action': 'stop'});
      await Future<void>.delayed(Duration.zero);
      expect(container.read(ttsControllerProvider).status, TtsPlaybackStatus.idle);
      expect(calls.where((c) => c.method == 'clearMediaSession').length, 1);
    });

    testWidgets('GlobalTtsMiniCapsule 在 RootShell 底栏上方悬浮、播停/关闭与回跳 ReaderPage 自动重连定位', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('yuewei_capsule_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = ChapterFileStore(rootDirProvider: () async => tempDir);
      await tester.runAsync(() => _seedBookWith3Chapters(db: db, store: store, bookId: 'b_cap', sourceId: kLocalBookSourceId, includeSource: false));

      late ProviderContainer rootContainer;
      await tester.pumpWidget(ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db), chapterFileStoreProvider.overrideWithValue(store)],
        child: Consumer(builder: (context, ref, _) {
          rootContainer = ProviderScope.containerOf(context);
          final router = ref.watch(appRouterProvider);
          return MaterialApp.router(
            theme: SoftTokens.resolve(SoftPalette.mistyJade, isDark: false).toThemeData(),
            routerConfig: router,
          );
        }),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(GlobalTtsMiniCapsule), findsOneWidget);
      expect(find.bySemanticsLabel('关闭听书'), findsNothing);

      final ch1 = ['\u3000\u3000墨大夫传授口诀。', '\u3000\u3000第二章第二段。'];
      await tester.runAsync(() => rootContainer.read(ttsControllerProvider.notifier).startReading(
        bookId: 'b_cap',
        bookTitle: '凡人修仙传',
        author: '忘语',
        chapterIndex: 1,
        chapterTitle: '第二章 墨大夫',
        paragraphs: ch1,
        startParagraphIndex: 1,
        totalChapters: 3,
      ));
      await tester.pumpAndSettle();

      final capsuleRect = tester.getRect(find.byType(GlobalTtsMiniCapsule));
      final dockRect = tester.getRect(find.byType(SublimeFloatingDock));
      expect(capsuleRect.bottom, lessThanOrEqualTo(dockRect.top + 0.1));
      expect(find.byIcon(Icons.headphones_rounded), findsOneWidget);
      expect(find.textContaining('第二章 墨大夫'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('暂停听书'));
      await tester.pumpAndSettle();
      expect(rootContainer.read(ttsControllerProvider).isPaused, isTrue);
      expect(find.bySemanticsLabel('继续听书'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('继续听书'));
      await tester.pumpAndSettle();
      expect(rootContainer.read(ttsControllerProvider).isPlaying, isTrue);

      // 点击胶囊主体跳转到 ReaderPage：自动 attach 且定位到正在朗读的章节与段偏移
      await tester.tap(find.descendant(of: find.byType(GlobalTtsMiniCapsule), matching: find.text('凡人修仙传')));
      for (var i = 0; i < 40 && find.byType(ReaderPagerViews).evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.byType(ReaderPage), findsOneWidget);
      expect(rootContainer.read(ttsControllerProvider).isReaderAttached, isTrue);
      final pager = tester.widget<ReaderPagerViews>(find.byType(ReaderPagerViews));
      expect((pager.currentItem.chapterIndex, pager.initialCharOffset), (1, TtsController.charOffsetOfParagraph(ch1, 1)));

      // 返回离开 ReaderPage：不断播且 isReaderAttached 归 false
      final stopCountOnReader = calls.where((c) => c.method == 'ttsStop').length;
      rootContainer.read(appRouterProvider).pop();
      await tester.pumpAndSettle();
      expect(rootContainer.read(ttsControllerProvider).isPlaying, isTrue);
      expect(rootContainer.read(ttsControllerProvider).isReaderAttached, isFalse);
      expect(calls.where((c) => c.method == 'ttsStop').length, stopCountOnReader);

      // 软键盘弹出时胶囊随底栏同步隐藏（透明度归零）
      tester.view.viewInsets = const FakeViewPadding(bottom: 600.0);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final dockOpacity = tester.widget<AnimatedOpacity>(
        find.ancestor(of: find.byType(GlobalTtsMiniCapsule), matching: find.byType(AnimatedOpacity)),
      );
      expect(dockOpacity.opacity, 0.0);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();

      // 带封面 URL 时展示 BookCover，点击关闭按钮停播并清除 MediaSession
      await tester.runAsync(() => rootContainer.read(ttsControllerProvider.notifier).startReading(
        bookId: 'b_cap', bookTitle: '凡人修仙传', coverUrl: 'local_cover://b_cap/cover.jpg',
        chapterIndex: 0, chapterTitle: '第一章 七玄门', paragraphs: ['\u3000\u3000山村少年韩立。'], totalChapters: 3,
      ));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(GlobalTtsMiniCapsule), matching: find.byType(BookCover)), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('关闭听书'));
      await tester.pumpAndSettle();
      expect(rootContainer.read(ttsControllerProvider).status, TtsPlaybackStatus.idle);
      expect(find.bySemanticsLabel('关闭听书'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
