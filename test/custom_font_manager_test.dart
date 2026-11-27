import 'dart:io';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yuewei_reader/app/providers.dart';
import 'package:yuewei_reader/core/database/app_database.dart';
import 'package:yuewei_reader/features/reader/engine/page_models.dart';
import 'package:yuewei_reader/features/reader/fonts/custom_font_manager.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_settings_provider.dart';

Uint8List _validTtfBytes([int seed = 1]) =>
    Uint8List.fromList([0x00, 0x01, 0x00, 0x00, seed, 0x10, 0x20, 0x30]);

Uint8List _validOtfBytes([int seed = 2]) =>
    Uint8List.fromList([0x4F, 0x54, 0x54, 0x4F, seed, 0x40, 0x50, 0x60]);

void main() {
  late Directory tempDir;
  late AppDatabase db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('yuewei_font_test_');
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('CustomFontEntry JSON 编解码与坏条目容错', () {
    final now = DateTime.utc(2026, 11, 27, 9, 0);
    final list = [
      CustomFontEntry(
        id: 'font_abc',
        displayName: '霞鹜文楷',
        fontFamily: 'YueweiFont_font_abc',
        fileName: 'font_abc.ttf',
        fileSizeBytes: 1024,
        importedAt: now,
      ),
    ];
    final decoded = CustomFontEntry.decodeList(CustomFontEntry.encodeList(list));
    expect(decoded, equals(list));
    expect(CustomFontEntry.decodeList('not-json'), isEmpty);
    expect(
      CustomFontEntry.decodeList('[{"id":"","fontFamily":"x"},{"id":"a","fontFamily":"b","fileName":"c.ttf"}]').length,
      1,
    );
  });

  test('魔数头校验、30MB 体积熔断、picked_fonts 清理、持久化、容错重载与删除', () async {
    expect(CustomFontService.defaultMaxFontBytes, 30 * 1024 * 1024);
    expect(AppDatabase.isSyncablePreferenceKey(CustomFontService.prefsKey), isFalse);
    expect(CustomFontService.isValidFontHeader([0x74, 0x72, 0x75, 0x65]), isTrue);
    expect(CustomFontService.isValidFontHeader([0x74, 0x74, 0x63, 0x66]), isTrue);

    final loadedFamilies = <(String, int)>[];
    final service = CustomFontService(
      db: db,
      rootDirProvider: () async => tempDir,
      fontLoader: (family, bytes) async => loadedFamilies.add((family, bytes.length)),
    );

    final pickedDir = await Directory(p.join(tempDir.path, 'picked_fonts')).create(recursive: true);
    final pickedTtf = File(p.join(pickedDir.path, 'LXGWWenKai.ttf'))..writeAsBytesSync(_validTtfBytes(1));
    final keepOtf = File(p.join(tempDir.path, 'SourceHan.otf'))..writeAsBytesSync(_validOtfBytes(2));
    final badPicked = File(p.join(pickedDir.path, 'fake.ttf'))..writeAsBytesSync([0x50, 0x4B, 0x03, 0x04]);

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      customFontServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);

    final notifier = container.read(customFontManagerProvider.notifier);
    final font1 = await notifier.importFontFile(sourcePath: pickedTtf.path);
    expect(await pickedTtf.exists(), isFalse);
    expect(font1.displayName, 'LXGWWenKai');
    expect(File(p.join(tempDir.path, 'custom_fonts', font1.fileName)).existsSync(), isTrue);

    // 幂等重复导入不产生重复记录
    final dupSource = File(p.join(tempDir.path, 'dup.ttf'))..writeAsBytesSync(_validTtfBytes(1));
    await notifier.importFontFile(sourcePath: dupSource.path, displayName: '霞鹜文楷');
    expect(container.read(customFontManagerProvider).length, 1);
    expect(container.read(customFontManagerProvider).first.displayName, '霞鹜文楷');

    // 导入第二款 OTF 字体并保留非 picked_fonts 原文件
    final font2 = await notifier.importFontFile(sourcePath: keepOtf.path);
    expect(await keepOtf.exists(), isTrue);
    expect(container.read(customFontManagerProvider).length, 2);
    expect(loadedFamilies.last.$1, font2.fontFamily);
    expect(await db.getPreference(AppDatabase.syncPrefsUpdatedAtKey), isNull);

    // 无效魔数头拒绝且 picked_fonts 临时文件仍被清理
    await expectLater(notifier.importFontFile(sourcePath: badPicked.path), throwsA(isA<FormatException>()));
    expect(await badPicked.exists(), isFalse);

    // 不支持的扩展名拒绝
    final badExt = File(p.join(tempDir.path, 'a.woff2'))..writeAsBytesSync(_validTtfBytes(9));
    await expectLater(notifier.importFontFile(sourcePath: badExt.path), throwsA(isA<FormatException>()));

    // 体积上限熔断拦截
    final smallLimit = CustomFontService(
      db: db,
      rootDirProvider: () async => tempDir,
      fontLoader: (_, _) async => fail('超限文件不应触发引擎注册'),
      maxFontBytes: 4,
    );
    await expectLater(
      smallLimit.importFontBytes(fileName: 'big.ttf', bytes: _validTtfBytes(5)),
      throwsA(isA<FormatException>()),
    );

    // 模拟重启：第1款磁盘文件缺失/损坏，loadAllRegisteredFonts 容错仅保留第2款
    await File(p.join(tempDir.path, 'custom_fonts', font1.fileName)).delete();
    loadedFamilies.clear();
    final container2 = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      customFontServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container2.dispose);
    final reloaded = await container2.read(customFontManagerProvider.notifier).loadAllRegisteredFonts();
    expect(reloaded.map((e) => e.id).toList(), [font2.id]);
    expect(loadedFamilies.map((e) => e.$1).toList(), [font2.fontFamily]);

    // deleteFont 删文件并清理元数据
    await container2.read(customFontManagerProvider.notifier).deleteFont(font2.id);
    expect(container2.read(customFontManagerProvider), isEmpty);
    expect(File(p.join(tempDir.path, 'custom_fonts', font2.fileName)).existsSync(), isFalse);
    expect(CustomFontEntry.decodeList(await db.getPreference(CustomFontService.prefsKey)), isEmpty);
  });

  test('ReaderSettingsNotifier 精细排版设置持久化、clamp 与 resetTypographyDefaults', () async {
    final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    final notifier = container.read(readerSettingsProvider.notifier);
    await notifier.setPaperTheme(ReaderPaperTheme.mistyGreen);
    await notifier.setFontFamily('YueweiFont_font_abc');
    await notifier.setParagraphGap(40.0);
    await notifier.setHorizontalPadding(5.0);
    await notifier.setLetterSpacing(3.5);
    await notifier.setIndentFirstLine(false);
    await notifier.setLayoutMode(ReaderLayoutMode.dual);

    final s = container.read(readerSettingsProvider);
    expect(s.fontFamily, 'YueweiFont_font_abc');
    expect(s.paragraphGap, 28.0);
    expect(s.horizontalPadding, 12.0);
    expect(s.letterSpacing, 2.0);
    expect(s.indentFirstLine, isFalse);
    expect(s.layoutMode, ReaderLayoutMode.dual);

    await notifier.setFontFamily(null);
    expect(container.read(readerSettingsProvider).fontFamily, isNull);
    expect(await db.getPreference('reader_font_family'), '');

    // 新容器冷读验证与重置默认值
    final container2 = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(container2.dispose);
    container2.read(readerSettingsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final reloaded = container2.read(readerSettingsProvider);
    expect(reloaded.paragraphGap, 28.0);
    expect(reloaded.indentFirstLine, isFalse);
    expect(reloaded.layoutMode, ReaderLayoutMode.dual);

    await container2.read(readerSettingsProvider.notifier).resetTypographyDefaults();
    final reset = container2.read(readerSettingsProvider);
    expect(reset.fontSize, 19.0);
    expect(reset.paragraphGap, 13.0);
    expect(reset.horizontalPadding, 22.0);
    expect(reset.letterSpacing, 0.35);
    expect(reset.indentFirstLine, isTrue);
    expect(reset.layoutMode, ReaderLayoutMode.auto);
    expect(reset.fontFamily, isNull);
    expect(reset.paperTheme, ReaderPaperTheme.mistyGreen);
  });
}
