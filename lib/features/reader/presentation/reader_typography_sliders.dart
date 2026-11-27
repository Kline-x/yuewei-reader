import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/components/soft_button.dart';
import '../../../design_system/components/soft_switch.dart';
import '../../../design_system/feedback/app_feedback.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';
import '../engine/page_models.dart';
import 'reader_settings_provider.dart';

/// 排版与字体抽屉复用的圆角胶囊选择项
class TypographyChoicePill extends StatelessWidget {
  const TypographyChoicePill({
    super.key,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

/// 精细排版控制区（段距 / 页边距 / 字距 / 首行缩进 / 版式模式 / 重置默认排版）
class ReaderTypographySliders extends ConsumerWidget {
  const ReaderTypographySliders({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = SoftTokens.of(context);
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '精细排版',
          style: SoftTypography.caption.copyWith(color: tokens.textSecondary),
        ),
        const SizedBox(height: SoftSpacing.sm),
        Container(
          padding: const EdgeInsets.fromLTRB(
            SoftSpacing.md,
            SoftSpacing.sm,
            SoftSpacing.md,
            SoftSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(SoftRadius.subCard),
            border: Border.all(color: tokens.borderSubtle, width: 0.8),
          ),
          child: Column(
            children: [
              _FineSliderRow(
                sliderKey: const Key('typo_paragraph_gap_slider'),
                label: '段距',
                valueText: '${settings.paragraphGap.round()} px',
                value: settings.paragraphGap,
                min: 8.0,
                max: 28.0,
                divisions: 20,
                onChanged: notifier.setParagraphGap,
              ),
              _FineSliderRow(
                sliderKey: const Key('typo_horizontal_padding_slider'),
                label: '页边距',
                valueText: '${settings.horizontalPadding.round()} px',
                value: settings.horizontalPadding,
                min: 12.0,
                max: 40.0,
                divisions: 28,
                onChanged: notifier.setHorizontalPadding,
              ),
              _FineSliderRow(
                sliderKey: const Key('typo_letter_spacing_slider'),
                label: '字距',
                valueText: '${settings.letterSpacing.toStringAsFixed(2)} px',
                value: settings.letterSpacing,
                min: 0.0,
                max: 2.0,
                divisions: 40,
                onChanged: notifier.setLetterSpacing,
              ),
              Divider(height: 12.0, thickness: 0.8, color: tokens.borderSubtle),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '首行 2 字缩进',
                          style: SoftTypography.body.copyWith(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '段落开头自动空两格',
                          style: SoftTypography.micro
                              .copyWith(color: tokens.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  SoftSwitch(
                    key: const Key('typo_indent_switch'),
                    value: settings.indentFirstLine,
                    semanticLabel: '首行 2 字缩进',
                    onChanged: notifier.setIndentFirstLine,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: SoftSpacing.lg),
        Text(
          '阅读版式',
          style: SoftTypography.caption.copyWith(color: tokens.textSecondary),
        ),
        const SizedBox(height: SoftSpacing.sm),
        Row(
          children: ReaderLayoutMode.values.asMap().entries.map((entry) {
            final i = entry.key;
            final mode = entry.value;
            final isLast = i == ReaderLayoutMode.values.length - 1;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: isLast ? 0.0 : 8.0),
                child: TypographyChoicePill(
                  label: mode.label,
                  selected: settings.layoutMode == mode,
                  onTap: () => notifier.setLayoutMode(mode),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: SoftSpacing.md),
        SoftButton(
          key: const Key('typo_reset_button'),
          label: '重置默认排版',
          icon: Icons.restart_alt_rounded,
          tone: SoftButtonTone.tonal,
          compact: true,
          expand: true,
          onPressed: () async {
            await notifier.resetTypographyDefaults();
            if (context.mounted) {
              AppFeedback.showToast(context, '已恢复默认排版设置');
            }
          },
        ),
      ],
    );
  }
}

class _FineSliderRow extends StatelessWidget {
  const _FineSliderRow({
    required this.sliderKey,
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final Key sliderKey;
  final String label;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    return Row(
      children: [
        SizedBox(
          width: 48.0,
          child: Text(
            label,
            style: SoftTypography.caption.copyWith(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
            ),
            child: Slider(
              key: sliderKey,
              min: min,
              max: max,
              divisions: divisions,
              activeColor: tokens.accent,
              inactiveColor: tokens.borderSubtle,
              value: value.clamp(min, max),
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 54.0,
          child: Text(
            valueText,
            textAlign: TextAlign.end,
            style: SoftTypography.micro.copyWith(
              color: tokens.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
