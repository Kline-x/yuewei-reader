import 'dart:isolate';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';
import '../../reader/engine/content_pipeline.dart';
import '../../sources/engine/book_metadata_sanitizer.dart';
import '../../sources/engine/rule_evaluator.dart';
import 'charset_and_txt_parser.dart';
import 'epub_archive_utils.dart';

class _ManifestItem {
  const _ManifestItem(this.id, this.resolvedPath, this.mediaType, this.properties);

  final String id;
  final String resolvedPath;
  final String mediaType;
  final String properties;
}

/// 标准 EPUB 2/3 后台解析引擎（ZIP 炸弹防护 + XML/HTML 清洗 + ContentPipeline）
class EpubBookParser {
  const EpubBookParser._();

  static const ContentPipeline _pipeline = ContentPipeline();
  static final RegExp _scriptStyleRe = RegExp(
    r'<(script|style|noscript)\b[^>]*>[\s\S]*?</\1\s*>',
    caseSensitive: false,
  );

  /// 在独立 Isolate 中解析 EPUB 二进制包
  static Future<LocalParsedBook> parseInIsolate({
    required List<int> bytes,
    required String fileName,
  }) {
    final safeBytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    return Isolate.run(() => parseSync(bytes: safeBytes, fileName: fileName));
  }

  /// 同步解析 EPUB 字节流（提取元数据、封面、目录映射与 XHTML 正文）
  static LocalParsedBook parseSync({
    required List<int> bytes,
    required String fileName,
    int maxEntries = EpubArchiveUtils.maxZipEntries,
    int maxUncompressedBytes = EpubArchiveUtils.maxUncompressedBytes,
  }) {
    final archive = EpubArchiveUtils.decodeZipSafely(
      bytes,
      maxEntries: maxEntries,
      maxUncompressed: maxUncompressedBytes,
    );
    final budget = EpubByteBudget(maxUncompressedBytes: maxUncompressedBytes);

    final exactMap = <String, ArchiveFile>{};
    final lowerMap = <String, ArchiveFile>{};
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final norm = EpubArchiveUtils.normalizeZipPath(file.name);
      exactMap[norm] = file;
      lowerMap[norm.toLowerCase()] = file;
    }

    ArchiveFile? lookup(String path) {
      final norm = EpubArchiveUtils.normalizeZipPath(path);
      final decoded = EpubArchiveUtils.safeUriDecode(norm);
      return exactMap[norm] ??
          exactMap[decoded] ??
          lowerMap[norm.toLowerCase()] ??
          lowerMap[decoded.toLowerCase()];
    }

    final opfPath = _findOpfPath(exactMap, lookup, budget);
    final opfFile = lookup(opfPath);
    if (opfFile == null) {
      throw const FormatException('无法定位 EPUB 的 OPF 核心描述文件');
    }

    final opfDoc = XmlDocument.parse(
      CharsetAndTxtParser.decodeTextBytes(budget.readFileBytes(opfFile)),
    );
    final opfDir = EpubArchiveUtils.dirname(opfPath);
    final fallbackMeta = CharsetAndTxtParser.inferMetaFromFileName(fileName);
    final metaEl = _elementsByLocal(opfDoc, 'metadata').firstOrNull;
    final title = _firstText(metaEl, 'title') ?? fallbackMeta.title;
    final author = _firstText(metaEl, 'creator') ?? fallbackMeta.author;
    final rawDesc = (_firstText(metaEl, 'description') ?? '')
        .replaceAll(_scriptStyleRe, '')
        .replaceAll(RegExp(r'<[^>]+>'), ' ');
    final decodedDesc = RuleEvaluator.decodeHtmlEntities(rawDesc);
    final intro = BookMetadataSanitizer.cleanSeoIntro(decodedDesc);

    final spineEl = _elementsByLocal(opfDoc, 'spine').firstOrNull;
    final spineTocId = spineEl?.getAttribute('toc')?.trim() ?? '';
    final metaCoverId = _extractMetaCoverId(metaEl);

    final manifest = <String, _ManifestItem>{};
    _ManifestItem? coverItem;
    _ManifestItem? navItem;
    _ManifestItem? ncxItem;

    for (final el in _elementsByLocal(opfDoc, 'item')) {
      final id = el.getAttribute('id')?.trim() ?? '';
      final rawHref = el.getAttribute('href')?.trim() ?? '';
      final cleanHref = EpubArchiveUtils.stripHrefFragmentAndQuery(rawHref);
      if (id.isEmpty || cleanHref.isEmpty) continue;
      final mediaType = (el.getAttribute('media-type') ?? '').trim().toLowerCase();
      final props = (el.getAttribute('properties') ?? '').trim().toLowerCase();
      final resolved = EpubArchiveUtils.resolveRelative(opfDir, cleanHref);
      final entry = _ManifestItem(id, resolved, mediaType, props);
      manifest[id] = entry;

      final tokens = props.split(RegExp(r'\s+'));
      if (tokens.contains('cover-image')) {
        coverItem = entry;
      } else if (coverItem == null && id == metaCoverId) {
        coverItem = entry;
      } else if (coverItem == null &&
          mediaType.startsWith('image/') &&
          (id.toLowerCase().contains('cover') ||
              cleanHref.toLowerCase().contains('cover'))) {
        coverItem = entry;
      }
      if (tokens.contains('nav')) navItem = entry;
      if (id == spineTocId ||
          mediaType == 'application/x-dtbncx+xml' ||
          cleanHref.toLowerCase().endsWith('.ncx')) {
        ncxItem ??= entry;
      }
    }

    final tocTitles = _parseTocTitles(ncxItem, navItem, lookup, budget);
    final cover = _extractCover(coverItem, lookup, budget);
    final chapters = _extractSpineChapters(spineEl, manifest, tocTitles, lookup, budget);

    return LocalParsedBook(
      title: title, author: author, intro: intro, format: 'epub',
      chapters: chapters, coverBytes: cover.bytes, coverExt: cover.ext,
    );
  }

  static String _extractMetaCoverId(XmlElement? metaEl) {
    if (metaEl == null) return '';
    for (final m in _elementsByLocal(metaEl, 'meta')) {
      if (m.getAttribute('name')?.trim().toLowerCase() == 'cover') {
        return m.getAttribute('content')?.trim() ?? '';
      }
    }
    return '';
  }

  static Map<String, String> _parseTocTitles(
    _ManifestItem? ncxItem, _ManifestItem? navItem,
    ArchiveFile? Function(String) lookup, EpubByteBudget budget,
  ) {
    final tocTitles = <String, String>{};
    if (ncxItem != null) {
      final f = lookup(ncxItem.resolvedPath);
      if (f != null) {
        _parseNcx(CharsetAndTxtParser.decodeTextBytes(budget.readFileBytes(f)),
            EpubArchiveUtils.dirname(ncxItem.resolvedPath), tocTitles);
      }
    }
    if (navItem != null) {
      final f = lookup(navItem.resolvedPath);
      if (f != null) {
        _parseNav(CharsetAndTxtParser.decodeTextBytes(budget.readFileBytes(f)),
            EpubArchiveUtils.dirname(navItem.resolvedPath), tocTitles);
      }
    }
    return tocTitles;
  }

  static ({List<int>? bytes, String ext}) _extractCover(
    _ManifestItem? coverItem, ArchiveFile? Function(String) lookup, EpubByteBudget budget,
  ) {
    if (coverItem == null) return (bytes: null, ext: '.jpg');
    final file = lookup(coverItem.resolvedPath);
    if (file == null) return (bytes: null, ext: '.jpg');
    final raw = budget.readFileBytes(file);
    if (raw.isEmpty) return (bytes: null, ext: '.jpg');
    return (bytes: raw, ext: _inferImageExt(coverItem.mediaType, coverItem.resolvedPath));
  }

  static List<LocalParsedChapter> _extractSpineChapters(
    XmlElement? spineEl, Map<String, _ManifestItem> manifest,
    Map<String, String> tocTitles, ArchiveFile? Function(String) lookup, EpubByteBudget budget,
  ) {
    if (spineEl == null) return const [];
    final chapters = <LocalParsedChapter>[];
    for (final ref in _elementsByLocal(spineEl, 'itemref')) {
      final item = manifest[ref.getAttribute('idref')?.trim() ?? ''];
      if (item == null || !_isHtmlItem(item)) continue;
      final file = lookup(item.resolvedPath);
      if (file == null) continue;

      final xhtml = CharsetAndTxtParser.decodeTextBytes(budget.readFileBytes(file));
      final doc = html_parser.parse(xhtml);
      for (final junk in doc.querySelectorAll('script, style, noscript')) {
        junk.remove();
      }
      final heading = doc.querySelector('h1, h2, h3, title')?.text.trim() ?? '';
      final title = _pickTitle(tocTitles[item.resolvedPath], heading, chapters.length + 1);
      final paragraphs = _pipeline.processHtmlToParagraphs(doc.body?.innerHtml ?? xhtml, chapterTitle: title);
      if (paragraphs.isEmpty) continue;
      final serialized = _pipeline.serializeParagraphs(paragraphs);
      chapters.add(LocalParsedChapter(
        index: chapters.length, title: title, serializedContent: serialized, rawLength: serialized.length,
      ));
    }
    return chapters;
  }

  static String _findOpfPath(
    Map<String, ArchiveFile> exactMap,
    ArchiveFile? Function(String) lookup,
    EpubByteBudget budget,
  ) {
    final container = lookup('META-INF/container.xml');
    if (container != null) {
      final doc = XmlDocument.parse(
        CharsetAndTxtParser.decodeTextBytes(budget.readFileBytes(container)),
      );
      for (final rf in _elementsByLocal(doc, 'rootfile')) {
        final full = rf.getAttribute('full-path')?.trim() ?? '';
        if (full.isNotEmpty) return EpubArchiveUtils.normalizeZipPath(full);
      }
    }
    for (final path in exactMap.keys) {
      if (path.toLowerCase().endsWith('.opf')) return path;
    }
    throw const FormatException('无效 EPUB 文件：未找到 container.xml 或 .opf');
  }

  static void _parseNcx(
    String xmlText,
    String baseDir,
    Map<String, String> out,
  ) {
    try {
      final doc = XmlDocument.parse(xmlText);
      for (final pt in _elementsByLocal(doc, 'navPoint')) {
        final label =
            _elementsByLocal(pt, 'text').firstOrNull?.innerText.trim() ?? '';
        final src =
            _elementsByLocal(pt, 'content').firstOrNull?.getAttribute('src')?.trim() ??
                '';
        final key = EpubArchiveUtils.resolveRelative(baseDir, src);
        if (label.isEmpty || key.isEmpty) continue;
        out.putIfAbsent(key, () => label);
      }
    } catch (_) {}
  }

  static void _parseNav(
    String htmlText,
    String baseDir,
    Map<String, String> out,
  ) {
    try {
      final doc = html_parser.parse(htmlText);
      final navs = doc.querySelectorAll('nav');
      final tocNav = navs.where((el) {
            final t = el.attributes['epub:type'] ?? el.attributes['type'] ?? '';
            return t.toLowerCase().contains('toc');
          }).firstOrNull ??
          navs.firstOrNull;
      if (tocNav == null) return;
      for (final a in tocNav.querySelectorAll('a[href]')) {
        final key =
            EpubArchiveUtils.resolveRelative(baseDir, a.attributes['href'] ?? '');
        final label = a.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (key.isNotEmpty && label.isNotEmpty) {
          out.putIfAbsent(key, () => label);
        }
      }
    } catch (_) {}
  }

  static String _pickTitle(String? tocTitle, String domTitle, int seq) {
    final t = (tocTitle ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isNotEmpty) return t;
    final d = domTitle.replaceAll(RegExp(r'\s+'), ' ').trim();
    return (d.isNotEmpty && d.length <= 60) ? d : '第 $seq 节';
  }

  static bool _isHtmlItem(_ManifestItem item) {
    if (item.mediaType.contains('html') || item.mediaType.contains('xhtml')) {
      return true;
    }
    final lower = item.resolvedPath.toLowerCase();
    return lower.endsWith('.xhtml') ||
        lower.endsWith('.html') ||
        lower.endsWith('.htm');
  }

  static String _inferImageExt(String mediaType, String path) {
    final pLow = path.toLowerCase();
    if (mediaType.contains('png') || pLow.endsWith('.png')) return '.png';
    if (mediaType.contains('webp') || pLow.endsWith('.webp')) return '.webp';
    if (mediaType.contains('gif') || pLow.endsWith('.gif')) return '.gif';
    return '.jpg';
  }

  static Iterable<XmlElement> _elementsByLocal(XmlNode root, String local) =>
      root.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == local);

  static String? _firstText(XmlNode? root, String local) {
    if (root == null) return null;
    for (final el in _elementsByLocal(root, local)) {
      final text = el.innerText.trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }
}
