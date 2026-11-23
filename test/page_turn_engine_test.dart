import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuewei_reader/features/reader/engine/content_pipeline.dart';
import 'package:yuewei_reader/features/reader/engine/curl_geometry.dart';
import 'package:yuewei_reader/features/reader/engine/page_models.dart';
import 'package:yuewei_reader/features/reader/engine/reader_page_slot.dart';
import 'package:yuewei_reader/features/reader/engine/reader_scroll_layout.dart';
import 'package:yuewei_reader/features/reader/engine/reader_slide_window.dart';
import 'package:yuewei_reader/features/reader/engine/reader_turn_gesture_math.dart';
import 'package:yuewei_reader/features/reader/engine/typography_engine.dart';

void main() {
  group('QQ阅读级五模式与 3D 贝塞尔仿真卷页几何单测', () {
    test('PageTurnMode 完整覆盖五种模式且默认仿真', () {
      expect(
        PageTurnMode.values.map((e) => e.label).toList(),
        ['仿真', '覆盖', '平移', '上下', '无'],
      );
      expect(PageTurnMode.fromName('unknown_value'), PageTurnMode.curl);
      expect(PageTurnMode.fromName('none'), PageTurnMode.none);
      expect(PageTurnMode.fromName('scroll'), PageTurnMode.scroll);
    });

    test('CurlGeometry 覆盖右下/右上/极左防撕裂/零值等坐标零 NaN 零越界', () {
      const size = Size(390.0, 844.0);
      final bottomRight = Offset(size.width, size.height);
      final topRight = Offset(size.width, 0.0);

      final testCases = <(Offset touch, Offset corner, bool expectIdle)>[
        (const Offset(260, 760), bottomRight, false),
        (const Offset(120, 620), bottomRight, false),
        (const Offset(-350, 780), bottomRight, false),
        (const Offset(220, 140), topRight, false),
        (const Offset(200, 844), bottomRight, false),
        (const Offset(389.5, 843.5), bottomRight, true),
        (const Offset(double.nan, 400), bottomRight, true),
      ];

      for (final (touch, corner, expectIdle) in testCases) {
        final g = CurlGeometry.compute(
          size: size,
          touch: touch,
          corner: corner,
        );
        expect(g.isIdle, expectIdle, reason: 'touch=$touch corner=$corner');
        if (!g.isIdle) {
          expect(g.effectiveTouch.dx.isFinite, isTrue);
          expect(g.effectiveTouch.dy.isFinite, isTrue);
          expect(g.bezierStartX.dx, greaterThanOrEqualTo(-0.01));
          expect(g.nextRevealPath.getBounds().isEmpty, isFalse);
          expect(g.backFoldPath.getBounds().isEmpty, isFalse);

          final matrix = g.buildMirrorMatrix();
          expect(matrix.length, 16);
          for (final v in matrix) {
            expect(v.isFinite, isTrue);
          }
          final det = matrix[0] * matrix[5] - matrix[1] * matrix[4];
          expect(det, closeTo(-1.0, 1e-4));
        }
      }

      final zeroGeom = CurlGeometry.compute(
        size: Size.zero,
        touch: const Offset(10, 10),
        corner: Offset.zero,
      );
      expect(zeroGeom.isIdle, isTrue);
    });
  });

  group('标点空白清洗、避头孤字防护与手势/进度对齐单测', () {
    test('ContentPipeline 清除中文与标点间空格并保护缩进与英文空格', () {
      const dirty = '\u3000\u3000萧炎自嘲的一笑 ， 意兴阑珊的道 。';
      expect(
        ContentPipeline.normalizeInlineSpaces(dirty),
        '\u3000\u3000萧炎自嘲的一笑，意兴阑珊的道。',
      );
      expect(
        ContentPipeline.normalizeInlineSpaces('　　极为少数还对自己保持着尊敬的人 。'),
        '　　极为少数还对自己保持着尊敬的人。',
      );
      expect(
        ContentPipeline.normalizeInlineSpaces('Hello world  from Flutter'),
        'Hello world from Flutter',
      );

      const pipeline = ContentPipeline();
      final cached = pipeline.parseCachedText(
        '　　“ 我是这么说的 ” 。\n　　道 。',
      );
      expect(cached, ['　　“我是这么说的”。', '　　道。']);
    });

    test('TypographyEngine 多宽度压测杜绝行首避头标点与单标点孤行', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      const engine = TypographyEngine();
      final paras = [
        '　　极为少数还对自己依旧保持着尊敬的人。',
        '　　望着面前这颗已经成长为家族中最璀璨的明珠，萧炎苦涩的道，她是在自己落魄后 ， 极为少数还对自己依旧保持着尊敬的人 。',
        '　　站在原地望着少年那恍如与世隔绝的孤独背影，萧薰儿踌躇了一会，然后在身后一干嫉妒的狼嚎声中，快步追了上去，与少年并肩而行。',
      ];
      final cleaned = paras.map(ContentPipeline.normalizeInlineSpaces).toList();

      for (var w = 180.0; w <= 360.0; w += 4.0) {
        final cfg = TypographyConfig(
          fontSize: 19.0,
          lineHeightRatio: 1.75,
          viewportWidth: w,
          viewportHeight: 800.0,
          horizontalPadding: 20.0,
          topPadding: 54.0,
          bottomPadding: 44.0,
        );
        final pages = engine.paginate(
          paragraphs: cleaned,
          chapterTitle: '第一章 陨落的天才',
          config: cfg,
        );
        for (final p in pages) {
          for (final l in p.lines) {
            final firstChar = l.text.characters.first;
            expect(
              TypographyEngine.avoidLineStart.contains(firstChar),
              isFalse,
              reason: 'width=$w 出现行首避头标点: "${l.text}"',
            );
            if (l.text.characters.length == 1) {
              expect(
                TypographyEngine.avoidLineStart.contains(l.text.characters.single),
                isFalse,
                reason: 'width=$w 出现单标点孤行: "${l.text}"',
              );
            }
          }
        }
      }
    });

    test('ReaderTurnGestureMath 与 ReaderSlideWindow.estimateCharRatio 精准运行', () {
      const size = Size(400, 880);
      expect(
        ReaderTurnGestureMath.resolveCurlCorner(size, const Offset(300, 180)),
        const Offset(400, 0),
      );
      expect(
        ReaderTurnGestureMath.resolveCurlCorner(size, const Offset(300, 620)),
        const Offset(400, 880),
      );
      expect(
        ReaderTurnGestureMath.shouldCommitDrag(
          direction: 1,
          progress: 0.2,
          velocityX: 0,
        ),
        isTrue,
      );
      expect(
        ReaderTurnGestureMath.shouldCommitDrag(
          direction: -1,
          progress: 0.05,
          velocityX: 400,
        ),
        isTrue,
      );
      expect(
        ReaderTurnGestureMath.computeSettleDurationMs(
          progress: 0.5,
          commit: true,
        ),
        inInclusiveRange(150, 310),
      );

      final sampleParas = ['一二三四五六七八九十', '甲乙丙丁戊己庚辛壬癸'];
      expect(ReaderSlideWindow.estimateCharRatio(sampleParas, 0), 0.0);
      expect(
        ReaderSlideWindow.estimateCharRatio(sampleParas, 11),
        closeTo(0.5, 0.05),
      );
      expect(ReaderSlideWindow.estimateCharRatio(sampleParas, 999), 1.0);
    });

    test('ReaderScrollLayout 精确测量段落高度与字符偏移双向换算一致', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      final paras = [
        '　　第一段：斗之力，三段。望着测验魔石碑上面闪亮得甚至有些刺眼的五个大字，少年面无表情，唇角有着一抹自嘲。',
        '　　第二段：中年男子话刚刚脱口，便是不出意外的在人头汹涌的广场上带起了一阵嘲讽的骚动与喧嚣。',
        '　　第三段：三年前那名声望达到巅峰的天才少年，却在一夜之间跌落到了连普通人都不如的地步。',
        '　　第四段：面对着萧炎的颓废，萧薰儿纤细的眉毛微微皱了皱，认真的安慰起面前的孤独少年。',
      ];
      final block = ChapterBlock(
        chapterIndex: 0,
        chapterTitle: '第一章 陨落的天才',
        paragraphs: paras,
      );
      const cfg = TypographyConfig(
        fontSize: 19.0,
        lineHeightRatio: 1.75,
        viewportWidth: 390.0,
        viewportHeight: 844.0,
        horizontalPadding: 20.0,
        topPadding: 54.0,
        bottomPadding: 44.0,
      );
      final layout = ReaderScrollLayout.measureChapter(
        block: block,
        config: cfg,
        showDivider: false,
      );
      expect(layout.itemExtents.length, paras.length);
      expect(layout.totalHeight, greaterThan(layout.headerHeight));
      expect(ReaderScrollLayout.offsetForChar(layout, paras, 0), 0.0);

      final midChar = paras[0].length + 1 + (paras[1].length ~/ 2);
      final midY = ReaderScrollLayout.offsetForChar(layout, paras, midChar);
      final backChar =
          ReaderScrollLayout.charOffsetAtLocalY(layout, paras, midY);
      expect((backChar - midChar).abs(), lessThan(22));

      final endChar = paras.fold<int>(0, (s, p) => s + p.length + 1) - 3;
      final endY = ReaderScrollLayout.offsetForChar(layout, paras, endChar);
      final backEnd =
          ReaderScrollLayout.charOffsetAtLocalY(layout, paras, endY);
      expect((backEnd - endChar).abs(), lessThan(22));

      final pStart =
          ReaderScrollLayout.displayProgressAtLocalY(layout, 0.0, cfg);
      final pEnd = ReaderScrollLayout.displayProgressAtLocalY(
        layout,
        layout.totalHeight,
        cfg,
      );
      expect(pStart, greaterThan(0.05));
      expect(pEnd, 1.0);
    });
  });
}
