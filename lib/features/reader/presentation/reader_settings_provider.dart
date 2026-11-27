import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../engine/page_models.dart';

@immutable
class ReaderSettingsState {
  const ReaderSettingsState({
    this.fontSize = 19.0,
    this.spacingPreset = LineSpacingPreset.comfort,
    this.turnMode = PageTurnMode.curl,
    this.paperTheme = ReaderPaperTheme.porcelainWhite,
    this.followSystemTheme = false,
    this.volumeKeyPaging = true,
    this.keepScreenOn = true,
    this.fontFamily,
    this.paragraphGap = 13.0,
    this.horizontalPadding = 22.0,
    this.letterSpacing = 0.35,
    this.indentFirstLine = true,
    this.layoutMode = ReaderLayoutMode.auto,
  });

  static const Object _unset = Object();

  final double fontSize;
  final LineSpacingPreset spacingPreset;
  final PageTurnMode turnMode;
  final ReaderPaperTheme paperTheme;
  final bool followSystemTheme;
  final bool volumeKeyPaging;
  final bool keepScreenOn;
  final String? fontFamily;
  final double paragraphGap;
  final double horizontalPadding;
  final double letterSpacing;
  final bool indentFirstLine;
  final ReaderLayoutMode layoutMode;

  ReaderSettingsState copyWith({
    double? fontSize,
    LineSpacingPreset? spacingPreset,
    PageTurnMode? turnMode,
    ReaderPaperTheme? paperTheme,
    bool? followSystemTheme,
    bool? volumeKeyPaging,
    bool? keepScreenOn,
    Object? fontFamily = _unset,
    double? paragraphGap,
    double? horizontalPadding,
    double? letterSpacing,
    bool? indentFirstLine,
    ReaderLayoutMode? layoutMode,
  }) {
    return ReaderSettingsState(
      fontSize: fontSize ?? this.fontSize,
      spacingPreset: spacingPreset ?? this.spacingPreset,
      turnMode: turnMode ?? this.turnMode,
      paperTheme: paperTheme ?? this.paperTheme,
      followSystemTheme: followSystemTheme ?? this.followSystemTheme,
      volumeKeyPaging: volumeKeyPaging ?? this.volumeKeyPaging,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      fontFamily: identical(fontFamily, _unset)
          ? this.fontFamily
          : fontFamily as String?,
      paragraphGap: paragraphGap ?? this.paragraphGap,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      indentFirstLine: indentFirstLine ?? this.indentFirstLine,
      layoutMode: layoutMode ?? this.layoutMode,
    );
  }

  /// 解析当前实际应渲染的纸张配色（独立于全局主题或按开关跟随系统）
  ReaderPaperTheme effectiveTheme(Brightness systemBrightness) {
    if (!followSystemTheme) return paperTheme;
    if (systemBrightness == Brightness.dark) {
      return paperTheme.isDark ? paperTheme : ReaderPaperTheme.slateNight;
    }
    return paperTheme.isDark ? ReaderPaperTheme.porcelainWhite : paperTheme;
  }
}

class ReaderSettingsNotifier extends Notifier<ReaderSettingsState> {
  static const _kFontSize = 'reader_font_size';
  static const _kSpacing = 'reader_line_spacing';
  static const _kTurnMode = 'reader_turn_mode';
  static const _kPaperId = 'reader_paper_theme';
  static const _kFollowSys = 'reader_follow_system';
  static const _kVolKey = 'reader_volume_key';
  static const _kKeepScreen = 'reader_keep_screen_on';
  static const _kFontFamily = 'reader_font_family';
  static const _kParagraphGap = 'reader_paragraph_gap';
  static const _kHorizontalPadding = 'reader_horizontal_padding';
  static const _kLetterSpacing = 'reader_letter_spacing';
  static const _kIndentFirstLine = 'reader_indent_first_line';
  static const _kLayoutMode = 'reader_layout_mode';

  int _mutationGen = 0;
  bool _disposed = false;

  @override
  ReaderSettingsState build() {
    _disposed = false;
    _mutationGen = 0;
    ref.onDispose(() => _disposed = true);
    _load();
    return const ReaderSettingsState();
  }

  Future<void> _load() async {
    final gen = _mutationGen;
    final db = ref.read(appDatabaseProvider);
    final fs = double.tryParse((await db.getPreference(_kFontSize)) ?? '');
    final sp = LineSpacingPreset.fromName(await db.getPreference(_kSpacing));
    final tm = PageTurnMode.fromName(await db.getPreference(_kTurnMode));
    final pt = ReaderPaperTheme.fromId(await db.getPreference(_kPaperId));
    final fSys = (await db.getPreference(_kFollowSys)) == 'true';
    final vol = (await db.getPreference(_kVolKey)) != 'false';
    final keep = (await db.getPreference(_kKeepScreen)) != 'false';
    final rawFont = await db.getPreference(_kFontFamily);
    final font =
        (rawFont == null || rawFont.trim().isEmpty) ? null : rawFont.trim();
    final gap = double.tryParse((await db.getPreference(_kParagraphGap)) ?? '');
    final pad =
        double.tryParse((await db.getPreference(_kHorizontalPadding)) ?? '');
    final ls = double.tryParse((await db.getPreference(_kLetterSpacing)) ?? '');
    final indent = (await db.getPreference(_kIndentFirstLine)) != 'false';
    final layout =
        ReaderLayoutMode.fromName(await db.getPreference(_kLayoutMode));
    if (_disposed || gen != _mutationGen) return;

    state = ReaderSettingsState(
      fontSize: (fs ?? 19.0).clamp(14.0, 30.0),
      spacingPreset: sp,
      turnMode: tm,
      paperTheme: pt,
      followSystemTheme: fSys,
      volumeKeyPaging: vol,
      keepScreenOn: keep,
      fontFamily: font,
      paragraphGap: (gap ?? 13.0).clamp(8.0, 28.0),
      horizontalPadding: (pad ?? 22.0).clamp(12.0, 40.0),
      letterSpacing: (ls ?? 0.35).clamp(0.0, 2.0),
      indentFirstLine: indent,
      layoutMode: layout,
    );
  }

  Future<void> setFontSize(double size) async {
    _mutationGen++;
    final clamped = size.clamp(14.0, 30.0);
    state = state.copyWith(fontSize: clamped);
    await ref.read(appDatabaseProvider).setPreference(_kFontSize, '$clamped');
  }

  Future<void> setSpacing(LineSpacingPreset preset) async {
    _mutationGen++;
    state = state.copyWith(spacingPreset: preset);
    await ref
        .read(appDatabaseProvider)
        .setPreference(_kSpacing, preset.name);
  }

  Future<void> setTurnMode(PageTurnMode mode) async {
    _mutationGen++;
    state = state.copyWith(turnMode: mode);
    await ref.read(appDatabaseProvider).setPreference(_kTurnMode, mode.name);
  }

  Future<void> setPaperTheme(ReaderPaperTheme theme) async {
    _mutationGen++;
    state = state.copyWith(paperTheme: theme, followSystemTheme: false);
    final db = ref.read(appDatabaseProvider);
    await db.setPreference(_kPaperId, theme.id);
    await db.setPreference(_kFollowSys, 'false');
  }

  /// 阅读器内快捷切换日间 / 夜间（按当前实际渲染态 effectiveTheme 取反，绝不篡改全局主题）
  Future<void> toggleDarkQuick({required Brightness systemBrightness}) async {
    final isCurrentlyDark = state.effectiveTheme(systemBrightness).isDark;
    final target = isCurrentlyDark
        ? ReaderPaperTheme.porcelainWhite
        : ReaderPaperTheme.slateNight;
    await setPaperTheme(target);
  }

  Future<void> setFollowSystem(bool follow) async {
    _mutationGen++;
    state = state.copyWith(followSystemTheme: follow);
    await ref.read(appDatabaseProvider).setPreference(_kFollowSys, '$follow');
  }

  Future<void> setVolumeKeyPaging(bool enabled) async {
    _mutationGen++;
    state = state.copyWith(volumeKeyPaging: enabled);
    await ref.read(appDatabaseProvider).setPreference(_kVolKey, '$enabled');
  }

  Future<void> setKeepScreenOn(bool enabled) async {
    _mutationGen++;
    state = state.copyWith(keepScreenOn: enabled);
    await ref
        .read(appDatabaseProvider)
        .setPreference(_kKeepScreen, '$enabled');
  }

  /// 设置阅读字体族（传 null 或空串持久化为 ''，表示系统默认字体）
  Future<void> setFontFamily(String? family) async {
    _mutationGen++;
    final normalized =
        (family == null || family.trim().isEmpty) ? null : family.trim();
    state = state.copyWith(fontFamily: normalized);
    await ref
        .read(appDatabaseProvider)
        .setPreference(_kFontFamily, normalized ?? '');
  }

  Future<void> setParagraphGap(double gap) async {
    _mutationGen++;
    final clamped = gap.clamp(8.0, 28.0);
    state = state.copyWith(paragraphGap: clamped);
    await ref
        .read(appDatabaseProvider)
        .setPreference(_kParagraphGap, '$clamped');
  }

  Future<void> setHorizontalPadding(double padding) async {
    _mutationGen++;
    final clamped = padding.clamp(12.0, 40.0);
    state = state.copyWith(horizontalPadding: clamped);
    await ref
        .read(appDatabaseProvider)
        .setPreference(_kHorizontalPadding, '$clamped');
  }

  Future<void> setLetterSpacing(double spacing) async {
    _mutationGen++;
    final clamped = spacing.clamp(0.0, 2.0);
    state = state.copyWith(letterSpacing: clamped);
    await ref
        .read(appDatabaseProvider)
        .setPreference(_kLetterSpacing, '$clamped');
  }

  Future<void> setIndentFirstLine(bool indent) async {
    _mutationGen++;
    state = state.copyWith(indentFirstLine: indent);
    await ref
        .read(appDatabaseProvider)
        .setPreference(_kIndentFirstLine, '$indent');
  }

  Future<void> setLayoutMode(ReaderLayoutMode mode) async {
    _mutationGen++;
    state = state.copyWith(layoutMode: mode);
    await ref.read(appDatabaseProvider).setPreference(_kLayoutMode, mode.name);
  }

  /// 恢复全部排版默认参数（保留纸感配色、翻页动效与按键/常亮偏好）
  Future<void> resetTypographyDefaults() async {
    _mutationGen++;
    state = state.copyWith(
      fontSize: 19.0,
      spacingPreset: LineSpacingPreset.comfort,
      fontFamily: null,
      paragraphGap: 13.0,
      horizontalPadding: 22.0,
      letterSpacing: 0.35,
      indentFirstLine: true,
      layoutMode: ReaderLayoutMode.auto,
    );
    final db = ref.read(appDatabaseProvider);
    await Future.wait([
      db.setPreference(_kFontSize, '19.0'),
      db.setPreference(_kSpacing, LineSpacingPreset.comfort.name),
      db.setPreference(_kFontFamily, ''),
      db.setPreference(_kParagraphGap, '13.0'),
      db.setPreference(_kHorizontalPadding, '22.0'),
      db.setPreference(_kLetterSpacing, '0.35'),
      db.setPreference(_kIndentFirstLine, 'true'),
      db.setPreference(_kLayoutMode, ReaderLayoutMode.auto.name),
    ]);
  }
}

final readerSettingsProvider =
    NotifierProvider<ReaderSettingsNotifier, ReaderSettingsState>(
  ReaderSettingsNotifier.new,
);
