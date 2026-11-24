import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuewei_reader/core/database/app_database.dart';
import 'package:yuewei_reader/design_system/tokens/soft_tokens.dart';
import 'package:yuewei_reader/features/book_detail/presentation/book_detail_sections.dart';

Book _makeBook(String intro) {
  return Book(
    id: 'book_test_1',
    title: '斗破苍穹',
    cleanTitle: '斗破苍穹',
    author: '天蚕土豆',
    coverUrl: '',
    intro: intro,
    category: '玄幻',
    statusText: '已完结',
    latestChapterTitle: '第一千六百二十三章 结束，也是开始',
    lastUpdateTime: '2026-01-01',
    sourceId: 'src_test',
    bookUrl: 'https://example.com/book/1',
    tocUrl: 'https://example.com/book/1',
    totalChapters: 1623,
    currentChapterIndex: 0,
    currentChapterTitle: '',
    currentCharOffset: 0,
    hasEverRead: false,
    isPinned: false,
    isInShelf: false,
    hasUnreadUpdate: false,
    updatedAt: DateTime(2026, 1, 1),
  );
}

Widget _wrap360(Widget child) {
  return MaterialApp(
    theme: SoftTokens.resolve(SoftPalette.mistyJade, isDark: false).toThemeData(),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 360.0,
          child: SingleChildScrollView(child: child),
        ),
      ),
    ),
  );
}

BookDetailHeaderSection _buildHeader(
  String intro, {
  required bool introExpanded,
  VoidCallback? onToggleIntro,
}) {
  return BookDetailHeaderSection(
    book: _makeBook(intro),
    chapterCount: 1623,
    sourceName: '测试书源',
    latestChapterTitle: '大结局',
    refreshingMeta: false,
    introExpanded: introExpanded,
    descending: false,
    onToggleShelf: () {},
    onOpenDownload: () {},
    onStartReading: () {},
    onTapLatestChapter: () {},
    onToggleIntro: onToggleIntro ?? () {},
    onLocateCurrent: () {},
    onToggleOrder: () {},
  );
}

void main() {
  group('BookDetailHeaderSection 作品简介真实排版折行判定测试', () {
    testWidgets('3 行以内的中文短简介不显示「展开全文」或「收起」按钮', (tester) async {
      // 360px 宽容器（含 SoftCard 32px 内边距，可用宽度 328px）下控制在 3 行以内的短简介
      const shortIntro =
          '这里是属于斗气的世界，没有花俏艳丽的魔法，有的仅仅是繁衍到巅峰的斗气！少年萧炎曾是家族天才，却一朝跌落谷底，在药老相助下重新踏上巅峰之路。';

      await tester.pumpWidget(
        _wrap360(_buildHeader(shortIntro, introExpanded: false)),
      );
      await tester.pumpAndSettle();

      expect(find.text('展开全文'), findsNothing);
      expect(find.text('收起'), findsNothing);
    });

    testWidgets('超过 3 行的长简介在折叠态显示「展开全文」，展开态切换为「收起」', (tester) async {
      const longIntro =
          '这里是属于斗气的世界，没有花俏艳丽的魔法，有的仅仅是繁衍到巅峰的斗气！'
          '心潮澎湃，无限幻想，迎风挥击千层浪，少年不败热血！'
          '三十年河东，三十年河西，莫欺少年穷！昔日名震乌坦城的修炼天才萧炎，'
          '在经历三年修为莫名倒退的屈辱与未婚妻上门退婚的打击后，于绝境之中唤醒沉睡在黑曜石戒指里的炼药宗师药老，'
          '自此一路炼丹修习异火、闯荡加玛帝国与中州大陆，最终破茧成蝶成就炎帝之名。';

      var expanded = false;
      await tester.pumpWidget(
        _wrap360(
          StatefulBuilder(
            builder: (context, setState) {
              return _buildHeader(
                longIntro,
                introExpanded: expanded,
                onToggleIntro: () => setState(() => expanded = !expanded),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('展开全文'), findsOneWidget);
      expect(find.text('收起'), findsNothing);

      await tester.tap(find.text('展开全文'));
      await tester.pumpAndSettle();

      expect(find.text('收起'), findsOneWidget);
      expect(find.text('展开全文'), findsNothing);
    });
  });
}
