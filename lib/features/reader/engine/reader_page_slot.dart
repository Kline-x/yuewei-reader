import 'package:flutter/foundation.dart';
import 'page_models.dart';

/// 供跨章翻页手势与矢量缓存使用的单页/对开双页完整描述槽位
@immutable
class PageRenderItem {
  const PageRenderItem({
    required this.chapterIndex,
    required this.chapterTitle,
    required this.page,
    required this.totalPagesInChapter,
    required this.bookTitle,
    this.rightPage,
    this.isDualPage = false,
    this.spineWidth = 0.0,
    this.config,
  });

  final int chapterIndex;
  final String chapterTitle;
  final TypedPage page;
  final int totalPagesInChapter;
  final String bookTitle;
  final TypedPage? rightPage;
  final bool isDualPage;
  final double spineWidth;
  final TypographyConfig? config;

  int get _contentHash {
    var h = page.lines.length;
    for (final line in page.lines) {
      h = Object.hash(h, line.text);
    }
    if (rightPage != null) {
      h = Object.hash(h, rightPage!.lines.length);
      for (final line in rightPage!.lines) {
        h = Object.hash(h, line.text);
      }
    }
    return h;
  }

  String get cacheKey {
    final rIdx = rightPage?.pageIndex ?? -1;
    final rEnd = rightPage?.charEnd ?? -1;
    final spineTag = spineWidth.toStringAsFixed(1);
    final cfg = config;
    final typoTag = cfg == null
        ? ''
        : '_${cfg.fontFamily ?? ''}_${cfg.paragraphGap}_${cfg.horizontalPadding}_${cfg.letterSpacing}_${cfg.indentFirstLine}';
    return '${chapterIndex}_${page.pageIndex}_${totalPagesInChapter}_${page.charStart}_${page.charEnd}_${chapterTitle.hashCode}_${bookTitle.hashCode}_${isDualPage ? 1 : 0}_${rIdx}_${rEnd}_${spineTag}_$_contentHash$typoTag';
  }

  @override
  bool operator ==(Object other) {
    return other is PageRenderItem &&
        other.chapterIndex == chapterIndex &&
        other.chapterTitle == chapterTitle &&
        other.page == page &&
        other.totalPagesInChapter == totalPagesInChapter &&
        other.bookTitle == bookTitle &&
        other.rightPage == rightPage &&
        other.isDualPage == isDualPage &&
        other.spineWidth == spineWidth &&
        other.config == config;
  }

  @override
  int get hashCode => Object.hash(
        chapterIndex,
        chapterTitle,
        page,
        totalPagesInChapter,
        bookTitle,
        rightPage,
        isDualPage,
        spineWidth,
        config,
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
