import 'package:flutter/material.dart';

enum PageTurnMode {
  curl('仿真'),
  cover('覆盖'),
  slide('平移'),
  scroll('上下'),
  none('无');

  const PageTurnMode(this.label);
  final String label;

  static PageTurnMode fromName(String? raw) {
    return PageTurnMode.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => PageTurnMode.curl,
    );
  }
}

enum LineSpacingPreset {
  compact('紧凑', 1.48),
  comfort('舒适', 1.72),
  loose('宽松', 1.98);

  const LineSpacingPreset(this.label, this.ratio);
  final String label;
  final double ratio;

  static LineSpacingPreset fromName(String? raw) {
    return LineSpacingPreset.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => LineSpacingPreset.comfort,
    );
  }
}

/// 阅读器版式模式（自适应宽度 / 强制单页 / 强制双页）
enum ReaderLayoutMode {
  auto('自动'),
  single('单页'),
  dual('双页');

  const ReaderLayoutMode(this.label);
  final String label;

  static ReaderLayoutMode fromName(String? raw) {
    return ReaderLayoutMode.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => ReaderLayoutMode.auto,
    );
  }
}

/// 5 款经严格 WCAG 校验的护眼纸感阅读色板
@immutable
class ReaderPaperTheme {
  const ReaderPaperTheme({
    required this.id,
    required this.name,
    required this.isDark,
    required this.background,
    required this.textColor,
    required this.secondaryText,
    required this.accent,
    required this.menuBg,
  });

  final String id;
  final String name;
  final bool isDark;
  final Color background;
  final Color textColor;
  final Color secondaryText;
  final Color accent;
  final Color menuBg;

  static const porcelainWhite = ReaderPaperTheme(
    id: 'porcelainWhite',
    name: '宣纸白',
    isDark: false,
    background: Color(0xFFFBFBF9),
    textColor: Color(0xFF1F2421),
    secondaryText: Color(0xFF717D76),
    accent: Color(0xFF236B58),
    menuBg: Color(0xFFF3F6F4),
  );

  static const warmParchment = ReaderPaperTheme(
    id: 'warmParchment',
    name: '羊皮纸',
    isDark: false,
    background: Color(0xFFF4ECD8),
    textColor: Color(0xFF33291E),
    secondaryText: Color(0xFF7D6E5C),
    accent: Color(0xFFA85814),
    menuBg: Color(0xFFECE2CA),
  );

  static const mistyGreen = ReaderPaperTheme(
    id: 'mistyGreen',
    name: '护眼青',
    isDark: false,
    background: Color(0xFFE5F0E7),
    textColor: Color(0xFF1A2920),
    secondaryText: Color(0xFF5D7366),
    accent: Color(0xFF236B58),
    menuBg: Color(0xFFDCEAE0),
  );

  static const slateNight = ReaderPaperTheme(
    id: 'slateNight',
    name: '深空蓝',
    isDark: true,
    background: Color(0xFF141B24),
    textColor: Color(0xFFD5DFEB),
    secondaryText: Color(0xFF7A8B9E),
    accent: Color(0xFF5AC8FA),
    menuBg: Color(0xFF1D2633),
  );

  static const oledInk = ReaderPaperTheme(
    id: 'oledInk',
    name: '极夜黑',
    isDark: true,
    background: Color(0xFF0A0C0B),
    textColor: Color(0xFFC2CCC7),
    secondaryText: Color(0xFF6B7771),
    accent: Color(0xFF38D9A9),
    menuBg: Color(0xFF151917),
  );

  static const List<ReaderPaperTheme> all = [
    porcelainWhite,
    warmParchment,
    mistyGreen,
    slateNight,
    oledInk,
  ];

  static ReaderPaperTheme fromId(String? id) {
    return all.firstWhere(
      (t) => t.id == id,
      orElse: () => porcelainWhite,
    );
  }
}

@immutable
class TypographyConfig {
  const TypographyConfig({
    this.fontSize = 19.0,
    this.lineHeightRatio = 1.72,
    this.paragraphGap = 13.0,
    this.letterSpacing = 0.35,
    required this.viewportWidth,
    required this.viewportHeight,
    this.horizontalPadding = 22.0,
    this.topPadding = 52.0,
    this.bottomPadding = 38.0,
    this.fontFamily,
    this.indentFirstLine = true,
  });

  final double fontSize;
  final double lineHeightRatio;
  final double paragraphGap;
  final double letterSpacing;
  final double viewportWidth;
  final double viewportHeight;
  final double horizontalPadding;
  final double topPadding;
  final double bottomPadding;
  final String? fontFamily;
  final bool indentFirstLine;

  double get lineHeight => fontSize * lineHeightRatio;
  double get contentWidth =>
      (viewportWidth - horizontalPadding * 2).clamp(120.0, 2000.0);
  double get contentHeight =>
      (viewportHeight - topPadding - bottomPadding).clamp(120.0, 4000.0);

  @override
  bool operator ==(Object other) {
    return other is TypographyConfig &&
        other.fontSize == fontSize &&
        other.lineHeightRatio == lineHeightRatio &&
        other.paragraphGap == paragraphGap &&
        other.letterSpacing == letterSpacing &&
        other.viewportWidth == viewportWidth &&
        other.viewportHeight == viewportHeight &&
        other.horizontalPadding == horizontalPadding &&
        other.topPadding == topPadding &&
        other.bottomPadding == bottomPadding &&
        other.fontFamily == fontFamily &&
        other.indentFirstLine == indentFirstLine;
  }

  @override
  int get hashCode => Object.hash(
        fontSize,
        lineHeightRatio,
        paragraphGap,
        letterSpacing,
        viewportWidth,
        viewportHeight,
        horizontalPadding,
        topPadding,
        bottomPadding,
        fontFamily,
        indentFirstLine,
      );
}

@immutable
class TypedLine {
  const TypedLine({
    required this.text,
    required this.paragraphIndex,
    required this.charStart,
    required this.charEnd,
    required this.isFirstLineOfPara,
    required this.isLastLineOfPara,
  });

  final String text;
  final int paragraphIndex;
  final int charStart;
  final int charEnd;
  final bool isFirstLineOfPara;
  final bool isLastLineOfPara;
}

@immutable
class TypedPage {
  const TypedPage({
    required this.pageIndex,
    required this.lines,
    required this.charStart,
    required this.charEnd,
    this.showChapterHeading = false,
  });

  final int pageIndex;
  final List<TypedLine> lines;
  final int charStart;
  final int charEnd;
  final bool showChapterHeading;
}
