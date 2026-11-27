import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../design_system/components/soft_bottom_sheet.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';
import '../engine/page_models.dart';
import '../fonts/custom_font_manager.dart';
import 'reader_font_sheet.dart';
import 'reader_settings_provider.dart';
import 'reader_typography_sliders.dart';

/// 阅读器排版设置底部抽屉（字号 + 阅读字体 + 行距 + 精细排版 + 5 模式翻页 + 5 款纸感色板）
class ReaderTypographySheet extends ConsumerWidget {
  const ReaderTypographySheet({super.key});

  static Future<void> show(BuildContext context) {
    return SoftBottomSheet.show(
      context,
      title: '排版与纸感设置',
      headerIcon: Icons.text_fields_rounded,
      maxHeightFactor: 0.78,
      builder: (_) => const ReaderTypographySheet(),
    );
  }

  static String _resolveFontLabel(
    String? fontFamily,
    List<CustomFontEntry> fonts,
  ) {
    if (fontFamily == null || fontFamily.trim().isEmpty) return '系统默认';
    for (final entry in fonts) {
      if (entry.fontFamily == fontFamily) return entry.displayName;
    }
    return '自定义字体';
  }

  void _openFontSheet(BuildContext context) {
    final nav = Navigator.of(context);
    final router = GoRouter.maybeOf(context);
    ReaderFontSheet.show(
      context,
      onWifiTransfer: () {
        if (nav.canPop()) nav.pop();
        router?.push('/import');
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = SoftTokens.of(context);
    final settings = ref.watch(readerSettingsProvider);
    final fonts = ref.watch(customFontManagerProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);
    final fontLabel = _resolveFontLabel(settings.fontFamily, fonts);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        SoftSpacing.xl,
        SoftSpacing.lg,
        SoftSpacing.xl,
        SoftSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 字号调节
          Row(
            children: [
              Text(
                '字号',
                style: SoftTypography.caption
                    .copyWith(color: tokens.textSecondary),
              ),
              const Spacer(),
              IconButton(
                constraints:
                    const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
                onPressed: settings.fontSize > 14.0
                    ? () => notifier.setFontSize(settings.fontSize - 1.0)
                    : null,
                icon: const Icon(Icons.text_decrease_rounded, size: 19.0),
              ),
              Expanded(
                flex: 4,
                child: Slider(
                  key: const Key('typo_font_size_slider'),
                  min: 14.0,
                  max: 30.0,
                  divisions: 16,
                  activeColor: tokens.accent,
                  value: settings.fontSize,
                  onChanged: (v) => notifier.setFontSize(v),
                ),
              ),
              IconButton(
                constraints:
                    const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
                onPressed: settings.fontSize < 30.0
                    ? () => notifier.setFontSize(settings.fontSize + 1.0)
                    : null,
                icon: const Icon(Icons.text_increase_rounded, size: 19.0),
              ),
              SizedBox(
                width: 30.0,
                child: Text(
                  '${settings.fontSize.round()}',
                  textAlign: TextAlign.end,
                  style: SoftTypography.cardTitle
                      .copyWith(color: tokens.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: SoftSpacing.md),

          // 2. 阅读字体入口
          Material(
            key: const Key('typo_font_entry_row'),
            color: tokens.surface,
            borderRadius: BorderRadius.circular(SoftRadius.subCard),
            child: InkWell(
              borderRadius: BorderRadius.circular(SoftRadius.subCard),
              onTap: () => _openFontSheet(context),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48.0),
                padding: const EdgeInsets.symmetric(
                  horizontal: SoftSpacing.md,
                  vertical: 12.0,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(SoftRadius.subCard),
                  border: Border.all(color: tokens.borderSubtle, width: 0.8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.font_download_outlined,
                      size: 18.0,
                      color: tokens.accent,
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      '阅读字体',
                      style: SoftTypography.body.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Text(
                        fontLabel,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SoftTypography.caption.copyWith(
                          color: tokens.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18.0,
                      color: tokens.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: SoftSpacing.lg),

          // 3. 行距密度
          Text(
            '行距密度',
            style: SoftTypography.caption.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: SoftSpacing.sm),
          Row(
            children: LineSpacingPreset.values.asMap().entries.map((entry) {
              final i = entry.key;
              final preset = entry.value;
              final isLast = i == LineSpacingPreset.values.length - 1;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: isLast ? 0.0 : 8.0),
                  child: TypographyChoicePill(
                    label: preset.label,
                    selected: settings.spacingPreset == preset,
                    onTap: () => notifier.setSpacing(preset),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: SoftSpacing.lg),

          // 4. 精细排版滑杆与版式控制
          const ReaderTypographySliders(),
          const SizedBox(height: SoftSpacing.lg),

          // 5. 翻页动效（5 模式：仿真 / 覆盖 / 平移 / 上下 / 无）
          Text(
            '翻页方式',
            style: SoftTypography.caption.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: SoftSpacing.sm),
          Row(
            children: PageTurnMode.values.asMap().entries.map((entry) {
              final i = entry.key;
              final mode = entry.value;
              final isLast = i == PageTurnMode.values.length - 1;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: isLast ? 0.0 : 6.0),
                  child: TypographyChoicePill(
                    label: mode.label,
                    selected: settings.turnMode == mode,
                    onTap: () => notifier.setTurnMode(mode),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: SoftSpacing.lg),

          // 6. 5 款护眼纸张底色
          Text(
            '纸感色板',
            style: SoftTypography.caption.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: SoftSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ReaderPaperTheme.all.map((paper) {
              final selected = settings.paperTheme.id == paper.id;
              return GestureDetector(
                onTap: () => notifier.setPaperTheme(paper),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48.0,
                      height: 48.0,
                      decoration: BoxDecoration(
                        color: paper.background,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              selected ? tokens.accent : tokens.borderSubtle,
                          width: selected ? 2.4 : 1.0,
                        ),
                      ),
                      child: selected
                          ? Icon(
                              Icons.check_rounded,
                              size: 20.0,
                              color: paper.accent,
                            )
                          : null,
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      paper.name,
                      style: SoftTypography.micro.copyWith(
                        color: selected ? tokens.accent : tokens.textSecondary,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
