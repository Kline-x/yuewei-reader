import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// EPUB ZIP 解包安全配额追踪器（防止中央目录伪造 uncompressedSize 的二次防线）
class EpubByteBudget {
  EpubByteBudget({required this.maxUncompressedBytes});

  final int maxUncompressedBytes;
  int _consumed = 0;

  /// 读取单个 ZIP 条目内容并累加真实解压字节数，超限立即抛出可读 FormatException
  List<int> readFileBytes(ArchiveFile file) {
    final data = file.content;
    if (data is! List<int>) return const [];
    _consumed += data.length;
    if (_consumed > maxUncompressedBytes) {
      throw const FormatException('EPUB 解压体积超过安全上限，已中止解析以防止内存溢出');
    }
    return data;
  }
}

/// EPUB 归档安全校验与路径解码工具（ZIP 炸弹防护、锚点/查询串剥离、逐段安全 %XX 解码）
class EpubArchiveUtils {
  const EpubArchiveUtils._();

  static const int maxZipEntries = 5000;
  static const int maxUncompressedBytes = 256 * 1024 * 1024;

  static final RegExp _percentBlockRe = RegExp(r'(?:%[0-9a-fA-F]{2})+');

  /// 解析 ZIP 前预检中央目录条目数与累计解压字节数，防范 ZIP 炸弹引发 OOM
  static Archive decodeZipSafely(
    List<int> bytes, {
    int maxEntries = maxZipEntries,
    int maxUncompressed = maxUncompressedBytes,
  }) {
    final ZipDirectory dir;
    try {
      dir = ZipDirectory.read(InputStream(bytes));
    } catch (_) {
      throw const FormatException('无法识别的 EPUB 压缩包格式，请确认文件完整');
    }

    if (dir.fileHeaders.length > maxEntries) {
      throw FormatException(
        'EPUB 文件条目数过多（超过 $maxEntries 项），已拒绝解析以防内存溢出',
      );
    }

    var declaredTotal = 0;
    for (final zfh in dir.fileHeaders) {
      final sz = zfh.uncompressedSize ?? 0;
      if (sz < 0) {
        throw const FormatException('EPUB 压缩包存在异常条目长度，无法解析');
      }
      declaredTotal += sz;
      if (declaredTotal > maxUncompressed) {
        throw const FormatException('EPUB 解压总大小超过 256MB 安全上限，已拒绝解析');
      }
    }

    final archive = ZipDecoder().decodeBytes(bytes);
    if (archive.files.length > maxEntries) {
      throw FormatException(
        'EPUB 文件条目数过多（超过 $maxEntries 项），已拒绝解析以防内存溢出',
      );
    }
    return archive;
  }

  /// 剥离 href 中的 `#fragment` 与 `?query`
  static String stripHrefFragmentAndQuery(String href) {
    var clean = href.trim();
    final hashIdx = clean.indexOf('#');
    if (hashIdx >= 0) clean = clean.substring(0, hashIdx);
    final queryIdx = clean.indexOf('?');
    if (queryIdx >= 0) clean = clean.substring(0, queryIdx);
    return clean.trim();
  }

  static String normalizeZipPath(String raw) {
    var s = raw.replaceAll('\\', '/').trim();
    while (s.startsWith('/')) {
      s = s.substring(1);
    }
    final norm = p.posix.normalize(s);
    return norm == '.' ? '' : norm;
  }

  static String dirname(String zipPath) {
    final d = p.posix.dirname(zipPath);
    return d == '.' ? '' : d;
  }

  static String resolveRelative(String baseDir, String href) {
    final stripped = stripHrefFragmentAndQuery(href).replaceAll('\\', '/');
    if (stripped.isEmpty) return '';
    final decoded = safeUriDecode(stripped);
    final joined = baseDir.isEmpty ? decoded : p.posix.join(baseDir, decoded);
    return normalizeZipPath(joined);
  }

  /// 逐段安全解码 `%XX` 字节块：兼容同时包含 `%20` 与字面量 `%`（如 `100%`）的文件名
  static String safeUriDecode(String value) {
    if (!value.contains('%')) return value;
    return value.replaceAllMapped(_percentBlockRe, (m) {
      final seq = m.group(0)!;
      final bytes = <int>[];
      for (var i = 0; i < seq.length; i += 3) {
        final code = int.tryParse(seq.substring(i + 1, i + 3), radix: 16);
        if (code == null) return seq;
        bytes.add(code);
      }
      try {
        return utf8.decode(bytes, allowMalformed: false);
      } catch (_) {
        return seq;
      }
    });
  }
}
