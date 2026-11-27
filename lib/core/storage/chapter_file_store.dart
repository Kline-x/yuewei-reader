import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 本地导入书籍统一的 sourceId 常量（与在线书源严格隔离）
const String kLocalBookSourceId = 'local_file';

/// 本地封面相对路径协议前缀（隔离 iOS 容器 UUID 变更）
const String kLocalCoverScheme = 'local_cover://';

/// 沙盒冷章节正文与本地封面异步存储服务（严格防路径穿越，纯异步 I/O）
class ChapterFileStore {
  ChapterFileStore({Future<Directory> Function()? rootDirProvider})
      : _rootDirProvider = rootDirProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _rootDirProvider;

  static String? _cachedCoversRootPath;
  static Future<String>? _pendingCoversRootFuture;

  /// 判断路径是否为本地封面路径（相对契约或历史绝对路径）
  static bool isLocalCoverUrl(String url) {
    final trimmed = url.trim();
    return trimmed.startsWith(kLocalCoverScheme) ||
        trimmed.startsWith('/') ||
        trimmed.startsWith('file://');
  }

  /// 同步解析本地封面文件：命中静态根目录缓存时直接返回，未命中返回 null 供异步解析
  static File? resolveLocalCoverFileSync(String coverUrl) {
    final trimmed = coverUrl.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith(kLocalCoverScheme)) {
      final root = _cachedCoversRootPath;
      if (root == null || root.isEmpty) return null;
      return _buildSafeCoverFile(root, trimmed.substring(kLocalCoverScheme.length));
    }
    return _parseLegacyAbsoluteCover(trimmed);
  }

  /// 异步解析本地封面文件（首次自动初始化并缓存封面根目录，同时兼容历史绝对路径）
  static Future<File?> resolveLocalCoverFileAsync(
    String coverUrl, {
    Future<Directory> Function()? rootDirProvider,
  }) async {
    final trimmed = coverUrl.trim();
    if (trimmed.isEmpty) return null;
    if (!trimmed.startsWith(kLocalCoverScheme)) {
      return _parseLegacyAbsoluteCover(trimmed);
    }
    final rel = trimmed.substring(kLocalCoverScheme.length);
    if (rootDirProvider != null) {
      final base = await rootDirProvider();
      final coversRoot = p.join(base.path, 'yuewei_covers');
      _cachedCoversRootPath = coversRoot;
      return _buildSafeCoverFile(coversRoot, rel);
    }
    final cached = _cachedCoversRootPath;
    if (cached != null && cached.isNotEmpty) {
      return _buildSafeCoverFile(cached, rel);
    }
    _pendingCoversRootFuture ??= getApplicationDocumentsDirectory().then((base) {
      final coversRoot = p.join(base.path, 'yuewei_covers');
      _cachedCoversRootPath = coversRoot;
      return coversRoot;
    });
    try {
      final coversRoot = await _pendingCoversRootFuture!;
      return _buildSafeCoverFile(coversRoot, rel);
    } catch (_) {
      _pendingCoversRootFuture = null;
      return null;
    }
  }

  static File? _parseLegacyAbsoluteCover(String trimmed) {
    if (trimmed.startsWith('file://')) {
      final path = Uri.tryParse(trimmed)?.toFilePath() ?? trimmed.substring(7);
      return path.isEmpty ? null : File(path);
    }
    if (trimmed.startsWith('/')) return File(trimmed);
    return null;
  }

  static File? _buildSafeCoverFile(String coversRoot, String relativePath) {
    final cleanRel = relativePath.trim();
    if (cleanRel.isEmpty || cleanRel.contains('..')) return null;
    final parts = cleanRel.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    final fullPath = p.normalize(p.joinAll([coversRoot, ...parts]));
    if (!p.isWithin(p.normalize(coversRoot), fullPath)) return null;
    return File(fullPath);
  }

  /// 使用当前存储实例解析本地封面文件（兼容相对路径与历史绝对路径）
  Future<File?> resolveLocalCoverFile(String coverUrl) {
    return resolveLocalCoverFileAsync(coverUrl, rootDirProvider: _rootDirProvider);
  }

  /// 将 bookId 规范为安全的目录名，彻底消除 `..` / `/` 路径逃逸隐患
  static String safeBookDirName(String bookId) {
    final cleaned = bookId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return cleaned.isEmpty ? 'unknown_book' : cleaned;
  }

  Future<Directory> _chaptersRoot() async {
    final base = await _rootDirProvider();
    final dir = Directory(p.join(base.path, 'yuewei_chapters'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _bookDir(String bookId) async {
    final root = await _chaptersRoot();
    final safeName = safeBookDirName(bookId);
    final dir = Directory(p.join(root.path, safeName));
    // 二次边界核验：确认绝对路径严格在 root 下
    if (!p.isWithin(root.path, dir.path)) {
      throw ArgumentError('非法书籍目录标识: $bookId');
    }
    return dir;
  }

  Future<File> _chapterFile(String bookId, int chapterIndex) async {
    final dir = await _bookDir(bookId);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, '$chapterIndex.txt'));
  }

  /// 写入清洗后的章节正文，返回实际写入字节数
  Future<int> writeChapter(
    String bookId,
    int chapterIndex,
    String content,
  ) async {
    final file = await _chapterFile(bookId, chapterIndex);
    await file.writeAsString(content, flush: true);
    return file.length();
  }

  /// 异步读取单章已缓存正文（不存在则返回 null）
  Future<String?> readChapter(String bookId, int chapterIndex) async {
    final dir = await _bookDir(bookId);
    final file = File(p.join(dir.path, '$chapterIndex.txt'));
    if (!await file.exists()) return null;
    try {
      final text = await file.readAsString();
      return text.trim().isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }

  /// 安全迁移章节缓存文件（经同目录临时中转子目录，彻底防下标偏移覆盖错乱与正文串章）
  /// 返回实际已在目标下标就位的章节新下标集合。
  Future<Set<int>> migrateChapterFiles(
    String bookId,
    Map<int, int> oldToNewIndex, {
    bool pruneUnlisted = false,
  }) async {
    final dir = await _bookDir(bookId);
    if (!await dir.exists()) return const <int>{};

    final readyNewIndices = <int>{};
    final unchangedKept = <int>{};
    final moves = <MapEntry<int, int>>[];

    for (final entry in oldToNewIndex.entries) {
      if (entry.key < 0 || entry.value < 0) continue;
      if (entry.key == entry.value) {
        final file = File(p.join(dir.path, '${entry.key}.txt'));
        if (await file.exists()) {
          unchangedKept.add(entry.key);
          readyNewIndices.add(entry.key);
        }
      } else {
        moves.add(entry);
      }
    }

    final tmpDir = Directory(
      p.join(dir.path, '.migrate_${DateTime.now().microsecondsSinceEpoch}'),
    );
    final stagedNewIndices = <int>[];

    try {
      if (moves.isNotEmpty) {
        await tmpDir.create(recursive: true);
        for (final entry in moves) {
          final src = File(p.join(dir.path, '${entry.key}.txt'));
          if (!await src.exists()) continue;
          final staged = File(p.join(tmpDir.path, '${entry.value}.txt'));
          if (await staged.exists()) await staged.delete();
          await src.rename(staged.path);
          stagedNewIndices.add(entry.value);
        }
      }

      // 清理所有将与目标冲突或不再保留的孤立旧下标文件
      final targetIndices = oldToNewIndex.values.toSet();
      if (pruneUnlisted) {
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is! File) continue;
          final name = p.basename(entity.path);
          if (!name.endsWith('.txt')) continue;
          final idx = int.tryParse(name.substring(0, name.length - 4));
          if (idx == null || !unchangedKept.contains(idx)) {
            await entity.delete();
          }
        }
      } else {
        for (final newIdx in targetIndices) {
          if (unchangedKept.contains(newIdx)) continue;
          final conflict = File(p.join(dir.path, '$newIdx.txt'));
          if (await conflict.exists()) {
            await conflict.delete();
          }
        }
      }

      // 将中转目录中的章节文件按新下标移回
      for (final newIdx in stagedNewIndices) {
        final staged = File(p.join(tmpDir.path, '$newIdx.txt'));
        if (!await staged.exists()) continue;
        final dest = File(p.join(dir.path, '$newIdx.txt'));
        if (await dest.exists()) await dest.delete();
        await staged.rename(dest.path);
        readyNewIndices.add(newIdx);
      }
    } finally {
      if (await tmpDir.exists()) {
        try {
          await tmpDir.delete(recursive: true);
        } catch (_) {}
      }
    }

    return readyNewIndices;
  }

  /// 清空单本书全部离线缓存目录
  Future<void> clearBookCache(String bookId) async {
    final dir = await _bookDir(bookId);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// 清空全库离线缓存目录
  Future<void> clearAllCaches() async {
    final root = await _chaptersRoot();
    if (await root.exists()) {
      await root.delete(recursive: true);
      await root.create(recursive: true);
    }
  }

  /// 仅清理非本地导入书籍的离线章节缓存（保留 keepBookIds 对应目录）
  Future<void> clearNonLocalCaches(Set<String> keepBookIds) async {
    final root = await _chaptersRoot();
    if (!await root.exists()) return;
    final keepDirs = keepBookIds.map(safeBookDirName).toSet();
    await for (final entity in root.list(followLinks: false)) {
      if (entity is Directory && !keepDirs.contains(p.basename(entity.path))) {
        await entity.delete(recursive: true);
      }
    }
  }

  Future<Directory> _coversRoot() async {
    final base = await _rootDirProvider();
    final dir = Directory(p.join(base.path, 'yuewei_covers'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cachedCoversRootPath = dir.path;
    return dir;
  }

  /// 清理不在保留集合内的孤儿本地封面目录
  Future<void> clearOrphanCovers(Set<String> keepBookIds) async {
    final root = await _coversRoot();
    if (!await root.exists()) return;
    final keepDirs = keepBookIds.map(safeBookDirName).toSet();
    await for (final entity in root.list(followLinks: false)) {
      if (entity is Directory && !keepDirs.contains(p.basename(entity.path))) {
        await entity.delete(recursive: true);
      }
    }
  }

  Future<Directory> _bookCoverDir(String bookId) async {
    final root = await _coversRoot();
    final dir = Directory(p.join(root.path, safeBookDirName(bookId)));
    if (!p.isWithin(root.path, dir.path)) {
      throw ArgumentError('非法封面目录标识: $bookId');
    }
    return dir;
  }

  static String _sanitizeCoverExt(String ext) {
    final lower = ext.trim().toLowerCase();
    final dotExt = lower.startsWith('.') ? lower : '.$lower';
    if (RegExp(r'^\.(jpg|jpeg|png|webp|gif)$').hasMatch(dotExt)) {
      return dotExt;
    }
    return '.jpg';
  }

  /// 写入本地提取的书籍封面至 `yuewei_covers/<safeBookDir>/cover<ext>`，
  /// 返回跨 iOS 升级容器变更稳定的相对契约路径 `local_cover://<safeBookDir>/cover<ext>`
  Future<String> saveBookCoverBytes(
    String bookId,
    List<int> bytes, {
    String ext = '.jpg',
  }) async {
    final safeDir = safeBookDirName(bookId);
    final safeExt = _sanitizeCoverExt(ext);
    final dir = await _bookCoverDir(bookId);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, 'cover$safeExt'));
    if (!p.isWithin(dir.path, file.path)) {
      throw ArgumentError('非法封面文件路径: $bookId');
    }
    await file.writeAsBytes(bytes, flush: true);
    return '$kLocalCoverScheme$safeDir/cover$safeExt';
  }

  /// 删除单本书本地提取的封面目录
  Future<void> deleteBookCover(String bookId) async {
    final dir = await _bookCoverDir(bookId);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
