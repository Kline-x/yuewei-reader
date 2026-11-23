import '../domain/book_source_rule.dart';

/// 阅微纯净精选内置书源（全数经真机网络探活 200 OK，详情页含完整简介/更新时间/最新章节规则）
class BuiltinSources {
  static const List<BookSourceRule> all = [
    BookSourceRule(
      id: 'builtin_biquge7',
      name: '笔趣阁7',
      baseUrl: 'https://www.biquge7.xyz',
      groupName: '精品主力',
      charset: 'utf-8',
      isBuiltin: true,
      search: SearchRuleSpec(
        urlTemplate: 'https://www.biquge7.xyz/search?keyword={key}',
        item: '.tui_1_item',
        title: RuleField(selector: '.title a', attr: 'text'),
        author: RuleField(selector: '.author', attr: 'text'),
        detailUrl: RuleField(selector: '.title a', attr: 'href'),
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
        item: '.list ul li a',
        title: RuleField(attr: 'text'),
        url: RuleField(attr: 'href'),
      ),
      chapter: ChapterRuleSpec(
        content: RuleField(selector: '.text', attr: 'html'),
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
    BookSourceRule(
      id: 'builtin_sto66',
      name: '思兔阅读',
      baseUrl: 'https://www.sto66.com',
      groupName: '经典备选',
      charset: 'utf-8',
      isBuiltin: true,
      search: SearchRuleSpec(
        urlTemplate: 'https://www.sto66.com/search/{key}.html',
        item: 'div.bookbox',
        title: RuleField(selector: 'h2 a', attr: 'text'),
        author: RuleField(
          selector: 'div.author',
          attr: 'text',
          regex: r'^作者：',
        ),
        detailUrl: RuleField(selector: 'h2 a', attr: 'href'),
        coverUrl: RuleField(selector: 'img.thumbnail', attr: 'src'),
      ),
      detail: DetailRuleSpec(
        title: RuleField(selector: 'h1.booktitle, h1', attr: 'text'),
        author: RuleField(selector: 'p.booktag a.red', attr: 'text'),
        intro: RuleField(selector: 'p.bookintro', attr: 'text'),
        coverUrl:
            RuleField(selector: '.bookcover img.thumbnail', attr: 'src'),
        category: RuleField(selector: 'p.booktag a.blue', attr: 'text'),
        statusText: RuleField(selector: 'p.booktag span.red', attr: 'text'),
        latestChapter: RuleField(selector: 'a.bookchapter', attr: 'text'),
        lastUpdateTime: RuleField(
          selector: 'p.booktime',
          attr: 'text',
          regex: r'^更新时间[：:]\s*',
        ),
        tocUrl: RuleField(
          selector: '#allchapter dl dd:last-child a',
          attr: 'href',
        ),
      ),
      toc: TocRuleSpec(
        item: '#allchapter a',
        title: RuleField(attr: 'text'),
        url: RuleField(attr: 'href'),
      ),
      chapter: ChapterRuleSpec(
        content: RuleField(selector: '#content.readcontent', attr: 'html'),
      ),
    ),
    BookSourceRule(
      id: 'builtin_kk169',
      name: '穿越小说',
      baseUrl: 'http://www.kk169.net',
      groupName: 'GBK经典',
      charset: 'gbk',
      isBuiltin: true,
      search: SearchRuleSpec(
        urlTemplate: 'http://www.kk169.net/modules/article/search.php?q={key}',
        item: 'div.c_row',
        title: RuleField(selector: '.c_subject a', attr: 'text'),
        author: RuleField(selector: '.c_author a', attr: 'text'),
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
          regex: r'^\s*[^\n]*\(穿越小说\s*www\.kk169\.la\)[^\n]*$',
        ),
      ),
    ),
  ];
}
