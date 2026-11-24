import 'dart:ui';
import 'package:flutter/material.dart';

part 'soft_palettes.dart';

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
