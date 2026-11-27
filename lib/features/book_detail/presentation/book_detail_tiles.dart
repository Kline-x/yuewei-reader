import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';
import '../../../design_system/components/soft_button.dart';
import '../../../design_system/components/soft_card.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';

/// 书籍详情页顶部导航栏（返回、刷新元数据与换源/本地标签）
class BookDetailTopBar extends StatelessWidget {
  const BookDetailTopBar({
    super.key,
    required this.hasBook,
    required this.isLocal,
    required this.refreshingMeta,
    required this.sourceName,
    required this.onBack,
    required this.onRefresh,
    required this.onSwitchSource,
  });

  final bool hasBook;
  final bool isLocal;
  final bool refreshingMeta;
  final String sourceName;
  final VoidCallback onBack;
  final VoidCallback? onRefresh;
  final VoidCallback onSwitchSource;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8.0, 6.0, 16.0, 6.0),
      child: Row(
        children: [
          IconButton(
            constraints: const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
            onPressed: onBack,
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 19.0,
              color: tokens.textPrimary,
            ),
          ),
          const Spacer(),
          if (hasBook && isLocal)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: tokens.accentSoft,
                borderRadius: BorderRadius.circular(SoftRadius.pill),
              ),
              child: Text(
                '本地藏书',
                style: SoftTypography.caption.copyWith(
                  color: tokens.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else if (hasBook) ...[
            IconButton(
              tooltip: '刷新书籍信息',
              constraints: const BoxConstraints(minWidth: 40.0, minHeight: 40.0),
              onPressed: onRefresh,
              icon: refreshingMeta
                  ? SizedBox(
                      width: 16.0,
                      height: 16.0,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        color: tokens.accent,
                      ),
                    )
                  : Icon(
                      Icons.refresh_rounded,
                      size: 20.0,
                      color: tokens.textSecondary,
                    ),
            ),
            const SizedBox(width: 4.0),
            SoftButton(
              label: sourceName.isNotEmpty ? sourceName : '切换书源',
              icon: Icons.swap_horiz_rounded,
              tone: SoftButtonTone.tonal,
              compact: true,
              onPressed: onSwitchSource,
            ),
          ],
        ],
      ),
    );
  }
}

/// 目录章节列表单行组件（仅真实读过时显示「在读」角标，固定行高确保定位当前章像素级精准）
class BookDetailChapterTile extends StatelessWidget {
  const BookDetailChapterTile({
    super.key,
    required this.chapter,
    required this.isCurrent,
    required this.onTap,
    this.showDivider = false,
  });

  static const double rowExtent = 50.0;

  final Chapter chapter;
  final bool isCurrent;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.symmetric(horizontal: SoftSpacing.xl),
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
          ),
        ),
        if (showDivider)
          Divider(
            height: 1.0,
            indent: SoftSpacing.xl,
            endIndent: SoftSpacing.xl,
            color: tokens.borderSubtle,
          ),
      ],
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
