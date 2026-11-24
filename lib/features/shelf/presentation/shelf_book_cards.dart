import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';
import '../../../core/storage/chapter_file_store.dart';
import '../../../design_system/components/book_cover.dart';
import '../../../design_system/components/single_swipe_tile.dart';
import '../../../design_system/components/soft_card.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';
import '../data/shelf_repository.dart';

/// 书架列表模式单书卡片：支持单向左滑移除、点击直达阅读器、更多/长按呼出统一操作面板
class ShelfListBookCard extends StatelessWidget {
  const ShelfListBookCard({
    super.key,
    required this.book,
    required this.coordinator,
    required this.onTapRead,
    required this.onOpenActions,
    required this.onSwipeRemove,
  });

  final Book book;
  final SwipeCoordinator coordinator;
  final VoidCallback onTapRead;
  final VoidCallback onOpenActions;
  final VoidCallback onSwipeRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final isLocal = book.sourceId == kLocalBookSourceId;
    final hasUpdate = book.hasUnreadUpdate && !isLocal;
    final progress = ShelfRepository.computeProgress(book);
    final progressLabel = ShelfRepository.formatProgressLabel(book);
    final baseAuthor = book.author.isEmpty ? (isLocal ? '本地文档' : '佚名') : book.author;
    final authorLine = isLocal ? '$baseAuthor · 本地藏书' : baseAuthor;
    final chapterHint = book.hasEverRead && book.currentChapterTitle.isNotEmpty
        ? book.currentChapterTitle
        : (book.totalChapters > 0 ? '共 ${book.totalChapters} 章 · 尚未开卷' : '点击开始阅读');

    return Padding(
      padding: const EdgeInsets.only(bottom: SoftSpacing.md),
      child: SingleSwipeTile(
        itemId: book.id,
        coordinator: coordinator,
        actionLabel: '移出书架',
        actionIcon: Icons.delete_outline_rounded,
        onAction: onSwipeRemove,
        child: SoftCard(
          padding: const EdgeInsets.all(SoftSpacing.md),
          onTap: () {
            if (coordinator.activeItemId != null) {
              coordinator.closeAll();
              return;
            }
            onTapRead();
          },
          onLongPress: onOpenActions,
          child: Row(
            children: [
              BookCover(
                title: book.title,
                coverUrl: book.coverUrl,
                width: 60.0,
                height: 84.0,
                radius: 12.0,
              ),
              const SizedBox(width: SoftSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (book.isPinned) ...[
                          _ShelfTagChip(
                            label: '置顶',
                            bg: tokens.accentSoft,
                            fg: tokens.accent,
                          ),
                          const SizedBox(width: 6.0),
                        ],
                        if (hasUpdate) ...[
                          _ShelfTagChip(
                            label: '更新',
                            bg: tokens.accentSoft,
                            fg: tokens.accent,
                            showDot: true,
                          ),
                          const SizedBox(width: 6.0),
                        ],
                        Expanded(
                          child: Text(
                            book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SoftTypography.cardTitle
                                .copyWith(color: tokens.textPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      authorLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SoftTypography.caption
                          .copyWith(color: tokens.textSecondary),
                    ),
                    const SizedBox(height: 3.0),
                    Text(
                      chapterHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SoftTypography.micro
                          .copyWith(color: tokens.textTertiary),
                    ),
                    const SizedBox(height: 8.0),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999.0),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 4.0,
                              backgroundColor: tokens.surface,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(tokens.accent),
                            ),
                          ),
                        ),
                        const SizedBox(width: SoftSpacing.sm),
                        Text(
                          progressLabel,
                          style: SoftTypography.micro.copyWith(
                            color: book.hasEverRead
                                ? tokens.accent
                                : tokens.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '书籍操作',
                constraints:
                    const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
                onPressed: onOpenActions,
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: tokens.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 书架网格模式单书卡片：与列表交互完全统一（点击直达阅读、右上角或长按呼出菜单）
class ShelfGridBookCard extends StatelessWidget {
  const ShelfGridBookCard({
    super.key,
    required this.book,
    required this.onTapRead,
    required this.onOpenActions,
  });

  final Book book;
  final VoidCallback onTapRead;
  final VoidCallback onOpenActions;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final isLocal = book.sourceId == kLocalBookSourceId;
    final hasUpdate = book.hasUnreadUpdate && !isLocal;
    final label = ShelfRepository.formatProgressLabel(book);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTapRead,
      onLongPress: onOpenActions,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, box) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    BookCover(
                      title: book.title,
                      coverUrl: book.coverUrl,
                      width: box.maxWidth,
                      height: box.maxHeight,
                      radius: 14.0,
                    ),
                    if (book.isPinned)
                      Positioned(
                        left: 6.0,
                        top: 6.0,
                        child: _ShelfTagChip(
                          label: '置顶',
                          bg: tokens.accent,
                          fg: tokens.onAccent,
                          fontSize: 9.5,
                        ),
                      ),
                    if (hasUpdate || isLocal)
                      Positioned(
                        left: 6.0,
                        bottom: 6.0,
                        child: _ShelfTagChip(
                          label: hasUpdate ? '更新' : '本地',
                          bg: hasUpdate ? tokens.accent : const Color(0x99000000),
                          fg: hasUpdate ? tokens.onAccent : Colors.white,
                          fontSize: 9.5,
                        ),
                      ),
                    Positioned(
                      right: 4.0,
                      top: 4.0,
                      child: Material(
                        color: const Color(0x66000000),
                        borderRadius: BorderRadius.circular(999.0),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999.0),
                          onTap: onOpenActions,
                          child: const Padding(
                            padding: EdgeInsets.all(5.0),
                            child: Icon(
                              Icons.more_horiz_rounded,
                              size: 16.0,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 7.0),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SoftTypography.caption.copyWith(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 2.0),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SoftTypography.micro.copyWith(
              color: book.hasEverRead ? tokens.accent : tokens.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShelfTagChip extends StatelessWidget {
  const _ShelfTagChip({
    required this.label,
    required this.bg,
    required this.fg,
    this.fontSize = 10.0,
    this.showDot = false,
  });

  final String label;
  final Color bg;
  final Color fg;
  final double fontSize;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 5.0,
              height: 5.0,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4.0),
          ],
          Text(
            label,
            style: SoftTypography.micro.copyWith(
              color: fg,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }
}
