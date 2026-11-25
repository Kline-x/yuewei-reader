import 'dart:io';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuewei_reader/app/providers.dart';
import 'package:yuewei_reader/core/database/app_database.dart';
import 'package:yuewei_reader/core/platform/host_bridge.dart';
import 'package:yuewei_reader/core/storage/chapter_file_store.dart';
import 'package:yuewei_reader/design_system/tokens/soft_tokens.dart';
import 'package:yuewei_reader/features/reader/engine/page_models.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_page.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_pager_views.dart';
import 'package:yuewei_reader/features/tts/tts_control_sheet.dart';
import 'package:yuewei_reader/features/tts/tts_controller.dart';

const _channel = MethodChannel('com.kline.yuewei/host_bridge');

Future<void> _sendNativeCall(String method, Map<String, dynamic> args) async {
  final data = const StandardMethodCodec().encodeMethodCall(MethodCall(method, args));
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(_channel.name, data, (_) {});
}

({AppDatabase db, ProviderContainer container}) _createTtsScope() {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
  addTearDown(container.dispose);
  return (db: db, container: container);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  // 确保提前初始化 HostBridge 方法处理器
  HostBridge.instance;

  final calls = <MethodCall>[];

  var speakFailRemaining = 0;

  setUp(() {
    calls.clear();
    speakFailRemaining = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'ttsSpeak':
          if (speakFailRemaining > 0) { speakFailRemaining--; return false; }
          return true;
        case 'ttsStop' || 'ttsIsAvailable' || 'setVolumeKeyIntercept' || 'keepScreenOn':
          return true;
        case 'getHostCapabilities':
          return {'platform': 'android', 'supportsVolumeKeyPaging': true, 'versionName': '1.0.0', 'versionCode': 1};
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  group('TTS 沉浸听书状态机与跨章/倍速/定时单测', () {
    test('起播跳过空段、暂停恢复、utteranceId 校验跨段定位与自动跨章续播', () async {
      final scope = _createTtsScope();
      final located = <(int, int)>[];
      final requestedChapters = <int>[];
      final notifier = scope.container.read(ttsControllerProvider.notifier);
      notifier.bindReader(
        owner: 'reader_1',
        onLocate: (ch, off) => located.add((ch, off)),
        onRequestChapter: (targetIdx) async {
          requestedChapters.add(targetIdx);
          if (targetIdx != 1) return null;
          return (chapterIndex: 1, chapterTitle: '第二章 异火降世', paragraphs: ['\u3000\u3000新章首段内容。', '新章次段内容。'], totalChapters: 2);
        },
      );

      final ch0Paras = ['   ', '\u3000\u3000第一段正文。', '', '\u3000\u3000第二段正文。'];
      expect(await notifier.startReading(bookId: 'b1', chapterIndex: 0, chapterTitle: '第一章 陨落天才', paragraphs: ch0Paras, totalChapters: 2), isTrue);
      var state = scope.container.read(ttsControllerProvider);
      expect(state.status, TtsPlaybackStatus.playing);
      expect(state.paragraphIndex, 1);
      expect(calls.last.method, 'ttsSpeak');
      expect((calls.last.arguments as Map)['text'], '第一段正文。');
      final firstUid = (calls.last.arguments as Map)['utteranceId'] as String;

      await notifier.pause();
      expect(scope.container.read(ttsControllerProvider).status, TtsPlaybackStatus.paused);
      expect(calls.last.method, 'ttsStop');

      await notifier.resume();
      expect(scope.container.read(ttsControllerProvider).status, TtsPlaybackStatus.playing);
      final resumedUid = (calls.last.arguments as Map)['utteranceId'] as String;
      expect(resumedUid, isNot(equals(firstUid)));

      await _sendNativeCall('onTtsDone', {'utteranceId': firstUid});
      await Future<void>.delayed(Duration.zero);
      expect(scope.container.read(ttsControllerProvider).paragraphIndex, 1);

      await _sendNativeCall('onTtsDone', {'utteranceId': resumedUid});
      await Future<void>.delayed(Duration.zero);
      state = scope.container.read(ttsControllerProvider);
      expect(state.paragraphIndex, 3);
      expect(located.last, (0, TtsController.charOffsetOfParagraph(ch0Paras, 3)));
      final lastParaUid = (calls.last.arguments as Map)['utteranceId'] as String;

      await _sendNativeCall('onTtsDone', {'utteranceId': lastParaUid});
      await Future<void>.delayed(Duration.zero);
      state = scope.container.read(ttsControllerProvider);
      expect(requestedChapters, [1]);
      expect(state.chapterIndex, 1);
      expect(state.chapterTitle, '第二章 异火降世');
      expect(state.paragraphIndex, 0);
      expect((calls.last.arguments as Map)['text'], '新章首段内容。');
    });

    test('5档倍速持久化与「播完本章」定时模式到章末停播', () async {
      final scope = _createTtsScope();
      final notifier = scope.container.read(ttsControllerProvider.notifier);
      await notifier.startReading(bookId: 'b2', chapterIndex: 0, chapterTitle: '第一章', paragraphs: ['唯一一段内容。'], totalChapters: 3);
      await notifier.setSpeechRate(1.5);
      expect(scope.container.read(ttsControllerProvider).speechRate, 1.5);
      expect((calls.last.arguments as Map)['rate'], 1.5);
      expect(await scope.db.getPreference(TtsController.speechRatePrefKey), '1.5');

      notifier.setSleepTimer(TtsSleepTimerMode.chapterEnd);
      final activeUid = (calls.last.arguments as Map)['utteranceId'] as String;
      await _sendNativeCall('onTtsDone', {'utteranceId': activeUid});
      await Future<void>.delayed(Duration.zero);
      expect(scope.container.read(ttsControllerProvider).status, TtsPlaybackStatus.idle);
      expect(calls.last.method, 'ttsStop');
      // 模拟备份热恢复覆盖持久化语速后，即时刷新内存态（不受手动调速守卫限制）
      await scope.db.setPreference(TtsController.speechRatePrefKey, '1.75');
      await notifier.reloadSpeechRateFromPrefs();
      expect(scope.container.read(ttsControllerProvider).speechRate, 1.75);
    });

    testWidgets('睡眠定时分钟倒计时每秒递减并在归零时自动停播 (FakeAsync)', (tester) async {
      final scope = _createTtsScope();
      final notifier = scope.container.read(ttsControllerProvider.notifier);
      await notifier.startReading(bookId: 'b3', chapterIndex: 0, chapterTitle: '第一章', paragraphs: ['睡眠测试段落。'], totalChapters: 1);
      expect(scope.container.read(ttsControllerProvider).isPlaying, isTrue);

      notifier.setSleepTimer(TtsSleepTimerMode.min15);
      expect(scope.container.read(ttsControllerProvider).remainingSeconds, 900);
      await tester.pump(const Duration(seconds: 61));
      expect(scope.container.read(ttsControllerProvider).remainingSeconds, 839);
      expect(scope.container.read(ttsControllerProvider).formattedSleepBadge, '13:59');

      await tester.pump(const Duration(seconds: 839));
      expect(scope.container.read(ttsControllerProvider).status, TtsPlaybackStatus.idle);
      expect(calls.last.method, 'ttsStop');
    });

    testWidgets('TtsControlSheet 与迷你悬浮胶囊渲染及按钮交互闭环', (tester) async {
      final db = _createTtsScope().db;
      await tester.pumpWidget(ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: SoftTokens.resolve(SoftPalette.mistyJade, isDark: false).toThemeData(), home: Consumer(builder: (context, ref, _) {
          final tts = ref.watch(ttsControllerProvider);
          return Scaffold(body: Stack(children: [
            Center(child: ElevatedButton(
              onPressed: () async {
                await ref.read(ttsControllerProvider.notifier).startReading(
                  bookId: 'b4', chapterIndex: 0, chapterTitle: '第三章 面板测试', paragraphs: ['第一段预览文本', '第二段预览文本'], totalChapters: 2,
                );
                if (context.mounted) TtsControlSheet.show(context);
              },
              child: const Text('打开听书'),
            )),
            if (tts.isActive)
              ReaderTtsFloatingPill(
                paper: ReaderPaperTheme.porcelainWhite, botSafe: 16.0, isPlaying: tts.isPlaying, sleepBadge: tts.formattedSleepBadge,
                onTapExpand: () => TtsControlSheet.show(context), onTogglePlayPause: ref.read(ttsControllerProvider.notifier).togglePlayPause,
              ),
          ]));
        })),
      ));

      await tester.tap(find.text('打开听书'));
      await tester.pumpAndSettle();
      expect(find.text('沉浸听书'), findsOneWidget);
      expect(find.text('第三章 面板测试'), findsOneWidget);
      expect(find.text('第一段预览文本'), findsOneWidget);

      await tester.tap(find.text('1.25x'));
      await tester.pumpAndSettle();
      expect((calls.last.arguments as Map)['rate'], 1.25);

      await tester.tap(find.text('下一段'));
      await tester.pumpAndSettle();
      expect(find.text('第二段预览文本'), findsOneWidget);

      // 模拟上一章切章失败（连续2次 false）降级为 paused 并展示高对比度错误提示条
      speakFailRemaining = 2;
      await tester.tap(find.text('上一段'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.text('语音引擎连接中断，请点击播放重试'), findsOneWidget);

      await tester.ensureVisible(find.text('退出听书'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('退出听书'));
      await tester.pumpAndSettle();
      expect(find.text('沉浸听书'), findsNothing);
      expect(find.text('听书中'), findsNothing);
    });

    test('ttsSpeak 首调失败自动重试续播与连续失败降级 paused 保留进度', () async {
      final scope = _createTtsScope();
      final notifier = scope.container.read(ttsControllerProvider.notifier);
      speakFailRemaining = 1;
      expect(await notifier.startReading(bookId: 'b_retry', chapterIndex: 0, chapterTitle: '第一章', paragraphs: ['首段内容。', '次段内容。'], totalChapters: 2), isTrue);
      expect(scope.container.read(ttsControllerProvider).isPlaying, isTrue);
      expect(scope.container.read(ttsControllerProvider).lastError, isNull);
      expect(calls.where((c) => c.method == 'ttsSpeak').length, 2);

      speakFailRemaining = 2;
      await notifier.nextParagraph();
      final pausedState = scope.container.read(ttsControllerProvider);
      expect(pausedState.status, TtsPlaybackStatus.paused);
      expect(pausedState.bookId, 'b_retry');
      expect(pausedState.paragraphIndex, 1);
      expect(pausedState.lastError, contains('语音引擎连接中断'));

      expect(await notifier.resume(), isTrue);
      expect(scope.container.read(ttsControllerProvider).isPlaying, isTrue);
      expect(scope.container.read(ttsControllerProvider).lastError, isNull);
    });

    test('unbindAndStopOnDispose 新旧 owner 互斥保护与 setSpeechRate 异步并发守卫', () async {
      final scope = _createTtsScope();
      final notifier = scope.container.read(ttsControllerProvider.notifier);
      notifier.bindReader(owner: 'owner_new', onLocate: (_, _) {}, onRequestChapter: (_) async => null);
      await notifier.startReading(bookId: 'b_lock', chapterIndex: 0, chapterTitle: '第一章', paragraphs: ['测试段落内容。'], totalChapters: 1);
      notifier.unbindAndStopOnDispose('owner_old');
      await Future<void>.delayed(Duration.zero);
      expect(scope.container.read(ttsControllerProvider).isPlaying, isTrue);

      final rateFuture = notifier.setSpeechRate(1.75);
      await notifier.pause();
      await rateFuture;
      expect(scope.container.read(ttsControllerProvider).isPaused, isTrue);
      expect(calls.last.method, 'ttsStop');
    });

    testWidgets('8套主题与5套纸感下 TtsControlSheet 及胶囊渲染无溢出且对比度合规', (tester) async {
      final db = _createTtsScope().db;
      for (final palette in SoftPalette.values) {
        for (final isDark in [false, true]) {
          final tokens = SoftTokens.resolve(palette, isDark: isDark);
          expect(SoftTokens.contrastRatio(tokens.textSecondary, tokens.card), greaterThanOrEqualTo(4.5));
          expect(SoftTokens.contrastRatio(tokens.textSecondary, tokens.surface), greaterThanOrEqualTo(4.5));
          await tester.pumpWidget(ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(db)],
            child: MaterialApp(theme: tokens.toThemeData(), home: const Scaffold(body: TtsControlSheet())),
          ));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
      }
      for (final paper in ReaderPaperTheme.all) {
        expect(SoftTokens.contrastRatio(paper.textColor, paper.menuBg), greaterThanOrEqualTo(4.5));
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: Stack(children: [
          ReaderTtsFloatingPill(paper: paper, botSafe: 34.0, isPlaying: true, sleepBadge: '14:59', onTapExpand: () {}, onTogglePlayPause: () {}),
        ]))));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('ReaderPage 听书态自动释放音量键拦截并守卫翻页、停播后恢复拦截', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final tempDir = Directory.systemTemp.createTempSync('yuewei_tts_reader_');
        addTearDown(() => tempDir.deleteSync(recursive: true));
        final db = _createTtsScope().db;
        final store = ChapterFileStore(rootDirProvider: () async => tempDir);

        await tester.runAsync(() async {
          await db.upsertBook(BooksCompanion.insert(
            id: 'tts_vol_b1', title: '听书音量键测试', cleanTitle: '听书音量键测试',
            sourceId: kLocalBookSourceId, bookUrl: 'local://tts_vol_b1',
            totalChapters: const Value(1), updatedAt: DateTime.now(),
          ));
          await db.replaceBookChapters('tts_vol_b1', [
            ChaptersCompanion.insert(bookId: 'tts_vol_b1', chapterIndex: 0, title: '第一章', url: 'l://0', isCached: const Value(true)),
          ]);
          final text = List.generate(35, (i) => '\u3000\u3000第${i + 1}段测试正文内容，用于验证听书状态与物理音量键拦截互斥闭环行为。').join('\n');
          await store.writeChapter('tts_vol_b1', 0, text);
        });

        await tester.pumpWidget(ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db), chapterFileStoreProvider.overrideWithValue(store)],
          child: MaterialApp(theme: SoftTokens.resolve(SoftPalette.mistyJade, isDark: false).toThemeData(), home: const ReaderPage(bookId: 'tts_vol_b1')),
        ));
        for (var i = 0; i < 40 && find.byType(ReaderPagerViews).evaluate().isEmpty; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          await tester.pump();
        }
        expect(find.byType(ReaderPagerViews), findsOneWidget);
        List<bool> intercepts() => calls.where((c) => c.method == 'setVolumeKeyIntercept').map((c) => (c.arguments as Map)['enabled'] as bool).toList();
        expect(intercepts().last, isTrue);

        await _sendNativeCall('onVolumeDown', {});
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        final offsetBeforeTts = (await tester.runAsync(() => db.getBookById('tts_vol_b1')))!.currentCharOffset;
        expect(offsetBeforeTts, greaterThan(0));

        final container = ProviderScope.containerOf(tester.element(find.byType(ReaderPage)));
        await tester.runAsync(() => container.read(ttsControllerProvider.notifier).startReading(
              bookId: 'tts_vol_b1', chapterIndex: 0, chapterTitle: '第一章', paragraphs: ['\u3000\u3000测试朗读第一段。'], totalChapters: 1,
            ));
        await tester.pump();
        expect(intercepts().last, isFalse);

        await _sendNativeCall('onVolumeDown', {});
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        expect((await tester.runAsync(() => db.getBookById('tts_vol_b1')))!.currentCharOffset, offsetBeforeTts);

        await tester.runAsync(() => container.read(ttsControllerProvider.notifier).stop());
        await tester.pump();
        expect(intercepts().last, isTrue);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}
