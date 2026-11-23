import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';
import '../../../design_system/components/soft_card.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';
import '../data/shelf_repository.dart';

/// 书架顶部品牌头栏
class ShelfHeaderBar extends StatelessWidget {
  const ShelfHeaderBar({
    super.key,
    required this.isGridView,
    required this.onTapSearch,
    required this.onTapSources,
    required this.onToggleView,
  });

  final bool isGridView;
  final VoidCallback onTapSearch;
  final VoidCallback onTapSources;
  final VoidCallback onToggleView;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SoftSpacing.xl,
        SoftSpacing.md,
        SoftSpacing.md,
        SoftSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YUEWEI',
                  style: SoftTypography.eyebrow.copyWith(color: tokens.accent),
                ),
                const SizedBox(height: 2.0),
                Text(
                  '阅微',
                  style: SoftTypography.displayTitle
                      .copyWith(color: tokens.textPrimary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '搜索找书',
            constraints: const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
            onPressed: onTapSearch,
            icon: Icon(Icons.search_rounded, color: tokens.textPrimary),
          ),
          IconButton(
            tooltip: '书源中心',
            constraints: const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
            onPressed: onTapSources,
            icon: Icon(Icons.dns_outlined, color: tokens.textPrimary),
          ),
          IconButton(
            tooltip: isGridView ? '切换列表视图' : '切换网格视图',
            constraints: const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
            onPressed: onToggleView,
            icon: Icon(
              isGridView
                  ? Icons.view_agenda_outlined
                  : Icons.grid_view_rounded,
              color: tokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 书架 Bento 双卡阅读看板（实时监听今日阅读分钟数与藏书均读进度）
class ShelfBentoBoard extends StatelessWidget {
  const ShelfBentoBoard({
    super.key,
    required this.db,
    required this.books,
  });

  final AppDatabase db;
  final List<Book> books;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final avgPct = books.isEmpty
        ? 0
        : (books.fold<double>(
                    0.0, (s, b) => s + ShelfRepository.computeProgress(b)) /
                books.length *
                100)
            .round();

    return Row(
      children: [
        Expanded(
          child: StreamBuilder<int>(
            stream: db.watchTodayReadingMinutes(),
            builder: (_, snap) {
              final mins = snap.data ?? 0;
              return SoftCard(
                padding: const EdgeInsets.all(SoftSpacing.md),
                radius: SoftRadius.subCard,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 14.0, color: tokens.accent),
                        const SizedBox(width: 5.0),
                        Text(
                          '今日心流',
                          style: SoftTypography.micro
                              .copyWith(color: tokens.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      '$mins 分钟',
                      style: SoftTypography.sectionTitle
                          .copyWith(color: tokens.textPrimary, fontSize: 18.0),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      mins == 0 ? '待启阅' : '专注阅读中',
                      style: SoftTypography.micro.copyWith(
                        color: mins == 0 ? tokens.textTertiary : tokens.accent,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(width: SoftSpacing.md),
        Expanded(
          child: SoftCard(
            padding: const EdgeInsets.all(SoftSpacing.md),
            radius: SoftRadius.subCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bookmarks_outlined,
                        size: 14.0, color: tokens.accent),
                    const SizedBox(width: 5.0),
                    Text(
                      '珍本在读',
                      style: SoftTypography.micro
                          .copyWith(color: tokens.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                Text(
                  '${books.length} 部',
                  style: SoftTypography.sectionTitle
                      .copyWith(color: tokens.textPrimary, fontSize: 18.0),
                ),
                const SizedBox(height: 2.0),
                Text(
                  books.isEmpty ? '静候启卷' : '均读 $avgPct%',
                  style: SoftTypography.micro.copyWith(
                    color: books.isEmpty ? tokens.textTertiary : tokens.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 书架排序胶囊条
class ShelfSortBar extends StatelessWidget {
  const ShelfSortBar({
    super.key,
    required this.currentMode,
    required this.onSelect,
  });

  final ShelfSortMode currentMode;
  final ValueChanged<ShelfSortMode> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    return Row(
      children: [
        Text(
          '藏书排序',
          style: SoftTypography.caption.copyWith(color: tokens.textTertiary),
        ),
        const Spacer(),
        ...ShelfSortMode.values.map((mode) {
          final selected = currentMode == mode;
          return Padding(
            padding: const EdgeInsets.only(left: 6.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(SoftRadius.pill),
              onTap: () => onSelect(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 5.0,
                ),
                decoration: BoxDecoration(
                  color: selected ? tokens.accentSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(SoftRadius.pill),
                  border: Border.all(
                    color: selected ? tokens.accent : tokens.borderSubtle,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  mode.label,
                  style: SoftTypography.micro.copyWith(
                    color: selected ? tokens.accent : tokens.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
