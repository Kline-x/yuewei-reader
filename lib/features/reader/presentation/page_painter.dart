import 'package:flutter/material.dart';
import '../engine/page_models.dart';
import '../engine/typography_engine.dart';

/// 出版级单页排版绘制器（供 CustomPainter 与 PictureRecorder 1:1 共享静态 drawPage 方法）
class PagePainter extends CustomPainter {
  const PagePainter({
    required this.page,
    required this.totalPages,
    required this.chapterTitle,
    required this.bookTitle,
    required this.config,
    required this.theme,
  });

  final TypedPage page;
  final int totalPages;
  final String chapterTitle;
  final String bookTitle;
  final TypographyConfig config;
  final ReaderPaperTheme theme;

  /// 将整页正文、页眉、页脚 1:1 绘制到任意 Canvas（用于实时渲染与 ui.Picture 离屏录制）
  static void drawPage(
    Canvas canvas,
    Size size, {
    required TypedPage page,
    required int totalPages,
    required String chapterTitle,
    required String bookTitle,
    required TypographyConfig config,
    required ReaderPaperTheme theme,
  }) {
    final bgPaint = Paint()..color = theme.background;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final metaStyle = TextStyle(
      fontSize: 11.5,
      color: theme.secondaryText,
      fontWeight: FontWeight.w500,
    );

    // 1. 顶部页眉（首屏展示醒目大标题时隐藏小页眉避免视觉冗余）
    if (!page.showChapterHeading) {
      final headerTp = TextPainter(
        text: TextSpan(text: chapterTitle, style: metaStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: config.contentWidth);
      headerTp.paint(
        canvas,
        Offset(
          config.horizontalPadding,
          (config.topPadding - 24.0).clamp(12.0, 80.0),
        ),
      );
      headerTp.dispose();
    }

    // 2. 正文排版绘制（与 TypographyEngine 保持 1:1 坐标一致）
    var currentY = config.topPadding;
    if (page.showChapterHeading) {
      final titleTp = TextPainter(
        text: TextSpan(
          text: chapterTitle,
          style: TypographyEngine.chapterHeadingStyle(config, theme.textColor),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: config.contentWidth);
      titleTp.paint(canvas, Offset(config.horizontalPadding, currentY));
      titleTp.dispose();
      currentY += TypographyEngine.measureHeadingHeight(chapterTitle, config);
    }

    final bodyStyle = TypographyEngine.bodyStyle(config, theme.textColor);
    for (final line in page.lines) {
      final lineTp = TextPainter(
        text: TextSpan(text: line.text, style: bodyStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      lineTp.paint(canvas, Offset(config.horizontalPadding, currentY));
      lineTp.dispose();

      currentY += config.lineHeight;
      if (line.isLastLineOfPara) {
        currentY += config.paragraphGap;
      }
    }

    // 3. 底部页脚（左：书名；右：页码与百分比）
    final footerY = size.height - config.bottomPadding + 10.0;
    final leftTp = TextPainter(
      text: TextSpan(text: bookTitle, style: metaStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: config.contentWidth * 0.58);
    leftTp.paint(canvas, Offset(config.horizontalPadding, footerY));
    leftTp.dispose();

    final pct = totalPages > 0
        ? (((page.pageIndex + 1) / totalPages) * 100).round()
        : 100;
    final pageLabel = '第 ${page.pageIndex + 1}/$totalPages 页 · $pct%';
    final rightTp = TextPainter(
      text: TextSpan(text: pageLabel, style: metaStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    rightTp.paint(
      canvas,
      Offset(size.width - config.horizontalPadding - rightTp.width, footerY),
    );
    rightTp.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    drawPage(
      canvas,
      size,
      page: page,
      totalPages: totalPages,
      chapterTitle: chapterTitle,
      bookTitle: bookTitle,
      config: config,
      theme: theme,
    );
  }

  @override
  bool shouldRepaint(covariant PagePainter oldDelegate) {
    return oldDelegate.page != page ||
        oldDelegate.totalPages != totalPages ||
        oldDelegate.chapterTitle != chapterTitle ||
        oldDelegate.bookTitle != bookTitle ||
        oldDelegate.config != config ||
        oldDelegate.theme.id != theme.id;
  }
}
