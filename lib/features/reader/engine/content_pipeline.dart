/// 单向内容处理管道：在抓包入库前执行一次清洗与分段规整
/// 严禁在排版重绘期间重复调用；严禁硬编码特定小说的角色名或剧情词；严禁误伤正常小说对白。
class ContentPipeline {
  const ContentPipeline();

  static final List<RegExp> _pureAdLinePatterns = [
    RegExp(
      r'^(?:本章未完[，,。]?请点击下一页继续阅读|请记住本书首发域名|天才一秒记住|最新网址[：:]|手机站全新改版).*$',
      caseSensitive: false,
    ),
    RegExp(
      r'^.*(?:www\.[a-z0-9\-]+\.(?:com|net|org|info|xyz|cc|la)|https?://[^\s]+).*$',
      caseSensitive: false,
    ),
    RegExp(
      r'^.*(?:求收藏|求推荐票|求月票|加入书签|投推荐票|点此报错).*$',
      caseSensitive: false,
    ),
    RegExp(
      r'^.*看最新(?:完整)?章节.{0,8}就上.*(?:阅读|小说|文学|谷|阁|网).*$',
      caseSensitive: false,
    ),
  ];

  static final RegExp _htmlTagRe = RegExp(r'<[^>]+>');
  static final RegExp _multiDialogueSplitRe =
      RegExp(r'([。！？!?…~][”’])\s*([“‘])');

  static final RegExp _leadingFullWidthRe = RegExp(r'^(\u3000+)');
  static final RegExp _zhSpaceBeforePunctRe = RegExp(
    r'([\u4E00-\u9FFF\u3000-\u303F\uFF00-\uFFEF\u2014\u2026\u2018\u2019\u201C\u201D])[ \t\u00A0]+([，。、；：？！…—”’）】》」』])',
  );
  static final RegExp _zhSpaceAfterOpenPunctRe = RegExp(
    r'([“‘（【《「『，。、；：？！…—”’）】》」』])[ \t\u00A0]+([\u4E00-\u9FFF“‘（【《「『])',
  );
  static final RegExp _multiHalfSpaceRe = RegExp(r'[ \t\u00A0]{2,}');

  /// 清理中文字符与中文标点间误夹杂的空白，保留首行全角缩进及英文词间单空格
  static String normalizeInlineSpaces(String text) {
    var indent = '';
    var body = text;
    final match = _leadingFullWidthRe.firstMatch(body);
    if (match != null) {
      indent = match.group(1)!;
      body = body.substring(indent.length);
    }
    body = body.replaceAll('\u00A0', ' ').trim();
    if (body.isEmpty) return '';

    // 最多两遍即可消除连续中文标点间（如 `" 。`）夹杂的多余空格
    for (var i = 0; i < 2; i++) {
      body = body.replaceAllMapped(
        _zhSpaceBeforePunctRe,
        (m) => '${m.group(1)}${m.group(2)}',
      );
    }
    body = body.replaceAllMapped(
      _zhSpaceAfterOpenPunctRe,
      (m) => '${m.group(1)}${m.group(2)}',
    );
    body = body.replaceAll(_multiHalfSpaceRe, ' ');
    return '$indent$body';
  }

  /// 将原始 HTML 片段或文本一次清洗为标准段落列表（带标准 2em 全角缩进）
  List<String> processHtmlToParagraphs(
    String rawHtmlOrText, {
    String? chapterTitle,
  }) {
    if (rawHtmlOrText.trim().isEmpty) return const [];

    // 1. 保留 HTML 块级与换行结构
    var text = rawHtmlOrText
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(r'</(p|div|li|blockquote|h[1-6])>', caseSensitive: false),
          '\n',
        )
        .replaceAll(
          RegExp(r'<(p|div|li|blockquote|h[1-6])[^>]*>', caseSensitive: false),
          '\n',
        )
        .replaceAll(_htmlTagRe, '');

    text = _decodeEntities(text);

    // 2. 按行分割并洗净广告与空白
    final rawLines = text.split(RegExp(r'\r?\n'));
    final cleanTitle = _normalizeTitle(chapterTitle ?? '');
    final paragraphs = <String>[];

    for (final rawLine in rawLines) {
      var line = rawLine.replaceAll('\u00A0', ' ').trim();
      line = line.replaceFirst(RegExp(r'^[\u3000\s]+'), '').trim();
      if (line.isEmpty) continue;

      // 仅剥离首行与当前章名高度一致的重复标题（严格保护正文中含章名短词的对白）
      if (paragraphs.isEmpty &&
          cleanTitle.isNotEmpty &&
          _normalizeTitle(line) == cleanTitle) {
        continue;
      }

      if (_isPureAdLine(line)) continue;

      // 安全拆分挤在同一行里的连环台词
      final splitText = line.replaceAllMapped(
        _multiDialogueSplitRe,
        (m) => '${m.group(1)}\n${m.group(2)}',
      );

      for (final sub in splitText.split('\n')) {
        final s = normalizeInlineSpaces(sub);
        if (s.isNotEmpty) {
          paragraphs.add('\u3000\u3000$s');
        }
      }
    }

    return paragraphs;
  }

  /// 将清洗后的段落序列化为冷缓存纯文本（单换行分隔）
  String serializeParagraphs(List<String> paragraphs) {
    return paragraphs.join('\n');
  }

  /// 从已落盘冷缓存直接反序列化为段落列表并清洗标点前多余空格
  List<String> parseCachedText(String cachedText) {
    if (cachedText.trim().isEmpty) return const [];
    final out = <String>[];
    for (final line in cachedText.split('\n')) {
      final clean = normalizeInlineSpaces(line);
      if (clean.isNotEmpty) out.add(clean);
    }
    return out;
  }

  static bool _isPureAdLine(String line) {
    final hasUrl = line.contains('http://') ||
        line.contains('https://') ||
        RegExp(r'\b[a-z0-9\-]+\.(com|cn|net|org|xyz|cc|info)\b',
                caseSensitive: false)
            .hasMatch(line);

    // 长段落保护：超过 45 字且不含 URL，大概率为小说正常情节，绝不误删
    if (line.length > 45 && !hasUrl) {
      return false;
    }

    for (final pattern in _pureAdLinePatterns) {
      if (pattern.hasMatch(line)) return true;
    }
    return false;
  }

  static String _normalizeTitle(String raw) {
    return raw.replaceAll(RegExp(r'[\s《》【】\[\]\-：:第章回节]'), '').toLowerCase();
  }

  static String _decodeEntities(String input) {
    var out = input
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#160;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&mdash;', '—')
        .replaceAll('&hellip;', '…')
        .replaceAll('&ldquo;', '“')
        .replaceAll('&rdquo;', '”');

    out = out.replaceAllMapped(RegExp(r'&#(x?)([0-9a-fA-F]{1,8});'), (m) {
      final isHex = m.group(1) == 'x';
      final code = int.tryParse(m.group(2)!, radix: isHex ? 16 : 10);
      if (code == null || code < 0x20 || code > 0x10FFFF) return '';
      if (code >= 0xD800 && code <= 0xDFFF) return '';
      return String.fromCharCode(code);
    });
    return out;
  }
}
