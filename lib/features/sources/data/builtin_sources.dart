import '../domain/book_source_rule.dart';
import 'builtin_sources_extra.dart';
import 'builtin_sources_more.dart';

/// 阅微纯净精选内置书源（12 组全数经实网全链路 200 OK 验证，详情页与正文清洗规则完备）
class BuiltinSources {
  static const List<BookSourceRule> _coreSources = [
    // 原 biquge7.xyz 已触发 Cloudflare 403 拦截，保留原 ID 替换为无拦截 HTTPS 影书笔趣阁
    BookSourceRule(
      id: 'builtin_biquge7',
      name: '影书笔趣阁',
      baseUrl: 'https://www.yingsx.com',
      groupName: '精品主力',
      charset: 'utf-8',
      isBuiltin: true,
      search: SearchRuleSpec(
        urlTemplate: 'https://www.yingsx.com/cse/search?q={key}&s=',
        item: '#main li',
        title: RuleField(selector: 'a.0', attr: 'text'),
        author: RuleField(selector: '.s4', attr: 'text'),
        detailUrl: RuleField(selector: 'a.0', attr: 'href'),
        latestChapter: RuleField(selector: 'a.1', attr: 'text'),
      ),
      detail: DetailRuleSpec(
        title: RuleField(selector: 'meta[property="og:title"]', attr: 'content'),
        author: RuleField(
          selector: 'meta[property="og:novel:author"]',
          attr: 'content',
        ),
        intro: RuleField(
          selector: 'meta[property="og:description"]',
          attr: 'content',
          regex: r'<br\s*/?>',
        ),
        coverUrl:
            RuleField(selector: 'meta[property="og:image"]', attr: 'content'),
        category: RuleField(
          selector: 'meta[property="og:novel:category"]',
          attr: 'content',
        ),
        statusText: RuleField(
          selector: 'meta[property="og:novel:status"]',
          attr: 'content',
        ),
        latestChapter: RuleField(
          selector: 'meta[property="og:novel:latest_chapter_name"]',
          attr: 'content',
        ),
        lastUpdateTime: RuleField(
          selector: 'meta[property="og:novel:update_time"]',
          attr: 'content',
        ),
      ),
      toc: TocRuleSpec(
        item: '#list dd a',
        title: RuleField(attr: 'text'),
        url: RuleField(attr: 'href'),
      ),
      chapter: ChapterRuleSpec(
        content: RuleField(
          selector: '#content',
          attr: 'html',
          regex: r'<script[^>]*>[\s\S]*?</script>',
        ),
      ),
    ),
    BookSourceRule(
      id: 'builtin_biqugezwx',
      name: '笔趣阁ZWX',
      baseUrl: 'https://www.biqugezwx.com',
      groupName: '精品主力',
      charset: 'utf-8',
      isBuiltin: true,
      search: SearchRuleSpec(
        urlTemplate:
            'https://www.biqugezwx.com/modules/article/search.php?searchkey={key}',
        item: 'div.item',
        title: RuleField(selector: 'h1 a', attr: 'text'),
        author: RuleField(
          selector: 'a[href*=authorarticle]',
          attr: 'text',
          regex: r'^作者：',
        ),
        detailUrl: RuleField(selector: 'h1 a', attr: 'href'),
        coverUrl: RuleField(selector: 'img', attr: 'src'),
      ),
      detail: DetailRuleSpec(
        title: RuleField(selector: '.itemtxt h1 a', attr: 'text'),
        author: RuleField(
          selector: '.itemtxt a[href*=authorarticle]',
          attr: 'text',
          regex: r'^作者[：:]\s*',
        ),
        intro: RuleField(selector: 'div.des', attr: 'text'),
        coverUrl: RuleField(selector: '.item img', attr: 'src'),
        statusText: RuleField(selector: '.itemtxt p span.0', attr: 'text'),
        category: RuleField(selector: '.itemtxt p span.1', attr: 'text'),
        latestChapter: RuleField(selector: '.itemtxt ul li a.0', attr: 'text'),
        lastUpdateTime: RuleField(
          selector: 'h2#dir span',
          attr: 'text',
          regex: r'^更新时间[：:]\s*',
        ),
      ),
      toc: TocRuleSpec(
        item: '#list a',
        title: RuleField(attr: 'text'),
        url: RuleField(attr: 'href'),
      ),
      chapter: ChapterRuleSpec(
        content: RuleField(selector: '.con', attr: 'html'),
      ),
    ),
    BookSourceRule(
      id: 'builtin_yetianlian',
      name: '夜天连看',
      baseUrl: 'http://www.yetianlian.info',
      groupName: '精品主力',
      charset: 'utf-8',
      isBuiltin: true,
      search: SearchRuleSpec(
        urlTemplate: 'http://www.yetianlian.info/s.php?ie=utf-8&q={key}',
        item: '.bookbox',
        title: RuleField(selector: '.bookname', attr: 'text'),
        author: RuleField(
          selector: '.author',
          attr: 'text',
          regex: r'^作者：',
        ),
        detailUrl: RuleField(selector: 'a', attr: 'href'),
        coverUrl: RuleField(selector: 'img', attr: 'src'),
      ),
      detail: DetailRuleSpec(
        title: RuleField(selector: 'meta[property="og:title"]', attr: 'content'),
        author: RuleField(
          selector: 'meta[property="og:novel:author"]',
          attr: 'content',
        ),
        intro: RuleField(
          selector: 'meta[property="og:description"]',
          attr: 'content',
        ),
        coverUrl:
            RuleField(selector: 'meta[property="og:image"]', attr: 'content'),
        category: RuleField(
          selector: 'meta[property="og:novel:category"]',
          attr: 'content',
        ),
        statusText: RuleField(
          selector: 'meta[property="og:novel:status"]',
          attr: 'content',
        ),
        latestChapter: RuleField(
          selector: 'meta[property="og:novel:latest_chapter_name"]',
          attr: 'content',
        ),
        lastUpdateTime: RuleField(
          selector: 'meta[property="og:novel:update_time"]',
          attr: 'content',
        ),
      ),
      toc: TocRuleSpec(
        item: '.listmain dd a',
        title: RuleField(attr: 'text'),
        url: RuleField(attr: 'href'),
      ),
      chapter: ChapterRuleSpec(
        content: RuleField(
          selector: '#content',
          attr: 'html',
          regex: r'请记住本书首发域名[^\n]*|https?://[^\s]*yetianlian[^\s]*',
        ),
      ),
    ),
    // 原 sto66.com 已触发 Cloudflare 403 拦截，保留原 ID 替换为高可用爱下文学
    BookSourceRule(
      id: 'builtin_sto66',
      name: '爱下文学',
      baseUrl: 'http://www.aixiawx.com',
      groupName: '经典备选',
      charset: 'utf-8',
      isBuiltin: true,
      search: SearchRuleSpec(
        urlTemplate:
            'http://www.aixiawx.com/modules/article/search.php?searchkey={key}&searchtype=articlename',
        item: 'tr',
        title: RuleField(selector: '@xpath://td[1]/a', attr: 'text'),
        author: RuleField(selector: '@xpath://td[3]', attr: 'text'),
        detailUrl: RuleField(selector: '@xpath://td[1]/a', attr: 'href'),
        latestChapter: RuleField(selector: '@xpath://td[2]/a', attr: 'text'),
      ),
      detail: DetailRuleSpec(
        title: RuleField(selector: 'meta[property="og:title"]', attr: 'content'),
        author: RuleField(
          selector: 'meta[property="og:novel:author"]',
          attr: 'content',
        ),
        intro: RuleField(
          selector: 'meta[property="og:description"]',
          attr: 'content',
        ),
        coverUrl:
            RuleField(selector: 'meta[property="og:image"]', attr: 'content'),
        category: RuleField(
          selector: 'meta[property="og:novel:category"]',
          attr: 'content',
        ),
        statusText: RuleField(
          selector: 'meta[property="og:novel:status"]',
          attr: 'content',
        ),
        latestChapter: RuleField(
          selector: 'meta[property="og:novel:latest_chapter_name"]',
          attr: 'content',
        ),
        lastUpdateTime: RuleField(
          selector: 'meta[property="og:novel:update_time"]',
          attr: 'content',
        ),
      ),
      toc: TocRuleSpec(
        item: '#list dd a',
        title: RuleField(attr: 'text'),
        url: RuleField(attr: 'href'),
      ),
      chapter: ChapterRuleSpec(
        content: RuleField(
          selector: '#content',
          attr: 'html',
          regex: r'<script[^>]*>[\s\S]*?</script>',
        ),
      ),
    ),
    // 域名已重定向至 kk169.la 且站方升级为 UTF-8，修复搜索作者与正文脚本清洗规则
    BookSourceRule(
      id: 'builtin_kk169',
      name: '穿越小说',
      baseUrl: 'http://www.kk169.la',
      groupName: '经典备选',
      charset: 'utf-8',
      isBuiltin: true,
      search: SearchRuleSpec(
        urlTemplate: 'http://www.kk169.la/modules/article/search.php?q={key}',
        item: 'div.c_row',
        title: RuleField(selector: '.c_subject a', attr: 'text'),
        author: RuleField(selector: '.c_tag .c_value.0', attr: 'text'),
        detailUrl: RuleField(selector: '.c_subject a', attr: 'href'),
        coverUrl: RuleField(selector: 'img', attr: 'src'),
      ),
      detail: DetailRuleSpec(
        title: RuleField(
          selector: 'meta[property="og:novel:book_name"]',
          attr: 'content',
        ),
        author: RuleField(
          selector: 'meta[property="og:novel:author"]',
          attr: 'content',
        ),
        intro: RuleField(selector: '.tabcontent .tabvalue.0', attr: 'text'),
        coverUrl:
            RuleField(selector: 'meta[property="og:image"]', attr: 'content'),
        category: RuleField(
          selector: 'meta[property="og:novel:category"]',
          attr: 'content',
        ),
        statusText: RuleField(
          selector: 'meta[property="og:novel:status"]',
          attr: 'content',
        ),
        latestChapter: RuleField(selector: '.divbox h3 a.0', attr: 'text'),
        lastUpdateTime: RuleField(
          selector: '.tabcontent td:contains(最后更新)',
          attr: 'text',
          regex: r'^最后更新[：:]\s*',
        ),
        tocUrl: RuleField(
          selector: 'meta[property="og:novel:read_url"]',
          attr: 'content',
        ),
      ),
      toc: TocRuleSpec(
        item: 'li.chapter a',
        title: RuleField(attr: 'text'),
        url: RuleField(attr: 'href'),
      ),
      chapter: ChapterRuleSpec(
        content: RuleField(
          selector: '#acontent',
          attr: 'html',
          regex:
              r'<h1[^>]*>[\s\S]*?</h1>|<div class="tishi">[\s\S]*?</div>|<script[^>]*>[\s\S]*?</script>|\(?穿越小说\s*www\.kk169\.la\)?',
        ),
      ),
    ),
  ];

  /// 全部预置书源（聚合基础主力源与实网验证扩充源，共 12 组）
  static const List<BookSourceRule> all = [
    ..._coreSources,
    ...builtinExtraSources,
    ...builtinMoreSources,
  ];
}
