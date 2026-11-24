import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 本地导入书籍统一的 sourceId 常量（与在线书源严格隔离）
const String kLocalBookSourceId = 'local_file';

/// 沙盒冷章节正文与本地封面异步存储服务（严格防路径穿越，纯异步 I/O）
class ChapterFileStore {
  ChapterFileStore({Future<Directory> Function()? rootDirProvider})
      : _rootDirProvider = rootDirProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _rootDirProvider;

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
    return dir;
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

  /// 写入本地提取的书籍封面至 `yuewei_covers/<safeBookDir>/cover<ext>`
  Future<String> saveBookCoverBytes(
    String bookId,
    List<int> bytes, {
    String ext = '.jpg',
  }) async {
    final dir = await _bookCoverDir(bookId);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, 'cover${_sanitizeCoverExt(ext)}'));
    if (!p.isWithin(dir.path, file.path)) {
      throw ArgumentError('非法封面文件路径: $bookId');
    }
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// 删除单本书本地提取的封面目录
  Future<void> deleteBookCover(String bookId) async {
    final dir = await _bookCoverDir(bookId);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
