import 'package:lpinyin/lpinyin.dart';
import '../../../core/database/app_database.dart';

enum ShelfSortMode {
  lastRead('最近阅读'),
  pinyin('书名拼音'),
  progress('阅读进度');

  const ShelfSortMode(this.label);
  final String label;

  static ShelfSortMode fromName(String? raw) {
    return ShelfSortMode.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => ShelfSortMode.lastRead,
    );
  }
}

/// 书架进度计算与多维度排序工具（与 ShelfRepository 解耦，严守单文件红线）
class ShelfBookSorter {
  const ShelfBookSorter._();

  /// 精准计算单本书阅读进度（未读过严格返回 0.0）
  static double computeProgress(Book book) {
    if (!book.hasEverRead) return 0.0;
    if (book.totalChapters <= 0) return 0.0;
    return ((book.currentChapterIndex + 1) / book.totalChapters).clamp(0.0, 1.0);
  }

  static String formatProgressLabel(Book book) {
    if (!book.hasEverRead) return '未读 · 0%';
    final ratio = computeProgress(book);
    final pct = (ratio * 100).round();
    if (pct == 0 && ratio > 0) return '已读 <1%';
    return '已读 $pct%';
  }

  static List<Book> sortBooks(List<Book> input, ShelfSortMode mode) {
    final list = List<Book>.from(input);
    final pinyinCache = <String, String>{};
    String pinyinOf(Book b) => pinyinCache.putIfAbsent(
          b.id,
          () => PinyinHelper.getShortPinyin(b.title).toLowerCase(),
        );

    list.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      switch (mode) {
        case ShelfSortMode.lastRead:
          final at = a.lastReadAt ?? a.addedAt ?? a.updatedAt;
          final bt = b.lastReadAt ?? b.addedAt ?? b.updatedAt;
          return bt.compareTo(at);
        case ShelfSortMode.pinyin:
          return pinyinOf(a).compareTo(pinyinOf(b));
        case ShelfSortMode.progress:
          return computeProgress(b).compareTo(computeProgress(a));
      }
    });
    return list;
  }
}
