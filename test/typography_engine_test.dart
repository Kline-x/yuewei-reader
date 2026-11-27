import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuewei_reader/features/reader/engine/page_models.dart';
import 'package:yuewei_reader/features/reader/engine/typography_engine.dart';
import 'package:yuewei_reader/features/reader/presentation/page_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const engine = TypographyEngine();

  group('TypographyEngine 出版级防半行与字符锚点测算测试', () {
    final sampleParagraphs = List<String>.generate(
      14,
      (i) => '\u3000\u3000第${i + 1}段：海风吹过灯塔与青瓦屋檐，“注意看前方暗礁！”'
          '老船长抬起手臂指向远处云层（坐标标注 127.4%）。星光闪烁着，潮水一波接着一波涌上石阶。',
    );

    test('分页严防底部切半行且绝无漏字或下标越界', () {
      const config = TypographyConfig(
        fontSize: 19.0,
        lineHeightRatio: 1.72,
        paragraphGap: 13.0,
        viewportWidth: 390.0,
        viewportHeight: 844.0,
        horizontalPadding: 22.0,
        topPadding: 58.0,
        bottomPadding: 44.0,
      );

      final pages = engine.paginate(
        paragraphs: sampleParagraphs,
        chapterTitle: '第一章 夜航惊涛',
        config: config,
      );

      expect(pages.length, greaterThan(1));
      final headingHeight =
          TypographyEngine.measureHeadingHeight('第一章 夜航惊涛', config);

      for (final page in pages) {
        expect(page.lines, isNotEmpty);
        var used = page.showChapterHeading ? headingHeight : 0.0;
        for (var i = 0; i < page.lines.length; i++) {
          final line = page.lines[i];
          // 当前行本身完整渲染不能超过可用内容底边
          expect(
            used + config.lineHeight,
            lessThanOrEqualTo(config.contentHeight + 0.001),
            reason: '第 ${page.pageIndex} 页出现底部切半行溢出',
          );
          used += config.lineHeight +
              (line.isLastLineOfPara ? config.paragraphGap : 0.0);
        }
      }

      // 校验全文字符连续无漏字、无重叠
      final rebuilt = pages.expand((p) => p.lines).map((l) => l.text).join();
      expect(rebuilt, equals(sampleParagraphs.join()));
    });

    test('更改字号重排后字符锚点可精确回落对应段落页码', () {
      const smallConfig = TypographyConfig(
        fontSize: 16.0,
        viewportWidth: 380.0,
        viewportHeight: 760.0,
      );
      const largeConfig = TypographyConfig(
        fontSize: 24.0,
        viewportWidth: 380.0,
        viewportHeight: 760.0,
      );

      final smallPages = engine.paginate(
        paragraphs: sampleParagraphs,
        chapterTitle: '第一章',
        config: smallConfig,
      );
      final largePages = engine.paginate(
        paragraphs: sampleParagraphs,
        chapterTitle: '第一章',
        config: largeConfig,
      );

      expect(largePages.length, greaterThan(smallPages.length));

      final midOffset = smallPages[smallPages.length ~/ 2].charStart;
      final restoredIdx = engine.findPageByCharOffset(largePages, midOffset);
      final targetPage = largePages[restoredIdx];

      expect(midOffset, greaterThanOrEqualTo(targetPage.charStart));
      expect(midOffset, lessThanOrEqualTo(targetPage.charEnd));
    });

    test('避头标点尽量不留在行首（中文逗号/句号前移或带前字换行）', () {
      const config = TypographyConfig(
        fontSize: 18.0,
        viewportWidth: 320.0,
        viewportHeight: 700.0,
      );
      final pages = engine.paginate(
        paragraphs: const [
          '\u3000\u3000今天天气真不错，我们一起去海边看看潮汐的变化吧，听说今晚会有流星雨。',
        ],
        chapterTitle: '测试章节',
        config: config,
      );
      for (final p in pages) {
        for (final line in p.lines) {
          if (line.text.isEmpty) continue;
          expect(
            TypographyEngine.avoidLineStart.contains(line.text[0]),
            isFalse,
            reason: '行首违规出现避头标点: "${line.text}"',
          );
        }
      }
    });

    test('多屏宽扫描下中文混排数字与英文词绝不被劈成两行且原文完整', () {
      const paragraphs = [
        '\u3000\u3000老船长翻开航海日志算了算，这次远航一共约莫796天，航速比原计划快了127.4%，'
            '船上的数字终端运行着基于Flutter重构的Yuewei阅读引擎，水手们都知道遇到暗礁时'
            '“don\'t panic”才是最稳妥的口令。夜幕低垂，潮声阵阵。',
        '\u3000\u3000甲板上的电子仪表闪烁着微光：连续航行一共约莫796天仍旧保持127.4%的稳定冗余，'
            '无论是Flutter底层、e-book格式还是Yuewei排版内核都未曾丢字，老伙计笑着念叨“796天真不算短，'
            'don\'t worry，明早就能靠岸。”',
      ];
      final fullText = paragraphs.join();
      const tokens = ['796', '127.4', 'Flutter', 'Yuewei', "don't", 'e-book'];

      int countToken(String text, String token) {
        var count = 0;
        var index = 0;
        while (true) {
          final found = text.indexOf(token, index);
          if (found < 0) break;
          count++;
          index = found + token.length;
        }
        return count;
      }

      for (var width = 260.0; width <= 410.0; width += 7.0) {
        final config = TypographyConfig(
          fontSize: 19.0,
          viewportWidth: width,
          viewportHeight: 760.0,
        );
        final pages = engine.paginate(
          paragraphs: paragraphs,
          chapterTitle: '混排测试',
          config: config,
        );
        final allLines = pages.expand((p) => p.lines).toList();
        expect(allLines, isNotEmpty);
        expect(
          allLines.map((l) => l.text).join(),
          equals(fullText),
          reason: 'viewportWidth=$width 时拼接文本出现漏字或重叠',
        );

        for (final token in tokens) {
          final expectedCount = countToken(fullText, token);
          final actualLineCount = allLines.fold<int>(
            0,
            (sum, line) => sum + countToken(line.text, token),
          );
          expect(
            actualLineCount,
            equals(expectedCount),
            reason: 'viewportWidth=$width 时 "$token" 被劈断跨行',
          );
        }

        final style = TypographyEngine.bodyStyle(config, Colors.black);
        final tp = TextPainter(textDirection: TextDirection.ltr, maxLines: 1);
        for (final line in allLines) {
          tp.text = TextSpan(text: line.text, style: style);
          tp.layout();
          expect(
            tp.width,
            lessThanOrEqualTo(config.contentWidth + 0.01),
            reason: 'viewportWidth=$width 行超宽: "${line.text}"',
          );
        }
        tp.dispose();
      }
    });

    test('超长无空格28字符以上英文数字串仍能正常折行且不超宽不死循环', () {
      const paragraphs = [
        '\u3000\u3000参考链接：https://example.com/abcdefghij123456，请复制后打开。',
        '\u3000\u3000校验哈希值supercalifragilistic1234567890abcd写入日志完毕。',
      ];
      final fullText = paragraphs.join();

      for (final width in [260.0, 300.0, 360.0]) {
        final config = TypographyConfig(
          fontSize: 19.0,
          viewportWidth: width,
          viewportHeight: 760.0,
        );
        final pages = engine.paginate(
          paragraphs: paragraphs,
          chapterTitle: '超长串测试',
          config: config,
        );
        final allLines = pages.expand((p) => p.lines).toList();
        expect(allLines.length, greaterThan(paragraphs.length));
        expect(allLines.map((l) => l.text).join(), equals(fullText));

        final style = TypographyEngine.bodyStyle(config, Colors.black);
        final tp = TextPainter(textDirection: TextDirection.ltr, maxLines: 1);
        for (final line in allLines) {
          expect(line.text, isNotEmpty);
          tp.text = TextSpan(text: line.text, style: style);
          tp.layout();
          expect(
            tp.width,
            lessThanOrEqualTo(config.contentWidth + 0.01),
            reason: 'viewportWidth=$width 超长串折行后仍超宽: "${line.text}"',
          );
        }
        tp.dispose();
      }
    });

    test('双行超长章标题实测高度与画笔 1:1 对齐，绝不与正文首行叠印或底边溢出', () {
      const config = TypographyConfig(
        fontSize: 20.0,
        lineHeightRatio: 1.72,
        paragraphGap: 13.0,
        viewportWidth: 360.0,
        viewportHeight: 780.0,
        horizontalPadding: 22.0,
        topPadding: 58.0,
        bottomPadding: 44.0,
      );
      const shortTitle = '第一章 启程';
      const longTitle =
          '第一百零八章 陨落的天才少年在乌坦城测验广场上立下三年之约并踏上远行之路';

      final shortH = TypographyEngine.measureHeadingHeight(shortTitle, config);
      final longH = TypographyEngine.measureHeadingHeight(longTitle, config);

      // 实测双行标题实际 TextPainter 高度，确认预留空间严格大于标题实体高度
      final tp = TextPainter(
        text: TextSpan(
          text: longTitle,
          style: TypographyEngine.chapterHeadingStyle(config, Colors.black),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: config.contentWidth);
      final actualTitleHeight = tp.height;
      tp.dispose();

      expect(longH, greaterThan(shortH + 20.0));
      expect(longH, greaterThanOrEqualTo(actualTitleHeight + 19.0));

      final shortPages = engine.paginate(
        paragraphs: sampleParagraphs,
        chapterTitle: shortTitle,
        config: config,
      );
      final longPages = engine.paginate(
        paragraphs: sampleParagraphs,
        chapterTitle: longTitle,
        config: config,
      );
      // 双行标题占用更高首屏空间，首页容纳行数不应多于单行标题，且总高严格不超 contentHeight
      expect(longPages.first.lines.length,
          lessThanOrEqualTo(shortPages.first.lines.length));
      var used = longH;
      for (final line in longPages.first.lines) {
        expect(used + config.lineHeight,
            lessThanOrEqualTo(config.contentHeight + 0.001));
        used += config.lineHeight +
            (line.isLastLineOfPara ? config.paragraphGap : 0.0);
      }

      // 离屏 Canvas 1:1 绘制校验零异常
      final rec = ui.PictureRecorder();
      PagePainter.drawPage(
        Canvas(rec),
        Size(config.viewportWidth, config.viewportHeight),
        page: longPages.first,
        totalPages: longPages.length,
        chapterTitle: longTitle,
        bookTitle: '测试书目',
        config: config,
        theme: ReaderPaperTheme.porcelainWhite,
      );
      rec.endRecording().dispose();
    });

    test('fontFamily 透传、ReaderLayoutMode 解析与关闭首行缩进坐标一致性', () {
      expect(ReaderLayoutMode.fromName('dual'), ReaderLayoutMode.dual);
      expect(ReaderLayoutMode.fromName('bad'), ReaderLayoutMode.auto);

      const base = TypographyConfig(viewportWidth: 360, viewportHeight: 680);
      const custom = TypographyConfig(
        viewportWidth: 360,
        viewportHeight: 680,
        fontFamily: 'YueweiFont_123',
        indentFirstLine: false,
      );
      expect(base == custom, isFalse);
      expect(base.hashCode == custom.hashCode, isFalse);
      expect(TypographyEngine.bodyStyle(custom, Colors.black).fontFamily, 'YueweiFont_123');
      expect(TypographyEngine.chapterHeadingStyle(custom, Colors.black).fontFamily, 'YueweiFont_123');

      final rawParas = List<String>.unmodifiable(sampleParagraphs.take(6).toList());
      final indentPages = engine.paginate(paragraphs: rawParas, chapterTitle: '缩进测试', config: base);
      final noIndentPages = engine.paginate(paragraphs: rawParas, chapterTitle: '缩进测试', config: custom);

      final noIndentLines = noIndentPages.expand((p) => p.lines).toList();
      final p0Lines = noIndentLines.where((l) => l.paragraphIndex == 0).toList();
      final p1Lines = noIndentLines.where((l) => l.paragraphIndex == 1).toList();
      expect(p0Lines.first.text.startsWith('\u3000'), isFalse);
      expect(p0Lines.first.charStart, 2);
      expect(p1Lines.first.charStart, rawParas[0].length + 1 + 2);
      for (final line in noIndentLines) {
        expect(line.charEnd - line.charStart, line.text.length);
      }

      // 开关缩进互切重锚定均精确回落对应段落页码
      final anchor = noIndentPages[noIndentPages.length ~/ 2].charStart;
      final restored = engine.findPageByCharOffset(indentPages, anchor);
      expect(anchor, greaterThanOrEqualTo(indentPages[restored].charStart));
      expect(anchor, lessThanOrEqualTo(indentPages[restored].charEnd));
    });
  });
}
