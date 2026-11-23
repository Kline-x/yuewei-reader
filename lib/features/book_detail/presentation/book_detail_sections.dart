import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';
import '../../../design_system/components/book_cover.dart';
import '../../../design_system/components/soft_button.dart';
import '../../../design_system/components/soft_card.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';
import '../../sources/engine/source_crawler_service.dart';
import 'book_detail_tiles.dart';

/// 书籍详情页顶部信息卡、状态看板、操作区、简介卡与最新更新卡（≤ 350 行）
class BookDetailHeaderSection extends StatelessWidget {
  const BookDetailHeaderSection({
    super.key,
    required this.book,
    required this.chapterCount,
    required this.sourceName,
    required this.latestChapterTitle,
    required this.refreshingMeta,
    required this.introExpanded,
    required this.descending,
    required this.onToggleShelf,
    required this.onOpenDownload,
    required this.onStartReading,
    required this.onTapLatestChapter,
    required this.onToggleIntro,
    required this.onLocateCurrent,
    required this.onToggleOrder,
  });

  final Book book;
  final int chapterCount;
  final String sourceName;
  final String latestChapterTitle;
  final bool refreshingMeta;
  final bool introExpanded;
  final bool descending;
  final VoidCallback onToggleShelf;
  final VoidCallback onOpenDownload;
  final VoidCallback? onStartReading;
  final VoidCallback? onTapLatestChapter;
  final VoidCallback onToggleIntro;
  final VoidCallback onLocateCurrent;
  final VoidCallback onToggleOrder;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final intro = SourceCrawlerService.cleanSeoIntro(book.intro);
    final safeCategory = SourceCrawlerService.sanitizeBadge(book.category);
    final parsedStatus = SourceCrawlerService.sanitizeBadge(book.statusText);
    final safeStatus = parsedStatus.isEmpty ? '连载中' : parsedStatus;
    final safeUpdateTime =
        SourceCrawlerService.sanitizeUpdateTime(book.lastUpdateTime);
    final divider =
        VerticalDivider(width: 1.0, thickness: 0.8, color: tokens.borderSubtle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookCover(
              title: book.title,
              coverUrl: book.coverUrl,
              width: 96.0,
              height: 132.0,
              radius: 16.0,
            ),
            const SizedBox(width: SoftSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SoftTypography.displayTitle.copyWith(
                      fontSize: 21.0,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  Text(
                    book.author.isNotEmpty ? book.author : '未知作者',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SoftTypography.body
                        .copyWith(color: tokens.textSecondary),
                  ),
                  if (safeCategory.isNotEmpty) ...[
                    const SizedBox(height: 8.0),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 3.0),
                        decoration: BoxDecoration(
                          color: tokens.accentSoft,
                          borderRadius: BorderRadius.circular(SoftRadius.pill),
                        ),
                        child: Text(
                          safeCategory,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SoftTypography.micro
                              .copyWith(color: tokens.accent),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: SoftSpacing.lg),
        SoftCard(
          padding: const EdgeInsets.symmetric(
              vertical: SoftSpacing.md, horizontal: SoftSpacing.sm),
          child: IntrinsicHeight(
            child: Row(
              children: [
                BookDetailStatCell(value: safeStatus, label: '连载状态'),
                divider,
                BookDetailStatCell(value: '$chapterCount 章', label: '全书篇幅'),
                divider,
                BookDetailStatCell(
                  value: sourceName,
                  label: '当前书源',
                  highlight: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: SoftSpacing.lg),
        Row(
          children: [
            SoftButton(
              label: book.isInShelf ? '已在书架' : '加入书架',
              icon: book.isInShelf ? Icons.check_rounded : Icons.add_rounded,
              tone: SoftButtonTone.tonal,
              onPressed: onToggleShelf,
            ),
            const SizedBox(width: SoftSpacing.sm),
            IconButton(
              tooltip: '离线缓存',
              constraints:
                  const BoxConstraints(minWidth: 46.0, minHeight: 46.0),
              style: IconButton.styleFrom(
                backgroundColor: tokens.surface,
                shape: const CircleBorder(),
              ),
              onPressed: onOpenDownload,
              icon: Icon(Icons.download_for_offline_outlined,
                  color: tokens.textPrimary),
            ),
            const SizedBox(width: SoftSpacing.sm),
            Expanded(
              child: SoftButton(
                label: book.hasEverRead
                    ? '继续阅读 (第${book.currentChapterIndex + 1}章)'
                    : '开始阅读',
                icon: Icons.menu_book_rounded,
                expand: true,
                onPressed: onStartReading,
              ),
            ),
          ],
        ),
        const SizedBox(height: SoftSpacing.lg),
        _IntroCard(
          intro: intro,
          introExpanded: introExpanded,
          refreshingMeta: refreshingMeta,
          onToggleIntro: onToggleIntro,
        ),
        if (chapterCount > 0 || safeUpdateTime.isNotEmpty || refreshingMeta) ...[
          const SizedBox(height: SoftSpacing.md),
          BookDetailLatestUpdateCard(
            latestChapterTitle: latestChapterTitle,
            lastUpdateTime: safeUpdateTime,
            refreshing: refreshingMeta,
            onTap: onTapLatestChapter,
          ),
        ],
        const SizedBox(height: SoftSpacing.xl),
        Row(
          children: [
            Text(
              '目录 ($chapterCount)',
              style: SoftTypography.sectionTitle
                  .copyWith(color: tokens.textPrimary),
            ),
            const Spacer(),
            IconButton(
              tooltip: '定位当前章',
              constraints:
                  const BoxConstraints(minWidth: 40.0, minHeight: 40.0),
              onPressed: onLocateCurrent,
              icon: Icon(Icons.my_location_rounded,
                  size: 19.0, color: tokens.accent),
            ),
            TextButton.icon(
              onPressed: onToggleOrder,
              icon: Icon(
                descending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 16.0,
                color: tokens.textSecondary,
              ),
              label: Text(
                descending ? '倒序' : '正序',
                style: SoftTypography.caption
                    .copyWith(color: tokens.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.intro,
    required this.introExpanded,
    required this.refreshingMeta,
    required this.onToggleIntro,
  });

  final String intro;
  final bool introExpanded;
  final bool refreshingMeta;
  final VoidCallback onToggleIntro;

  bool _exceedsThreeLines(
    String text,
    TextStyle style,
    double maxWidth,
    TextScaler textScaler,
    TextDirection textDirection,
  ) {
    if (text.isEmpty || !maxWidth.isFinite || maxWidth <= 0) return false;
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 3,
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth);
    final exceeded = tp.didExceedMaxLines;
    tp.dispose();
    return exceeded;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final displayText = intro.isNotEmpty
        ? intro
        : (refreshingMeta
            ? '正在同步作品简介与最新更新…'
            : '当前书源暂未收录作品简介，可点击右上角切换书源查看');
    final textStyle = SoftTypography.body.copyWith(
      color: intro.isEmpty ? tokens.textTertiary : tokens.textSecondary,
    );

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '作品简介',
                style: SoftTypography.cardTitle
                    .copyWith(color: tokens.textPrimary),
              ),
              if (refreshingMeta) ...[
                const SizedBox(width: 8.0),
                SizedBox(
                  width: 12.0,
                  height: 12.0,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.8, color: tokens.accent),
                ),
              ],
            ],
          ),
          const SizedBox(height: SoftSpacing.sm),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final effectiveStyle =
                  DefaultTextStyle.of(ctx).style.merge(textStyle);
              final canExpand = _exceedsThreeLines(
                intro,
                effectiveStyle,
                constraints.maxWidth,
                MediaQuery.textScalerOf(ctx),
                Directionality.of(ctx),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayText,
                    maxLines: intro.isEmpty || introExpanded ? null : 3,
                    overflow: intro.isEmpty || introExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: textStyle,
                  ),
                  if (intro.isNotEmpty && canExpand)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: onToggleIntro,
                        icon: Icon(
                          introExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18.0,
                          color: tokens.accent,
                        ),
                        label: Text(
                          introExpanded ? '收起' : '展开全文',
                          style: SoftTypography.caption
                              .copyWith(color: tokens.accent),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
