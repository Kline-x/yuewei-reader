import 'dart:ui';
import 'package:flutter/material.dart';

/// 四大静谧纸感意境预设
enum SoftPalette {
  mistyJade('苍岚烟雨', '宋瓷天青 · 晨雾宣纸'),
  twilightAmber('暮色暖珀', '焦糖蜜金 · 温润暖绒'),
  violetOrchid('紫陌幽兰', '丁香丝帛 · 文雅书香'),
  auroraInk('极夜星芒', '钛墨深海 · 极简澄澈');

  const SoftPalette(this.label, this.subtitle);
  final String label;
  final String subtitle;

  static SoftPalette fromName(String? raw) {
    return SoftPalette.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => SoftPalette.mistyJade,
    );
  }
}

/// Modern Soft UI v4 语义设计令牌（严格保证 WCAG 对比度）
@immutable
class SoftTokens extends ThemeExtension<SoftTokens> {
  const SoftTokens({
    required this.isDark,
    required this.palette,
    required this.canvas,
    required this.surface,
    required this.card,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.borderSubtle,
    required this.innerHighlight,
    required this.danger,
    required this.onDanger,
    required this.dangerSoft,
    required this.success,
    required this.warning,
    required this.dockBg,
    required this.shadowColor,
    required this.glowPrimary,
    required this.glowSecondary,
    required this.glowTertiary,
  });

  final bool isDark;
  final SoftPalette palette;
  final Color canvas;
  final Color surface;
  final Color card;
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color borderSubtle;
  final Color innerHighlight;
  final Color danger;
  final Color onDanger;
  final Color dangerSoft;
  final Color success;
  final Color warning;
  final Color dockBg;
  final Color shadowColor;
  final Color glowPrimary;
  final Color glowSecondary;
  final Color glowTertiary;

  static SoftTokens of(BuildContext context) {
    final ext = Theme.of(context).extension<SoftTokens>();
    assert(ext != null, 'SoftTokens 未注入 ThemeData.extensions');
    return ext ?? resolve(SoftPalette.mistyJade, isDark: false);
  }

  static SoftTokens resolve(SoftPalette palette, {required bool isDark}) {
    switch (palette) {
      case SoftPalette.mistyJade:
        return isDark ? _mistyJadeDark : _mistyJadeLight;
      case SoftPalette.twilightAmber:
        return isDark ? _twilightAmberDark : _twilightAmberLight;
      case SoftPalette.violetOrchid:
        return isDark ? _violetOrchidDark : _violetOrchidLight;
      case SoftPalette.auroraInk:
        return isDark ? _auroraInkDark : _auroraInkLight;
    }
  }

  static const _mistyJadeLight = SoftTokens(
    isDark: false,
    palette: SoftPalette.mistyJade,
    canvas: Color(0xFFF7FAF8),
    surface: Color(0xFFECF2EE),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFF236B58),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0x17236B58),
    textPrimary: Color(0xFF17211C),
    textSecondary: Color(0xFF54685E),
    textTertiary: Color(0xFF8A9B93),
    borderSubtle: Color(0x1417211C),
    innerHighlight: Color(0xE6FFFFFF),
    danger: Color(0xFFC93B3B),
    onDanger: Color(0xFFFFFFFF),
    dangerSoft: Color(0x19C93B3B),
    success: Color(0xFF1F7A5A),
    warning: Color(0xFFB86B1B),
    dockBg: Color(0xEBFFFFFF),
    shadowColor: Color(0x16121E18),
    glowPrimary: Color(0x47BCEAD5),
    glowSecondary: Color(0x3DFAD7B0),
    glowTertiary: Color(0x3DBBE4F8),
  );

  static const _mistyJadeDark = SoftTokens(
    isDark: true,
    palette: SoftPalette.mistyJade,
    canvas: Color(0xFF0C110E),
    surface: Color(0xFF141C18),
    card: Color(0xFF1B2420),
    accent: Color(0xFF38D9A9),
    onAccent: Color(0xFF062119),
    accentSoft: Color(0x2138D9A9),
    textPrimary: Color(0xFFE4EEE9),
    textSecondary: Color(0xFF93A89D),
    textTertiary: Color(0xFF64796F),
    borderSubtle: Color(0x17FFFFFF),
    innerHighlight: Color(0x14FFFFFF),
    danger: Color(0xFFF87171),
    onDanger: Color(0xFF280808),
    dangerSoft: Color(0x24F87171),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    dockBg: Color(0xEB1B2420),
    shadowColor: Color(0x52000000),
    glowPrimary: Color(0x1C10B981),
    glowSecondary: Color(0x1714B8A6),
    glowTertiary: Color(0x146366F1),
  );

  static const _twilightAmberLight = SoftTokens(
    isDark: false,
    palette: SoftPalette.twilightAmber,
    canvas: Color(0xFFFAF7F2),
    surface: Color(0xFFF2ECE2),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFFA85814),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0x17A85814),
    textPrimary: Color(0xFF241B14),
    textSecondary: Color(0xFF6E5E52),
    textTertiary: Color(0xFF9B8B7E),
    borderSubtle: Color(0x14241B14),
    innerHighlight: Color(0xE6FFFFFF),
    danger: Color(0xFFC93B3B),
    onDanger: Color(0xFFFFFFFF),
    dangerSoft: Color(0x19C93B3B),
    success: Color(0xFF2E7D5B),
    warning: Color(0xFFB86B1B),
    dockBg: Color(0xEBFFFFFF),
    shadowColor: Color(0x1723180F),
    glowPrimary: Color(0x4AFED7AA),
    glowSecondary: Color(0x3AFDE68A),
    glowTertiary: Color(0x33EDE9FE),
  );

  static const _twilightAmberDark = SoftTokens(
    isDark: true,
    palette: SoftPalette.twilightAmber,
    canvas: Color(0xFF120F0C),
    surface: Color(0xFF1C1713),
    card: Color(0xFF251F1A),
    accent: Color(0xFFEAA055),
    onAccent: Color(0xFF221305),
    accentSoft: Color(0x24EAA055),
    textPrimary: Color(0xFFF0E9E2),
    textSecondary: Color(0xFFA8988C),
    textTertiary: Color(0xFF726459),
    borderSubtle: Color(0x17FFFFFF),
    innerHighlight: Color(0x14FFFFFF),
    danger: Color(0xFFF87171),
    onDanger: Color(0xFF280808),
    dangerSoft: Color(0x24F87171),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    dockBg: Color(0xEB251F1A),
    shadowColor: Color(0x52000000),
    glowPrimary: Color(0x1CD97706),
    glowSecondary: Color(0x17B45309),
    glowTertiary: Color(0x14F472B6),
  );

  static const _violetOrchidLight = SoftTokens(
    isDark: false,
    palette: SoftPalette.violetOrchid,
    canvas: Color(0xFFF9F8FC),
    surface: Color(0xFFEFECF6),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFF654F96),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0x17654F96),
    textPrimary: Color(0xFF1D1926),
    textSecondary: Color(0xFF5F5870),
    textTertiary: Color(0xFF938CA3),
    borderSubtle: Color(0x141D1926),
    innerHighlight: Color(0xE6FFFFFF),
    danger: Color(0xFFC93B3B),
    onDanger: Color(0xFFFFFFFF),
    dangerSoft: Color(0x19C93B3B),
    success: Color(0xFF1F7A5A),
    warning: Color(0xFFB86B1B),
    dockBg: Color(0xEBFFFFFF),
    shadowColor: Color(0x161B1528),
    glowPrimary: Color(0x47DDD6FE),
    glowSecondary: Color(0x3ABAE6FD),
    glowTertiary: Color(0x33FECDD3),
  );

  static const _violetOrchidDark = SoftTokens(
    isDark: true,
    palette: SoftPalette.violetOrchid,
    canvas: Color(0xFF100E16),
    surface: Color(0xFF191623),
    card: Color(0xFF221E2E),
    accent: Color(0xFFB197FC),
    onAccent: Color(0xFF180F2E),
    accentSoft: Color(0x24B197FC),
    textPrimary: Color(0xFFEDE9F6),
    textSecondary: Color(0xFFA299B5),
    textTertiary: Color(0xFF6F6682),
    borderSubtle: Color(0x17FFFFFF),
    innerHighlight: Color(0x14FFFFFF),
    danger: Color(0xFFF87171),
    onDanger: Color(0xFF280808),
    dangerSoft: Color(0x24F87171),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    dockBg: Color(0xEB221E2E),
    shadowColor: Color(0x52000000),
    glowPrimary: Color(0x1E8B5CF6),
    glowSecondary: Color(0x176366F1),
    glowTertiary: Color(0x14EC4899),
  );

  static const _auroraInkLight = SoftTokens(
    isDark: false,
    palette: SoftPalette.auroraInk,
    canvas: Color(0xFFF5F8FA),
    surface: Color(0xFFE9EFF4),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFF1D5A8F),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0x171D5A8F),
    textPrimary: Color(0xFF131C24),
    textSecondary: Color(0xFF526270),
    textTertiary: Color(0xFF8B99A6),
    borderSubtle: Color(0x14131C24),
    innerHighlight: Color(0xE6FFFFFF),
    danger: Color(0xFFC93B3B),
    onDanger: Color(0xFFFFFFFF),
    dangerSoft: Color(0x19C93B3B),
    success: Color(0xFF1F7A5A),
    warning: Color(0xFFB86B1B),
    dockBg: Color(0xEBFFFFFF),
    shadowColor: Color(0x160F1924),
    glowPrimary: Color(0x42BAE6FD),
    glowSecondary: Color(0x38C7D2FE),
    glowTertiary: Color(0x33FED7AA),
  );

  static const _auroraInkDark = SoftTokens(
    isDark: true,
    palette: SoftPalette.auroraInk,
    canvas: Color(0xFF0A0D11),
    surface: Color(0xFF121820),
    card: Color(0xFF19212B),
    accent: Color(0xFF5AC8FA),
    onAccent: Color(0xFF061B29),
    accentSoft: Color(0x215AC8FA),
    textPrimary: Color(0xFFE7EDF3),
    textSecondary: Color(0xFF93A3B3),
    textTertiary: Color(0xFF637282),
    borderSubtle: Color(0x17FFFFFF),
    innerHighlight: Color(0x14FFFFFF),
    danger: Color(0xFFF87171),
    onDanger: Color(0xFF280808),
    dangerSoft: Color(0x24F87171),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    dockBg: Color(0xEB19212B),
    shadowColor: Color(0x52000000),
    glowPrimary: Color(0x1C0EA5E9),
    glowSecondary: Color(0x176366F1),
    glowTertiary: Color(0x1410B981),
  );

  @override
  SoftTokens copyWith({bool? isDark, SoftPalette? palette}) {
    return resolve(palette ?? this.palette, isDark: isDark ?? this.isDark);
  }

  @override
  SoftTokens lerp(covariant ThemeExtension<SoftTokens>? other, double t) {
    if (other is! SoftTokens) return this;
    return SoftTokens(
      isDark: t < 0.5 ? isDark : other.isDark,
      palette: t < 0.5 ? palette : other.palette,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      innerHighlight: Color.lerp(innerHighlight, other.innerHighlight, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      dockBg: Color.lerp(dockBg, other.dockBg, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      glowPrimary: Color.lerp(glowPrimary, other.glowPrimary, t)!,
      glowSecondary: Color.lerp(glowSecondary, other.glowSecondary, t)!,
      glowTertiary: Color.lerp(glowTertiary, other.glowTertiary, t)!,
    );
  }

  /// 构建全局 ThemeData，严禁再把底栏垫高强塞进全局 SnackBarThemeData
  ThemeData toThemeData() {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accent,
        onPrimary: onAccent,
        secondary: accent,
        onSecondary: onAccent,
        error: danger,
        onError: onDanger,
        surface: card,
        onSurface: textPrimary,
      ),
      dividerColor: borderSubtle,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[this],
    );
  }

  /// WCAG 相对亮度对比度计算（用于设计系统自动化防线测试）
  static double contrastRatio(Color fg, Color bg) {
    final l1 = fg.computeLuminance();
    final l2 = bg.computeLuminance();
    final hi = l1 > l2 ? l1 : l2;
    final lo = l1 > l2 ? l2 : l1;
    return (hi + 0.05) / (lo + 0.05);
  }

  static double lerpDoubleValue(double a, double b, double t) =>
      lerpDouble(a, b, t) ?? a;
}
