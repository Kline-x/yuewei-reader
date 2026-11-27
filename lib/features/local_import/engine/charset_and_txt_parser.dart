import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:characters/characters.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:path/path.dart' as p;
import '../../reader/engine/content_pipeline.dart';

/// 本地解析产出的单章结构（纯 Dart 值，可安全跨 Isolate 传递）
class LocalParsedChapter {
  const LocalParsedChapter({
    required this.index,
    required this.title,
    required this.serializedContent,
    this.rawLength = 0,
  });

  final int index;
  final String title;
  final String serializedContent;
  final int rawLength;
}

/// 本地 TXT / EPUB 解析产出的整书结构（纯 Dart 值，可安全跨 Isolate 传递）
class LocalParsedBook {
  const LocalParsedBook({
    required this.title,
    required this.author,
    required this.intro,
    required this.format,
    required this.chapters,
    this.coverBytes,
    this.coverExt = '.jpg',
  });

  final String title;
  final String author;
  final String intro;
  final String format;
  final List<LocalParsedChapter> chapters;
  final List<int>? coverBytes;
  final String coverExt;
}

/// 字符集自动探测与本地 TXT 后台分章引擎
class CharsetAndTxtParser {
  const CharsetAndTxtParser._();

  static const int _autoSliceTargetChars = 3500;
  static const ContentPipeline _pipeline = ContentPipeline();

  static final RegExp _chapterLineRe = RegExp(
    r'^(?:'
    r'第\s*[零一二三四五六七八九十百千万两0-9]+\s*[章节回卷集部篇]'
    r'(?:[\s：:、.\-—]+[^\n]{0,40})?'
    r'|(?:序[章言曲]?|前言|楔子|引子|尾声|后记|番外|终章|内容简介)'
    r'(?:[\s：:、.\-—]+[^\n]{0,36})?'
    r'|Chapter\s*\d+(?:[\s：:.\-—]+[^\n]{0,40})?'
    r')$',
    caseSensitive: false,
  );

  /// BOM + 严格 UTF-8 + fast_gbk 自动探测解码
  static String decodeTextBytes(List<int> bytes) {
    if (bytes.isEmpty) return '';
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _decodeUtf16(bytes, littleEndian: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _decodeUtf16(bytes, littleEndian: false);
    }
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      return gbk.decode(bytes, allowMalformed: true);
    }
  }

  static String _decodeUtf16(List<int> bytes, {required bool littleEndian}) {
    final len = (bytes.length - 2) ~/ 2;
    final units = Uint16List(len);
    for (var i = 0; i < len; i++) {
      final b0 = bytes[2 + i * 2];
      final b1 = bytes[2 + i * 2 + 1];
      units[i] = littleEndian ? (b0 | (b1 << 8)) : ((b0 << 8) | b1);
    }
    return String.fromCharCodes(units);
  }

  /// 从文件名推断书名与作者（剔除校对版/全本标签与常见书名号）
  static ({String title, String author}) inferMetaFromFileName(String fileName) {
    var stem = p.basenameWithoutExtension(fileName).trim();
    var author = '';
    final authorMatch = RegExp(
      r'[\s_\-\(（\[]*作者[：:]\s*([^\s\)）\]]+)',
    ).firstMatch(stem);
    if (authorMatch != null) {
      author = (authorMatch.group(1) ?? '').trim();
      stem = stem.replaceRange(authorMatch.start, authorMatch.end, '').trim();
    }
    final quoted = RegExp(r'《([^》]+)》').firstMatch(stem);
    if (quoted != null && (quoted.group(1) ?? '').trim().isNotEmpty) {
      stem = quoted.group(1)!.trim();
    } else {
      stem = stem
          .replaceAll(RegExp(r'[\(\[（【][^)\]）】]*(?:全本|校对|精校|完结|TXT)[^)\]）】]*[\)\]）】]', caseSensitive: false), '')
          .replaceAll(RegExp(r'[《》]'), '')
          .trim();
    }
    return (
      title: stem.isEmpty ? '未命名藏书' : stem,
      author: author,
    );
  }

  /// 在独立 Isolate 中解析 TXT 字节流，确保不阻塞主线程 UI
  static Future<LocalParsedBook> parseInIsolate({
    required List<int> bytes,
    required String fileName,
  }) {
    final safeBytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    return Isolate.run(() => parseSync(bytes: safeBytes, fileName: fileName));
  }

  /// 同步解析 TXT 字节流为分章书籍结构
  static LocalParsedBook parseSync({
    required List<int> bytes,
    required String fileName,
  }) {
    final meta = inferMetaFromFileName(fileName);
    final rawText = decodeTextBytes(bytes)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    if (rawText.trim().isEmpty) {
      return LocalParsedBook(
        title: meta.title,
        author: meta.author,
        intro: '',
        format: 'txt',
        chapters: const [],
      );
    }

    final rawChapters = _splitByHeadings(rawText);
    final useHeadingSplit = rawChapters.length >= 2;
    final sections = useHeadingSplit ? rawChapters : _splitByParagraphLength(rawText);

    final chapters = <LocalParsedChapter>[];
    for (final sec in sections) {
      final cleaned = _pipeline.processHtmlToParagraphs(
        sec.body,
        chapterTitle: sec.title,
      );
      if (cleaned.isEmpty) continue;
      final serialized = _pipeline.serializeParagraphs(cleaned);
      chapters.add(
        LocalParsedChapter(
          index: chapters.length,
          title: sec.title,
          serializedContent: serialized,
          rawLength: serialized.length,
        ),
      );
    }

    // 极端短文本兜底，确保非空文件至少拥有一章可读内容
    if (chapters.isEmpty) {
      final fallback = _pipeline.processHtmlToParagraphs(rawText);
      final serialized = fallback.isNotEmpty
          ? _pipeline.serializeParagraphs(fallback)
          : '\u3000\u3000${rawText.trim()}';
      chapters.add(
        LocalParsedChapter(
          index: 0,
          title: '第 1 节',
          serializedContent: serialized,
          rawLength: serialized.length,
        ),
      );
    }

    return LocalParsedBook(
      title: meta.title,
      author: meta.author,
      intro: _extractPreviewIntro(chapters.first.serializedContent),
      format: 'txt',
      chapters: chapters,
    );
  }

  static List<({String title, String body})> _splitByHeadings(String text) {
    final lines = text.split('\n');
    final result = <({String title, String body})>[];
    String? currentTitle;
    final buffer = StringBuffer();

    void flushCurrent() {
      final content = buffer.toString().trim();
      buffer.clear();
      if (content.isEmpty) return;
      final title = currentTitle;
      if (title != null) {
        result.add((title: title, body: content));
      } else if (content.length >= 20) {
        result.add((title: '序章', body: content));
      }
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (_isChapterHeading(trimmed)) {
        flushCurrent();
        currentTitle = trimmed;
      } else {
        buffer.writeln(line);
      }
    }
    flushCurrent();
    return result;
  }

  static bool _isChapterHeading(String trimmed) {
    if (trimmed.isEmpty || trimmed.length > 45) return false;
    if ((trimmed.contains('“') || trimmed.contains('”')) &&
        !trimmed.startsWith('第')) {
      return false;
    }
    return _chapterLineRe.hasMatch(trimmed);
  }

  static List<({String title, String body})> _splitByParagraphLength(
    String text,
  ) {
    final rawLines = text.split('\n');
    final sections = <({String title, String body})>[];
    final buf = StringBuffer();
    var accChars = 0;

    void emitSection() {
      final content = buf.toString().trim();
      buf.clear();
      accChars = 0;
      if (content.isNotEmpty) {
        sections.add((title: '第 ${sections.length + 1} 节', body: content));
      }
    }

    for (final rawLine in rawLines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      // 单段超长无换行长文按句末标点软分节，避免单章过大
      if (line.length > _autoSliceTargetChars * 1.6) {
        if (accChars > 0) emitSection();
        for (final piece in _sliceOversizedParagraph(line)) {
          sections.add((title: '第 ${sections.length + 1} 节', body: piece));
        }
        continue;
      }
      buf.writeln(line);
      accChars += line.length;
      if (accChars >= _autoSliceTargetChars) {
        emitSection();
      }
    }
    emitSection();
    return sections;
  }

  static List<String> _sliceOversizedParagraph(String text) {
    final out = <String>[];
    var start = 0;
    while (start < text.length) {
      var end = start + _autoSliceTargetChars;
      if (end >= text.length) {
        out.add(text.substring(start));
        break;
      }
      final searchLimit = (end + 300).clamp(0, text.length);
      var splitAt = -1;
      for (var i = end; i < searchLimit; i++) {
        final ch = text[i];
        if (ch == '。' || ch == '！' || ch == '？' || ch == '.' || ch == '!' || ch == '?') {
          splitAt = i + 1;
          break;
        }
      }
      end = splitAt > start ? splitAt : end;
      // 避开在 UTF-16 高代理码元处截断
      if (end < text.length) {
        final prevUnit = text.codeUnitAt(end - 1);
        if (prevUnit >= 0xD800 && prevUnit <= 0xDBFF) {
          end++;
        }
      }
      out.add(text.substring(start, end));
      start = end;
    }
    return out;
  }

  static String _extractPreviewIntro(String firstChapterSerialized) {
    final clean = firstChapterSerialized
        .replaceAll('\u3000', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final chars = clean.characters;
    if (chars.length <= 120) return clean;
    return '${chars.take(120)}…';
  }
}
