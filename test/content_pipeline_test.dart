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
