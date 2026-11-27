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

  int get _contentHash {
    var h = page.lines.length;
    for (final line in page.lines) {
      h = Object.hash(h, line.text);
    }
    return h;
  }

  String get cacheKey =>
      '${chapterIndex}_${page.pageIndex}_${totalPagesInChapter}_${page.charStart}_${page.charEnd}_${chapterTitle.hashCode}_${bookTitle.hashCode}_$_contentHash';

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

/// 连续滚动模式显式定位指令（每次切章/跳转递增 token，待新 blocks 渲染生效后安全重定位）
@immutable
class ScrollJumpCommand {
  const ScrollJumpCommand({
    required this.token,
    required this.chapterIndex,
    this.charOffset = 0,
    this.landOnEnd = false,
    this.animate = false,
  });

  final int token;
  final int chapterIndex;
  final int charOffset;
  final bool landOnEnd;
  final bool animate;
}
