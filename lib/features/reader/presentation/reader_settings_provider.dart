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
  });

  final double fontSize;
  final LineSpacingPreset spacingPreset;
  final PageTurnMode turnMode;
  final ReaderPaperTheme paperTheme;
  final bool followSystemTheme;
  final bool volumeKeyPaging;
  final bool keepScreenOn;

  ReaderSettingsState copyWith({
    double? fontSize,
    LineSpacingPreset? spacingPreset,
    PageTurnMode? turnMode,
    ReaderPaperTheme? paperTheme,
    bool? followSystemTheme,
    bool? volumeKeyPaging,
    bool? keepScreenOn,
  }) {
    return ReaderSettingsState(
      fontSize: fontSize ?? this.fontSize,
      spacingPreset: spacingPreset ?? this.spacingPreset,
      turnMode: turnMode ?? this.turnMode,
      paperTheme: paperTheme ?? this.paperTheme,
      followSystemTheme: followSystemTheme ?? this.followSystemTheme,
      volumeKeyPaging: volumeKeyPaging ?? this.volumeKeyPaging,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
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

  @override
  ReaderSettingsState build() {
    _load();
    return const ReaderSettingsState();
  }

  Future<void> _load() async {
    final db = ref.read(appDatabaseProvider);
    final fs = double.tryParse((await db.getPreference(_kFontSize)) ?? '');
    final sp = LineSpacingPreset.fromName(await db.getPreference(_kSpacing));
    final tm = PageTurnMode.fromName(await db.getPreference(_kTurnMode));
    final pt = ReaderPaperTheme.fromId(await db.getPreference(_kPaperId));
    final fSys = (await db.getPreference(_kFollowSys)) == 'true';
    final vol = (await db.getPreference(_kVolKey)) != 'false';
    final keep = (await db.getPreference(_kKeepScreen)) != 'false';

    state = ReaderSettingsState(
      fontSize: (fs ?? 19.0).clamp(14.0, 30.0),
      spacingPreset: sp,
      turnMode: tm,
      paperTheme: pt,
      followSystemTheme: fSys,
      volumeKeyPaging: vol,
      keepScreenOn: keep,
    );
  }

  Future<void> setFontSize(double size) async {
    final clamped = size.clamp(14.0, 30.0);
    state = state.copyWith(fontSize: clamped);
    await ref.read(appDatabaseProvider).setPreference(_kFontSize, '$clamped');
  }

  Future<void> setSpacing(LineSpacingPreset preset) async {
    state = state.copyWith(spacingPreset: preset);
    await ref
        .read(appDatabaseProvider)
        .setPreference(_kSpacing, preset.name);
  }

  Future<void> setTurnMode(PageTurnMode mode) async {
    state = state.copyWith(turnMode: mode);
    await ref.read(appDatabaseProvider).setPreference(_kTurnMode, mode.name);
  }

  Future<void> setPaperTheme(ReaderPaperTheme theme) async {
    state = state.copyWith(paperTheme: theme, followSystemTheme: false);
    final db = ref.read(appDatabaseProvider);
    await db.setPreference(_kPaperId, theme.id);
    await db.setPreference(_kFollowSys, 'false');
  }

  /// 阅读器内快捷切换日间 / 夜间（绝不篡改外部全局主题设置！）
  Future<void> toggleDarkQuick() async {
    final target = state.paperTheme.isDark
        ? ReaderPaperTheme.porcelainWhite
        : ReaderPaperTheme.slateNight;
    await setPaperTheme(target);
  }

  Future<void> setFollowSystem(bool follow) async {
    state = state.copyWith(followSystemTheme: follow);
    await ref.read(appDatabaseProvider).setPreference(_kFollowSys, '$follow');
  }

  Future<void> setVolumeKeyPaging(bool enabled) async {
    state = state.copyWith(volumeKeyPaging: enabled);
    await ref.read(appDatabaseProvider).setPreference(_kVolKey, '$enabled');
  }

  Future<void> setKeepScreenOn(bool enabled) async {
    state = state.copyWith(keepScreenOn: enabled);
    await ref
        .read(appDatabaseProvider)
        .setPreference(_kKeepScreen, '$enabled');
  }
}

final readerSettingsProvider =
    NotifierProvider<ReaderSettingsNotifier, ReaderSettingsState>(
  ReaderSettingsNotifier.new,
);
