import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:yuewei_reader/features/sources/data/builtin_sources.dart';
import 'package:yuewei_reader/features/sources/domain/book_match_models.dart';
import 'package:yuewei_reader/features/sources/domain/book_source_rule.dart';
import 'package:yuewei_reader/features/sources/engine/book_metadata_sanitizer.dart';
import 'package:yuewei_reader/features/sources/engine/legado_rule_adapter.dart';
import 'package:yuewei_reader/features/sources/engine/rule_evaluator.dart';
import 'package:yuewei_reader/features/sources/engine/source_crawler_service.dart';

void main() {
  const evaluator = RuleEvaluator();

  group('RuleEvaluator 与 Legado 书源解析测试', () {
    test('CSS 选择器、:contains 过滤与 .0/.-1 索引切片准确解析', () {
      const html = '''
        <div class="result-list">
          <div class="item">
            <a class="book-link" href="/book/101.html">《山海夜巡人》</a>
            <span class="meta">作者：林岚</span>
            <span class="meta">连载中</span>
          </div>
          <div class="item">
            <a class="book-link" href="/book/202.html">《风雪归舟》</a>
            <span class="meta">作者：顾言</span>
            <span class="meta">已完结</span>
          </div>
        </div>
      ''';

      final nodes = evaluator.selectNodes(html, '.result-list .item');
      expect(nodes.length, 2);

      final firstTitle = evaluator.evaluateField(
        nodes[0],
        const RuleField(selector: '.book-link', attr: 'text'),
      );
      final firstAuthor = evaluator.evaluateField(
        nodes[0],
        const RuleField(selector: '.meta.0', attr: 'text', regex: r'^作者[：:]'),
      );
      final secondStatus = evaluator.evaluateField(
        nodes[1],
        const RuleField(selector: '.meta.-1', attr: 'text'),
      );
      final firstUrl = evaluator.evaluateField(
        nodes[0],
        const RuleField(selector: '.book-link', attr: 'href'),
        baseUrl: 'https://www.example.com/search',
      );

      expect(firstTitle, '《山海夜巡人》');
      expect(firstAuthor, '林岚');
      expect(secondStatus, '已完结');
      expect(firstUrl, 'https://www.example.com/book/101.html');

      final matchedNodes =
          evaluator.selectNodes(html, '.item:contains(风雪归舟)');
      expect(matchedNodes.length, 1);
    });

    test('JSONPath 与 XPath 解析管道均正常工作', () {
      const jsonRaw = '''
        {
          "data": {
            "books": [
              {"name": "星渊航图", "author": "南风", "url": "https://api.test/b/1"}
            ]
          }
        }
      ''';
      final jsonNodes = evaluator.selectNodes(jsonRaw, r'$.data.books[*]');
      expect(jsonNodes.length, 1);
      expect(
        evaluator.evaluateField(jsonNodes.first, const RuleField(selector: r'$.name')),
        '星渊航图',
      );

      const xmlHtml = '<ul id="toc"><li><a href="/c/1">第一章</a></li></ul>';
      final xpNodes = evaluator.selectNodes(xmlHtml, '//ul[@id="toc"]/li/a');
      expect(xpNodes.length, 1);
      expect(
        evaluator.evaluateField(xpNodes.first, const RuleField(attr: 'text')),
        '第一章',
      );
    });

    test('LegadoRuleAdapter 可解析标准 Legado 3.0 JSON 并校验内置主力源合法性', () {
      const legadoSample = r'''
      [{
        "bookSourceName": "开源样例书站",
        "bookSourceUrl": "https://sample.legado.org",
        "bookSourceGroup": "测试分组",
        "searchUrl": "https://sample.legado.org/search?q={{key}},{\"charset\":\"gbk\"}",
        "ruleSearch": {
          "bookList": ".list .row",
          "name": "a.title@text",
          "author": "span.author@text",
          "bookUrl": "a.title@href"
        },
        "ruleToc": {
          "chapterList": "#chapters li a",
          "chapterName": "text",
          "chapterUrl": "href"
        },
        "ruleContent": {
          "content": "#article@html"
        }
      }]
      ''';

      final parsed = LegadoRuleAdapter.parseJson(legadoSample);
      expect(parsed.length, 1);
      final rule = parsed.first;
      expect(rule.name, '开源样例书站');
      expect(rule.charset.toLowerCase(), 'gbk');
      expect(rule.search.urlTemplate, contains('{key}'));

      expect(BuiltinSources.all.length, greaterThanOrEqualTo(10));
      final seenIds = <String>{};
      for (final src in BuiltinSources.all) {
        expect(src.id, isNotEmpty);
        expect(seenIds.add(src.id), isTrue, reason: '重复书源ID: ${src.id}');
        expect(src.name, isNotEmpty);
        expect(src.groupName, isNotEmpty);
        expect(src.charset, isNotEmpty);
        expect(src.isBuiltin, isTrue);
        expect(
          src.baseUrl,
          anyOf(startsWith('https://'), startsWith('http://')),
        );
        expect(src.search.urlTemplate, contains('{key}'));
        expect(src.search.item, isNotEmpty);
        expect(src.search.title.isEmpty, isFalse);
        expect(src.search.detailUrl.isEmpty, isFalse);
        expect(src.toc.item, isNotEmpty);
        expect(src.toc.url.isEmpty, isFalse);
        expect(src.chapter.content.selector, isNotEmpty);

        final roundTrip = BookSourceRule.fromJsonString(src.toJsonString());
        expect(roundTrip.id, src.id);
        expect(roundTrip.name, src.name);
        expect(roundTrip.baseUrl, src.baseUrl);
        expect(roundTrip.groupName, src.groupName);
        expect(roundTrip.charset, src.charset);
        expect(roundTrip.isBuiltin, src.isBuiltin);
        expect(roundTrip.search.urlTemplate, src.search.urlTemplate);
        expect(roundTrip.search.method, src.search.method);
        expect(roundTrip.search.item, src.search.item);
        expect(roundTrip.detail.intro.selector, src.detail.intro.selector);
        expect(roundTrip.detail.intro.regex, src.detail.intro.regex);
        expect(roundTrip.toc.item, src.toc.item);
        expect(roundTrip.chapter.content.selector, src.chapter.content.selector);
        expect(roundTrip.chapter.content.regex, src.chapter.content.regex);
      }

      for (final coreId in const [
        'builtin_biquge7',
        'builtin_biqugezwx',
        'builtin_yetianlian',
        'builtin_sto66',
        'builtin_kk169',
      ]) {
        expect(seenIds.contains(coreId), isTrue, reason: '缺少保留核心ID: $coreId');
      }
    });

    test('未配置 selector 的默认 RuleField 绝不吞噬全页 HTML/JS 且仍兼容 a 标签自身属性提取', () {
      const fullHtml = '''
        <html>
          <head><script>window.dataLayer = [];</script></head>
          <body>
            <div class="box"><a href="/c/99.html">第九十九章 大结局</a></div>
          </body>
        </html>
      ''';
      final doc = html_parser.parse(fullHtml);
      final rootNode = EvaluatedNode.html(doc.documentElement!);

      // 未配置 selector 的可选字段应严格返回空串（彻底根除 script/HTML 污染 category/statusText）
      expect(evaluator.evaluateField(rootNode, const RuleField()), isEmpty);
      expect(evaluator.evaluateField(rootNode, RuleField.fromJson(const {})), isEmpty);

      // 局部节点 <div class="box"> 包含 <script> 时也应剔除 JS 脚本
      const htmlWithInlineScript =
          '<div class="intro">真实简介正文<script>window.__secret=1;</script></div>';
      final divNode = evaluator.selectNodes(htmlWithInlineScript, '.intro').first;
      expect(evaluator.evaluateField(divNode, const RuleField(attr: 'text')), '真实简介正文');

      // 目录 <a> 标签配合显式 attr: text/href 应正常工作
      final aNode = evaluator.selectNodes(fullHtml, '.box a').first;
      expect(evaluator.evaluateField(aNode, const RuleField(attr: 'text')), '第九十九章 大结局');
      expect(
        evaluator.evaluateField(aNode, const RuleField(attr: 'href'), baseUrl: 'https://test.org'),
        'https://test.org/c/99.html',
      );
    });

    test('cleanSeoIntro 折叠换行空白、剥离序号噪声并过滤 SEO 模板', () {
      expect(SourceCrawlerService.cleanSeoIntro('  1\n   \n'), isEmpty);
      expect(
        SourceCrawlerService.cleanSeoIntro(
          '1\n  《某书》\n 作者：某人\n 简介：这里是属于斗气的世界！\n  全新等级体系。',
        ),
        '这里是属于斗气的世界！ 全新等级体系。',
      );
      expect(
        SourceCrawlerService.cleanSeoIntro('window.__CF=1; function(){}'),
        isEmpty,
      );
      expect(
        BookMetadataSanitizer.cleanSeoIntro(
          '这里是属于斗气的世界，没有花俏艳丽的魔法！\n《斗破苍穹》是作家「天蚕土豆」倾力打造的一部玄幻佳作。本书由思兔小说为您呈现，无错字精校。',
        ),
        '这里是属于斗气的世界，没有花俏艳丽的魔法！',
      );
    });

    test('五组内置书源详情页规则正确提取简介、最新章节与更新时间并过滤脏时间', () {
      expect(BookMetadataSanitizer.sanitizeUpdateTime('更新时间：2026-01-22 22:43'), '2026-01-22 22:43');
      expect(BookMetadataSanitizer.sanitizeUpdateTime('最后更新：2019-04-02 07:59:51'), '2019-04-02 07:59:51');
      expect(BookMetadataSanitizer.sanitizeUpdateTime('未知时间'), isEmpty);
      expect(BookMetadataSanitizer.sanitizeUpdateTime('<script>x</script>'), isEmpty);

      // 1. 笔趣阁ZWX 真实 DOM 样本
      final zwx = BuiltinSources.all.firstWhere((s) => s.id == 'builtin_biqugezwx');
      const zwxHtml = '''
        <html><body><div class="container"><div class="item">
          <img src="https://img.example.com/605s.jpg"/>
          <div class="itemtxt">
            <h1><i>万字</i><a href="/605/#dir">斗破苍穹</a></h1>
            <p><span>已完结</span><span>玄幻小说</span></p>
            <p><a href="/authorarticle?author=1">作者：天蚕土豆</a></p>
            <ul><li><i>未知时间</i><a href="/605/1.html">第1661章 萧炎云韵篇</a></li></ul>
          </div>
        </div>
        <div class="des bb">这里是属于斗气的世界！</div>
        <h2 id="dir"><span>更新时间：2026-01-22 22:43</span></h2>
        </div></body></html>
      ''';
      final zwxRoot = EvaluatedNode.html(html_parser.parse(zwxHtml).documentElement!);
      expect(evaluator.evaluateField(zwxRoot, zwx.detail.intro), '这里是属于斗气的世界！');
      expect(evaluator.evaluateField(zwxRoot, zwx.detail.latestChapter), '第1661章 萧炎云韵篇');
      expect(evaluator.evaluateField(zwxRoot, zwx.detail.lastUpdateTime), '2026-01-22 22:43');
      expect(evaluator.evaluateField(zwxRoot, zwx.detail.statusText), '已完结');
      expect(evaluator.evaluateField(zwxRoot, zwx.detail.category), '玄幻小说');

      // 2. 笔趣阁7 / 夜天连看 OpenGraph meta 提取
      final b7 = BuiltinSources.all.firstWhere((s) => s.id == 'builtin_biquge7');
      const ogHtml = '''
        <html><head>
          <meta property="og:title" content="万相之王" />
          <meta property="og:description" content="天地间，有万相。而我李洛，终将成为这万相之王。" />
          <meta property="og:novel:category" content="玄幻奇幻" />
          <meta property="og:novel:status" content="完结" />
          <meta property="og:novel:update_time" content="2025-11-14 18:00:00" />
          <meta property="og:novel:latest_chapter_name" content="第一千八百三十七章 大结局" />
        </head><body></body></html>
      ''';
      final ogRoot = EvaluatedNode.html(html_parser.parse(ogHtml).documentElement!);
      expect(evaluator.evaluateField(ogRoot, b7.detail.intro), '天地间，有万相。而我李洛，终将成为这万相之王。');
      expect(evaluator.evaluateField(ogRoot, b7.detail.lastUpdateTime), '2025-11-14 18:00:00');
      expect(evaluator.evaluateField(ogRoot, b7.detail.latestChapter), '第一千八百三十七章 大结局');
    });

    test('修复源与新增扩充源典型 DOM/XPath 及广告清洗正则生效', () {
      final groups = BuiltinSources.all.map((s) => s.groupName).toSet();
      expect(groups, containsAll(const ['精品主力', '经典备选', '精选扩充']));

      final kk = BuiltinSources.all.firstWhere((s) => s.id == 'builtin_kk169');
      const kkChHtml = '''
        <div id="acontent"><h1>第一章 陨落的天才</h1><script>read2();</script>
        <div class="tishi">穿越小说推荐</div>(穿越小说 www.kk169.la)月如银盘。<br/>穿越小说 www.kk169.la</div>
      ''';
      final kkNode =
          EvaluatedNode.html(html_parser.parse(kkChHtml).documentElement!);
      final kkCleaned = evaluator.evaluateField(kkNode, kk.chapter.content);
      expect(kkCleaned, contains('月如银盘。'));
      expect(kkCleaned, isNot(contains('read2')));
      expect(kkCleaned, isNot(contains('kk169.la')));

      final qs = BuiltinSources.all.firstWhere((s) => s.id == 'builtin_qiushu');
      const qsHtml = '''
        <div class="book_con_list"><ul><li><a href="/new.html">最新章</a></li></ul></div>
        <div class="book_con_list"><ul><li><a href="1.html">第一章 绯红</a></li></ul></div>
        <div id="content">痛！<p>手机阅读：http://m.qiushu.info/1/</p><p>为了方便下次阅读，加入书签</p></div>
      ''';
      final tocNodes = evaluator.selectNodes(qsHtml, qs.toc.item);
      expect(tocNodes.length, 1);
      expect(evaluator.evaluateField(tocNodes.first, qs.toc.title), '第一章 绯红');
      final qsContent = evaluator.evaluateField(
        EvaluatedNode.html(html_parser.parse(qsHtml).documentElement!),
        qs.chapter.content,
      );
      expect(qsContent, '痛！');

      final bd = BuiltinSources.all.firstWhere((s) => s.id == 'builtin_botaodz');
      const bdHtml = '<meta property="og:description" content="一段传奇。\n各位书友要是觉得《某书》还不错的话请不要忘记推荐！" />';
      expect(
        evaluator.evaluateField(EvaluatedNode.html(html_parser.parse(bdHtml).documentElement!), bd.detail.intro),
        '一段传奇。',
      );

      final xy = BuiltinSources.all.firstWhere((s) => s.id == 'builtin_xyusk');
      expect(xy.baseUrl, 'http://www.8xiaoshuo.net');
      expect(xy.search.urlTemplate, startsWith('http://www.8xiaoshuo.net/'));
    });

    test('AggregatedBookMatch.bestIntro 过滤占位符并择优真实简介', () {
      SourceSearchHit hit(String id, String intro) => SourceSearchHit(
            sourceId: id, sourceName: id, title: '遮天', author: '辰东',
            bookUrl: 'https://test.org/$id', intro: intro, latencyMs: 100,
          );

      final agg = AggregatedBookMatch(
        cleanTitle: '遮天', cleanAuthor: '辰东',
        hits: [
          hit('s1', '...'), hit('s2', '……  '), hit('s3', '暂无简介。'),
          hit('s4', '暂无介绍'), hit('s5', '无简介'), hit('s6', '好书！'),
          hit('s7', '冰冷与黑暗并存的宇宙深处。'),
          hit('s8', '冰冷与黑暗并存的宇宙深处，九具庞大的龙尸拉着一口青铜古棺，亘古长存。'),
        ],
      );
      expect(agg.bestIntro, '冰冷与黑暗并存的宇宙深处，九具庞大的龙尸拉着一口青铜古棺，亘古长存。');

      final emptyAgg = AggregatedBookMatch(
        cleanTitle: '遮天', cleanAuthor: '辰东',
        hits: [hit('s1', '...'), hit('s2', '暂无简介'), hit('s3', '无')],
      );
      expect(emptyAgg.bestIntro, isEmpty);
    });
  });
}
