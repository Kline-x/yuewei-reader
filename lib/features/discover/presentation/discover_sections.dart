import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';
import '../../../design_system/components/book_cover.dart';
import '../../../design_system/components/soft_card.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';
import '../../sources/domain/book_match_models.dart';

/// 探索页空闲状态视图（搜索历史与多源聚合找书引导，≤ 200 行）
class DiscoverIdleSection extends StatelessWidget {
  const DiscoverIdleSection({
    super.key,
    required this.db,
    required this.onSelectKeyword,
  });

  final AppDatabase db;
  final ValueChanged<String> onSelectKeyword;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(SoftSpacing.xl, SoftSpacing.md, SoftSpacing.xl, SoftSpacing.dockClearance),
      children: [
        StreamBuilder<List<SearchHistoryData>>(
          stream: db.watchSearchHistory(),
          builder: (context, snap) {
            final history = snap.data ?? const [];
            if (history.isEmpty) {
              return SoftCard(
                backgroundColor: tokens.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('多源聚合找书', style: SoftTypography.cardTitle.copyWith(color: tokens.textPrimary)),
                    const SizedBox(height: 6.0),
                    Text(
                      '输入完整或部分书名，自动并发检索全网已启用书源并按同书聚合排序，支持随时无感换源与 Legado 书源导入。',
                      style: SoftTypography.body.copyWith(color: tokens.textSecondary),
                    ),
                  ],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('最近搜索', style: SoftTypography.sectionTitle.copyWith(color: tokens.textPrimary)),
                    TextButton(
                      onPressed: db.clearSearchHistory,
                      child: Text('清空', style: SoftTypography.caption.copyWith(color: tokens.textSecondary)),
                    ),
                  ],
                ),
                const SizedBox(height: SoftSpacing.sm),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: history.map((h) {
                    return ActionChip(
                      label: Text(h.keyword, style: SoftTypography.caption.copyWith(color: tokens.textPrimary)),
                      backgroundColor: tokens.surface,
                      side: BorderSide(color: tokens.borderSubtle, width: 0.8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SoftRadius.pill)),
                      onPressed: () => onSelectKeyword(h.keyword),
                    );
                  }).toList(),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// 探索页多源聚合检索结果列表
class DiscoverResultsList extends StatelessWidget {
  const DiscoverResultsList({
    super.key,
    required this.results,
    required this.onTapBook,
  });

  final List<AggregatedBookMatch> results;
  final ValueChanged<AggregatedBookMatch> onTapBook;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        SoftSpacing.xl,
        SoftSpacing.md,
        SoftSpacing.xl,
        SoftSpacing.dockClearance,
      ),
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: SoftSpacing.md),
      itemBuilder: (ctx, i) {
        final book = results[i];
        return SoftCard(
          onTap: () => onTapBook(book),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookCover(
                title: book.displayTitle,
                coverUrl: book.bestCoverUrl,
                width: 68.0,
                height: 94.0,
              ),
              const SizedBox(width: SoftSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SoftTypography.cardTitle
                          .copyWith(color: tokens.textPrimary),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      book.displayAuthor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SoftTypography.caption
                          .copyWith(color: tokens.textSecondary),
                    ),
                    if (book.bestIntro.isNotEmpty) ...[
                      const SizedBox(height: 6.0),
                      Text(
                        book.bestIntro,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SoftTypography.caption
                            .copyWith(color: tokens.textTertiary),
                      ),
                    ],
                    const SizedBox(height: 8.0),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 3.0,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.accentSoft,
                            borderRadius: BorderRadius.circular(SoftRadius.pill),
                          ),
                          child: Text(
                            '${book.sourceCount} 个可用书源 · 最快 ${book.fastestLatencyMs}ms',
                            style: SoftTypography.micro
                                .copyWith(color: tokens.accent),
                          ),
                        ),
                      ],
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
