import 'dart:async';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../../../core/network/app_http_client.dart';
import '../../reader/engine/content_pipeline.dart';
import '../domain/book_match_models.dart';
import '../domain/book_source_rule.dart';
import 'book_metadata_sanitizer.dart';
import 'rule_evaluator.dart';

/// 并发抓书与聚合搜书引擎（全程透传 CancelToken、零假书源注入、安全过滤 SEO 广告简介）
class SourceCrawlerService {
  SourceCrawlerService({
    required this.httpClient,
    this.evaluator = const RuleEvaluator(),
    this.pipeline = const ContentPipeline(),
  });

  final AppHttpClient httpClient;
  final RuleEvaluator evaluator;
  final ContentPipeline pipeline;

  static String sanitizeBadge(String raw) =>
      BookMetadataSanitizer.sanitizeBadge(raw);

  static String cleanSeoIntro(String raw) =>
      BookMetadataSanitizer.cleanSeoIntro(raw);

  static String sanitizeUpdateTime(String raw) =>
      BookMetadataSanitizer.sanitizeUpdateTime(raw);

  static String sanitizeLatestChapter(String raw) =>
      BookMetadataSanitizer.sanitizeLatestChapter(raw);

  /// 并发检索多个启用书源，流式实时发出每条结果（取消订阅即中断底层 HTTP 请求）
  Stream<SourceSearchHit> searchStream(
    List<BookSourceRule> sources,
    String keyword, {
    CancelToken? cancelToken,
  }) {
    final cleanKey = keyword.trim();
    if (cleanKey.isEmpty || sources.isEmpty) {
      return const Stream.empty();
    }

    final token = cancelToken ?? CancelToken();
    final controller = StreamController<SourceSearchHit>();
    controller.onCancel = () {
      if (!token.isCancelled) token.cancel('用户中止搜索');
    };

    var remaining = sources.length;
    for (final src in sources) {
      _searchSingleSource(src, cleanKey, token).then((hits) {
        if (!controller.isClosed) {
          for (final h in hits) {
            controller.add(h);
          }
        }
      }).whenComplete(() {
        remaining--;
        if (remaining <= 0 && !controller.isClosed) {
          controller.close();
        }
      });
    }

    return controller.stream;
  }

  Future<List<SourceSearchHit>> _searchSingleSource(
    BookSourceRule src,
    String keyword,
    CancelToken token,
  ) async {
    try {
      final encoded = AppHttpClient.encodeQuery(keyword, src.charset);
      final url = src.search.urlTemplate.replaceAll('{key}', encoded);
      final body = src.search.bodyTemplate.replaceAll('{key}', encoded);

      final res = await httpClient.fetchText(
        url,
        method: src.search.method,
        body: body,
        referer: src.baseUrl,
        charsetHint: src.charset,
        cancelToken: token,
      );

      final nodes = evaluator.selectNodes(res.body, src.search.item);
      final hits = <SourceSearchHit>[];
      for (final node in nodes) {
        final title = evaluator.evaluateField(node, src.search.title);
        final detailUrl = evaluator.evaluateField(
          node,
          src.search.detailUrl,
          baseUrl: src.baseUrl,
        );
        if (title.isEmpty || detailUrl.isEmpty) continue;

        final author = evaluator.evaluateField(node, src.search.author);
        final cover = evaluator.evaluateField(
          node,
          src.search.coverUrl,
          baseUrl: src.baseUrl,
        );
        final rawIntro = evaluator.evaluateField(node, src.search.intro);
        final latest =
            evaluator.evaluateField(node, src.search.latestChapter);

        hits.add(
          SourceSearchHit(
            sourceId: src.id,
            sourceName: src.name,
            title: title,
            author: author,
            bookUrl: detailUrl,
            coverUrl: cover,
            intro: cleanSeoIntro(rawIntro),
            latestChapter: sanitizeLatestChapter(latest),
            latencyMs: res.latencyMs,
          ),
        );
      }
      return hits;
    } catch (_) {
      return const [];
    }
  }

  /// 获取书籍详情与完整目录（自动以 OpenGraph 兜底、去重前置最新章节预览）
  Future<
          ({
            ParsedBookDetail detail,
            List<ParsedChapterEntry> chapters,
            int latencyMs
          })>
      fetchBookDetailAndToc(
    BookSourceRule src,
    String bookUrl, {
    CancelToken? cancelToken,
  }) async {
    final res = await httpClient.fetchText(
      bookUrl,
      referer: src.baseUrl,
      charsetHint: src.charset,
      cancelToken: cancelToken,
    );

    final doc = html_parser.parse(res.body);
    final rootEl = doc.documentElement;
    final rootNode =
        rootEl != null ? EvaluatedNode.html(rootEl) : EvaluatedNode.text('');

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

    final title = evalOrOg(src.detail.title, 'og:title');
    final author = evalOrOg(src.detail.author, 'og:novel:author');
    final rawIntro = evalOrOg(src.detail.intro, 'og:description');
    final cover = evalOrOg(
      src.detail.coverUrl,
      'og:image',
      urlBase: res.finalUrl,
    );
    final status = sanitizeBadge(
      evalOrOg(src.detail.statusText, 'og:novel:status'),
    );
    final category = sanitizeBadge(
      evalOrOg(src.detail.category, 'og:novel:category'),
    );
    final rawLatest = evalOrOg(
      src.detail.latestChapter,
      'og:novel:latest_chapter_name',
    );
    final rawUpdateTime = evalOrOg(
      src.detail.lastUpdateTime,
      'og:novel:update_time',
    );

    final rawTocUrl = src.detail.tocUrl.selector.trim().isEmpty
        ? ''
        : evaluator.evaluateField(
            rootNode,
            src.detail.tocUrl,
            baseUrl: res.finalUrl,
          );
    final tocUrl = _isValidHttpUrl(rawTocUrl) ? rawTocUrl : '';

    var tocHtml = res.body;
    var tocBase = res.finalUrl;
    if (tocUrl.isNotEmpty && tocUrl != res.finalUrl) {
      final tocRes = await httpClient.fetchText(
        tocUrl,
        referer: res.finalUrl,
        charsetHint: src.charset,
        cancelToken: cancelToken,
      );
      tocHtml = tocRes.body;
      tocBase = tocRes.finalUrl;
    }

    final tocNodes = evaluator.selectNodes(tocHtml, src.toc.item);
    final rawChapters = <({String title, String url})>[];
    for (final node in tocNodes) {
      final chTitle = evaluator.evaluateField(node, src.toc.title);
      final chUrl = evaluator.evaluateField(
        node,
        src.toc.url,
        baseUrl: tocBase,
      );
      if (chTitle.isNotEmpty && chUrl.isNotEmpty) {
        rawChapters.add((title: chTitle, url: chUrl));
      }
    }

    final chapters = _sanitizeToc(rawChapters);
    var cleanLatest = sanitizeLatestChapter(rawLatest);
    if (cleanLatest.isEmpty && chapters.isNotEmpty) {
      cleanLatest = chapters.last.title;
    }

    return (
      detail: ParsedBookDetail(
        title: title,
        author: author,
        intro: cleanSeoIntro(rawIntro),
        coverUrl: cover,
        tocUrl: tocBase,
        statusText: status.isEmpty ? '连载中' : status,
        category: category,
        latestChapter: cleanLatest,
        lastUpdateTime: sanitizeUpdateTime(rawUpdateTime),
      ),
      chapters: chapters,
      latencyMs: res.latencyMs,
    );
  }

  /// 抓取单章正文并通过 ContentPipeline 执行一次性清洗与分段
  Future<List<String>> fetchChapterParagraphs(
    BookSourceRule src,
    String chapterUrl, {
    String? chapterTitle,
    CancelToken? cancelToken,
  }) async {
    final res = await httpClient.fetchText(
      chapterUrl,
      referer: src.baseUrl,
      charsetHint: src.charset,
      cancelToken: cancelToken,
    );
    final doc = html_parser.parse(res.body);
    final rootEl = doc.documentElement;
    final rootNode =
        rootEl != null ? EvaluatedNode.html(rootEl) : EvaluatedNode.text('');

    final contentHtml = evaluator.evaluateField(rootNode, src.chapter.content);
    if (contentHtml.trim().isEmpty) return const [];
    return pipeline.processHtmlToParagraphs(
      contentHtml,
      chapterTitle: chapterTitle,
    );
  }

  /// 剔除网页头部重复的“最新章节推荐”并保持正文顺序
  static List<ParsedChapterEntry> _sanitizeToc(
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

  static bool _isValidHttpUrl(String url) {
    if (url.isEmpty || url.contains(RegExp(r'\s'))) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }
}
