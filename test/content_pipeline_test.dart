import 'package:flutter_test/flutter_test.dart';
import 'package:yuewei_reader/features/reader/engine/content_pipeline.dart';

void main() {
  const pipeline = ContentPipeline();

  group('ContentPipeline 单向净化管道测试', () {
    test('还原 HTML 块级与换行标记，移除首行重复章节标题并剥离纯广告行', () {
      const rawHtml = '''
        <p>第一章 初入晨雾</p>
        <p>天才一秒记住本站地址：www.example-novel.com</p>
        <p>清晨的海雾漫过码头，空气中带着咸湿气息。</p>
        <p>“你看清前面亮灯的地方了吗？”“看清了，似乎是一座旧钟楼。”</p>
        <p>求收藏！求推荐票！本章未完，请点击下一页继续阅读</p>
      ''';

      final paragraphs = pipeline.processHtmlToParagraphs(
        rawHtml,
        chapterTitle: '第一章：初入晨雾',
      );

      expect(paragraphs.length, 3);
      expect(paragraphs[0], '\u3000\u3000清晨的海雾漫过码头，空气中带着咸湿气息。');
      expect(paragraphs[1], '\u3000\u3000“你看清前面亮灯的地方了吗？”');
      expect(paragraphs[2], '\u3000\u3000“看清了，似乎是一座旧钟楼。”');
    });

    test('绝不误伤包含网站/数字词或章名片段的正常对白正文', () {
      const rawHtml = '''
        <p>第二章 归途</p>
        <p>他缓缓说道：“我们总要踏上归途，哪怕山路泥泞。”</p>
        <p>桌上的笔记本记录着凌晨一点零五分的风速。</p>
      ''';

      final paragraphs = pipeline.processHtmlToParagraphs(
        rawHtml,
        chapterTitle: '第二章 归途',
      );

      expect(paragraphs.length, 2);
      expect(paragraphs[0], contains('踏上归途'));
      expect(paragraphs[1], contains('凌晨一点零五分'));
    });

    test('彻底剥离跨行与大小写混合的 script / style / noscript 整块源码', () {
      const rawHtml = '''
        <STYLE type="text/css">
          .ad-banner { display: none; color: #ff0000; }
        </STYLE>
        <p>夜幕低垂，旧港口亮起零星渔火。</p>
        <SCRIPT language="javascript">
          var adToken = "leak_js_code";
          function injectPopup() { return true; }
        </SCRIPT>
        <noscript>请启用 JavaScript 查看广告</noscript>
        <p>他合上手记，缓步走上石阶。</p>
      ''';

      final paragraphs = pipeline.processHtmlToParagraphs(rawHtml);

      expect(paragraphs.length, 2);
      expect(paragraphs[0], '\u3000\u3000夜幕低垂，旧港口亮起零星渔火。');
      expect(paragraphs[1], '\u3000\u3000他合上手记，缓步走上石阶。');
      final joined = paragraphs.join('\n');
      expect(joined, isNot(contains('ad-banner')));
      expect(joined, isNot(contains('leak_js_code')));
      expect(joined, isNot(contains('injectPopup')));
      expect(joined, isNot(contains('JavaScript')));
    });

    test('HTML 实体解码先解命名与数字实体再解 &amp;，并放行 &#10;/&#13; 换行实体', () {
      const rawHtml =
          '<p>转义符号：&amp;lt;tag&amp;gt; 与 &amp;#65;，以及 A &amp; B</p>'
          '<p>第一行&#10;第二行&#13;&#10;第三行&#x0A;第四行 &ldquo;引语&rdquo;&mdash;&hellip;</p>';

      final paragraphs = pipeline.processHtmlToParagraphs(rawHtml);

      expect(paragraphs.length, 5);
      expect(paragraphs[0], '\u3000\u3000转义符号：&lt;tag&gt; 与 &#65;，以及 A & B');
      expect(paragraphs[1], '\u3000\u3000第一行');
      expect(paragraphs[2], '\u3000\u3000第二行');
      expect(paragraphs[3], '\u3000\u3000第三行');
      expect(paragraphs[4], '\u3000\u3000第四行 “引语”—…');
    });

    test('冷缓存序列化与反序列化严格可逆，且不再重复缩进', () {
      final origin = [
        '\u3000\u3000第一段正文。',
        '\u3000\u3000第二段正文。',
      ];
      final serialized = pipeline.serializeParagraphs(origin);
      final restored = pipeline.parseCachedText(serialized);
      expect(restored, equals(origin));
    });
  });
}
