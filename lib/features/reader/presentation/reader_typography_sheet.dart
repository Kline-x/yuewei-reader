import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/components/soft_bottom_sheet.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';
import '../engine/page_models.dart';
import 'reader_settings_provider.dart';

/// 阅读器排版设置底部抽屉（字号滑轨 + 行距 + 4种翻页 + 带中文名的5款纸张底色）
class ReaderTypographySheet extends ConsumerWidget {
  const ReaderTypographySheet({super.key});

  static Future<void> show(BuildContext context) {
    return SoftBottomSheet.show(
      context,
      title: '排版与纸感设置',
      headerIcon: Icons.text_fields_rounded,
      maxHeightFactor: 0.72,
      builder: (_) => const ReaderTypographySheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = SoftTokens.of(context);
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);

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

          // 2. 行距调节
          Text(
            '行距密度',
            style: SoftTypography.caption.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: SoftSpacing.sm),
          Row(
            children: LineSpacingPreset.values.map((preset) {
              final selected = settings.spacingPreset == preset;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: _ChoicePill(
                    label: preset.label,
                    selected: selected,
                    onTap: () => notifier.setSpacing(preset),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: SoftSpacing.lg),

          // 3. 翻页动效（仿 QQ 阅读 5 模式：仿真 / 覆盖 / 平移 / 上下 / 无）
          Text(
            '翻页方式',
            style: SoftTypography.caption.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: SoftSpacing.sm),
          Row(
            children: PageTurnMode.values.asMap().entries.map((entry) {
              final i = entry.key;
              final mode = entry.value;
              final selected = settings.turnMode == mode;
              final isLast = i == PageTurnMode.values.length - 1;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: isLast ? 0.0 : 6.0),
                  child: _ChoicePill(
                    label: mode.label,
                    selected: selected,
                    onTap: () => notifier.setTurnMode(mode),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: SoftSpacing.lg),

          // 4. 带明确中文名标签的 5 款护眼纸张底色
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

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    return Material(
      color: selected ? tokens.accent : tokens.surface,
      borderRadius: BorderRadius.circular(SoftRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(SoftRadius.pill),
        onTap: onTap,
        child: Container(
          height: 40.0,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SoftRadius.pill),
            border: Border.all(
              color: selected ? tokens.accent : tokens.borderSubtle,
              width: 0.8,
            ),
          ),
          child: Text(
            label,
            style: SoftTypography.caption.copyWith(
              color: selected ? tokens.onAccent : tokens.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
