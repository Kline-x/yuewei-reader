import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuewei_reader/core/database/app_database.dart';
import 'package:yuewei_reader/features/reader/engine/content_pipeline.dart';
import 'package:yuewei_reader/features/reader/engine/curl_geometry.dart';
import 'package:yuewei_reader/features/reader/engine/page_models.dart';
import 'package:yuewei_reader/features/reader/engine/reader_chapter_loader.dart';
import 'package:yuewei_reader/features/reader/engine/reader_page_slot.dart';
import 'package:yuewei_reader/features/reader/engine/reader_scroll_layout.dart';
import 'package:yuewei_reader/features/reader/engine/reader_slide_window.dart';
import 'package:yuewei_reader/features/reader/engine/reader_turn_gesture_math.dart';
import 'package:yuewei_reader/features/reader/engine/typography_engine.dart';
import 'package:yuewei_reader/features/reader/presentation/page_picture_cache.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_continuous_scroll_view.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_pager_painter_factory.dart';
import 'package:yuewei_reader/features/reader/presentation/reader_pager_views.dart';
import 'package:yuewei_reader/features/reader/presentation/slide_cover_painter.dart';

PageRenderItem _slot(int ch, int pg, String text, {int charStart = 0, int charEnd = 20}) => PageRenderItem(
      chapterIndex: ch, chapterTitle: '第${ch + 1}章', totalPagesInChapter: 2, bookTitle: '测试书籍',
      page: TypedPage(
        pageIndex: pg, charStart: charStart, charEnd: charEnd,
        lines: [TypedLine(text: text, paragraphIndex: 0, charStart: charStart, charEnd: charEnd, isFirstLineOfPara: true, isLastLineOfPara: true)],
      ),
    );

void main() {
  group('QQ阅读级五模式与 3D 贝塞尔仿真卷页几何单测', () {
    test('PageTurnMode 完整覆盖五种模式且默认仿真', () {
      expect(PageTurnMode.values.map((e) => e.label).toList(), ['仿真', '覆盖', '平移', '上下', '无']);
      expect(PageTurnMode.fromName('unknown_value'), PageTurnMode.curl);
      expect(PageTurnMode.fromName('none'), PageTurnMode.none);
      expect(PageTurnMode.fromName('scroll'), PageTurnMode.scroll);
    });

    test('CurlGeometry 覆盖右下/右上/极左防撕裂/零值等坐标零 NaN 零越界', () {
      const size = Size(390.0, 844.0);
      final br = Offset(size.width, size.height);
      final tr = Offset(size.width, 0.0);
      final cases = <(Offset, Offset, bool)>[
        (const Offset(260, 760), br, false),
        (const Offset(120, 620), br, false),
        (const Offset(-350, 780), br, false),
        (const Offset(220, 140), tr, false),
        (const Offset(200, 844), br, false),
        (const Offset(389.5, 843.5), br, true),
        (const Offset(double.nan, 400), br, true),
      ];
      for (final (touch, corner, expectIdle) in cases) {
        final g = CurlGeometry.compute(size: size, touch: touch, corner: corner);
        expect(g.isIdle, expectIdle);
        if (!g.isIdle) {
          expect(g.effectiveTouch.dx.isFinite && g.effectiveTouch.dy.isFinite, isTrue);
          expect(g.bezierStartX.dx, greaterThanOrEqualTo(-0.01));
          expect(g.nextRevealPath.getBounds().isEmpty, isFalse);
          expect(g.backFoldPath.getBounds().isEmpty, isFalse);
          final m = g.buildMirrorMatrix();
          expect(m.length, 16);
          expect(m.every((v) => v.isFinite), isTrue);
          expect(m[0] * m[5] - m[1] * m[4], closeTo(-1.0, 1e-4));
        }
      }
      expect(CurlGeometry.compute(size: Size.zero, touch: const Offset(10, 10), corner: Offset.zero).isIdle, isTrue);
    });
  });

  group('标点空白清洗、避头孤字防护与手势/进度对齐单测', () {
    test('ContentPipeline 清除中文与标点间空格并保护缩进与英文空格', () {
      expect(ContentPipeline.normalizeInlineSpaces('\u3000\u3000萧炎自嘲的一笑 ， 意兴阑珊的道 。'), '\u3000\u3000萧炎自嘲的一笑，意兴阑珊的道。');
      expect(ContentPipeline.normalizeInlineSpaces('　　极为少数还对自己保持着尊敬的人 。'), '　　极为少数还对自己保持着尊敬的人。');
      expect(ContentPipeline.normalizeInlineSpaces('Hello world  from Flutter'), 'Hello world from Flutter');
      expect(const ContentPipeline().parseCachedText('　　“ 我是这么说的 ” 。\n　　道 。'), ['　　“我是这么说的”。', '　　道。']);
    });

    test('TypographyEngine 多宽度压测杜绝行首避头标点与单标点孤行', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      const engine = TypographyEngine();
      final cleaned = [
        '　　极为少数还对自己依旧保持着尊敬的人。',
        '　　望着面前这颗已经成长为家族中最璀璨的明珠，萧炎苦涩的道，她是在自己落魄后 ， 极为少数还对自己依旧保持着尊敬的人 。',
        '　　站在原地望着少年那恍如与世隔绝的孤独背影，萧薰儿踌躇了一会，然后在身后一干嫉妒的狼嚎声中，快步追了上去，与少年并肩而行。',
      ].map(ContentPipeline.normalizeInlineSpaces).toList();
      for (var w = 180.0; w <= 360.0; w += 4.0) {
        final cfg = TypographyConfig(fontSize: 19.0, lineHeightRatio: 1.75, viewportWidth: w, viewportHeight: 800.0, horizontalPadding: 20.0, topPadding: 54.0, bottomPadding: 44.0);
        for (final p in engine.paginate(paragraphs: cleaned, chapterTitle: '第一章 陨落的天才', config: cfg)) {
          for (final l in p.lines) {
            expect(TypographyEngine.avoidLineStart.contains(l.text.characters.first), isFalse);
            if (l.text.characters.length == 1) {
              expect(TypographyEngine.avoidLineStart.contains(l.text.characters.single), isFalse);
            }
          }
        }
      }
    });

    test('ReaderTurnGestureMath 反向回拖归零、反向快甩取消与 estimateCharRatio 验证', () {
      const size = Size(400, 880);
      expect(ReaderTurnGestureMath.resolveCurlCorner(size, const Offset(300, 180)), const Offset(400, 0));
      expect(ReaderTurnGestureMath.resolveCurlCorner(size, const Offset(300, 620)), const Offset(400, 880));
      // 有向投影：向下一页起手后反向右拖越过起手点，进度归 0 而非反弹
      expect(ReaderTurnGestureMath.computeDirectedProgress(direction: 1, dx: -100, viewportWidth: 400), closeTo(0.25, 1e-6));
      expect(ReaderTurnGestureMath.computeDirectedProgress(direction: 1, dx: 120, viewportWidth: 400), 0.0);
      expect(ReaderTurnGestureMath.computeDirectedProgress(direction: -1, dx: -120, viewportWidth: 400), 0.0);
      // 正常提交与反向快甩取消
      expect(ReaderTurnGestureMath.shouldCommitDrag(direction: 1, progress: 0.2, velocityX: 0), isTrue);
      expect(ReaderTurnGestureMath.shouldCommitDrag(direction: -1, progress: 0.05, velocityX: 400), isTrue);
      expect(ReaderTurnGestureMath.shouldCommitDrag(direction: 1, progress: 0.45, velocityX: 380), isFalse);
      expect(ReaderTurnGestureMath.shouldCommitDrag(direction: -1, progress: 0.45, velocityX: -380), isFalse);
      expect(ReaderTurnGestureMath.computeSettleDurationMs(progress: 0.5, commit: true), inInclusiveRange(150, 310));

      final sampleParas = ['一二三四五六七八九十', '甲乙丙丁戊己庚辛壬癸'];
      expect(ReaderSlideWindow.estimateCharRatio(sampleParas, 0), 0.0);
      expect(ReaderSlideWindow.estimateCharRatio(sampleParas, 11), closeTo(0.5, 0.05));
      expect(ReaderSlideWindow.estimateCharRatio(sampleParas, 999), 1.0);
    });

    test('ReaderScrollLayout 精确测量段落高度、双向换算与 landOnEnd 不越界', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      final paras = [
        '　　第一段：斗之力，三段。望着测验魔石碑上面闪亮得甚至有些刺眼的五个大字，少年面无表情，唇角有着一抹自嘲。',
        '　　第二段：中年男子话刚刚脱口，便是不出意外的在人头汹涌的广场上带起了一阵嘲讽的骚动与喧嚣。',
        '　　第三段：三年前那名声望达到巅峰的天才少年，却在一夜之间跌落到了连普通人都不如的地步。',
        '　　第四段：面对着萧炎的颓废，萧薰儿纤细的眉毛微微皱了皱，认真的安慰起面前的孤独少年。',
      ];
      final block = ChapterBlock(chapterIndex: 0, chapterTitle: '第一章 陨落的天才', paragraphs: paras);
      const cfg = TypographyConfig(fontSize: 19.0, lineHeightRatio: 1.75, viewportWidth: 390.0, viewportHeight: 844.0, horizontalPadding: 20.0, topPadding: 54.0, bottomPadding: 44.0);
      final layout = ReaderScrollLayout.measureChapter(block: block, config: cfg, showDivider: false);
      expect(layout.itemExtents.length, paras.length);
      expect(layout.totalHeight, greaterThan(layout.headerHeight));
      expect(ReaderScrollLayout.offsetForChar(layout, paras, 0), 0.0);

      final midChar = paras[0].length + 1 + (paras[1].length ~/ 2);
      expect((ReaderScrollLayout.charOffsetAtLocalY(layout, paras, ReaderScrollLayout.offsetForChar(layout, paras, midChar)) - midChar).abs(), lessThan(22));
      final endChar = paras.fold<int>(0, (s, p) => s + p.length + 1) - 3;
      expect((ReaderScrollLayout.charOffsetAtLocalY(layout, paras, ReaderScrollLayout.offsetForChar(layout, paras, endChar)) - endChar).abs(), lessThan(22));
      expect(ReaderScrollLayout.displayProgressAtLocalY(layout, 0.0, cfg), greaterThan(0.05));
      expect(ReaderScrollLayout.displayProgressAtLocalY(layout, layout.totalHeight, cfg), 1.0);
      expect(ReaderScrollLayout.computeLandOnEndLocalY(layout, cfg), lessThan(layout.totalHeight));
    });

    test('ReaderSlideWindow 淘汰超窗缓存且 PageRenderItem.cacheKey 随正文内容变化', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      final win = ReaderSlideWindow();
      const cfg = TypographyConfig(fontSize: 18.0, viewportWidth: 360.0, viewportHeight: 680.0);
      final chapters = List.generate(8, (i) => Chapter(bookId: 'b', chapterIndex: i, title: '第${i + 1}章', url: 'u$i', isCached: true, cachedBytes: 10));
      for (var i = 0; i < 6; i++) {
        win.ensurePaginated(chapterIndex: i, chapterTitle: '第${i + 1}章', paragraphs: ['\u3000\u3000第$i章测试正文。'], config: cfg);
      }
      win.syncWindow(config: cfg, activeChapterIndex: 5, bookId: 'b', chapters: chapters, loader: ReaderChapterLoader());
      expect(win.pagesOf(0), isNull);
      expect(win.pagesOf(2), isNull);
      expect(win.pagesOf(3), isNotNull);
      expect(win.pagesOf(5), isNotNull);

      final a = _slot(0, 0, '旧书源第一页正文内容');
      final b = _slot(0, 0, '新书源第一页正文内容');
      expect(a.cacheKey, isNot(equals(b.cacheKey)));
    });
  });

Widget pagerHarness({
  Key? key,
  required double width,
  required double height,
  required PageTurnMode turnMode,
  required PageRenderItem currentItem,
  PageRenderItem? prevItem,
  PageRenderItem? nextItem,
  required TypographyConfig config,
  bool hasPrev = false,
  bool hasNext = false,
  VoidCallback? onNext,
  VoidCallback? onPrev,
  VoidCallback? onMenu,
}) =>
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: height,
          child: ReaderPagerViews(
            key: key, turnMode: turnMode, bookTitle: '手势测试', initialCharOffset: 0,
            currentItem: currentItem, prevItem: prevItem, nextItem: nextItem,
            scrollBlocks: const [], config: config, theme: ReaderPaperTheme.porcelainWhite,
            hasPrevChapter: hasPrev, hasNextChapter: hasNext,
            onCommitNext: onNext ?? () {}, onCommitPrev: onPrev ?? () {},
            onTapCenterMenu: onMenu ?? () {}, onNeedAppendNextChapter: () {},
            onRequestPrevChapter: () {}, onScrollChapterProgress: (_, _) {},
          ),
        ),
      ),
    );

  group('翻页交互手势与连续滚动状态安全回归单测', () {
    testWidgets('未预取邻居章拖拽跨章、反向回拖不翻页、快速连点不捕获过期槽位多提交', (tester) async {
      const cfg = TypographyConfig(fontSize: 18.0, viewportWidth: 400.0, viewportHeight: 700.0);
      final pagerKey = GlobalKey<ReaderPagerViewsState>();
      var nextCommits = 0, prevCommits = 0;

      await tester.pumpWidget(pagerHarness(
        key: pagerKey, width: 400, height: 700, turnMode: PageTurnMode.slide,
        currentItem: _slot(1, 0, '当前页内容'), config: cfg, hasPrev: true, hasNext: true,
        onNext: () => nextCommits++, onPrev: () => prevCommits++,
      ));

      // 1. nextItem == null 且 hasNextChapter == true 时左拖达阈值直接提交跨章
      await tester.dragFrom(const Offset(320, 350), const Offset(-140, 0));
      await tester.pump();
      expect(nextCommits, 1);

      // 2. prevItem == null 且 hasPrevChapter == true 时右拖达阈值直接提交上一章
      await tester.dragFrom(const Offset(80, 350), const Offset(140, 0));
      await tester.pump();
      expect(prevCommits, 1);

      // 3. 左拖起手后反向右拖越过起手点，进度归 0 绝不强行翻页
      final g = await tester.startGesture(const Offset(240, 350));
      await g.moveBy(const Offset(-40, 0));
      await tester.pump();
      await g.moveBy(const Offset(180, 0));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
      expect(nextCommits, 1);

      // 4. 动画期间同步连点两次 turnNextAnimated，第二次仅结算当前动画不以过期槽位多提交
      await tester.pumpWidget(pagerHarness(
        key: pagerKey, width: 400, height: 700, turnMode: PageTurnMode.slide,
        currentItem: _slot(1, 0, '第一页'), nextItem: _slot(1, 1, '第二页'),
        config: cfg, onNext: () => nextCommits++, onPrev: () => prevCommits++,
      ));
      pagerKey.currentState!.turnNextAnimated();
      await tester.pump(const Duration(milliseconds: 40));
      pagerKey.currentState!.turnNextAnimated();
      await tester.pumpAndSettle();
      expect(nextCommits, 2);
    });

    testWidgets('ReaderContinuousScrollView 切章防回写、landOnEnd 落章尾、末页 clamp 与调字号重锚定', (tester) async {
      final longParas = List.generate(28, (i) => '\u3000\u3000第${i + 1}段较长正文内容，用于撑高连续滚动视图并验证跨章切换与字号重排锚定稳定性。');
      final ch0 = ChapterBlock(chapterIndex: 0, chapterTitle: '第一章 序幕', paragraphs: longParas);
      final ch1 = ChapterBlock(chapterIndex: 1, chapterTitle: '第二章 启程', paragraphs: longParas);
      final reports = <(int, int)>[];
      final scrollKey = GlobalKey<ReaderContinuousScrollViewState>();

      Widget buildView({
        required List<ChapterBlock> blocks,
        required int initialOffset,
        required ScrollJumpCommand cmd,
        double fontSize = 18.0,
      }) => MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 380,
                height: 680,
                child: ReaderContinuousScrollView(
                  key: scrollKey,
                  blocks: blocks,
                  bookTitle: '滚动测试书',
                  initialCharOffset: initialOffset,
                  scrollJumpCommand: cmd,
                  config: TypographyConfig(fontSize: fontSize, viewportWidth: 380, viewportHeight: 680),
                  theme: ReaderPaperTheme.porcelainWhite,
                  hasPrevChapter: blocks.first.chapterIndex > 0,
                  hasNextChapter: true,
                  onNeedAppendNextChapter: () {},
                  onRequestPrevChapter: () {},
                  onTapCenterMenu: () {},
                  onScrollChapterProgress: (ch, off) => reports.add((ch, off)),
                ),
              ),
            ),
          );

      // 1. 从末页超大 charOffset 切入 scroll 被 maxScrollExtent clamp 时不把偏小 charOffset 回写
      final totalLen = longParas.fold<int>(0, (s, p) => s + p.length + 1);
      await tester.pumpWidget(buildView(blocks: [ch1], initialOffset: totalLen - 5, cmd: const ScrollJumpCommand(token: 1, chapterIndex: 1)));
      await tester.pumpAndSettle();
      expect(reports, isEmpty);

      // 2. 点击「加载上一章」传 landOnEnd: true 切回第 0 章：应落在第 0 章末尾且绝不反向回写旧章 1
      await tester.pumpWidget(buildView(
        blocks: [ch0, ch1],
        initialOffset: 0,
        cmd: const ScrollJumpCommand(token: 2, chapterIndex: 0, landOnEnd: true),
      ));
      await tester.pumpAndSettle();
      expect(reports.where((e) => e.$1 == 1), isEmpty);
      expect(find.text('第一章 序幕'), findsWidgets);

      // 3. 调大字号触发 configChanged：重锚定过程被抑制上报保护，不产生漂移回写
      final countBeforeResize = reports.length;
      await tester.pumpWidget(buildView(blocks: [ch0, ch1], initialOffset: 0, cmd: const ScrollJumpCommand(token: 2, chapterIndex: 0, landOnEnd: true), fontSize: 24.0));
      await tester.pumpAndSettle();
      expect(reports.length, countBeforeResize);
    });

    testWidgets('双页模式 curl 自动平滑降级 cover 且点击区按总视口宽判定', (tester) async {
      const cfg = TypographyConfig(fontSize: 18.0, viewportWidth: 386.0, viewportHeight: 600.0);
      final dualCur = PageRenderItem(
        chapterIndex: 0, chapterTitle: '第1章', page: _slot(0, 0, '左').page, rightPage: _slot(0, 1, '右').page,
        totalPagesInChapter: 4, bookTitle: '双页', isDualPage: true, spineWidth: 28.0,
      );
      final dualNext = PageRenderItem(
        chapterIndex: 0, chapterTitle: '第1章', page: _slot(0, 2, '下左').page, rightPage: _slot(0, 3, '下右').page,
        totalPagesInChapter: 4, bookTitle: '双页', isDualPage: true, spineWidth: 28.0,
      );
      final picCache = PagePictureCache();
      addTearDown(picCache.clear);
      final painter = ReaderPagerPainterFactory.build(
        turnMode: PageTurnMode.curl, picCache: picCache, currentItem: dualCur, prevItem: null, nextItem: dualNext,
        config: cfg, theme: ReaderPaperTheme.porcelainWhite, size: const Size(800, 600),
        activeDirection: 1, linearProgress: 0.4, curlTouch: Offset.zero, curlCorner: Offset.zero,
      );
      expect((painter as SlideCoverPainter).turnMode, PageTurnMode.cover);

      var menuTapped = 0, nextTapped = 0;
      await tester.pumpWidget(pagerHarness(
        width: 800, height: 600, turnMode: PageTurnMode.curl,
        currentItem: dualCur, nextItem: dualNext, config: cfg,
        onNext: () => nextTapped++, onMenu: () => menuTapped++,
      ));
      await tester.tapAt(const Offset(400, 300));
      await tester.pump();
      expect((menuTapped, nextTapped), (1, 0));
      await tester.tapAt(const Offset(720, 300));
      await tester.pumpAndSettle();
      expect(nextTapped, 1);
    });
  });
}
