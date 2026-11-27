import 'package:flutter/widgets.dart';
import '../../../design_system/feedback/app_feedback.dart';
import '../../tts/tts_controller.dart';
import '../engine/reader_page_slot.dart';
import 'reader_session_controller.dart';
import 'reader_sheets_launcher.dart';

/// 阅读器与沉浸 TTS 状态机的双向装配辅助器
class ReaderTtsBinding {
  const ReaderTtsBinding._();

  static void attach({
    required Object owner,
    required TtsController tts,
    required ReaderSessionController session,
    TtsLocateCallback? onLocate,
  }) {
    tts.bindReader(
      owner: owner,
      onLocate: onLocate ??
          (chIdx, offset) =>
              session.jumpToLocation(chIdx, offset, animateScroll: true),
      onRequestChapter: (targetIdx) async {
        if (targetIdx < 0 || targetIdx >= session.chapters.length) return null;
        await session.loadChapter(targetIdx);
        if (session.loading ||
            session.errorMsg != null ||
            session.chapterIndex != targetIdx ||
            session.paragraphs.isEmpty) {
          return null;
        }
        return (
          chapterIndex: targetIdx,
          chapterTitle: session.currentChapterTitle,
          paragraphs: session.paragraphs,
          totalChapters: session.chapters.length,
        );
      },
    );
  }

  static int resolveStartParagraph({
    required List<String> paragraphs,
    required PageRenderItem? currentItem,
    required int charAnchorOffset,
    required bool isScrollMode,
  }) {
    if (!isScrollMode && currentItem != null && currentItem.page.lines.isNotEmpty) {
      return currentItem.page.lines.first.paragraphIndex.clamp(0, paragraphs.length - 1);
    }
    return TtsController.paragraphIndexAtCharOffset(paragraphs, charAnchorOffset);
  }

  static Future<void> onTapHeadphone({
    required BuildContext context,
    required TtsState ttsState,
    required TtsController ttsNotifier,
    required ReaderSessionController session,
    required PageRenderItem? currentItem,
    required bool isScrollMode,
    required ValueChanged<bool> setMenuVisible,
    required Future<void> Function(Future<void> Function() task) runWithGuard,
  }) async {
    if (session.loading || session.paragraphs.isEmpty) {
      AppFeedback.showToast(context, '当前章节内容尚未就绪');
      return;
    }
    setMenuVisible(false);
    if (ttsState.isActive && ttsState.bookId == session.bookId) {
      await ReaderSheetsLauncher.openTtsControlSheet(
        context: context,
        runWithGuard: runWithGuard,
      );
      return;
    }
    final startPara = resolveStartParagraph(
      paragraphs: session.paragraphs,
      currentItem: currentItem,
      charAnchorOffset: session.charAnchorOffset,
      isScrollMode: isScrollMode,
    );
    final ok = await ttsNotifier.startReading(
      bookId: session.bookId,
      chapterIndex: session.chapterIndex,
      chapterTitle: session.currentChapterTitle,
      paragraphs: session.paragraphs,
      startParagraphIndex: startPara,
      totalChapters: session.chapters.length,
    );
    if (!context.mounted) return;
    if (!ok) {
      AppFeedback.showToast(context, '当前设备语音朗读引擎不可用', isError: true);
      return;
    }
    await ReaderSheetsLauncher.openTtsControlSheet(
      context: context,
      runWithGuard: runWithGuard,
    );
  }
}
