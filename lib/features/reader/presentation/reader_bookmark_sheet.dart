import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/bookmark_dao.dart';
import '../../../design_system/components/soft_bottom_sheet.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';

/// 阅读器书签管理底部抽屉（实时响应增删、当前章高亮、精确字符偏移跳转）
class ReaderBookmarkSheet extends StatefulWidget {
  const ReaderBookmarkSheet({
    super.key,
    required this.db,
    required this.bookId,
    required this.currentChapterIndex,
    required this.onSelectBookmark,
  });

  final AppDatabase db;
  final String bookId;
  final int currentChapterIndex;
  final Future<void> Function(int chapterIndex, int charOffset) onSelectBookmark;

  static Future<void> show(
    BuildContext context, {
    required AppDatabase db,
    required String bookId,
    required int currentChapterIndex,
    required Future<void> Function(int chapterIndex, int charOffset) onSelectBookmark,
  }) {
    return SoftBottomSheet.show(
      context,
      title: '本书书签',
      headerIcon: Icons.bookmark_rounded,
      maxHeightFactor: 0.78,
      builder: (_) => ReaderBookmarkSheet(
        db: db, bookId: bookId,
        currentChapterIndex: currentChapterIndex,
        onSelectBookmark: onSelectBookmark,
      ),
    );
  }

  @override
  State<ReaderBookmarkSheet> createState() => _ReaderBookmarkSheetState();
}

class _ReaderBookmarkSheetState extends State<ReaderBookmarkSheet> {
  late final Stream<List<Bookmark>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = widget.db.watchBookmarksByBook(widget.bookId);
  }

  static String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final sameYear = dt.year == now.year;
    if (sameYear && dt.month == now.month && dt.day == now.day) return '今天 $hh:$mm';
    final y = now.subtract(const Duration(days: 1));
    if (dt.year == y.year && dt.month == y.month && dt.day == y.day) return '昨天 $hh:$mm';
    final mo = dt.month.toString().padLeft(2, '0');
    final da = dt.day.toString().padLeft(2, '0');
    return sameYear ? '$mo-$da $hh:$mm' : '${dt.year}-$mo-$da';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    return StreamBuilder<List<Bookmark>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return SizedBox(
            height: 220.0,
            child: Center(child: CircularProgressIndicator(color: tokens.accent)),
          );
        }
        final list = snapshot.data ?? const <Bookmark>[];
        if (list.isEmpty) {
          return SizedBox(
            height: 240.0,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: SoftSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bookmark_border_rounded, size: 38.0, color: tokens.textTertiary),
                    const SizedBox(height: SoftSpacing.md),
                    Text(
                      '暂无书签，点击阅读顶栏书签图标即可随手标记',
                      textAlign: TextAlign.center,
                      style: SoftTypography.body.copyWith(color: tokens.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(SoftSpacing.xl, SoftSpacing.sm, SoftSpacing.xl, 4.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '共 ${list.length} 条书签 · 点击跳回对应位置',
                  style: SoftTypography.micro.copyWith(color: tokens.textTertiary),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: SoftSpacing.xs),
                itemCount: list.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1.0, indent: SoftSpacing.xl, endIndent: SoftSpacing.xl,
                  color: tokens.borderSubtle,
                ),
                itemBuilder: (ctx, idx) => _buildRow(ctx, list[idx], tokens),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRow(BuildContext context, Bookmark item, SoftTokens tokens) {
    final isCurrent = item.chapterIndex == widget.currentChapterIndex;
    return Material(
      color: isCurrent ? tokens.accentSoft : Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          unawaited(widget.onSelectBookmark(item.chapterIndex, item.charOffset));
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(SoftSpacing.xl, SoftSpacing.md, SoftSpacing.sm, SoftSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isCurrent) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                            decoration: BoxDecoration(
                              color: tokens.accent, borderRadius: BorderRadius.circular(6.0),
                            ),
                            child: Text(
                              '当前章',
                              style: SoftTypography.micro.copyWith(color: tokens.onAccent, fontSize: 10.0),
                            ),
                          ),
                          const SizedBox(width: 6.0),
                        ],
                        Expanded(
                          child: Text(
                            item.chapterTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SoftTypography.cardTitle.copyWith(
                              fontSize: 14.0,
                              color: isCurrent ? tokens.accent : tokens.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          _formatTime(item.createdAt),
                          style: SoftTypography.micro.copyWith(color: tokens.textTertiary),
                        ),
                      ],
                    ),
                    if (item.excerpt.isNotEmpty) ...[
                      const SizedBox(height: 5.0),
                      Text(
                        item.excerpt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SoftTypography.caption.copyWith(color: tokens.textSecondary, height: 1.45),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4.0),
              IconButton(
                tooltip: '删除书签',
                constraints: const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
                onPressed: () => widget.db.deleteBookmark(item.id),
                icon: Icon(Icons.delete_outline_rounded, size: 19.0, color: tokens.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
