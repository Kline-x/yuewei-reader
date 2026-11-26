import 'dart:convert';
import '../domain/book_source_rule.dart';

/// 主流 Legado（阅读 3.0）书源 JSON 适配器
/// 支持解析导入单条 JSON 对象或数组格式的开源书源。
class LegadoRuleAdapter {
  static List<BookSourceRule> parseJson(String rawJson) {
    final decoded = jsonDecode(rawJson.trim());
    final items = <Map<String, dynamic>>[];

    if (decoded is List) {
      for (final e in decoded) {
        if (e is Map<String, dynamic>) items.add(e);
      }
    } else if (decoded is Map<String, dynamic>) {
      items.add(decoded);
    }

    final rules = <BookSourceRule>[];
    for (final item in items) {
      final parsed = _convertOne(item);
      if (parsed != null) rules.add(parsed);
    }
    return rules;
  }

  static BookSourceRule? _convertOne(Map<String, dynamic> map) {
    final name = (map['bookSourceName'] as String? ?? map['name'] as String? ?? '')
        .trim();
    final baseUrl =
        (map['bookSourceUrl'] as String? ?? map['baseUrl'] as String? ?? '')
            .trim();
    if (name.isEmpty || baseUrl.isEmpty) return null;

    // 若本身就是阅微原生 JSON 结构则直读
    if (map.containsKey('search') && map.containsKey('toc')) {
      return BookSourceRule.fromJson(map);
    }

    final rawSearchUrl = (map['searchUrl'] as String?) ?? '';
    final parsedUrl = _parseLegadoSearchUrl(baseUrl, rawSearchUrl);

    final searchMap = (map['ruleSearch'] as Map<String, dynamic>?) ?? const {};
    final bookMap = (map['ruleBookInfo'] as Map<String, dynamic>?) ?? const {};
    final tocMap = (map['ruleToc'] as Map<String, dynamic>?) ?? const {};
    final contentMap =
        (map['ruleContent'] as Map<String, dynamic>?) ?? const {};

    final searchItem = (searchMap['bookList'] as String?) ?? '';
    final tocItem = (tocMap['chapterList'] as String?) ?? '';
    final contentSel = (contentMap['content'] as String?) ?? '';
    if (parsedUrl.url.isEmpty || searchItem.isEmpty || tocItem.isEmpty) {
      return null;
    }

    final safeId = 'legado_${baseUrl.hashCode.abs()}_${name.hashCode.abs()}';

    return BookSourceRule(
      id: safeId,
      name: name,
      baseUrl: baseUrl,
      groupName: (map['bookSourceGroup'] as String?)?.trim().isNotEmpty == true
          ? (map['bookSourceGroup'] as String).trim()
          : '导入源',
      charset: parsedUrl.charset,
      enabled: (map['enabled'] as bool?) ?? true,
      isBuiltin: false,
      search: SearchRuleSpec(
        urlTemplate: parsedUrl.url,
        method: parsedUrl.method,
        bodyTemplate: parsedUrl.body,
        item: searchItem,
        title: _parseRuleString(searchMap['name'] as String?, defaultAttr: 'text'),
        author:
            _parseRuleString(searchMap['author'] as String?, defaultAttr: 'text'),
        detailUrl:
            _parseRuleString(searchMap['bookUrl'] as String?, defaultAttr: 'href'),
        coverUrl:
            _parseRuleString(searchMap['coverUrl'] as String?, defaultAttr: 'src'),
        intro: _parseRuleString(searchMap['intro'] as String?, defaultAttr: 'text'),
        latestChapter: _parseRuleString(
          searchMap['lastChapter'] as String?,
          defaultAttr: 'text',
        ),
      ),
      detail: DetailRuleSpec(
        title: _parseRuleString(bookMap['name'] as String?, defaultAttr: 'text'),
        author:
            _parseRuleString(bookMap['author'] as String?, defaultAttr: 'text'),
        intro: _parseRuleString(bookMap['intro'] as String?, defaultAttr: 'text'),
        coverUrl:
            _parseRuleString(bookMap['coverUrl'] as String?, defaultAttr: 'src'),
        tocUrl: _parseRuleString(bookMap['tocUrl'] as String?, defaultAttr: 'href'),
        category:
            _parseRuleString(bookMap['kind'] as String?, defaultAttr: 'text'),
        latestChapter: _parseRuleString(
          bookMap['lastChapter'] as String?,
          defaultAttr: 'text',
        ),
        lastUpdateTime: _parseRuleString(
          bookMap['updateTime'] as String?,
          defaultAttr: 'text',
        ),
      ),
      toc: TocRuleSpec(
        item: tocItem,
        title:
            _parseRuleString(tocMap['chapterName'] as String?, defaultAttr: 'text'),
        url:
            _parseRuleString(tocMap['chapterUrl'] as String?, defaultAttr: 'href'),
        nextPageUrl:
            _parseRuleString(tocMap['nextTocUrl'] as String?, defaultAttr: 'href'),
      ),
      chapter: ChapterRuleSpec(
        content: _parseRuleString(contentSel, defaultAttr: 'html'),
        nextPageUrl: _parseRuleString(
          contentMap['nextContentUrl'] as String?,
          defaultAttr: 'href',
        ),
      ),
    );
  }

  static RuleField _parseRuleString(
    String? raw, {
    required String defaultAttr,
  }) {
    if (raw == null || raw.trim().isEmpty) return const RuleField();
    var text = raw.trim();
    var regex = '';
    var replacement = '';

    // 剥离 `##正则` 或 `##正则##替换文本`（保留 replacement 内部空白字符）
    final hashIdx = text.indexOf('##');
    if (hashIdx >= 0) {
      final parts = text.substring(hashIdx + 2).split('##');
      regex = parts[0];
      replacement = parts.length > 1 ? parts[1] : '';
      text = text.substring(0, hashIdx).trim();
    }

    // 保留 @xpath: 或 $. 前缀，拆分 CSS 选择器结尾的 @attr（避开跨 || 分支误切）
    var attr = defaultAttr;
    if (!text.startsWith('@xpath:') && !text.startsWith(r'$.')) {
      final lastAt = text.lastIndexOf('@');
      if (lastAt >= 0) {
        final tail = text.substring(lastAt + 1).trim();
        if (tail.isNotEmpty && !tail.contains(' ') && !tail.contains('||')) {
          attr = tail == 'textNodes' ? 'text' : tail;
          text = text.substring(0, lastAt).trim();
        }
      }
    }

    return RuleField(
      selector: text,
      attr: attr,
      regex: regex,
      replacement: replacement,
    );
  }

  static ({String url, String method, String body, String charset})
      _parseLegadoSearchUrl(String baseUrl, String raw) {
    var urlPart = raw.trim();
    var method = 'GET';
    var body = '';
    var charset = 'utf-8';

    final commaIdx = urlPart.indexOf(',{');
    if (commaIdx > 0) {
      final optJson = urlPart.substring(commaIdx + 1);
      urlPart = urlPart.substring(0, commaIdx).trim();
      try {
        final opt = jsonDecode(optJson) as Map<String, dynamic>;
        method = ((opt['method'] as String?) ?? 'GET').toUpperCase();
        body = (opt['body'] as String?) ?? '';
        charset = ((opt['charset'] as String?) ?? 'utf-8').toLowerCase();
      } catch (_) {}
    }

    urlPart = urlPart.replaceAll('{{key}}', '{key}');
    body = body.replaceAll('{{key}}', '{key}');
    if (!urlPart.startsWith('http://') && !urlPart.startsWith('https://')) {
      urlPart = '${baseUrl.replaceAll(RegExp(r'/$'), '')}${urlPart.startsWith('/') ? urlPart : '/$urlPart'}';
    }
    return (url: urlPart, method: method, body: body, charset: charset);
  }
}
