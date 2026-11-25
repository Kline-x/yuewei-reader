import '../domain/book_source_rule.dart';

/// 阅微精选内置扩充书源（第二批：啃书阁 / 飞速小说 / 聚文阁）
const List<BookSourceRule> builtinMoreSources = [
  BookSourceRule(
    id: 'builtin_kenshuwx',
    name: '啃书阁',
    baseUrl: 'http://www.kenshuwx.com',
    groupName: '精选扩充',
    charset: 'utf-8',
    isBuiltin: true,
    search: SearchRuleSpec(
      urlTemplate:
          'http://www.kenshuwx.com/modules/article/search.php?area=2&searchkey={key}',
      item: '.search-list li',
      title: RuleField(selector: 'a.1', attr: 'text'),
      author: RuleField(
        selector: '.author p.0',
        attr: 'text',
        regex: r'^作者[：:]\s*',
      ),
      detailUrl: RuleField(selector: 'a.1', attr: 'href'),
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
      tocUrl: RuleField(selector: 'a:contains(查看目录)', attr: 'href'),
    ),
    toc: TocRuleSpec(
      item: '.chapter-list li a',
      title: RuleField(attr: 'text'),
      url: RuleField(attr: 'href'),
    ),
    chapter: ChapterRuleSpec(
      content: RuleField(
        selector: '.article-con',
        attr: 'html',
        regex:
            r'<script[^>]*>[\s\S]*?</script>|(?:以下是)?啃书小说网[^\n<]*版权归作者或出版社。|最新网址[^\n<]*',
      ),
    ),
  ),
  BookSourceRule(
    id: 'builtin_feisuwx',
    name: '飞速小说',
    baseUrl: 'http://www.feisuwx.org',
    groupName: '精选扩充',
    charset: 'utf-8',
    isBuiltin: true,
    search: SearchRuleSpec(
      urlTemplate:
          'http://www.feisuwx.org/modules/article/search.php?searchkey={key}',
      item: 'div.novelslist3 ul li, #newscontent li',
      title: RuleField(selector: '.s2 a', attr: 'text'),
      author: RuleField(selector: '.s4', attr: 'text'),
      detailUrl: RuleField(selector: '.s1 a', attr: 'href'),
      latestChapter: RuleField(selector: '.s3 a', attr: 'text'),
    ),
    detail: DetailRuleSpec(
      title: RuleField(selector: '#info h1', attr: 'text'),
      author: RuleField(
        selector: '#info .s1',
        attr: 'text',
        regex: r'^作[\s\u00A0]*者[：:]\s*',
      ),
      intro: RuleField(selector: '#intro p.0', attr: 'text'),
      coverUrl: RuleField(selector: '#fmimg img', attr: 'src'),
      latestChapter: RuleField(selector: '#intro .s2 a', attr: 'text'),
    ),
    toc: TocRuleSpec(
      item: '#list dd a',
      title: RuleField(attr: 'text'),
      url: RuleField(attr: 'href'),
    ),
    chapter: ChapterRuleSpec(
      content: RuleField(
        selector: 'div#content',
        attr: 'html',
        regex:
            r'<script[^>]*>[\s\S]*?</script>|读[^，。]*请记好本站的地址[^\n<]*',
      ),
    ),
  ),
  BookSourceRule(
    id: 'builtin_rulianshi',
    name: '聚文阁(RLS)',
    baseUrl: 'http://www.rulianshi.cc',
    groupName: '精选扩充',
    charset: 'utf-8',
    isBuiltin: true,
    search: SearchRuleSpec(
      urlTemplate: 'http://www.rulianshi.cc/s.php?q={key}',
      item: '.bookbox',
      title: RuleField(selector: '.bookname a', attr: 'text'),
      author: RuleField(
        selector: '.author',
        attr: 'text',
        regex: r'^作者[：:]\s*',
      ),
      detailUrl: RuleField(selector: '.bookname a', attr: 'href'),
      coverUrl: RuleField(selector: '.bookimg img', attr: 'src'),
      latestChapter: RuleField(selector: '.update a', attr: 'text'),
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
        regex: r'<script[^>]*>[\s\S]*?</script>',
      ),
    ),
  ),
];
