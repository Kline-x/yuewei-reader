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
import 'package:yuewei_reader/features/reader/presentation/reader_continuous_scroll_view.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_page.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_pager_views.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_settings_provider.dart';
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
          if (speakFailRemaining > 0) {
            speakFailRemaining--;
            return false;
          }
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

  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null));

  group('TTS 沉浸听书状态机、超长段切片、暂停冻时与滚动联动单测', () {
    test('起播跳过空段、暂停恢复、utteranceId 校验、章首上一段落上章末段与跨章续播', () async {
      final scope = _createTtsScope();
      final located = <(int, int)>[];
      final requestedChapters = <int>[];
      final notifier = scope.container.read(ttsControllerProvider.notifier);
      notifier.bindReader(
        owner: 'reader_1',
        onLocate: (ch, off) => located.add((ch, off)),
        onRequestChapter: (targetIdx) async {
          requestedChapters.add(targetIdx);
          if (targetIdx == 0) {
            return (chapterIndex: 0, chapterTitle: '第一章 陨落天才', paragraphs: ['首段。', '上章末段内容。', '   '], totalChapters: 2);
          }
          if (targetIdx == 1) {
            return (chapterIndex: 1, chapterTitle: '第二章 异火降世', paragraphs: ['\u3000\u3000新章首段内容。', '新章次段内容。'], totalChapters: 2);
          }
          return null;
        },
      );

      final ch0Paras = ['   ', '\u3000\u3000第一段正文。', '', '\u3000\u3000第二段正文。'];
      expect(await notifier.startReading(bookId: 'b1', chapterIndex: 0, chapterTitle: '第一章 陨落天才', paragraphs: ch0Paras, totalChapters: 2), isTrue);
      var st = scope.container.read(ttsControllerProvider);
      expect((st.status, st.paragraphIndex, (calls.last.arguments as Map)['text']), (TtsPlaybackStatus.playing, 1, '第一段正文。'));
      final firstUid = (calls.last.arguments as Map)['utteranceId'] as String;

      await notifier.pause();
      expect(scope.container.read(ttsControllerProvider).isPaused, isTrue);
      await notifier.resume();
      final resumedUid = (calls.last.arguments as Map)['utteranceId'] as String;
      expect(resumedUid, isNot(equals(firstUid)));

      await _sendNativeCall('onTtsDone', {'utteranceId': firstUid});
      await Future<void>.delayed(Duration.zero);
      expect(scope.container.read(ttsControllerProvider).paragraphIndex, 1);

      await _sendNativeCall('onTtsDone', {'utteranceId': resumedUid});
      await Future<void>.delayed(Duration.zero);
      st = scope.container.read(ttsControllerProvider);
      expect(st.paragraphIndex, 3);
      expect(located.last, (0, TtsController.charOffsetOfParagraph(ch0Paras, 3)));

      final lastUid = (calls.last.arguments as Map)['utteranceId'] as String;
      await _sendNativeCall('onTtsDone', {'utteranceId': lastUid});
      await Future<void>.delayed(Duration.zero);
      st = scope.container.read(ttsControllerProvider);
      expect(requestedChapters, [1]);
      expect((st.chapterIndex, st.paragraphIndex), (1, 0));

      // 章首调用 previousParagraph 应落到上一章最后一个非空段（索引 1）
      await notifier.previousParagraph();
      st = scope.container.read(ttsControllerProvider);
      expect((st.chapterIndex, st.paragraphIndex, st.currentParagraphText), (0, 1, '上章末段内容。'));
    });

    test('超长段落（>1200 字含标点与代理对 Emoji）安全切分、零丢字零劈裂并依次播报', () async {
      final scope = _createTtsScope();
      final notifier = scope.container.read(ttsControllerProvider.notifier);
      final longPara = '${'这是一段用于检验超长分段安全切片的中文测试句子。' * 65}🔥🚀🌟${'后续收尾正文。' * 10}';
      final chunks = TtsController.splitForSpeech(longPara);
      expect(chunks.length, greaterThanOrEqualTo(2));
      expect(chunks.join(), equals(TtsController.cleanParagraph(longPara)));
      for (final c in chunks) {
        expect(c.characters.length, lessThanOrEqualTo(1200));
        // 严禁出现孤立 UTF-16 代理对码元
        for (var i = 0; i < c.length; i++) {
          final u = c.codeUnitAt(i);
          if (u >= 0xD800 && u <= 0xDBFF) {
            expect(i + 1 < c.length && c.codeUnitAt(i + 1) >= 0xDC00 && c.codeUnitAt(i + 1) <= 0xDFFF, isTrue);
          }
        }
      }

      expect(await notifier.startReading(bookId: 'b_long', chapterIndex: 0, chapterTitle: '长段章', paragraphs: [longPara, '真正下一段。'], totalChapters: 1), isTrue);
      expect((calls.last.arguments as Map)['text'], chunks.first);
      final uid0 = (calls.last.arguments as Map)['utteranceId'] as String;
      await _sendNativeCall('onTtsDone', {'utteranceId': uid0});
      await Future<void>.delayed(Duration.zero);
      // 仍在第 0 段播第 2 子片段，不提前跳段
      expect(scope.container.read(ttsControllerProvider).paragraphIndex, 0);
      expect((calls.last.arguments as Map)['text'], chunks[1]);
    });

    test('空章/null 回退 paused 写 lastError、自动跨章失败保留进度定时与 onTtsError 透传 message', () async {
      final scope = _createTtsScope();
      final notifier = scope.container.read(ttsControllerProvider.notifier);
      var returnEmpty = false;
      notifier.bindReader(
        owner: 'r_err',
        onLocate: (_, _) {},
        onRequestChapter: (_) async => returnEmpty
            ? (chapterIndex: 1, chapterTitle: '空章', paragraphs: ['   ', ''], totalChapters: 3)
            : null,
      );
      await notifier.startReading(bookId: 'b_err', chapterIndex: 0, chapterTitle: '第一章', paragraphs: ['唯二段落。'], totalChapters: 3);
      notifier.setSleepTimer(TtsSleepTimerMode.min15);

      // 1. onTtsError 透传原生 message 到 lastError 并降级 paused
      final uid = (calls.last.arguments as Map)['utteranceId'] as String;
      await _sendNativeCall('onTtsError', {'utteranceId': uid, 'message': '语音播放被系统打断'});
      await Future<void>.delayed(Duration.zero);
      var st = scope.container.read(ttsControllerProvider);
      expect((st.status, st.lastError), (TtsPlaybackStatus.paused, '语音播放被系统打断'));

      // 2. 恢复播放后自然到章末自动跨章，但目标章返回 null -> 降级 paused 保留进度与定时
      await notifier.resume();
      final uid2 = (calls.last.arguments as Map)['utteranceId'] as String;
      await _sendNativeCall('onTtsDone', {'utteranceId': uid2});
      await Future<void>.delayed(Duration.zero);
      st = scope.container.read(ttsControllerProvider);
      expect(st.status, TtsPlaybackStatus.paused);
      expect(st.bookId, 'b_err');
      expect(st.remainingSeconds, isNotNull);
      expect(st.lastError, isNotEmpty);

      // 3. 手动切章遇到空章亦回退 paused 并写 lastError
      returnEmpty = true;
      expect(await notifier.nextChapter(), isFalse);
      st = scope.container.read(ttsControllerProvider);
      expect(st.status, TtsPlaybackStatus.paused);
      expect(st.lastError, contains('为空'));
    });

    test('5档倍速持久化、「播完本章」停播、重试降级与并发守卫', () async {
      final scope = _createTtsScope();
      final notifier = scope.container.read(ttsControllerProvider.notifier);
      notifier.bindReader(owner: 'owner_new', onLocate: (_, _) {}, onRequestChapter: (_) async => null);
      speakFailRemaining = 1;
      expect(await notifier.startReading(bookId: 'b2', chapterIndex: 0, chapterTitle: '第一章', paragraphs: ['首段内容。', '次段内容。'], totalChapters: 3), isTrue);
      expect(calls.where((c) => c.method == 'ttsSpeak').length, 2);

      await notifier.setSpeechRate(1.5);
      expect(await scope.db.getPreference(TtsController.speechRatePrefKey), '1.5');
      notifier.unbindAndStopOnDispose('owner_old');
      await Future<void>.delayed(Duration.zero);
      expect(scope.container.read(ttsControllerProvider).isPlaying, isTrue);

      speakFailRemaining = 2;
      await notifier.nextParagraph();
      expect(scope.container.read(ttsControllerProvider).status, TtsPlaybackStatus.paused);
      expect(await notifier.resume(), isTrue);

      notifier.setSleepTimer(TtsSleepTimerMode.chapterEnd);
      final uid = (calls.last.arguments as Map)['utteranceId'] as String;
      await _sendNativeCall('onTtsDone', {'utteranceId': uid});
      await Future<void>.delayed(Duration.zero);
      expect(scope.container.read(ttsControllerProvider).status, TtsPlaybackStatus.idle);
      await scope.db.setPreference(TtsController.speechRatePrefKey, '1.75');
      await notifier.reloadSpeechRateFromPrefs();
      expect(scope.container.read(ttsControllerProvider).speechRate, 1.75);
    });

    testWidgets('睡眠定时在暂停态冻结扣减、恢复后归零自动停播 (FakeAsync)', (tester) async {
      final scope = _createTtsScope();
      final notifier = scope.container.read(ttsControllerProvider.notifier);
      await notifier.startReading(bookId: 'b3', chapterIndex: 0, chapterTitle: '第一章', paragraphs: ['睡眠测试段落。'], totalChapters: 1);
      notifier.setSleepTimer(TtsSleepTimerMode.min15);
      await tester.pump(const Duration(seconds: 61));
      expect(scope.container.read(ttsControllerProvider).remainingSeconds, 839);
      expect(scope.container.read(ttsControllerProvider).formattedSleepBadge, '13:59');

      // 暂停 30 秒期间 remainingSeconds 冻结不扣减
      await notifier.pause();
      await tester.pump(const Duration(seconds: 30));
      expect(scope.container.read(ttsControllerProvider).remainingSeconds, 839);

      // 恢复后继续倒计时直至归零停播
      await notifier.resume();
      await tester.pump(const Duration(seconds: 839));
      expect(scope.container.read(ttsControllerProvider).status, TtsPlaybackStatus.idle);
      expect(calls.last.method, 'ttsStop');
    });

    testWidgets('TtsControlSheet、胶囊交互与主题对比度合规校验', (tester) async {
      final db = _createTtsScope().db;
      await tester.pumpWidget(ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: SoftTokens.resolve(SoftPalette.mistyJade, isDark: false).toThemeData(), home: Consumer(builder: (context, ref, _) {
          final tts = ref.watch(ttsControllerProvider);
          return Scaffold(body: Stack(children: [
            Center(child: ElevatedButton(
              onPressed: () async {
                await ref.read(ttsControllerProvider.notifier).startReading(bookId: 'b4', chapterIndex: 0, chapterTitle: '第三章 面板测试', paragraphs: ['第一段预览文本', '第二段预览文本'], totalChapters: 2);
                if (context.mounted) TtsControlSheet.show(context);
              },
              child: const Text('打开听书'),
            )),
            if (tts.isActive)
              ReaderTtsFloatingPill(paper: ReaderPaperTheme.porcelainWhite, botSafe: 16.0, isPlaying: tts.isPlaying, sleepBadge: tts.formattedSleepBadge, onTapExpand: () => TtsControlSheet.show(context), onTogglePlayPause: ref.read(ttsControllerProvider.notifier).togglePlayPause),
          ]));
        })),
      ));
      await tester.tap(find.text('打开听书'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1.25x'));
      await tester.pumpAndSettle();
      expect((calls.last.arguments as Map)['rate'], 1.25);
      await tester.tap(find.text('下一段'));
      await tester.pumpAndSettle();
      expect(find.text('第二段预览文本'), findsOneWidget);

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

      for (final palette in SoftPalette.values) {
        for (final isDark in [false, true]) {
          final t = SoftTokens.resolve(palette, isDark: isDark);
          expect(SoftTokens.contrastRatio(t.textSecondary, t.card), greaterThanOrEqualTo(4.5));
          expect(SoftTokens.contrastRatio(t.textSecondary, t.surface), greaterThanOrEqualTo(4.5));
        }
      }
      for (final paper in ReaderPaperTheme.all) {
        expect(SoftTokens.contrastRatio(paper.textColor, paper.menuBg), greaterThanOrEqualTo(4.5));
      }
    });

    testWidgets('ReaderPage 听书释放音量键拦截且 scroll 模式 TTS 跟随不销毁重建滚动视图', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final tempDir = Directory.systemTemp.createTempSync('yuewei_tts_reader_');
        addTearDown(() => tempDir.deleteSync(recursive: true));
        final db = _createTtsScope().db;
        final store = ChapterFileStore(rootDirProvider: () async => tempDir);
        final paras = List.generate(30, (i) => '\u3000\u3000第${i + 1}段测试正文内容，用于验证听书状态、物理音量键互斥与连续滚动平滑跟随无闪烁。');
        await tester.runAsync(() async {
          await db.upsertBook(BooksCompanion.insert(id: 'tts_vol_b1', title: '听书测试', cleanTitle: '听书测试', sourceId: kLocalBookSourceId, bookUrl: 'local://tts_vol_b1', totalChapters: const Value(1), updatedAt: DateTime.now()));
          await db.replaceBookChapters('tts_vol_b1', [ChaptersCompanion.insert(bookId: 'tts_vol_b1', chapterIndex: 0, title: '第一章', url: 'l://0', isCached: const Value(true))]);
          await store.writeChapter('tts_vol_b1', 0, paras.join('\n'));
        });

        await tester.pumpWidget(ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db), chapterFileStoreProvider.overrideWithValue(store)],
          child: MaterialApp(theme: SoftTokens.resolve(SoftPalette.mistyJade, isDark: false).toThemeData(), home: const ReaderPage(bookId: 'tts_vol_b1')),
        ));
        for (var i = 0; i < 40 && find.byType(ReaderPagerViews).evaluate().isEmpty; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          await tester.pump();
        }
        List<bool> intercepts() => calls.where((c) => c.method == 'setVolumeKeyIntercept').map((c) => (c.arguments as Map)['enabled'] as bool).toList();
        expect(intercepts().last, isTrue);

        final container = ProviderScope.containerOf(tester.element(find.byType(ReaderPage)));
        await tester.runAsync(() => container.read(readerSettingsProvider.notifier).setTurnMode(PageTurnMode.scroll));
        await tester.pumpAndSettle();
        final scrollStateBefore = tester.state<ReaderContinuousScrollViewState>(find.byType(ReaderContinuousScrollView));

        await tester.runAsync(() => container.read(ttsControllerProvider.notifier).startReading(bookId: 'tts_vol_b1', chapterIndex: 0, chapterTitle: '第一章', paragraphs: paras, totalChapters: 1));
        await tester.pump();
        expect(intercepts().last, isFalse);

        // TTS 推进到下一段触发 onLocate：滚动视图 State 必须保持同一实例，绝不更换 GlobalKey 重建
        await tester.runAsync(() => container.read(ttsControllerProvider.notifier).nextParagraph());
        await tester.pump(const Duration(milliseconds: 260));
        final scrollStateAfter = tester.state<ReaderContinuousScrollViewState>(find.byType(ReaderContinuousScrollView));
        expect(identical(scrollStateBefore, scrollStateAfter), isTrue);

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
