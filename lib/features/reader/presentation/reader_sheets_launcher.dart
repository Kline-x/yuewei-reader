import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/storage/chapter_file_store.dart';
import '../../../design_system/feedback/app_feedback.dart';
import '../engine/reader_chapter_loader.dart';
import '../engine/reader_slide_window.dart';
import '../../tts/tts_control_sheet.dart';
import 'reader_bookmark_sheet.dart';
import 'reader_catalog_sheet.dart';
import 'reader_download_sheet.dart';
import 'reader_in_book_search_sheet.dart';
import 'reader_source_sheet.dart';
import 'reader_typography_sheet.dart';

/// 阅读器二级功能弹窗调度器（换源 / 缓存 / 目录 / 书签 / 搜索 / 排版 / 加书架）
class ReaderSheetsLauncher {
  const ReaderSheetsLauncher._();

  static Future<void> addToShelf({
    required BuildContext context,
    required WidgetRef ref,
    required AppDatabase db,
    required Book? book,
    required ValueChanged<Book?> onBookUpdated,
  }) async {
    if (book == null) return;
    if (book.isInShelf) {
      AppFeedback.showToast(context, '本书已在书架中');
      return;
    }
    await ref.read(shelfRepositoryProvider).setInShelf(book.id, true);
    final updated = await db.getBookById(book.id);
    if (!context.mounted) return;
    onBookUpdated(updated);
    AppFeedback.showToast(context, '已加入书架');
  }

  static Future<void> openSourceSheet({
    required BuildContext context,
    required WidgetRef ref,
    required AppDatabase db,
    required Book? book,
    required int currentChapterIndex,
    required String currentChapterTitle,
    required ReaderChapterLoader loader,
    required ReaderSlideWindow window,
    required Future<void> Function(Future<void> Function() task) runWithGuard,
    required Future<void> Function({
      required Book? updatedBook,
      required List<Chapter> updatedChapters,
      required int jumpIndex,
      required String ruleName,
    }) onSwitched,
  }) async {
    if (book == null) return;
    await runWithGuard(
      () => ReaderSourceSheet.show(
        context,
        bookTitle: book.title,
        bookAuthor: book.author,
        currentSourceId: book.sourceId,
        onSelectSource: (rule, hit, chapters) async {
          final newIdx = await ref.read(shelfRepositoryProvider).switchBookSource(
                bookId: book.id,
                newSourceId: rule.id,
                newBookUrl: hit.bookUrl,
                newTocUrl: hit.bookUrl,
                newChapters: chapters,
                preferredChapterTitle: currentChapterTitle,
                fallbackChapterIndex: currentChapterIndex,
              );
          loader.invalidateBook(book.id);
          window.clear();
          final updatedBook = await db.getBookById(book.id);
          final updatedChapters = await db.getChaptersByBook(book.id);
          await onSwitched(
            updatedBook: updatedBook,
            updatedChapters: updatedChapters,
            jumpIndex: newIdx,
            ruleName: rule.name,
          );
        },
      ),
    );
  }

  static Future<void> openDownloadSheet({
    required BuildContext context,
    required String bookId,
    required String bookTitle,
    required int totalChapters,
    required int currentChapterIndex,
    required Future<void> Function(Future<void> Function() task) runWithGuard,
  }) {
    return runWithGuard(
      () => ReaderDownloadSheet.show(
        context,
        bookId: bookId,
        bookTitle: bookTitle,
        totalChapters: totalChapters,
        currentChapterIndex: currentChapterIndex,
      ),
    );
  }

  static Future<void> openCatalogSheet({
    required BuildContext context,
    required List<Chapter> chapters,
    required int currentChapterIndex,
    required Future<void> Function(int idx) onSelectChapter,
    required Future<void> Function(Future<void> Function() task) runWithGuard,
  }) {
    return runWithGuard(
      () => ReaderCatalogSheet.show(
        context,
        chapters: chapters,
        currentChapterIndex: currentChapterIndex,
        onSelectChapter: (idx) => onSelectChapter(idx),
      ),
    );
  }

  static Future<void> openBookmarkSheet({
    required BuildContext context,
    required AppDatabase db,
    required String bookId,
    required int currentChapterIndex,
    required Future<void> Function(int chapterIndex, int charOffset) onSelectBookmark,
    required Future<void> Function(Future<void> Function() task) runWithGuard,
  }) {
    return runWithGuard(
      () => ReaderBookmarkSheet.show(
        context,
        db: db,
        bookId: bookId,
        currentChapterIndex: currentChapterIndex,
        onSelectBookmark: onSelectBookmark,
      ),
    );
  }

  static Future<void> openInBookSearchSheet({
    required BuildContext context,
    required String bookId,
    required List<Chapter> chapters,
    required ChapterFileStore fileStore,
    required bool isLocalBook,
    required Future<void> Function(int chapterIndex, int charOffset) onSelectHit,
    required Future<void> Function(Future<void> Function() task) runWithGuard,
  }) {
    return runWithGuard(
      () => ReaderInBookSearchSheet.show(
        context,
        bookId: bookId,
        chapters: chapters,
        fileStore: fileStore,
        isLocalBook: isLocalBook,
        onSelectHit: onSelectHit,
      ),
    );
  }

  static Future<void> openTypographySheet({
    required BuildContext context,
    required Future<void> Function(Future<void> Function() task) runWithGuard,
  }) {
    return runWithGuard(() => ReaderTypographySheet.show(context));
  }

  static Future<void> openTtsControlSheet({
    required BuildContext context,
    required Future<void> Function(Future<void> Function() task) runWithGuard,
  }) {
    return runWithGuard(() => TtsControlSheet.show(context));
  }
}
