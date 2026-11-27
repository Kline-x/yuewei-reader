import 'dart:async';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../../../core/network/app_http_client.dart';
import '../../reader/engine/content_pipeline.dart';
import '../domain/book_match_models.dart';
import '../domain/book_source_rule.dart';
import 'book_metadata_sanitizer.dart';
import 'rule_evaluator.dart';
import 'source_crawler_helpers.dart';

/// 并发抓书与聚合搜书引擎（全程透传 CancelToken、分页目录/正文、302 详情直跳）
class SourceCrawlerService {
  SourceCrawlerService({
    required this.httpClient,
    this.evaluator = const RuleEvaluator(),
    this.pipeline = const ContentPipeline(),
  });

  static const int _maxTocPages = 30;
  static const int _maxChapterPages = 15;

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

      final resolveBase =
          res.finalUrl.isNotEmpty ? res.finalUrl : src.baseUrl;
      final nodes = evaluator.selectNodes(res.body, src.search.item);
      if (nodes.isEmpty && res.finalUrl.isNotEmpty && res.finalUrl != url) {
        final directHit = SourceCrawlerHelpers.extractDirectDetailHit(
          evaluator: evaluator,
          src: src,
          html: res.body,
          finalUrl: res.finalUrl,
          latencyMs: res.latencyMs,
        );
        return directHit == null ? const [] : [directHit];
      }

      final hits = <SourceSearchHit>[];
      for (final node in nodes) {
        final title = evaluator.evaluateField(node, src.search.title);
        final detailUrl = evaluator.evaluateField(
          node,
          src.search.detailUrl,
          baseUrl: resolveBase,
        );
        if (title.isEmpty || detailUrl.isEmpty) continue;

        final author = evaluator.evaluateField(node, src.search.author);
        final cover = evaluator.evaluateField(
          node,
          src.search.coverUrl,
          baseUrl: resolveBase,
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

  /// 获取书籍详情与完整目录（OpenGraph 兜底、支持目录分页最多 30 页与防环去重）
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

    final fields = SourceCrawlerHelpers.extractDetailFields(
      evaluator: evaluator,
      src: src,
      rootNode: rootNode,
      finalUrl: res.finalUrl,
    );

    var currentHtml = res.body;
    var currentBase = res.finalUrl;
    if (fields.tocUrl.isNotEmpty && fields.tocUrl != res.finalUrl) {
      final tocRes = await httpClient.fetchText(
        fields.tocUrl,
        referer: res.finalUrl,
        charsetHint: src.charset,
        cancelToken: cancelToken,
      );
      currentHtml = tocRes.body;
      currentBase = tocRes.finalUrl;
    }

    final firstTocBase = currentBase;
    final visitedUrls = <String>{
      if (fields.tocUrl.isNotEmpty) fields.tocUrl,
      if (currentBase.isNotEmpty) currentBase,
    };
    final rawChapters = <({String title, String url})>[];

    for (var page = 0; page < _maxTocPages; page++) {
      final tocNodes = evaluator.selectNodes(currentHtml, src.toc.item);
      for (final node in tocNodes) {
        final chTitle = evaluator.evaluateField(node, src.toc.title);
        final chUrl = evaluator.evaluateField(
          node,
          src.toc.url,
          baseUrl: currentBase,
        );
        if (chTitle.isNotEmpty && chUrl.isNotEmpty) {
          rawChapters.add((title: chTitle, url: chUrl));
        }
      }

      if (src.toc.nextPageUrl.isEmpty) break;
      final pageDoc = html_parser.parse(currentHtml);
      final pageEl = pageDoc.documentElement;
      if (pageEl == null) break;

      final nextUrl = evaluator.evaluateField(
        EvaluatedNode.html(pageEl),
        src.toc.nextPageUrl,
        baseUrl: currentBase,
      );
      if (!SourceCrawlerHelpers.isValidHttpUrl(nextUrl) ||
          !visitedUrls.add(nextUrl)) {
        break;
      }

      final HttpFetchResult nextRes;
      try {
        nextRes = await httpClient.fetchText(
          nextUrl,
          referer: currentBase,
          charsetHint: src.charset,
          cancelToken: cancelToken,
        );
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) rethrow;
        break;
      } catch (_) {
        break;
      }
      if (nextRes.finalUrl.isNotEmpty &&
          nextRes.finalUrl != nextUrl &&
          !visitedUrls.add(nextRes.finalUrl)) {
        break;
      }
      currentHtml = nextRes.body;
      currentBase = nextRes.finalUrl.isNotEmpty ? nextRes.finalUrl : nextUrl;
    }

    final chapters = SourceCrawlerHelpers.sanitizeToc(rawChapters);
    var cleanLatest = sanitizeLatestChapter(fields.rawLatest);
    if (cleanLatest.isEmpty && chapters.isNotEmpty) {
      cleanLatest = chapters.last.title;
    }

    return (
      detail: ParsedBookDetail(
        title: fields.title,
        author: fields.author,
        intro: cleanSeoIntro(fields.rawIntro),
        coverUrl: fields.cover,
        tocUrl: firstTocBase,
        statusText: fields.status.isEmpty ? '连载中' : fields.status,
        category: fields.category,
        latestChapter: cleanLatest,
        lastUpdateTime: sanitizeUpdateTime(fields.rawUpdateTime),
      ),
      chapters: chapters,
      latencyMs: res.latencyMs,
    );
  }

  /// 抓取单章正文（支持章节内分页最多 15 页 + visitedUrls 防环，仅首页去重章名）
  Future<List<String>> fetchChapterParagraphs(
    BookSourceRule src,
    String chapterUrl, {
    String? chapterTitle,
    CancelToken? cancelToken,
  }) async {
    final visitedUrls = <String>{chapterUrl};
    final allParagraphs = <String>[];
    var currentUrl = chapterUrl;
    var currentReferer = src.baseUrl;

    for (var page = 0; page < _maxChapterPages; page++) {
      final HttpFetchResult res;
      try {
        res = await httpClient.fetchText(
          currentUrl,
          referer: currentReferer,
          charsetHint: src.charset,
          cancelToken: cancelToken,
        );
      } on DioException catch (e) {
        if (page == 0 || e.type == DioExceptionType.cancel) rethrow;
        break;
      } catch (_) {
        if (page == 0) rethrow;
        break;
      }

      final pageBase = res.finalUrl.isNotEmpty ? res.finalUrl : currentUrl;
      if (page == 0) {
        visitedUrls.add(pageBase);
      } else if (pageBase != currentUrl && !visitedUrls.add(pageBase)) {
        break;
      }

      final doc = html_parser.parse(res.body);
      final rootEl = doc.documentElement;
      final rootNode =
          rootEl != null ? EvaluatedNode.html(rootEl) : EvaluatedNode.text('');

      final contentHtml = evaluator.evaluateField(rootNode, src.chapter.content);
      if (contentHtml.trim().isNotEmpty) {
        allParagraphs.addAll(
          pipeline.processHtmlToParagraphs(
            contentHtml,
            chapterTitle: page == 0 ? chapterTitle : null,
          ),
        );
      }

      if (src.chapter.nextPageUrl.isEmpty) break;
      final nextUrl = evaluator.evaluateField(
        rootNode,
        src.chapter.nextPageUrl,
        baseUrl: pageBase,
      );
      if (!SourceCrawlerHelpers.isValidHttpUrl(nextUrl) ||
          !visitedUrls.add(nextUrl)) {
        break;
      }
      currentUrl = nextUrl;
      currentReferer = pageBase;
    }

    return allParagraphs;
  }
}
