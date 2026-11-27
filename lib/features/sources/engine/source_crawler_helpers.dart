import 'package:html/parser.dart' as html_parser;
import '../domain/book_match_models.dart';
import '../domain/book_source_rule.dart';
import 'book_metadata_sanitizer.dart';
import 'rule_evaluator.dart';

/// 抓书引擎无状态解析与清洗辅助器（详情元数据提取、302 详情直跳解析、目录去重）
class SourceCrawlerHelpers {
  const SourceCrawlerHelpers._();

  /// 从详情页节点结合 OpenGraph 兜底提取全套书籍元数据及独立目录页 URL
  static ({
    String title,
    String author,
    String rawIntro,
    String cover,
    String status,
    String category,
    String rawLatest,
    String rawUpdateTime,
    String tocUrl,
  }) extractDetailFields({
    required RuleEvaluator evaluator,
    required BookSourceRule src,
    required EvaluatedNode rootNode,
    required String finalUrl,
  }) {
    String evalOrOg(RuleField field, String ogName, {String urlBase = ''}) {
      final v = evaluator.evaluateField(rootNode, field, baseUrl: urlBase);
      if (v.isNotEmpty) return v;
      return BookMetadataSanitizer.extractOgMeta(
        evaluator,
        rootNode,
        ogName,
        baseUrl: urlBase,
      );
    }

    final rawTocUrl = src.detail.tocUrl.selector.trim().isEmpty
        ? ''
        : evaluator.evaluateField(
            rootNode,
            src.detail.tocUrl,
            baseUrl: finalUrl,
          );

    return (
      title: evalOrOg(src.detail.title, 'og:title'),
      author: evalOrOg(src.detail.author, 'og:novel:author'),
      rawIntro: evalOrOg(src.detail.intro, 'og:description'),
      cover: evalOrOg(src.detail.coverUrl, 'og:image', urlBase: finalUrl),
      status: BookMetadataSanitizer.sanitizeBadge(
        evalOrOg(src.detail.statusText, 'og:novel:status'),
      ),
      category: BookMetadataSanitizer.sanitizeBadge(
        evalOrOg(src.detail.category, 'og:novel:category'),
      ),
      rawLatest: evalOrOg(
        src.detail.latestChapter,
        'og:novel:latest_chapter_name',
      ),
      rawUpdateTime: evalOrOg(
        src.detail.lastUpdateTime,
        'og:novel:update_time',
      ),
      tocUrl: isValidHttpUrl(rawTocUrl) ? rawTocUrl : '',
    );
  }

  /// 杰奇 CMS 精确命中 302 直跳详情页时，使用详情规则与 OG Meta 提取单条搜索结果
  static SourceSearchHit? extractDirectDetailHit({
    required RuleEvaluator evaluator,
    required BookSourceRule src,
    required String html,
    required String finalUrl,
    required int latencyMs,
  }) {
    if (!isValidHttpUrl(finalUrl)) return null;
    final doc = html_parser.parse(html);
    final rootEl = doc.documentElement;
    if (rootEl == null) return null;

    final fields = extractDetailFields(
      evaluator: evaluator,
      src: src,
      rootNode: EvaluatedNode.html(rootEl),
      finalUrl: finalUrl,
    );
    if (fields.title.isEmpty) return null;

    final cleanIntro = BookMetadataSanitizer.cleanSeoIntro(fields.rawIntro);
    final cleanLatest =
        BookMetadataSanitizer.sanitizeLatestChapter(fields.rawLatest);
    final hasBookMeta = fields.author.isNotEmpty ||
        cleanIntro.isNotEmpty ||
        cleanLatest.isNotEmpty ||
        fields.cover.isNotEmpty ||
        evaluator.selectNodes(html, src.toc.item).isNotEmpty;
    if (!hasBookMeta) return null;

    return SourceSearchHit(
      sourceId: src.id,
      sourceName: src.name,
      title: fields.title,
      author: fields.author,
      bookUrl: finalUrl,
      coverUrl: fields.cover,
      intro: cleanIntro,
      latestChapter: cleanLatest,
      latencyMs: latencyMs,
    );
  }

  /// 剔除网页头部重复的“最新章节推荐”并保持正文顺序
  static List<ParsedChapterEntry> sanitizeToc(
    List<({String title, String url})> raw,
  ) {
    if (raw.isEmpty) return const [];
    final countByUrl = <String, int>{};
    for (final item in raw) {
      countByUrl[item.url] = (countByUrl[item.url] ?? 0) + 1;
    }

    final seen = <String>{};
    final result = <ParsedChapterEntry>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (i < 16 && (countByUrl[item.url] ?? 0) > 1) {
        countByUrl[item.url] = countByUrl[item.url]! - 1;
        continue;
      }
      if (!seen.add(item.url)) continue;
      result.add(
        ParsedChapterEntry(
          index: result.length,
          title: item.title,
          url: item.url,
        ),
      );
    }
    return result;
  }

  static bool isValidHttpUrl(String url) {
    if (url.isEmpty || url.contains(RegExp(r'\s'))) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }
}
