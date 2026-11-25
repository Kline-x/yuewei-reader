import '../domain/book_source_rule.dart';

/// 阅微精选内置扩充书源（第一批：求书网 / 优四小说 / 快眼看书 / 去读书网）
const List<BookSourceRule> builtinExtraSources = [
  BookSourceRule(
    id: 'builtin_qiushu',
    name: '求书网',
    baseUrl: 'http://www.qiushu.info',
    groupName: '精品主力',
    charset: 'utf-8',
    isBuiltin: true,
    search: SearchRuleSpec(
      urlTemplate: 'http://www.qiushu.info/search.php?searchkey={key}&submit=',
      item: '.read_list li',
      title: RuleField(selector: 'dd .t1 a', attr: 'text', regex: r'《|》'),
      author: RuleField(
        selector: 'dd .t2',
        attr: 'text',
        regex: r'^作者[：:]\s*|更新时间.*$',
      ),
      detailUrl: RuleField(selector: 'dd .t1 a', attr: 'href'),
      coverUrl: RuleField(selector: '.pic img', attr: 'src'),
      intro: RuleField(selector: 'dd .t3', attr: 'text'),
      latestChapter: RuleField(selector: 'dd .t4 .tl a', attr: 'text'),
    ),
    detail: DetailRuleSpec(
      title: RuleField(selector: 'meta[property="og:title"]', attr: 'content'),
      author: RuleField(
        selector: 'meta[property="og:novel:author"]',
        attr: 'content',
      ),
      intro: RuleField(selector: '.xiaoshuo .intro p.1', attr: 'text'),
      coverUrl:
          RuleField(selector: 'meta[property="og:image"]', attr: 'content'),
      category: RuleField(
        selector: 'meta[property="og:novel:category"]',
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
      item: '@xpath://div[@class="book_con_list"][2]//li/a',
      title: RuleField(attr: 'text'),
      url: RuleField(attr: 'href'),
    ),
    chapter: ChapterRuleSpec(
      content: RuleField(
        selector: '#content',
        attr: 'html',
        regex:
            r'<script[^>]*>[\s\S]*?</script>|read_di\(\);?|<p>手机阅读[\s\S]*$|<p>为了方便下次阅读[\s\S]*$|为了方便下次阅读[\s\S]*$|\(本章免费\)',
      ),
    ),
  ),
  BookSourceRule(
    id: 'builtin_xyusk',
    name: '优四小说',
    baseUrl: 'http://www.8xiaoshuo.net',
    groupName: '精品主力',
    charset: 'utf-8',
    isBuiltin: true,
    search: SearchRuleSpec(
      urlTemplate: 'http://www.8xiaoshuo.net/search.php?searchkey={key}',
      item: '.bookbox',
      title: RuleField(selector: '.bookname a', attr: 'text'),
      author: RuleField(
        selector: '.author',
        attr: 'text',
        regex: r'^作者[：:]\s*',
      ),
      detailUrl: RuleField(selector: '.bookname a', attr: 'href'),
      coverUrl: RuleField(selector: 'img', attr: 'src'),
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
        regex: r'<script[^>]*>[\s\S]*?</script>|请记住本书首发域名[^\n<]*',
      ),
    ),
  ),
  BookSourceRule(
    id: 'builtin_botaodz',
    name: '快眼看书',
    baseUrl: 'http://www.botaodz.com',
    groupName: '经典备选',
    charset: 'utf-8',
    isBuiltin: true,
    search: SearchRuleSpec(
      urlTemplate:
          'http://www.botaodz.com/modules/article/search.php?searchkey={key}',
      item: '.librarylist li',
      title: RuleField(selector: '.novelname', attr: 'text'),
      author: RuleField(
        selector: '.info span.1',
        attr: 'text',
        regex: r'^作者[：:]\s*',
      ),
      detailUrl: RuleField(selector: 'a.0', attr: 'href'),
      coverUrl: RuleField(selector: 'img', attr: 'src'),
      latestChapter: RuleField(selector: '.last a', attr: 'text'),
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
        regex: r'各位书友要是觉得[\s\S]*$',
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
      item: '.hide a',
      title: RuleField(attr: 'text'),
      url: RuleField(attr: 'href'),
    ),
    chapter: ChapterRuleSpec(
      content: RuleField(
        selector: '#chaptercontent',
        attr: 'html',
        regex: r'<script[^>]*>[\s\S]*?</script>',
      ),
    ),
  ),
  BookSourceRule(
    id: 'builtin_qudushu',
    name: '去读书网',
    baseUrl: 'http://www.qudushu.org',
    groupName: '经典备选',
    charset: 'utf-8',
    isBuiltin: true,
    search: SearchRuleSpec(
      urlTemplate: 'http://www.qudushu.org/modules/article/search.php?q={key}',
      item: '#jieqi_page_contents .c_row',
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
            r'<h1[^>]*>[\s\S]*?</h1>|<div class="tishi">[\s\S]*?</div>|<script[^>]*>[\s\S]*?</script>|\(?去读书\s*www\.qudu(?:shu|wx)\.[a-z]+\)?|read2\(\);?',
      ),
    ),
  ),
];
