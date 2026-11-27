import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:yuewei_reader/app/providers.dart';
import 'package:yuewei_reader/core/database/app_database.dart';
import 'package:yuewei_reader/core/network/app_http_client.dart';
import 'package:yuewei_reader/core/storage/chapter_file_store.dart';
import 'package:yuewei_reader/design_system/tokens/soft_tokens.dart';
import 'package:yuewei_reader/features/local_import/data/local_import_service.dart';
import 'package:yuewei_reader/features/local_import/presentation/import_and_transfer_page.dart';
import 'package:yuewei_reader/features/reader/engine/page_models.dart';
import 'package:yuewei_reader/features/reader/fonts/custom_font_manager.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_font_sheet.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_settings_provider.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_typography_sheet.dart';
import 'package:yuewei_reader/features/sources/data/source_repository.dart';

class _DirectHttpOverrides extends HttpOverrides {}

List<int> _validTtfBytes([int seed = 7]) => <int>[0x00, 0x01, 0x00, 0x00, seed, 0x11, 0x22, 0x33];

void main() {
  const hostChannel = MethodChannel('com.kline.yuewei/host_bridge');
  late Directory tempDir;
  late AppDatabase db;
  late CustomFontService fontService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('yuewei_typo_ui_');
    db = AppDatabase(NativeDatabase.memory());
    fontService = CustomFontService(
      db: db,
      rootDirProvider: () async => tempDir,
      fontLoader: (_, _) async {},
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(hostChannel, null);
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  List<Override> overrides() => [
        appDatabaseProvider.overrideWithValue(db),
        customFontServiceProvider.overrideWithValue(fontService),
        chapterFileStoreProvider.overrideWithValue(ChapterFileStore(rootDirProvider: () async => tempDir)),
        sourceRepositoryProvider.overrideWithValue(SourceRepository(db: db, httpClient: AppHttpClient())),
      ];

  void useLargeViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> flushRealIo(
    WidgetTester tester, {
    bool Function()? until,
  }) async {
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump(const Duration(milliseconds: 20));
      final spinnerGone = find.byType(CircularProgressIndicator).evaluate().isEmpty;
      if (spinnerGone && (until == null || until())) break;
    }
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpAndSettle();
  }

  testWidgets('排版抽屉精细滑杆（段距/边距/字距）、首行缩进、版式切换与重置按钮交互', (tester) async {
    useLargeViewport(tester);
    late WidgetRef capturedRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          theme: SoftTokens.resolve(SoftPalette.mistyJade, isDark: false).toThemeData(),
          home: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return Scaffold(
                body: Center(
                  child: ElevatedButton(onPressed: () => ReaderTypographySheet.show(context), child: const Text('打开排版')),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开排版'));
    await tester.pumpAndSettle();
    expect(find.text('阅读字体'), findsOneWidget);
    expect(find.text('系统默认'), findsOneWidget);

    for (final keyName in [
      'typo_paragraph_gap_slider',
      'typo_horizontal_padding_slider',
      'typo_letter_spacing_slider',
    ]) {
      final finder = find.byKey(Key(keyName));
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      final rect = tester.getRect(finder);
      await tester.tapAt(Offset(rect.right - 14.0, rect.center.dy));
      await tester.pumpAndSettle();
    }

    final afterSlide = capturedRef.read(readerSettingsProvider);
    expect(afterSlide.paragraphGap, greaterThan(13.0));
    expect(afterSlide.horizontalPadding, greaterThan(22.0));
    expect(afterSlide.letterSpacing, greaterThan(0.35));

    final indentSwitch = find.byKey(const Key('typo_indent_switch'));
    await tester.ensureVisible(indentSwitch);
    await tester.tap(indentSwitch);
    await tester.pumpAndSettle();
    expect(capturedRef.read(readerSettingsProvider).indentFirstLine, isFalse);

    await tester.ensureVisible(find.text('双页'));
    await tester.tap(find.text('双页'));
    await tester.pumpAndSettle();
    expect(capturedRef.read(readerSettingsProvider).layoutMode, ReaderLayoutMode.dual);

    await tester.tap(find.text('单页'));
    await tester.pumpAndSettle();
    expect(capturedRef.read(readerSettingsProvider).layoutMode, ReaderLayoutMode.single);

    final resetBtn = find.byKey(const Key('typo_reset_button'));
    await tester.ensureVisible(resetBtn);
    await tester.tap(resetBtn);
    await tester.pumpAndSettle();

    final resetState = capturedRef.read(readerSettingsProvider);
    expect(resetState.paragraphGap, 13.0);
    expect(resetState.horizontalPadding, 22.0);
    expect(resetState.letterSpacing, 0.35);
    expect(resetState.indentFirstLine, isTrue);
    expect(resetState.layoutMode, ReaderLayoutMode.auto);
    expect(find.text('已恢复默认排版设置'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('ReaderFontSheet 本机导入、异常拦截、切换默认、删除回落与跳转 Wi-Fi 传字体', (tester) async {
    useLargeViewport(tester);
    final validFile = File(p.join(tempDir.path, 'WenKaiLite.ttf'))..writeAsBytesSync(_validTtfBytes(9));
    final badFile = File(p.join(tempDir.path, 'Broken.ttf'))..writeAsBytesSync(<int>[0x42, 0x41, 0x44, 0x21]);
    var pickRound = 0;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(hostChannel, (call) async {
      if (call.method != 'pickFontFile') return null;
      pickRound++;
      final f = pickRound == 1 ? validFile : badFile;
      return <String, dynamic>{'path': f.path, 'name': p.basename(f.path), 'size': f.lengthSync()};
    });

    late WidgetRef capturedRef;
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return Scaffold(
                body: Center(
                  child: ElevatedButton(onPressed: () => ReaderTypographySheet.show(context), child: const Text('打开排版')),
                ),
              );
            },
          ),
        ),
        GoRoute(path: '/import', builder: (_, _) => const Scaffold(body: Center(child: Text('传书工作台页面')))),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp.router(
          theme: SoftTokens.resolve(SoftPalette.mistyJade, isDark: false).toThemeData(),
          routerConfig: router,
        ),
      ),
    );

    await tester.tap(find.text('打开排版'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('typo_font_entry_row')));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderFontSheet), findsOneWidget);
    expect(find.text('系统默认字体'), findsOneWidget);

    await tester.tap(find.text('从本机导入 (.ttf / .otf)'));
    await flushRealIo(tester);
    final imported = capturedRef.read(customFontManagerProvider);
    expect(imported.length, 1);
    expect(imported.first.displayName, 'WenKaiLite');
    expect(capturedRef.read(readerSettingsProvider).fontFamily, imported.first.fontFamily);
    expect(find.textContaining('TTF · 8 B'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.text('从本机导入 (.ttf / .otf)'));
    await flushRealIo(tester);
    expect(find.textContaining('无效的字体文件头'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.text('系统默认字体'));
    await tester.pumpAndSettle();
    expect(capturedRef.read(readerSettingsProvider).fontFamily, isNull);

    await tester.tap(find.text('WenKaiLite').last);
    await tester.pumpAndSettle();
    expect(capturedRef.read(readerSettingsProvider).fontFamily, imported.first.fontFamily);

    await tester.tap(find.byTooltip('删除字体'));
    await tester.pumpAndSettle();
    expect(find.text('删除自定义字体'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await flushRealIo(
      tester,
      until: () =>
          capturedRef.read(customFontManagerProvider).isEmpty &&
          capturedRef.read(readerSettingsProvider).fontFamily == null,
    );
    expect(capturedRef.read(customFontManagerProvider), isEmpty);
    expect(capturedRef.read(readerSettingsProvider).fontFamily, isNull);
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.text('Wi-Fi 传字体'));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderFontSheet), findsNothing);
    expect(find.byType(ReaderTypographySheet), findsNothing);
    expect(find.text('传书工作台页面'), findsOneWidget);
  });

  testWidgets('wifiTransferServerProvider 注入 customFontImporter 及传书页展示与点击提示', (tester) async {
    await tester.runAsync(() async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final container = ProviderContainer(
          overrides: [
            ...overrides(),
            localImportServiceProvider.overrideWithValue(
              LocalImportService(db: db, fileStore: ChapterFileStore(rootDirProvider: () async => tempDir)),
            ),
          ],
        );
        addTearDown(container.dispose);

        final server = container.read(wifiTransferServerProvider);
        expect(server.customFontImporter, isNotNull);
        await server.start();
        final client = HttpClient();
        try {
          final req = await client.postUrl(
            Uri.parse('http://127.0.0.1:${server.port}/api/upload?name=SourceSerif.otf&token=${server.accessToken}'),
          );
          req.add(<int>[0x4F, 0x54, 0x54, 0x4F, 0x01, 0x02, 0x03]);
          final resp = await req.close();
          expect(resp.statusCode, HttpStatus.ok);
          final body = jsonDecode(await utf8.decodeStream(resp)) as Map<String, dynamic>;
          expect(body['kind'], 'font');
          expect(container.read(customFontManagerProvider).single.displayName, 'SourceSerif');
        } finally {
          client.close(force: true);
          await server.stop();
        }
      }, _DirectHttpOverrides());
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          theme: SoftTokens.resolve(SoftPalette.mistyJade, isDark: false).toThemeData(),
          home: const ImportAndTransferPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(ImportAndTransferPage));
    final pageServer = ProviderScope.containerOf(element).read(wifiTransferServerProvider);

    await tester.runAsync(() async {
      await HttpOverrides.runWithHttpOverrides(() async {
        await pageServer.start();
        final client = HttpClient();
        try {
          final req = await client.postUrl(
            Uri.parse('http://127.0.0.1:${pageServer.port}/api/upload?name=FangSong.ttf&token=${pageServer.accessToken}'),
          );
          req.add(_validTtfBytes(15));
          final resp = await req.close();
          expect(resp.statusCode, HttpStatus.ok);
          await resp.drain<void>();
          await Future<void>.delayed(const Duration(milliseconds: 50));
        } finally {
          client.close(force: true);
        }
      }, _DirectHttpOverrides());
    });

    await tester.pumpAndSettle();
    expect(find.text('已导入字体「FangSong」'), findsOneWidget);
    expect(find.byIcon(Icons.font_download_rounded), findsOneWidget);
    expect(find.text('字体'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.text('FangSong'));
    await tester.pumpAndSettle();
    expect(find.text('可在阅读器排版设置中选用该字体'), findsOneWidget);
    expect(find.text('未在书架找到该书籍，请回到书架查看'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.runAsync(() => pageServer.stop());
  });
}
