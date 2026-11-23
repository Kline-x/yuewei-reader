import 'package:flutter/material.dart';
import '../engine/page_models.dart';
import '../engine/reader_page_slot.dart';
import '../engine/reader_scroll_layout.dart';

/// 「上下」滚动模式顶部吸顶页眉：状态栏至小标题区域 100% 纯底色实遮挡，下方短羽化渐隐杜绝透字重影
class ReaderScrollTopHeader extends StatelessWidget {
  const ReaderScrollTopHeader({
    super.key,
    required this.topPadding,
    required this.horizontalPadding,
    required this.chapterTitle,
    required this.theme,
  });

  final double topPadding;
  final double horizontalPadding;
  final String chapterTitle;
  final ReaderPaperTheme theme;

  @override
  Widget build(BuildContext context) {
    final bg = theme.background;
    final metaStyle = TextStyle(
      fontSize: 11.5,
      color: theme.secondaryText,
      fontWeight: FontWeight.w500,
    );
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: topPadding,
              color: bg,
              alignment: Alignment.topLeft,
              padding: EdgeInsets.only(
                left: horizontalPadding,
                right: horizontalPadding,
                top: (topPadding - 24.0).clamp(12.0, 80.0),
              ),
              child: Text(
                chapterTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: metaStyle,
              ),
            ),
            Container(
              height: 14.0,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [bg, bg.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 「上下」滚动模式底部极简进度栏：上沿柔光渐显 + 安全区纯色实遮挡（书名 + 当前章内百分比）
class ReaderScrollBottomFooter extends StatelessWidget {
  const ReaderScrollBottomFooter({
    super.key,
    required this.bottomPadding,
    required this.horizontalPadding,
    required this.bookTitle,
    required this.chapterProgress,
    required this.theme,
  });

  final double bottomPadding;
  final double horizontalPadding;
  final String bookTitle;
  final double chapterProgress;
  final ReaderPaperTheme theme;

  @override
  Widget build(BuildContext context) {
    final bg = theme.background;
    final metaStyle = TextStyle(
      fontSize: 11.5,
      color: theme.secondaryText,
      fontWeight: FontWeight.w500,
    );
    final pct = (chapterProgress * 100).round().clamp(1, 100);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 12.0,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [bg.withValues(alpha: 0.0), bg],
                ),
              ),
            ),
            Container(
              height: bottomPadding,
              color: bg,
              padding: EdgeInsets.only(
                left: horizontalPadding,
                right: horizontalPadding,
                top: 10.0,
              ),
              alignment: Alignment.topCenter,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      bookTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: metaStyle,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Text('本章 $pct%', style: metaStyle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 「上下」滚动模式定高 Sliver 构造器（与 ReaderScrollLayout 测量高 1:1 精确锁定）
class ReaderScrollMetrics {
  const ReaderScrollMetrics._();

  static List<Widget> buildChapterBlockSlivers({
    required ChapterBlock block,
    required ScrollChapterLayout layout,
    required TypographyConfig config,
    required ReaderPaperTheme theme,
    required TextStyle bodyStyle,
  }) {
    final hPad = EdgeInsets.symmetric(horizontal: config.horizontalPadding);
    return [
      SliverPadding(
        padding: hPad,
        sliver: SliverToBoxAdapter(
          child: SizedBox(
            height: layout.headerHeight,
            child: Padding(
              padding: const EdgeInsets.only(top: 12.0, bottom: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (layout.showDivider) ...[
                    Divider(
                      height: 28.0,
                      thickness: 0.7,
                      color: theme.secondaryText.withValues(alpha: 0.22),
                    ),
                    const SizedBox(height: 8.0),
                  ],
                  Text(
                    block.chapterTitle,
                    style: TextStyle(
                      fontSize: config.fontSize * 1.32,
                      fontWeight: FontWeight.w800,
                      height: 1.32,
                      color: theme.textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: hPad,
        sliver: SliverVariedExtentList.builder(
          itemCount: block.paragraphs.length,
          itemExtentBuilder: (i, _) => layout.itemExtents[i],
          itemBuilder: (_, i) => Padding(
            padding: EdgeInsets.only(bottom: config.paragraphGap),
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(block.paragraphs[i], style: bodyStyle),
            ),
          ),
        ),
      ),
    ];
  }
}
