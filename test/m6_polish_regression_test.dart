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
import 'package:yuewei_reader/core/platform/host_bridge.dart';
import 'package:yuewei_reader/core/storage/chapter_file_store.dart';
import 'package:yuewei_reader/design_system/components/empty_error_view.dart';
import 'package:yuewei_reader/design_system/feedback/app_feedback.dart';
import 'package:yuewei_reader/design_system/tokens/soft_metrics.dart';
import 'package:yuewei_reader/design_system/tokens/soft_tokens.dart';
import 'package:yuewei_reader/features/discover/presentation/discover_page.dart';
import 'package:yuewei_reader/features/discover/presentation/discover_sections.dart';
import 'package:yuewei_reader/features/settings/presentation/settings_page.dart';
import 'package:yuewei_reader/features/shelf/presentation/shelf_page.dart';
import 'package:yuewei_reader/features/sources/domain/book_match_models.dart';
import 'package:yuewei_reader/features/tts/global_tts_mini_capsule.dart';
import 'package:yuewei_reader/features/tts/tts_controller.dart';

const _channel = MethodChannel('com.kline.yuewei/host_bridge');

void _assertNoOpacityAncestorAboveBackdropFilter(WidgetTester tester) {
  final backdropFinder = find.byType(BackdropFilter);
  expect(backdropFinder, findsWidgets);
  for (final element in backdropFinder.evaluate()) {
    element.visitAncestorElements((ancestor) {
      final w = ancestor.widget;
      expect(
        w is Opacity ||
            w is AnimatedOpacity ||
            w is FadeTransition ||
            w is SliverFadeTransition,
        isFalse,
        reason: 'BackdropFilter 上游严禁存在 ${w.runtimeType}（会触发 Impeller SetInheritedOpacity 日志）',
      );
      return true;
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  HostBridge.instance;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'ttsSpeak' ||
              'ttsStop' ||
              'ttsIsAvailable' ||
              'updateMediaSession' ||
              'clearMediaSession' ||
              'setVolumeKeyIntercept' ||
              'keepScreenOn':
          return true;
        case 'getHostCapabilities':
          return {
            'platform': 'android',
            'supportsVolumeKeyPaging': true,
            'versionName': '1.0.2',
            'versionCode': 3,
          };
        default:
          return null;
      }
    });
  });

  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, null));

  group('M6 尾项修复专项回归门禁', () {
    test('SoftSpacing.bottomClearance 动态净空标尺计算正确', () {
      expect(SoftSpacing.ttsCapsuleExtraClearance, 80.0);
      expect(SoftSpacing.bottomClearance(hasTtsCapsule: false), SoftSpacing.dockClearance);
      expect(
        SoftSpacing.bottomClearance(hasTtsCapsule: true),
        SoftSpacing.dockClearance + 80.0,
      );
    });

    testWidgets('听书胶囊活跃态时 SettingsPage / ShelfPage / DiscoverPage 与撤销条动态抬升 80dp',
        (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('yuewei_m6_clear_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = ChapterFileStore(rootDirProvider: () async => tempDir);

      await tester.runAsync(() => db.upsertBook(
            BooksCompanion.insert(
              id: 'b_clear',
              title: '雪中悍刀行',
              cleanTitle: '雪中悍刀行',
              author: const Value('烽火戏诸侯'),
              sourceId: 'local_book',
              bookUrl: '',
              totalChapters: const Value(1),
              isInShelf: const Value(true),
              updatedAt: DateTime.now(),
            ),
          ));

      late ProviderContainer rootContainer;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            chapterFileStoreProvider.overrideWithValue(store),
          ],
          child: Consumer(builder: (context, ref, _) {
            rootContainer = ProviderScope.containerOf(context);
            return MaterialApp.router(
              theme: SoftTokens.resolve(SoftPalette.mistyJade, isDark: false).toThemeData(),
              routerConfig: ref.watch(appRouterProvider),
            );
          }),
        ),
      );
      await tester.pumpAndSettle();

      // 1) 书架列表态初始净空 = 104.0
      expect(find.byType(ShelfPage), findsOneWidget);
      var shelfListPad = tester.widget<SliverPadding>(find.byType(SliverPadding).first);
      expect((shelfListPad.padding as EdgeInsets).bottom, SoftSpacing.dockClearance);

      // 激活听书胶囊
      await tester.runAsync(() => rootContainer.read(ttsControllerProvider.notifier).startReading(
            bookId: 'b_clear',
            bookTitle: '雪中悍刀行',
            chapterIndex: 0,
            chapterTitle: '第一章',
            paragraphs: ['北凉三千里。'],
            totalChapters: 1,
          ));
      await tester.pumpAndSettle();

      // 书架列表态净空抬升至 184.0
      shelfListPad = tester.widget<SliverPadding>(find.byType(SliverPadding).first);
      expect(
        (shelfListPad.padding as EdgeInsets).bottom,
        SoftSpacing.bottomClearance(hasTtsCapsule: true),
      );

      // 书架网格态净空抬升至 184.0
      await tester.runAsync(() => rootContainer.read(shelfViewPrefsProvider.notifier).toggleGridView());
      await tester.pumpAndSettle();
      final shelfGridPad = tester.widget<SliverPadding>(find.byType(SliverPadding).first);
      expect(
        (shelfGridPad.padding as EdgeInsets).bottom,
        SoftSpacing.bottomClearance(hasTtsCapsule: true),
      );

      // 切到探索页验证 DiscoverIdleSection 底部净空
      await tester.tap(find.text('探索'));
      await tester.pumpAndSettle();
      expect(find.byType(DiscoverPage), findsOneWidget);
      final discoverIdle = tester.widget<DiscoverIdleSection>(find.byType(DiscoverIdleSection));
      expect(discoverIdle.bottomClearance, SoftSpacing.bottomClearance(hasTtsCapsule: true));
      final discoverList = tester.widget<ListView>(
        find.descendant(of: find.byType(DiscoverIdleSection), matching: find.byType(ListView)),
      );
      expect((discoverList.padding as EdgeInsets).bottom, 184.0);

      // 切到设置页并滑到底部：检查「检查应用更新」位于悬浮听书胶囊上方且完全不被遮挡
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      final settingsListFinder = find.descendant(
        of: find.byType(SettingsPage),
        matching: find.byType(ListView),
      );
      final settingsList = tester.widget<ListView>(settingsListFinder);
      expect((settingsList.padding as EdgeInsets).bottom, 184.0);

      await tester.drag(settingsListFinder, const Offset(0, -1500));
      await tester.pumpAndSettle();
      final updateTileRect = tester.getRect(find.text('检查应用更新'));
      final capsuleRect = tester.getRect(find.byType(GlobalTtsMiniCapsule));
      expect(updateTileRect.bottom, lessThanOrEqualTo(capsuleRect.top));

      // 验证书架空态净空
      await tester.runAsync(() => rootContainer.read(shelfRepositoryProvider).setInShelf('b_clear', false));
      await tester.tap(find.text('书架'));
      await tester.pumpAndSettle();
      final emptyPad = tester.widget<Padding>(
        find.ancestor(of: find.byType(EmptyErrorView), matching: find.byType(Padding)).first,
      );
      expect((emptyPad.padding as EdgeInsets).bottom, 184.0);

      await tester.runAsync(() => rootContainer.read(ttsControllerProvider.notifier).stop());
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('AppFeedback.showUndoSnackBar 与 DiscoverResultsList 支持悬浮胶囊额外净空',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SoftTokens.resolve(SoftPalette.mistyJade, isDark: false).toThemeData(),
          home: Scaffold(
            body: Column(
              children: [
                Builder(
                  builder: (ctx) => TextButton(
                    onPressed: () => AppFeedback.showUndoSnackBar(
                      ctx,
                      message: '已移除测试书籍',
                      extraBottomClearance: SoftSpacing.ttsCapsuleExtraClearance,
                      onUndo: () {},
                      onCommitted: () {},
                    ),
                    child: const Text('触发撤销条'),
                  ),
                ),
                Expanded(
                  child: DiscoverResultsList(
                    bottomClearance: SoftSpacing.bottomClearance(hasTtsCapsule: true),
                    results: [
                      AggregatedBookMatch(
                        cleanTitle: '大道朝天',
                        cleanAuthor: '猫腻',
                        hits: const [
                          SourceSearchHit(
                            sourceId: 'src_1',
                            sourceName: '测试书源',
                            title: '大道朝天',
                            author: '猫腻',
                            bookUrl: 'https://example.com/book',
                            latencyMs: 36,
                          ),
                        ],
                      ),
                    ],
                    onTapBook: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final resList = tester.widget<ListView>(
        find.descendant(of: find.byType(DiscoverResultsList), matching: find.byType(ListView)),
      );
      expect((resList.padding as EdgeInsets).bottom, 184.0);

      await tester.tap(find.text('触发撤销条'));
      await tester.pump();
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(
        (snackBar.margin as EdgeInsets).bottom,
        SoftSpacing.dockClearance - 8.0 + SoftSpacing.ttsCapsuleExtraClearance,
      );
    });

    testWidgets('RootShell 与 GlobalTtsMiniCapsule 严禁任何透明度节点包裹 BackdropFilter',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      late ProviderContainer rootContainer;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: Consumer(builder: (context, ref, _) {
            rootContainer = ProviderScope.containerOf(context);
            return MaterialApp.router(
              theme: SoftTokens.resolve(SoftPalette.mistyJade, isDark: false).toThemeData(),
              routerConfig: ref.watch(appRouterProvider),
            );
          }),
        ),
      );
      await tester.pumpAndSettle();
      _assertNoOpacityAncestorAboveBackdropFilter(tester);

      // 激活悬浮胶囊途中与稳态均不能出现 FadeTransition / AnimatedOpacity / Opacity 包裹 BackdropFilter
      await tester.runAsync(() => rootContainer.read(ttsControllerProvider.notifier).startReading(
            bookId: 'b_impeller',
            bookTitle: '将夜',
            chapterIndex: 0,
            chapterTitle: '第一章',
            paragraphs: ['渭城朝雨。'],
            totalChapters: 1,
          ));
      await tester.pump(const Duration(milliseconds: 100));
      _assertNoOpacityAncestorAboveBackdropFilter(tester);
      await tester.pumpAndSettle();
      _assertNoOpacityAncestorAboveBackdropFilter(tester);

      // 软键盘弹出态滑出时同样不能有透明度父节点
      tester.view.viewInsets = const FakeViewPadding(bottom: 520.0);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump(const Duration(milliseconds: 100));
      _assertNoOpacityAncestorAboveBackdropFilter(tester);
      await tester.pumpAndSettle();
      _assertNoOpacityAncestorAboveBackdropFilter(tester);

      tester.view.resetViewInsets();
      await tester.runAsync(() => rootContainer.read(ttsControllerProvider.notifier).stop());
      await tester.pumpAndSettle();

      final routerCode = File('lib/app/router.dart').readAsStringSync();
      final capsuleCode = File('lib/features/tts/global_tts_mini_capsule.dart').readAsStringSync();
      expect(routerCode.contains('AnimatedOpacity'), isFalse);
      expect(capsuleCode.contains('FadeTransition'), isFalse);
      expect(capsuleCode.contains('AnimatedOpacity'), isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    test('MainActivity.kt 在 Android 13+ 拉起媒体会话时温和申请 POST_NOTIFICATIONS 且不阻塞前台服务', () {
      final kt = File('android/app/src/main/kotlin/com/kline/yuewei_reader/MainActivity.kt')
          .readAsStringSync();
      for (final token in [
        'private const val REQ_POST_NOTIFICATIONS = 4097',
        'private var requestedPostNotifications = false',
        'Build.VERSION_CODES.TIRAMISU',
        'Manifest.permission.POST_NOTIFICATIONS',
        'ContextCompat.checkSelfPermission',
        'ActivityCompat.requestPermissions',
        'maybeRequestPostNotificationsPermission()',
      ]) {
        expect(kt, contains(token), reason: 'MainActivity.kt 缺少 $token');
      }
    });
  });
}
