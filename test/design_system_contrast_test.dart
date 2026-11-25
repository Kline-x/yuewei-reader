import 'dart:io';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuewei_reader/app/providers.dart';
import 'package:yuewei_reader/core/database/app_database.dart';
import 'package:yuewei_reader/core/network/app_http_client.dart';
import 'package:yuewei_reader/design_system/components/single_swipe_tile.dart';
import 'package:yuewei_reader/design_system/feedback/app_feedback.dart';
import 'package:yuewei_reader/design_system/tokens/soft_tokens.dart';
import 'package:yuewei_reader/features/reader/engine/page_models.dart';
import 'package:yuewei_reader/features/sources/data/source_repository.dart';
import 'package:yuewei_reader/features/sources/presentation/sources_page.dart';

void main() {
  group('Modern Soft UI v4 对比度与设计防线测试', () {
    test('四大意境 × 深浅八套色盘均达到 WCAG AA (>= 4.5:1) 对比度标准', () {
      for (final palette in SoftPalette.values) {
        for (final isDark in [false, true]) {
          final tokens = SoftTokens.resolve(palette, isDark: isDark);
          final modeLabel = isDark ? 'dark' : 'light';

          expect(
            SoftTokens.contrastRatio(tokens.textPrimary, tokens.card),
            greaterThanOrEqualTo(4.5),
            reason: '${palette.name}($modeLabel) textPrimary vs card 对比度不足',
          );
          expect(
            SoftTokens.contrastRatio(tokens.textPrimary, tokens.canvas),
            greaterThanOrEqualTo(4.5),
            reason: '${palette.name}($modeLabel) textPrimary vs canvas 对比度不足',
          );
          expect(
            SoftTokens.contrastRatio(tokens.onAccent, tokens.accent),
            greaterThanOrEqualTo(4.5),
            reason: '${palette.name}($modeLabel) onAccent vs accent 对比度不足',
          );
          expect(
            SoftTokens.contrastRatio(tokens.onDanger, tokens.danger),
            greaterThanOrEqualTo(4.5),
            reason: '${palette.name}($modeLabel) onDanger vs danger 对比度不足',
          );
          expect(
            SoftTokens.contrastRatio(tokens.textSecondary, tokens.card),
            greaterThanOrEqualTo(3.5),
            reason: '${palette.name}($modeLabel) textSecondary 可读性不足',
          );
        }
      }
    });

    test('阅读器五套纸感护眼主题对比度达标', () {
      for (final paper in ReaderPaperTheme.all) {
        expect(
          SoftTokens.contrastRatio(paper.textColor, paper.background),
          greaterThanOrEqualTo(4.5),
          reason: '${paper.name} 正文对比度未达标',
        );
        expect(
          SoftTokens.contrastRatio(paper.secondaryText, paper.menuBg),
          greaterThanOrEqualTo(3.0),
          reason: '${paper.name} 次要信息与菜单背景对比度偏低',
        );
      }
    });

    test('全局源码绝不含刺眼微信绿 #07C160 或历史废名称硬编码', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final text = entity.readAsStringSync();
        expect(
          text.toUpperCase().contains('07C160'),
          isFalse,
          reason: '${entity.path} 不允许使用旧版 #07C160',
        );
        expect(
          text.contains('藏书阁'),
          isFalse,
          reason: '${entity.path} 不应出现已废弃的旧应用名',
        );
      }
    });
  });

  group('AppFeedback 撤销条自动关闭与手动收起生命周期测试', () {
    Future<BuildContext> pumpHost(WidgetTester tester) async {
      late BuildContext hostContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: SoftTokens.resolve(SoftPalette.mistyJade, isDark: false)
              .toThemeData(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                hostContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return hostContext;
    }

    testWidgets('带撤销按钮的 SnackBar 到时自动收起并触发 onCommitted', (tester) async {
      final ctx = await pumpHost(tester);
      var undone = false;
      var committed = false;

      AppFeedback.showUndoSnackBar(
        ctx,
        message: '已移出书架',
        onUndo: () => undone = true,
        onCommitted: () => committed = true,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('已移出书架'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.text('已移出书架'), findsNothing);
      expect(undone, isFalse);
      expect(committed, isTrue);
    });

    testWidgets('点击撤销触发 onUndo 且不触发 onCommitted；dismissSnackBar 立即收起并提交', (
      tester,
    ) async {
      final ctx = await pumpHost(tester);
      var undone1 = false;
      var committed1 = false;
      AppFeedback.showUndoSnackBar(
        ctx,
        message: '已移出第一本',
        onUndo: () => undone1 = true,
        onCommitted: () => committed1 = true,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('撤销'));
      await tester.pumpAndSettle();
      expect(undone1, isTrue);
      expect(committed1, isFalse);

      var undone2 = false;
      var committed2 = false;
      AppFeedback.showUndoSnackBar(
        ctx,
        message: '已移出第二本',
        onUndo: () => undone2 = true,
        onCommitted: () => committed2 = true,
      );
      await tester.pumpAndSettle();
      expect(find.text('已移出第二本'), findsOneWidget);

      AppFeedback.dismissSnackBar(ctx);
      await tester.pumpAndSettle();
      expect(find.text('已移出第二本'), findsNothing);
      expect(undone2, isFalse);
      expect(committed2, isTrue);
    });

    testWidgets('SingleSwipeTile 切 Tab 离屏 TickerMode 冻结时瞬间归零无残影', (tester) async {
      final coordinator = SwipeCoordinator();
      addTearDown(coordinator.dispose);
      var tickerEnabled = true;
      late StateSetter outerSetState;

      await tester.pumpWidget(
        MaterialApp(
          theme: SoftTokens.resolve(SoftPalette.mistyJade, isDark: false).toThemeData(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                outerSetState = setState;
                return TickerMode(
                  enabled: tickerEnabled,
                  child: SingleSwipeTile(
                    itemId: 'book_1',
                    coordinator: coordinator,
                    actionLabel: '移出书架',
                    actionIcon: Icons.delete_outline,
                    onAction: () {},
                    child: const SizedBox(height: 72.0, width: 320.0, child: Text('测试书籍卡片')),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // 模拟左滑展开操作按钮
      await tester.drag(find.text('测试书籍卡片'), const Offset(-84.0, 0.0));
      await tester.pumpAndSettle();
      expect(find.text('移出书架'), findsOneWidget);

      // 模拟切换 Tab：先触发 closeAll() 动画同时离屏 TickerMode 置 false
      outerSetState(() {
        coordinator.closeAll();
        tickerEnabled = false;
      });
      await tester.pump();
      expect(find.text('移出书架'), findsNothing);

      // 切回 Tab 恢复 TickerMode，必须保持彻底收起无动画残影
      outerSetState(() => tickerEnabled = true);
      await tester.pump();
      expect(find.text('移出书架'), findsNothing);
    });

    testWidgets('SourcesPage 删除当前选中自定义分组最后一条后自动回落「全部」', (tester) async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.runAsync(() async {
        final repo = SourceRepository(db: db, httpClient: AppHttpClient());
        await repo.ensureBuiltinSourcesSeeded();
        await repo.importLegadoJson(
          '[{"bookSourceName":"仅此一条","bookSourceUrl":"https://only.example.com","bookSourceGroup":"独木组","searchUrl":"/s?q={{key}}","ruleSearch":{"bookList":".b","name":"h3","bookUrl":"a@href"},"ruleToc":{"chapterList":".c a","chapterName":"text","chapterUrl":"href"},"ruleContent":{"content":"#c"}}]',
        );
      });

      await tester.pumpWidget(ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: SoftTokens.resolve(SoftPalette.mistyJade, isDark: false).toThemeData(),
          home: const SourcesPage(),
        ),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('独木组 (1)'));
      await tester.pumpAndSettle();
      expect(find.text('仅此一条'), findsOneWidget);

      await tester.tap(find.byTooltip('删除此书源'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      expect(find.text('该分组暂无书源'), findsNothing);
      expect(find.text('独木组 (1)'), findsNothing);
      expect(find.text('影书笔趣阁'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
