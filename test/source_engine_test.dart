import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:yuewei_reader/core/database/app_database.dart';
import 'package:yuewei_reader/core/network/app_http_client.dart';
import 'package:yuewei_reader/features/sources/data/builtin_sources.dart';
import 'package:yuewei_reader/features/sources/data/source_repository.dart';
import 'package:yuewei_reader/features/sources/domain/book_match_models.dart';
import 'package:yuewei_reader/features/sources/domain/book_source_rule.dart';
import 'package:yuewei_reader/features/sources/engine/book_metadata_sanitizer.dart';
import 'package:yuewei_reader/features/sources/engine/legado_rule_adapter.dart';
import 'package:yuewei_reader/features/sources/engine/rule_evaluator.dart';
import 'package:yuewei_reader/features/sources/engine/source_crawler_service.dart';

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions options, Uint8List body) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bb = BytesBuilder(copy: false);
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bb.add(chunk);
      }
    }
    return handler(options, bb.takeBytes());
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _htmlResp(String html, {String? finalUrl}) {
  return ResponseBody(
    Stream.value(Uint8List.fromList(utf8.encode(html))),
    200,
    headers: {Headers.contentTypeHeader: ['text/html; charset=utf-8']},
    isRedirect: finalUrl != null,
    redirects: finalUrl != null
        ? [RedirectRecord(302, 'GET', Uri.parse(finalUrl))]
        : null,
  );
}

BookSourceRule _buildTestRule({
  RuleField tocNext = const RuleField(),
  RuleField chapterNext = const RuleField(),
}) =>
    BookSourceRule(
      id: 'test_src',
      name: '测试源',
      baseUrl: 'https://book.test',
      search: const SearchRuleSpec(
        urlTemplate: 'https://book.test/search?q={key}',
        item: '.list .item',
        title: RuleField(selector: 'a.name', attr: 'text'),
        author: RuleField(selector: '.author', attr: 'text'),
        detailUrl: RuleField(selector: 'a.name', attr: 'href'),
        coverUrl: RuleField(selector: 'img', attr: 'src'),
      ),
      detail: const DetailRuleSpec(
        title: RuleField(selector: 'h1.book-title', attr: 'text'),
        author: RuleField(selector: '.book-author', attr: 'text'),
        intro: RuleField(selector: '.book-intro', attr: 'text'),
      ),
      toc: TocRuleSpec(
        item: '#toc a',
        title: const RuleField(attr: 'text'),
        url: const RuleField(attr: 'href'),
        nextPageUrl: tocNext,
      ),
      chapter: ChapterRuleSpec(
        content: const RuleField(selector: '#content', attr: 'html'),
        nextPageUrl: chapterNext,
      ),
    );

void main() {
  const evaluator = RuleEvaluator();

  group('RuleEvaluator、Legado 规则与网络解码测试', () {
    test('CSS 选择器、:contains、.0/.-1 索引切片、JSONPath 与 XPath 均准确解析', () {
      const html = '''
        <div class="result-list">
          <div class="item"><a class="book-link" href="/book/101.html">《山海夜巡人》</a><span class="meta">作者：林岚</span><span class="meta">连载中</span></div>
          <div class="item"><a class="book-link" href="/book/202.html">《风雪归舟》</a><span class="meta">作者：顾言</span><span class="meta">已完结</span></div>
        </div>''';
      final nodes = evaluator.selectNodes(html, '.result-list .item');
      expect(nodes.length, 2);
      expect(evaluator.evaluateField(nodes[0], const RuleField(selector: '.book-link', attr: 'text')), '《山海夜巡人》');
      expect(evaluator.evaluateField(nodes[0], const RuleField(selector: '.meta.0', attr: 'text', regex: r'^作者[：:]')), '林岚');
      expect(evaluator.evaluateField(nodes[1], const RuleField(selector: '.meta.-1', attr: 'text')), '已完结');
      expect(evaluator.evaluateField(nodes[0], const RuleField(selector: '.book-link', attr: 'href'), baseUrl: 'https://www.example.com/search'), 'https://www.example.com/book/101.html');
      expect(evaluator.selectNodes(html, '.item:contains(风雪归舟)').length, 1);

      const jsonRaw = '{"data":{"books":[{"name":"星渊航图","author":"南风"}]}}';
      final jsonNodes = evaluator.selectNodes(jsonRaw, r'$.data.books[*]');
      expect(evaluator.evaluateField(jsonNodes.first, const RuleField(selector: r'$.name')), '星渊航图');

      const xmlHtml = '<ul id="toc"><li><a href="/c/1">第一章</a></li></ul>';
      final xpNodes = evaluator.selectNodes(xmlHtml, '//ul[@id="toc"]/li/a');
      expect(evaluator.evaluateField(xpNodes.first, const RuleField(attr: 'text')), '第一章');
    });

    test('attr: html 剥离 script/style/noscript、实体顺序防双重反转义、##regex##replacement 与 || 回退链', () {
      const html = '''
        <div id="content">
          <style>.hide{display:none}</style>
          <p>第一段：&amp;lt;保留&amp;gt;&#10;第二行</p>
          <script>window.adLeak = 123;</script>
          <noscript>脚本提示</noscript>
        </div>
        <div class="fallback-title">备选书名：星辰</div>
        <a class="alt-link" href="/detail/9.html">入口</a>
      ''';
      final root = EvaluatedNode.html(html_parser.parse(html).documentElement!);
      final cleanHtml = evaluator.evaluateField(root, const RuleField(selector: '#content', attr: 'html'));
      expect(cleanHtml, contains('第一段'));
      expect(cleanHtml, isNot(contains('adLeak')));
      expect(cleanHtml, isNot(contains('display:none')));
      expect(cleanHtml, isNot(contains('脚本提示')));
      expect(html_parser.parse(html).querySelector('script'), isNotNull);

      expect(RuleEvaluator.decodeHtmlEntities('&amp;lt;div&amp;gt; &amp;#65; a&#10;b&#13;c'), '&lt;div&gt; &#65; a\nb\rc');

      // || 回退链与 ##regex##replacement
      final fallbackVal = evaluator.evaluateField(
        root,
        const RuleField(
          selector: '.missing-title || .fallback-title',
          attr: 'text',
          regex: r'^备选书名[：:]',
          replacement: '《',
        ),
      );
      expect(fallbackVal, '《星辰');
      final fallbackLink = evaluator.evaluateField(
        root,
        const RuleField(selector: '.none@href || .alt-link@href', attr: 'text'),
        baseUrl: 'https://book.test/x',
      );
      expect(fallbackLink, 'https://book.test/detail/9.html');
      expect(evaluator.selectNodes(html, '.none-list || .fallback-title').length, 1);

      // Legado ##regex##replacement 解析
      const legadoReplace = r'[{"bookSourceName":"替换测试","bookSourceUrl":"https://r.test","searchUrl":"/s?q={{key}}","ruleSearch":{"bookList":".i","name":"a@text##旧词##新词","bookUrl":"a@href"},"ruleToc":{"chapterList":".c a"},"ruleContent":{"content":"#txt"}}]';
      final rule = LegadoRuleAdapter.parseJson(legadoReplace).first;
      expect(rule.search.title.regex, '旧词');
      expect(rule.search.title.replacement, '新词');
      expect(BookSourceRule.fromJsonString(rule.toJsonString()).search.title.replacement, '新词');
    });

    test('UTF-8 明确声明遇单坏字节不误降级 GBK，GBK POST 发送字节流且 encodeQuery 容错 Emoji', () async {
      final utf8WithBadByte = <int>[...utf8.encode('第一章 星辰大海'), 0xFF, ...utf8.encode('终章')];
      final decoded = AppHttpClient.decodeBytes(utf8WithBadByte, contentType: 'text/html; charset=utf-8');
      expect(decoded, contains('第一章 星辰大海'));
      expect(decoded, contains('终章'));

      // encodeQuery 含超出 GBK 的 Emoji 不抛异常
      final encodedGbk = AppHttpClient.encodeQuery('斗破😀', 'gbk');
      expect(encodedGbk, contains('%B6%B7%C6%C6'));
      expect(encodedGbk, contains('%F0%9F%98%80'));

      // GBK POST 设置 charset=gbk 并以 GBK 字节流发送
      String? capturedCt;
      Uint8List? capturedBody;
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((opt, body) async {
          capturedCt = opt.headers['Content-Type']?.toString();
          capturedBody = body;
          return _htmlResp('<html><body>ok</body></html>');
        });
      final client = AppHttpClient(dio: dio);
      await client.fetchText(
        'https://gbk.test/search',
        method: 'POST',
        body: 'key=斗破',
        charsetHint: 'gbk',
      );
      expect(capturedCt, 'application/x-www-form-urlencoded; charset=gbk');
      expect(capturedBody, equals(Uint8List.fromList([...utf8.encode('key='), ...gbk.encode('斗破')])));
    });

    test('目录/正文多页 nextPageUrl 拼接防环、相对链接使用 finalUrl 与 302 详情直解', () async {
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((opt, _) async {
          final u = opt.uri.toString();
          if (u == 'https://book.test/search?q=%E8%AF%A1%E7%A7%98') {
            return _htmlResp(
              '<html><body><h1 class="book-title">诡秘之主</h1><div class="book-author">爱潜水的乌贼</div><div class="book-intro">蒸汽与机械的浪潮中。</div></body></html>',
              finalUrl: 'https://book.test/book/888/',
            );
          }
          if (u == 'https://book.test/search?q=rel') {
            return _htmlResp(
              '<div class="list"><div class="item"><a class="name" href="item/1.html">相对书</a><img src="img/1.jpg"/></div></div>',
              finalUrl: 'https://cdn.book.test/sub/search.php',
            );
          }
          if (u == 'https://book.test/book/1/') {
            return _htmlResp(
              '<h1 class="book-title">分页测试书</h1><div id="toc"><a href="/c/1.html">第一章</a><a href="/c/2.html">第二章</a></div><a class="next-toc" href="/book/1/p2.html">下一页</a>',
            );
          }
          if (u == 'https://book.test/book/1/p2.html') {
            return _htmlResp(
              '<div id="toc"><a href="/c/3.html">第三章</a></div><a class="next-toc" href="/book/1/">循环回首页</a>',
            );
          }
          if (u == 'https://book.test/c/1.html') {
            return _htmlResp(
              '<div id="content"><p>第一章 启程</p><p>第一页正文。</p></div><a class="next-ch" href="/c/1_2.html">下一页</a>',
            );
          }
          if (u == 'https://book.test/c/1_2.html') {
            return _htmlResp(
              '<div id="content"><p>第一章 启程</p><p>第二页正文。</p></div><a class="next-ch" href="/c/1.html">回环</a>',
            );
          }
          return _htmlResp('');
        });
      final crawler = SourceCrawlerService(httpClient: AppHttpClient(dio: dio));
      final rule = _buildTestRule(
        tocNext: const RuleField(selector: 'a.next-toc', attr: 'href'),
        chapterNext: const RuleField(selector: 'a.next-ch', attr: 'href'),
      );

      // 302 直跳详情页提取单条 SourceSearchHit
      final directHits = await crawler.searchStream([rule], '诡秘').toList();
      expect(directHits.length, 1);
      expect(directHits.first.title, '诡秘之主');
      expect(directHits.first.author, '爱潜水的乌贼');
      expect(directHits.first.bookUrl, 'https://book.test/book/888/');

      // 相对路径按 res.finalUrl 解析
      final relHits = await crawler.searchStream([rule], 'rel').toList();
      expect(relHits.first.bookUrl, 'https://cdn.book.test/sub/item/1.html');
      expect(relHits.first.coverUrl, 'https://cdn.book.test/sub/img/1.jpg');

      // 目录多页拼接 + 防环
      final detailRes = await crawler.fetchBookDetailAndToc(rule, 'https://book.test/book/1/');
      expect(detailRes.chapters.map((c) => c.title).toList(), ['第一章', '第二章', '第三章']);

      // 正文多页拼接 + 防环 + 仅首页按 chapterTitle 去重
      final paras = await crawler.fetchChapterParagraphs(rule, 'https://book.test/c/1.html', chapterTitle: '第一章 启程');
      expect(paras.length, 3);
      expect(paras[0], '\u3000\u3000第一页正文。');
      expect(paras[1], '\u3000\u3000第一章 启程');
      expect(paras[2], '\u3000\u3000第二页正文。');
    });

    test('SourceRepository 防篡改内置源且 ensureBuiltinSourcesSeeded 保留用户启用状态', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = SourceRepository(db: db, httpClient: AppHttpClient());
      await repo.ensureBuiltinSourcesSeeded();

      // 用户禁用 builtin_biquge7 后再次同步，ruleJson.enabled 须保持 false
      await repo.setEnabled('builtin_biquge7', false);
      await repo.ensureBuiltinSourcesSeeded();
      final keptRule = await repo.getRuleById('builtin_biquge7');
      expect(keptRule?.enabled, isFalse);

      // 尝试通过原生 JSON 覆写内置源或导入空 ID 均应被拦截
      final attackJson = jsonEncode([
        {...BuiltinSources.all.first.toJson(), 'name': '被篡改的内置源'},
        {...BuiltinSources.all.first.toJson(), 'id': ''},
        {...BuiltinSources.all.first.toJson(), 'id': 'custom_valid_1', 'name': '合法自定义源', 'isBuiltin': true},
      ]);
      final imported = await repo.importLegadoJson(attackJson);
      expect(imported, 1);
      expect((await repo.getRuleById(BuiltinSources.all.first.id))?.name, BuiltinSources.all.first.name);
      final custom = await repo.getRuleById('custom_valid_1');
      expect(custom?.name, '合法自定义源');
      expect(custom?.isBuiltin, isFalse);
    });

    test('内置书源合法性、元数据清洗、防劈裂代理对与 AggregatedBookMatch.bestIntro', () {
      expect(BuiltinSources.all.length, greaterThanOrEqualTo(10));
      final seenIds = <String>{};
      for (final src in BuiltinSources.all) {
        expect(seenIds.add(src.id), isTrue);
        expect(src.isBuiltin, isTrue);
        expect(src.search.urlTemplate, contains('{key}'));
        expect(BookSourceRule.fromJsonString(src.toJsonString()).id, src.id);
      }
      expect(seenIds, containsAll(const ['builtin_biquge7', 'builtin_biqugezwx', 'builtin_yetianlian', 'builtin_sto66', 'builtin_kk169']));

      // Emoji 简介截断不劈裂代理对
      final emojiIntro = '${'a' * 599}🚀${'b' * 20}';
      final truncated = BookMetadataSanitizer.cleanSeoIntro(emojiIntro);
      expect(truncated.contains('\uFFFD'), isFalse);
      expect(truncated, endsWith('🚀…'));

      expect(BookMetadataSanitizer.sanitizeUpdateTime('更新时间：2026-01-22 22:43'), '2026-01-22 22:43');
      expect(BookMetadataSanitizer.sanitizeUpdateTime('未知时间'), isEmpty);
      expect(SourceCrawlerService.cleanSeoIntro('window.__CF=1; function(){}'), isEmpty);
      expect(
        BookMetadataSanitizer.cleanSeoIntro(
          '斗破苍穹已更新，本站除提供免费在线阅读外（无广告哦），还提供txt电子书下载，《斗破苍穹》在手机也可以完美阅读和下载！',
        ),
        isEmpty,
      );
      expect(
        BookMetadataSanitizer.cleanSeoIntro(
          '这里是属于斗气的世界，没有花俏艳丽的魔法！ 斗破苍穹已更新，本站除提供免费在线阅读外（无广告哦），还提供TXT电子书下载，《斗破苍穹》在手机上也可以完美阅读和下载！',
        ),
        '这里是属于斗气的世界，没有花俏艳丽的魔法！',
      );
      expect(
        BookMetadataSanitizer.cleanSeoIntro(
          '少年在旧手机上读完父亲留下的日记，决意踏上寻找失踪船队的远航。',
        ),
        '少年在旧手机上读完父亲留下的日记，决意踏上寻找失踪船队的远航。',
      );

      final kk = BuiltinSources.all.firstWhere((s) => s.id == 'builtin_kk169');
      final kkNode = EvaluatedNode.html(html_parser.parse('<div id="acontent"><h1>第一章</h1><script>read2();</script>(穿越小说 www.kk169.la)月如银盘。</div>').documentElement!);
      expect(evaluator.evaluateField(kkNode, kk.chapter.content), contains('月如银盘。'));
      expect(evaluator.evaluateField(kkNode, kk.chapter.content), isNot(contains('read2')));

      SourceSearchHit hit(String id, String intro) => SourceSearchHit(
            sourceId: id, sourceName: id, title: '遮天', author: '辰东',
            bookUrl: 'https://test.org/$id', intro: intro, latencyMs: 100,
          );
      final agg = AggregatedBookMatch(cleanTitle: '遮天', cleanAuthor: '辰东', hits: [hit('s1', '暂无简介'), hit('s2', '九具庞大的龙尸拉着一口青铜古棺。')]);
      expect(agg.bestIntro, '九具庞大的龙尸拉着一口青铜古棺。');
    });
  });
}
