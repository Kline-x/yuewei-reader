import 'package:flutter/foundation.dart';
import 'page_models.dart';

/// 供跨章翻页手势与矢量缓存使用的单页完整描述槽位
@immutable
class PageRenderItem {
  const PageRenderItem({
    required this.chapterIndex,
    required this.chapterTitle,
    required this.page,
    required this.totalPagesInChapter,
    required this.bookTitle,
  });

  final int chapterIndex;
  final String chapterTitle;
  final TypedPage page;
  final int totalPagesInChapter;
  final String bookTitle;

  String get cacheKey =>
      '${chapterIndex}_${page.pageIndex}_${totalPagesInChapter}_${chapterTitle.hashCode}_${bookTitle.hashCode}';

  @override
  bool operator ==(Object other) {
    return other is PageRenderItem &&
        other.chapterIndex == chapterIndex &&
        other.chapterTitle == chapterTitle &&
        other.page == page &&
        other.totalPagesInChapter == totalPagesInChapter &&
        other.bookTitle == bookTitle;
  }

  @override
  int get hashCode => Object.hash(
        chapterIndex,
        chapterTitle,
        page,
        totalPagesInChapter,
        bookTitle,
      );
}

/// 上下连续无缝滚动模式的单章文本块
@immutable
class ChapterBlock {
  const ChapterBlock({
    required this.chapterIndex,
    required this.chapterTitle,
    required this.paragraphs,
  });

  final int chapterIndex;
  final String chapterTitle;
  final List<String> paragraphs;
}
