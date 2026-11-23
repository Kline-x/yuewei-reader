import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';
import '../../../design_system/components/soft_card.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';

/// 目录章节列表单行组件（仅真实读过时显示「在读」角标）
class BookDetailChapterTile extends StatelessWidget {
  const BookDetailChapterTile({
    super.key,
    required this.chapter,
    required this.isCurrent,
    required this.onTap,
  });

  final Chapter chapter;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: SoftSpacing.xl,
        vertical: 2.0,
      ),
      title: Text(
        chapter.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: SoftTypography.body.copyWith(
          color: isCurrent ? tokens.accent : tokens.textPrimary,
          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      trailing: isCurrent
          ? Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 2.0,
              ),
              decoration: BoxDecoration(
                color: tokens.accentSoft,
                borderRadius: BorderRadius.circular(SoftRadius.pill),
              ),
              child: Text(
                '在读',
                style: SoftTypography.micro.copyWith(color: tokens.accent),
              ),
            )
          : (chapter.isCached
              ? Icon(
                  Icons.offline_pin_rounded,
                  size: 15.0,
                  color: tokens.textTertiary,
                )
              : null),
      onTap: onTap,
    );
  }
}

/// 三栏统计看板单项单元格
class BookDetailStatCell extends StatelessWidget {
  const BookDetailStatCell({
    super.key,
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SoftTypography.cardTitle.copyWith(
                fontSize: 13.5,
                color: highlight ? tokens.accent : tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 3.0),
            Text(
              label,
              style: SoftTypography.micro.copyWith(color: tokens.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

/// 最新章节与更新时间卡片（支持点击直达最新章节阅读）
class BookDetailLatestUpdateCard extends StatelessWidget {
  const BookDetailLatestUpdateCard({
    super.key,
    required this.latestChapterTitle,
    required this.lastUpdateTime,
    required this.refreshing,
    this.onTap,
  });

  final String latestChapterTitle;
  final String lastUpdateTime;
  final bool refreshing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final chapterLabel = latestChapterTitle.trim().isNotEmpty
        ? latestChapterTitle.trim()
        : '暂无最新章节信息';
    final timeLabel = lastUpdateTime.trim().isNotEmpty
        ? '更新于 ${lastUpdateTime.trim()}'
        : (refreshing ? '正在核对最新更新时间…' : '当前书源未提供更新时间');

    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: SoftSpacing.lg,
        vertical: SoftSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7.0,
                        vertical: 2.0,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.accentSoft,
                        borderRadius: BorderRadius.circular(SoftRadius.pill),
                      ),
                      child: Text(
                        '最新',
                        style: SoftTypography.micro.copyWith(
                          color: tokens.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Text(
                        chapterLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SoftTypography.cardTitle.copyWith(
                          fontSize: 14.0,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6.0),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14.0,
                      color: tokens.textTertiary,
                    ),
                    const SizedBox(width: 5.0),
                    Expanded(
                      child: Text(
                        timeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SoftTypography.caption
                            .copyWith(color: tokens.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              size: 20.0,
              color: tokens.textTertiary,
            ),
        ],
      ),
    );
  }
}
