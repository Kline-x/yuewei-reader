import 'package:flutter/material.dart';
import '../../../design_system/components/empty_error_view.dart';
import '../engine/page_models.dart';
import '../engine/reader_page_slot.dart';
import 'reader_overlay_bars.dart';
import 'reader_pager_views.dart';

/// 阅读器内容画布、加载/错误反馈与顶底悬浮菜单装配层
class ReaderBodyView extends StatelessWidget {
  const ReaderBodyView({
    super.key,
    required this.pagerKey,
    required this.loading,
    required this.errorMsg,
    required this.menuVisible,
    required this.turnMode,
    required this.initialCharOffset,
    required this.paper,
    required this.config,
    required this.topSafe,
    required this.botSafe,
    required this.currentItem,
    required this.prevItem,
    required this.nextItem,
    required this.scrollBlocks,
    required this.chapterIndex,
    required this.totalChapters,
    required this.chapterTitles,
    required this.bookTitle,
    required this.chapterTitle,
    required this.inShelf,
    required this.onRetry,
    required this.onToggleMenu,
    required this.onCommitNext,
    required this.onCommitPrev,
    required this.onNeedAppendNextChapter,
    required this.onRequestPrevChapter,
    required this.onScrollChapterProgress,
    required this.onBack,
    required this.onOpenSource,
    required this.onAddToShelf,
    required this.onOpenDownload,
    required this.onJumpChapter,
    required this.onOpenCatalog,
    required this.onToggleDark,
    required this.onOpenTypography,
  });

  final GlobalKey<ReaderPagerViewsState> pagerKey;
  final bool loading;
  final String? errorMsg;
  final bool menuVisible;
  final PageTurnMode turnMode;
  final int initialCharOffset;
  final ReaderPaperTheme paper;
  final TypographyConfig config;
  final double topSafe;
  final double botSafe;
  final PageRenderItem? currentItem;
  final PageRenderItem? prevItem;
  final PageRenderItem? nextItem;
  final List<ChapterBlock> scrollBlocks;
  final int chapterIndex;
  final int totalChapters;
  final List<String> chapterTitles;
  final String bookTitle;
  final String chapterTitle;
  final bool inShelf;
  final VoidCallback onRetry;
  final VoidCallback onToggleMenu;
  final VoidCallback onCommitNext;
  final VoidCallback onCommitPrev;
  final VoidCallback onNeedAppendNextChapter;
  final VoidCallback onRequestPrevChapter;
  final void Function(int chapterIndex, int charOffset) onScrollChapterProgress;
  final VoidCallback onBack;
  final VoidCallback onOpenSource;
  final VoidCallback onAddToShelf;
  final VoidCallback onOpenDownload;
  final ValueChanged<int> onJumpChapter;
  final VoidCallback onOpenCatalog;
  final VoidCallback onToggleDark;
  final VoidCallback onOpenTypography;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (loading)
          Center(child: CircularProgressIndicator(color: paper.accent))
        else if (errorMsg != null || currentItem == null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggleMenu,
            child: EmptyErrorView(
              icon: Icons.wifi_off_rounded,
              title: '章节加载失败',
              description: errorMsg,
              actionLabel: '重新加载',
              onAction: onRetry,
            ),
          )
        else
          ReaderPagerViews(
            key: pagerKey,
            turnMode: turnMode,
            bookTitle: bookTitle,
            initialCharOffset: initialCharOffset,
            currentItem: currentItem!,
            prevItem: prevItem,
            nextItem: nextItem,
            scrollBlocks: scrollBlocks,
            config: config,
            theme: paper,
            hasPrevChapter: chapterIndex > 0,
            hasNextChapter: chapterIndex + 1 < totalChapters,
            onCommitNext: onCommitNext,
            onCommitPrev: onCommitPrev,
            onTapCenterMenu: onToggleMenu,
            onNeedAppendNextChapter: onNeedAppendNextChapter,
            onRequestPrevChapter: onRequestPrevChapter,
            onScrollChapterProgress: onScrollChapterProgress,
          ),
        if (menuVisible) ...[
          ReaderTopBar(
            paper: paper,
            topSafe: topSafe,
            bookTitle: bookTitle,
            chapterTitle: chapterTitle,
            inShelf: inShelf,
            onBack: onBack,
            onOpenSource: onOpenSource,
            onAddToShelf: onAddToShelf,
            onOpenDownload: onOpenDownload,
          ),
          ReaderBottomBar(
            paper: paper,
            botSafe: botSafe,
            chapterIndex: chapterIndex,
            totalChapters: totalChapters,
            chapterTitles: chapterTitles,
            onJumpChapter: onJumpChapter,
            onOpenCatalog: onOpenCatalog,
            onOpenSource: onOpenSource,
            onToggleDark: onToggleDark,
            onOpenTypography: onOpenTypography,
          ),
        ],
      ],
    );
  }
}
