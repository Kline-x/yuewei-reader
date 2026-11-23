import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';
import '../../../design_system/components/soft_card.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';

/// 设置页双卡片实时阅读统计看板
class SettingsRealtimeStatsRow extends StatelessWidget {
  const SettingsRealtimeStatsRow({super.key, required this.db});

  final AppDatabase db;

  static String formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '尚未计时';
    if (totalSeconds < 60) return '$totalSeconds 秒';
    final totalMin = totalSeconds ~/ 60;
    if (totalMin < 60) return '$totalMin 分钟';
    final hours = totalMin ~/ 60;
    final remMin = totalMin % 60;
    return remMin == 0 ? '$hours 小时' : '$hours 小时 $remMin 分钟';
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    return Row(
      children: [
        Expanded(
          child: StreamBuilder<int>(
            stream: db.watchTotalReadingSeconds(),
            builder: (_, snap) {
              final secs = snap.data ?? 0;
              return SoftCard(
                padding: const EdgeInsets.all(SoftSpacing.md),
                radius: SoftRadius.subCard,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.hourglass_bottom_rounded,
                            size: 14.0, color: tokens.accent),
                        const SizedBox(width: 5.0),
                        Text(
                          '累计阅读',
                          style: SoftTypography.micro
                              .copyWith(color: tokens.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      formatDuration(secs),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SoftTypography.sectionTitle
                          .copyWith(color: tokens.textPrimary, fontSize: 16.5),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(width: SoftSpacing.md),
        Expanded(
          child: StreamBuilder<int>(
            stream: db.watchTotalCachedBytes(),
            builder: (_, snap) {
              final bytes = snap.data ?? 0;
              return SoftCard(
                padding: const EdgeInsets.all(SoftSpacing.md),
                radius: SoftRadius.subCard,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.folder_zip_outlined,
                            size: 14.0, color: tokens.accent),
                        const SizedBox(width: 5.0),
                        Text(
                          '离线缓存',
                          style: SoftTypography.micro
                              .copyWith(color: tokens.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      formatBytes(bytes),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SoftTypography.sectionTitle
                          .copyWith(color: tokens.textPrimary, fontSize: 16.5),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 三段式明暗主题切换卡
class SettingsThemeModeCard extends StatelessWidget {
  const SettingsThemeModeCard({
    super.key,
    required this.currentMode,
    required this.onSelect,
  });

  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    const options = <(ThemeMode, String, IconData)>[
      (ThemeMode.system, '跟随系统', Icons.brightness_auto_rounded),
      (ThemeMode.light, '浅色纸感', Icons.wb_sunny_outlined),
      (ThemeMode.dark, '深色墨夜', Icons.nightlight_outlined),
    ];

    return SoftCard(
      padding: const EdgeInsets.all(SoftSpacing.sm),
      radius: SoftRadius.subCard,
      child: Row(
        children: options.map((opt) {
          final selected = currentMode == opt.$1;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(SoftRadius.control),
              onTap: () => onSelect(opt.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                decoration: BoxDecoration(
                  color: selected ? tokens.accentSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(SoftRadius.control),
                ),
                child: Column(
                  children: [
                    Icon(
                      opt.$3,
                      size: 18.0,
                      color: selected ? tokens.accent : tokens.textSecondary,
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      opt.$2,
                      style: SoftTypography.micro.copyWith(
                        color: selected ? tokens.accent : tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// 四大纸感意境 2×2 选择网格（选中态加强副标题对比度）
class SettingsPaletteGrid extends StatelessWidget {
  const SettingsPaletteGrid({
    super.key,
    required this.active,
    required this.onSelect,
  });

  final SoftPalette active;
  final ValueChanged<SoftPalette> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: SoftPalette.values.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: SoftSpacing.md,
        mainAxisSpacing: SoftSpacing.md,
        mainAxisExtent: 74.0,
      ),
      itemBuilder: (_, i) {
        final palette = SoftPalette.values[i];
        final preview = SoftTokens.resolve(palette, isDark: tokens.isDark);
        final selected = palette == active;
        return SoftCard(
          padding: const EdgeInsets.symmetric(
            horizontal: SoftSpacing.md,
            vertical: SoftSpacing.sm,
          ),
          radius: SoftRadius.subCard,
          borderColor: selected ? tokens.accent : tokens.borderSubtle,
          backgroundColor: selected ? tokens.accentSoft : tokens.card,
          onTap: () => onSelect(palette),
          child: Row(
            children: [
              Container(
                width: 24.0,
                height: 24.0,
                decoration: BoxDecoration(
                  color: preview.accent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: preview.canvas,
                    width: 2.0,
                  ),
                ),
              ),
              const SizedBox(width: SoftSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      palette.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SoftTypography.caption.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      palette.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SoftTypography.micro.copyWith(
                        color: selected
                            ? tokens.textSecondary
                            : tokens.textTertiary,
                        fontSize: 10.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
