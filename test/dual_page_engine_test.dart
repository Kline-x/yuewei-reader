import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuewei_reader/core/database/app_database.dart';
import 'package:yuewei_reader/features/reader/engine/dual_page_composer.dart';
import 'package:yuewei_reader/features/reader/engine/page_models.dart';
import 'package:yuewei_reader/features/reader/engine/reader_chapter_loader.dart';
import 'package:yuewei_reader/features/reader/engine/reader_page_slot.dart';
import 'package:yuewei_reader/features/reader/engine/reader_slide_window.dart';
import 'package:yuewei_reader/features/reader/engine/typography_engine.dart';
import 'package:yuewei_reader/features/reader/presentation/dual_page_painter.dart';

List<String> _buildParas(int count, String tag) => List.generate(
      count,
      (i) => '\u3000\u3000[$tag]第${i + 1}段：群山雾气缭绕，古道石阶蜿蜒向上，少年背着长剑前行，每一步都沉稳坚定。',
    );

Chapter _ch(int idx) => Chapter(
      bookId: 'b_dual', chapterIndex: idx, title: '第${idx + 1}章',
      url: 'u_$idx', isCached: true, cachedBytes: 120,
    );

DualPageGeometry _geom(
  double w, {
  ReaderLayoutMode layout = ReaderLayoutMode.auto,
  PageTurnMode turn = PageTurnMode.cover,
  List<ui.DisplayFeature> features = const [],
}) =>
    DualPageComposer.resolveDualPageGeometry(
      constraints: BoxConstraints.tightFor(width: w, height: 900.0),
      layoutMode: layout, turnMode: turn, displayFeatures: features,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DualPageComposer 几何决议、铰链避让与配对单测', () {
    test('覆盖 auto/single/dual/scroll 与竖向折叠屏铰链避让计算', () {
      final autoNarrow = _geom(679.0);
      expect((autoNarrow.isDualPage, autoNarrow.spineWidth, autoNarrow.columnWidth), (false, 0.0, 679.0));

      final autoWide = _geom(680.0, turn: PageTurnMode.curl);
      expect((autoWide.isDualPage, autoWide.spineWidth, autoWide.columnWidth), (true, 28.0, (680.0 - 28.0) / 2.0));

      expect(_geom(1200.0, layout: ReaderLayoutMode.single).isDualPage, isFalse);
      expect(_geom(520.0, layout: ReaderLayoutMode.dual).isDualPage, isTrue);
      expect(_geom(519.0, layout: ReaderLayoutMode.dual).isDualPage, isFalse);
      expect(_geom(1200.0, layout: ReaderLayoutMode.dual, turn: PageTurnMode.scroll).isDualPage, isFalse);

      // 竖向折叠屏铰链避让：spineWidth = max(28, hingeWidth + 16)
      final hingeGeom = _geom(800.0, features: const [
        ui.DisplayFeature(
          bounds: Rect.fromLTWH(388.0, 0.0, 24.0, 900.0),
          type: ui.DisplayFeatureType.hinge,
          state: ui.DisplayFeatureState.postureHalfOpened,
        ),
      ]);
      expect((hingeGeom.isDualPage, hingeGeom.spineWidth, hingeGeom.columnWidth), (true, 40.0, 380.0));

      // 短铰链（高度 < 0.6 * maxHeight）使用默认 28.0 书脊
      final shortHinge = _geom(800.0, features: const [
        ui.DisplayFeature(
          bounds: Rect.fromLTWH(380.0, 0.0, 40.0, 400.0),
          type: ui.DisplayFeatureType.hinge,
          state: ui.DisplayFeatureState.postureHalfOpened,
        ),
      ]);
      expect(shortHinge.spineWidth, 28.0);
    });

    test('对开页配对与 PageRenderItem.cacheKey 完整维度校验', () {
      const dummyLine = TypedLine(
        text: '测试行', paragraphIndex: 0, charStart: 0, charEnd: 3,
        isFirstLineOfPara: true, isLastLineOfPara: true,
      );
      final pages = List.generate(
        5,
        (i) => TypedPage(pageIndex: i, lines: const [dummyLine], charStart: i * 10, charEnd: (i + 1) * 10),
      );
      final pairs = DualPageComposer.pairPages(pages);
      expect(pairs.length, 3);
      expect((pairs[0].left.pageIndex, pairs[0].right?.pageIndex), (0, 1));
      expect((pairs[2].left.pageIndex, pairs[2].right), (4, null));

      const baseCfg = TypographyConfig(viewportWidth: 386.0, viewportHeight: 800.0);
      PageRenderItem makeItem({TypedPage? right, bool isDual = true, double spine = 28.0, TypographyConfig cfg = baseCfg}) =>
          PageRenderItem(
            chapterIndex: 0, chapterTitle: '第1章', page: pages[0], rightPage: right,
            totalPagesInChapter: 5, bookTitle: '测试书', isDualPage: isDual, spineWidth: spine, config: cfg,
          );

      final k0 = makeItem(right: pages[1]).cacheKey;
      expect(k0, isNot(makeItem(right: null).cacheKey));
      expect(k0, isNot(makeItem(right: pages[2]).cacheKey));
      expect(k0, isNot(makeItem(right: pages[1], isDual: false).cacheKey));
      expect(k0, isNot(makeItem(right: pages[1], spine: 40.0).cacheKey));
      expect(k0, isNot(makeItem(right: pages[1], cfg: const TypographyConfig(viewportWidth: 386.0, viewportHeight: 800.0, fontFamily: 'CustomSerif')).cacheKey));
      expect(k0, isNot(makeItem(right: pages[1], cfg: const TypographyConfig(viewportWidth: 386.0, viewportHeight: 800.0, paragraphGap: 20.0)).cacheKey));
      expect(k0, isNot(makeItem(right: pages[1], cfg: const TypographyConfig(viewportWidth: 386.0, viewportHeight: 800.0, horizontalPadding: 30.0)).cacheKey));
      expect(k0, isNot(makeItem(right: pages[1], cfg: const TypographyConfig(viewportWidth: 386.0, viewportHeight: 800.0, letterSpacing: 1.5)).cacheKey));
      expect(k0, isNot(makeItem(right: pages[1], cfg: const TypographyConfig(viewportWidth: 386.0, viewportHeight: 800.0, indentFirstLine: false)).cacheKey));
    });
  });

  group('ReaderSlideWindow 双页步进、跨章对齐与零漂移重锚定', () {
    test('双页步进 2、奇数尾页、跨章前翻/后翻与 charAnchorOffset 互切零漂移', () {
      const engine = TypographyEngine();
      const dualColCfg = TypographyConfig(fontSize: 18.0, viewportWidth: 360.0, viewportHeight: 540.0);

      var ch0Paras = _buildParas(10, 'C0');
      while (engine.paginate(paragraphs: ch0Paras, chapterTitle: '第1章', config: dualColCfg).length.isOdd ||
          engine.paginate(paragraphs: ch0Paras, chapterTitle: '第1章', config: dualColCfg).length < 4) {
        ch0Paras = _buildParas(ch0Paras.length + 1, 'C0');
      }
      var ch1Paras = _buildParas(10, 'C1');
      while (engine.paginate(paragraphs: ch1Paras, chapterTitle: '第2章', config: dualColCfg).length.isEven ||
          engine.paginate(paragraphs: ch1Paras, chapterTitle: '第2章', config: dualColCfg).length < 3) {
        ch1Paras = _buildParas(ch1Paras.length + 1, 'C1');
      }
      final ch2Paras = _buildParas(8, 'C2');

      final win = ReaderSlideWindow(engine: engine);
      final chapters = [_ch(0), _ch(1), _ch(2)];
      final p0 = win.ensurePaginated(chapterIndex: 0, chapterTitle: '第1章', paragraphs: ch0Paras, config: dualColCfg);
      final p1 = win.ensurePaginated(chapterIndex: 1, chapterTitle: '第2章', paragraphs: ch1Paras, config: dualColCfg);
      win.ensurePaginated(chapterIndex: 2, chapterTitle: '第3章', paragraphs: ch2Paras, config: dualColCfg);
      expect((p0.length.isEven, p1.length.isOdd), (true, true));

      // 传入奇数 pageIndex=1 仍规范化为 0 + 1 对开页，且步进 2
      final ch0Start = win.buildSlots(
        chapterIndex: 0, pageIndex: 1, bookTitle: '双页书', chapters: chapters, isDualPage: true, spineWidth: 28.0,
      );
      expect((ch0Start.current?.page.pageIndex, ch0Start.current?.rightPage?.pageIndex, ch0Start.next?.page.pageIndex), (0, 1, 2));
      final step1 = win.turnNext(chapterIndex: 0, pageIndex: 0, totalChapters: 3, isDualPage: true)!;
      expect((step1.chapterIndex, step1.pageIndex, step1.crossedChapter), (0, 2, false));

      // 第 1 章末奇数尾页（rightPage == null），next 无缝衔接第 2 章 [0, 1]
      final ch1OddTailIdx = p1.length - 1;
      final oddTail = win.buildSlots(
        chapterIndex: 1, pageIndex: ch1OddTailIdx, bookTitle: '双页书', chapters: chapters, isDualPage: true, spineWidth: 28.0,
      );
      expect((oddTail.current?.page.pageIndex, oddTail.current?.rightPage), (ch1OddTailIdx, null));
      expect((oddTail.next?.chapterIndex, oddTail.next?.page.pageIndex, oddTail.next?.rightPage?.pageIndex), (2, 0, 1));

      // 回退跨章：奇章对齐 N-1，偶章对齐 N-2 + N-1
      final backToCh1 = win.turnPrev(chapterIndex: 2, pageIndex: 0, isDualPage: true)!;
      expect((backToCh1.chapterIndex, backToCh1.pageIndex, backToCh1.crossedChapter), (1, p1.length - 1, true));
      final ch2Start = win.buildSlots(chapterIndex: 2, pageIndex: 0, bookTitle: '双页书', chapters: chapters, isDualPage: true);
      expect((ch2Start.prev?.chapterIndex, ch2Start.prev?.page.pageIndex, ch2Start.prev?.rightPage), (1, p1.length - 1, null));

      final backToCh0 = win.turnPrev(chapterIndex: 1, pageIndex: 0, isDualPage: true)!;
      expect((backToCh0.chapterIndex, backToCh0.pageIndex, backToCh0.crossedChapter), (0, p0.length - 2, true));
      final ch1Start = win.buildSlots(chapterIndex: 1, pageIndex: 0, bookTitle: '双页书', chapters: chapters, isDualPage: true);
      expect((ch1Start.prev?.chapterIndex, ch1Start.prev?.page.pageIndex, ch1Start.prev?.rightPage?.pageIndex), (0, p0.length - 2, p0.length - 1));

      // 单双页按 charAnchorOffset 互切零漂移
      const singleCfg = TypographyConfig(fontSize: 18.0, viewportWidth: 748.0, viewportHeight: 540.0);
      final singlePages = engine.paginate(paragraphs: ch0Paras, chapterTitle: '第1章', config: singleCfg);
      final anchorPageIdx = singlePages.length ~/ 2;
      final charAnchor = singlePages[anchorPageIdx].charStart;

      final dualIdx = win.resolveSyncedPageIndex(
        p0, currentPageIndex: 0, charAnchorOffset: charAnchor, needReanchor: true, landOnLastPage: false, isDualPage: true,
      );
      expect(dualIdx.isEven, isTrue);
      final dualSpreadEnd = (dualIdx + 1 < p0.length ? p0[dualIdx + 1] : p0[dualIdx]).charEnd;
      expect(charAnchor, inInclusiveRange(p0[dualIdx].charStart, dualSpreadEnd));

      final restoredSingleIdx = win.resolveSyncedPageIndex(
        singlePages, currentPageIndex: dualIdx, charAnchorOffset: charAnchor, needReanchor: true, landOnLastPage: false, isDualPage: false,
      );
      expect(restoredSingleIdx, anchorPageIdx);

      final winSync = ReaderSlideWindow(engine: engine);
      winSync.ensurePaginated(chapterIndex: 0, chapterTitle: '第1章', paragraphs: ch0Paras, config: dualColCfg);
      expect(
        winSync.syncWindow(
          config: dualColCfg, activeChapterIndex: 0, bookId: 'b_dual',
          chapters: chapters, loader: ReaderChapterLoader(), isDualPage: true,
        ),
        isTrue,
      );
    });
  });

  group('DualPagePainter 离屏绘制与双栏渲染验证', () {
    testWidgets('满栏双页、奇数右空栏与深色模式离屏及画布渲染无越界无异常', (tester) async {
      const colCfg = TypographyConfig(fontSize: 18.0, viewportWidth: 386.0, viewportHeight: 600.0);
      final pages = const TypographyEngine().paginate(
        paragraphs: _buildParas(10, 'PAINT'), chapterTitle: '双页绘制测试', config: colCfg,
      );
      expect(pages.length, greaterThanOrEqualTo(2));

      for (final (right, theme, spine) in [
        (pages[1], ReaderPaperTheme.porcelainWhite, 28.0),
        (null, ReaderPaperTheme.oledInk, 40.0),
      ]) {
        final rec = ui.PictureRecorder();
        DualPagePainter.drawSpread(
          Canvas(rec), const Size(800.0, 600.0),
          leftPage: pages[0], rightPage: right, totalPages: pages.length,
          chapterTitle: '双页绘制测试', bookTitle: '测试书目',
          config: colCfg, theme: theme, spineWidth: spine,
        );
        rec.endRecording().dispose();
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              size: const Size(800.0, 600.0),
              painter: DualPagePainter(
                leftPage: pages[0], rightPage: pages[1], totalPages: pages.length,
                chapterTitle: '双页绘制测试', bookTitle: '测试书目',
                config: colCfg, theme: ReaderPaperTheme.warmParchment, spineWidth: 28.0,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
