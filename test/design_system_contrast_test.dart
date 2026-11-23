import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuewei_reader/design_system/tokens/soft_tokens.dart';
import 'package:yuewei_reader/features/reader/engine/page_models.dart';

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
}
