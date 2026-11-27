import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import 'custom_font_models.dart';

export 'custom_font_models.dart';

/// 轻量自定义字体存储、魔数校验与引擎注册服务（不引入第三方包、30MB 防爆）
class CustomFontService {
  CustomFontService({
    required this.db,
    Future<Directory> Function()? rootDirProvider,
    CustomFontLoader? fontLoader,
    this.maxFontBytes = defaultMaxFontBytes,
  })  : _rootDirProvider =
            rootDirProvider ?? getApplicationDocumentsDirectory,
        _fontLoader = fontLoader ?? defaultFontLoader;

  /// 元数据偏好键名（故意不以 reader_ 开头，避免向远端同步本机字体路径元数据）
  static const String prefsKey = 'local_custom_fonts_v1';
  static const int defaultMaxFontBytes = CustomFontCodec.defaultMaxFontBytes;
  static const Set<String> supportedExtensions =
      CustomFontCodec.supportedExtensions;

  final AppDatabase db;
  final Future<Directory> Function() _rootDirProvider;
  final CustomFontLoader _fontLoader;
  final int maxFontBytes;

  Future<void> _serialTail = Future.value();

  /// 默认使用 Flutter 原生 FontLoader 注册自定义字体
  static Future<void> defaultFontLoader(
    String fontFamily,
    Uint8List bytes,
  ) async {
    final loader = FontLoader(fontFamily);
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
  }

  static bool isValidFontHeader(List<int> bytes) =>
      CustomFontCodec.isValidFontHeader(bytes);

  static String computeFontId(List<int> bytes) =>
      CustomFontCodec.computeFontId(bytes);

  Future<T> _synchronized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _serialTail = _serialTail.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<Directory> _fontsRoot() async {
    final base = await _rootDirProvider();
    final dir = Directory(p.join(base.path, 'custom_fonts'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _resolveSafeFontFile(String fileName) async {
    final dir = await _fontsRoot();
    final safeBase = p.basename(fileName.trim());
    if (safeBase.isEmpty || safeBase == '.' || safeBase.contains('..')) {
      throw const FormatException('非法字体文件名');
    }
    final target = File(p.normalize(p.join(dir.path, safeBase)));
    if (!p.isWithin(p.normalize(dir.path), target.path)) {
      throw const FormatException('非法字体存储路径');
    }
    return target;
  }

  static Future<void> _cleanupPickedTempCopy(File file) async {
    try {
      final segments = p.split(file.path);
      if (!segments.contains('picked_fonts')) return;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// 从本地文件路径导入 .ttf / .otf 字体，自动在 finally 中清理 picked_fonts/ 临时副本
  Future<({CustomFontEntry entry, List<CustomFontEntry> all})> importFontFile({
    required String sourcePath,
    String? displayName,
    String? originalFileName,
  }) async {
    final file = File(sourcePath);
    try {
      if (!await file.exists()) {
        throw FileSystemException('字体文件不存在', sourcePath);
      }
      final effectiveName =
          (originalFileName != null && originalFileName.trim().isNotEmpty)
              ? originalFileName.trim()
              : p.basename(sourcePath);
      final ext = p.extension(effectiveName).toLowerCase();
      if (!supportedExtensions.contains(ext)) {
        throw const FormatException('仅支持导入 .ttf 或 .otf 字体文件');
      }
      final size = await file.length();
      if (size <= 0) {
        throw const FormatException('所选字体文件为空');
      }
      if (size > maxFontBytes) {
        throw const FormatException('字体文件超过 30MB 上限，暂不支持导入');
      }
      final bytes = await file.readAsBytes();
      return await importFontBytes(
        fileName: effectiveName,
        bytes: bytes,
        displayName: displayName,
      );
    } finally {
      await _cleanupPickedTempCopy(file);
    }
  }

  /// 从原始字节流校验、持久化并注册字体（同时供文件导入与 Wi-Fi 传字体复用）
  Future<({CustomFontEntry entry, List<CustomFontEntry> all})> importFontBytes({
    required String fileName,
    required List<int> bytes,
    String? displayName,
  }) {
    return _synchronized(() async {
      final cleanName = p.basename(fileName.trim());
      final ext = p.extension(cleanName).toLowerCase();
      if (!supportedExtensions.contains(ext)) {
        throw const FormatException('仅支持导入 .ttf 或 .otf 字体文件');
      }
      if (bytes.isEmpty) {
        throw const FormatException('字体文件内容为空');
      }
      if (bytes.length > maxFontBytes) {
        throw const FormatException('字体文件超过 30MB 上限，暂不支持导入');
      }
      final rawBytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
      if (!isValidFontHeader(rawBytes)) {
        throw const FormatException('无效的字体文件头（仅支持标准 TTF / OTF 字体）');
      }

      final fontId = computeFontId(rawBytes);
      final fontFamily = 'YueweiFont_$fontId';
      final storedFileName = '$fontId$ext';
      final destFile = await _resolveSafeFontFile(storedFileName);
      await destFile.writeAsBytes(rawBytes, flush: true);

      await _fontLoader(fontFamily, rawBytes);

      final resolvedName = _resolveDisplayName(displayName, cleanName);
      final entry = CustomFontEntry(
        id: fontId,
        displayName: resolvedName,
        fontFamily: fontFamily,
        fileName: storedFileName,
        fileSizeBytes: rawBytes.length,
        importedAt: DateTime.now().toUtc(),
      );

      final current = await _readStoredEntries();
      final next = <CustomFontEntry>[];
      var replaced = false;
      for (final item in current) {
        if (item.id == entry.id) {
          next.add(entry);
          replaced = true;
        } else {
          next.add(item);
        }
      }
      if (!replaced) {
        next.add(entry);
      }

      await _writeStoredEntries(next);
      return (entry: entry, all: List<CustomFontEntry>.unmodifiable(next));
    });
  }

  /// 启动时加载并向引擎注册全部已导入字体（容错单个缺失或损坏条目）
  Future<List<CustomFontEntry>> loadAllRegisteredFonts() {
    return _synchronized(() async {
      final stored = await _readStoredEntries();
      if (stored.isEmpty) return const [];

      final valid = <CustomFontEntry>[];
      for (final entry in stored) {
        try {
          final file = await _resolveSafeFontFile(entry.fileName);
          if (!await file.exists()) continue;
          final size = await file.length();
          if (size <= 0 || size > maxFontBytes) continue;
          final bytes = await file.readAsBytes();
          if (!isValidFontHeader(bytes)) continue;
          await _fontLoader(entry.fontFamily, bytes);
          valid.add(entry);
        } catch (_) {
          // 单个文件损坏或加载异常不影响启动与其余字体注册
        }
      }

      if (valid.length != stored.length) {
        await _writeStoredEntries(valid);
      }
      return List<CustomFontEntry>.unmodifiable(valid);
    });
  }

  /// 删除指定字体（删除磁盘文件并从列表移除）
  Future<List<CustomFontEntry>> deleteFont(String id) {
    return _synchronized(() async {
      final stored = await _readStoredEntries();
      final next = <CustomFontEntry>[];
      for (final entry in stored) {
        if (entry.id == id) {
          try {
            final file = await _resolveSafeFontFile(entry.fileName);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (_) {}
        } else {
          next.add(entry);
        }
      }
      await _writeStoredEntries(next);
      return List<CustomFontEntry>.unmodifiable(next);
    });
  }

  Future<List<CustomFontEntry>> _readStoredEntries() async {
    final raw = await db.getPreference(prefsKey);
    return CustomFontEntry.decodeList(raw);
  }

  Future<void> _writeStoredEntries(List<CustomFontEntry> entries) async {
    await db.setPreference(
      prefsKey,
      CustomFontEntry.encodeList(entries),
      touchSyncTimestamp: false,
    );
  }

  static String _resolveDisplayName(String? displayName, String fileName) {
    final explicit = (displayName ?? '').trim();
    if (explicit.isNotEmpty) return explicit;
    final stem = p.basenameWithoutExtension(fileName).trim();
    return stem.isNotEmpty ? stem : '自定义字体';
  }
}

final customFontServiceProvider = Provider<CustomFontService>((ref) {
  return CustomFontService(db: ref.watch(appDatabaseProvider));
});

/// 阅读器自定义字体状态管理器（供启动预加载、排版抽屉及 Wi-Fi 传字体共享）
class CustomFontManager extends Notifier<List<CustomFontEntry>> {
  bool _disposed = false;

  @override
  List<CustomFontEntry> build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const [];
  }

  Future<List<CustomFontEntry>> loadAllRegisteredFonts() async {
    final fonts =
        await ref.read(customFontServiceProvider).loadAllRegisteredFonts();
    if (!_disposed) state = fonts;
    return fonts;
  }

  Future<CustomFontEntry> importFontFile({
    required String sourcePath,
    String? displayName,
    String? originalFileName,
  }) async {
    final res = await ref.read(customFontServiceProvider).importFontFile(
          sourcePath: sourcePath,
          displayName: displayName,
          originalFileName: originalFileName,
        );
    if (!_disposed) state = res.all;
    return res.entry;
  }

  Future<CustomFontEntry> importFontBytes({
    required String fileName,
    required List<int> bytes,
    String? displayName,
  }) async {
    final res = await ref.read(customFontServiceProvider).importFontBytes(
          fileName: fileName,
          bytes: bytes,
          displayName: displayName,
        );
    if (!_disposed) state = res.all;
    return res.entry;
  }

  Future<void> deleteFont(String id) async {
    final next = await ref.read(customFontServiceProvider).deleteFont(id);
    if (!_disposed) state = next;
  }
}

final customFontManagerProvider =
    NotifierProvider<CustomFontManager, List<CustomFontEntry>>(
  CustomFontManager.new,
);
