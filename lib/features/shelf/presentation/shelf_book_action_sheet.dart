import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/app_database.dart';
import '../../../design_system/components/soft_bottom_sheet.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';
import '../../reader/presentation/reader_download_sheet.dart';

/// 全书架统一的底部操作抽屉（使用根导航弹出，绝不被底栏遮挡）
Future<void> showShelfBookActionSheet(
  BuildContext context, {
  required Book book,
  required Future<void> Function() onTogglePin,
  required Future<void> Function() onClearBookCache,
  required VoidCallback onRemoveBook,
}) {
  return SoftBottomSheet.show(
    context,
    title: book.title,
    subtitle: book.author.isEmpty
        ? '共 ${book.totalChapters} 章'
        : '${book.author} · 共 ${book.totalChapters} 章',
    headerIcon: Icons.menu_book_rounded,
    maxHeightFactor: 0.65,
    builder: (sheetCtx) {
      final tokens = SoftTokens.of(sheetCtx);
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          SoftSpacing.xl,
          SoftSpacing.sm,
          SoftSpacing.xl,
          SoftSpacing.xl,
        ),
        children: [
          _ActionRow(
            icon: Icons.info_outline_rounded,
            label: '书籍详情与目录',
            onTap: () {
              Navigator.of(sheetCtx).pop();
              context.push('/book?id=${book.id}');
            },
          ),
          _ActionRow(
            icon: Icons.download_for_offline_outlined,
            label: '离线缓存章节',
            onTap: () {
              Navigator.of(sheetCtx).pop();
              ReaderDownloadSheet.show(
                context,
                bookId: book.id,
                bookTitle: book.title,
                totalChapters: book.totalChapters,
                currentChapterIndex: book.currentChapterIndex,
              );
            },
          ),
          _ActionRow(
            icon: book.isPinned
                ? Icons.push_pin_rounded
                : Icons.push_pin_outlined,
            label: book.isPinned ? '取消置顶' : '置顶此书',
            onTap: () async {
              Navigator.of(sheetCtx).pop();
              await onTogglePin();
            },
          ),
          _ActionRow(
            icon: Icons.cleaning_services_outlined,
            label: '清空本书缓存文件',
            onTap: () async {
              Navigator.of(sheetCtx).pop();
              await onClearBookCache();
            },
          ),
          _ActionRow(
            icon: Icons.delete_outline_rounded,
            label: '移出书架',
            color: tokens.danger,
            onTap: () {
              Navigator.of(sheetCtx).pop();
              onRemoveBook();
            },
          ),
        ],
      );
    },
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final fg = color ?? tokens.textPrimary;
    return InkWell(
      borderRadius: BorderRadius.circular(SoftRadius.control),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SoftSpacing.sm,
          vertical: 14.0,
        ),
        child: Row(
          children: [
            Icon(icon, size: 21.0, color: fg),
            const SizedBox(width: SoftSpacing.md),
            Text(
              label,
              style: SoftTypography.body.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
