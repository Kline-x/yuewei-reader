import 'package:flutter/widgets.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/bookmark_dao.dart';
import '../../../design_system/feedback/app_feedback.dart';
import '../engine/reader_page_slot.dart';

/// 阅读器字符级书签辅助器（分页区间/滚动窗口查重、48 字摘录清洗与快速切换）
class ReaderBookmarkHelper {
  const ReaderBookmarkHelper._();

  static const int scrollMatchWindow = 120;
  static const int maxExcerptLength = 48;

  /// 匹配当前阅读位置是否已存在书签
  static Bookmark? findMatchingBookmark({
    required List<Bookmark> bookmarks,
    required int chapterIndex,
    PageRenderItem? currentItem,
    required int charAnchorOffset,
    bool isScrollMode = false,
  }) {
    if (bookmarks.isEmpty) return null;
    if (!isScrollMode && currentItem != null) {
      final start = currentItem.page.charStart;
      final end = currentItem.page.charEnd;
      for (final b in bookmarks) {
        if (b.chapterIndex != chapterIndex) continue;
        final hit = end > start ? (b.charOffset >= start && b.charOffset < end) : b.charOffset == start;
        if (hit) return b;
      }
      return null;
    }
    Bookmark? nearest;
    var bestDist = scrollMatchWindow + 1;
    for (final b in bookmarks) {
      if (b.chapterIndex != chapterIndex) continue;
      final dist = (b.charOffset - charAnchorOffset).abs();
      if (dist <= scrollMatchWindow && dist < bestDist) {
        bestDist = dist;
        nearest = b;
      }
    }
    return nearest;
  }

  /// 清洗摘录：去掉全角缩进与多余空行，安全截取前 48 字（不拆断 Emoji/生僻字）
  static String cleanExcerpt(String raw, {int maxChars = maxExcerptLength}) {
    final cleaned = raw
        .replaceAll('\u3000', '')
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();
    if (cleaned.isEmpty) return '';
    final chars = cleaned.characters;
    return chars.length <= maxChars ? cleaned : chars.take(maxChars).toString().trimRight();
  }

  /// 计算当前阅读位置应当写入书签的精确字符偏移
  static int resolveCharOffset({PageRenderItem? currentItem, int charAnchorOffset = 0, bool isScrollMode = false}) {
    if (!isScrollMode && currentItem != null) return currentItem.page.charStart;
    return charAnchorOffset < 0 ? 0 : charAnchorOffset;
  }

  /// 抽取当前页首行或滚动锚点位置起干净的前 48 字摘录
  static String extractExcerpt({
    PageRenderItem? currentItem,
    List<String> paragraphs = const [],
    int charAnchorOffset = 0,
    String fallbackTitle = '',
    bool isScrollMode = false,
    int maxChars = maxExcerptLength,
  }) {
    if (!isScrollMode && currentItem != null && currentItem.page.lines.isNotEmpty) {
      final buf = StringBuffer();
      for (final line in currentItem.page.lines) {
        buf.write(line.text);
        if (line.isLastLineOfPara) buf.write('\n');
      }
      final fromPage = cleanExcerpt(buf.toString(), maxChars: maxChars);
      if (fromPage.isNotEmpty) return fromPage;
    }
    if (paragraphs.isNotEmpty) {
      final joined = paragraphs.join('\n');
      var safe = charAnchorOffset.clamp(0, joined.length);
      if (safe > 0 && safe < joined.length && joined.codeUnitAt(safe) >= 0xDC00 && joined.codeUnitAt(safe) <= 0xDFFF) {
        safe--;
      }
      final end = (safe + 220).clamp(0, joined.length);
      final fromOffset = cleanExcerpt(joined.substring(safe, end), maxChars: maxChars);
      if (fromOffset.isNotEmpty) return fromOffset;
    }
    return cleanExcerpt(fallbackTitle, maxChars: maxChars);
  }

  /// 切换当前阅读位置书签：已存在则移除，否则写入精确 charOffset 并提示
  static Future<bool> toggleCurrentBookmark({
    BuildContext? context,
    required AppDatabase db,
    required String bookId,
    required int chapterIndex,
    required String chapterTitle,
    List<Bookmark>? existingBookmarks,
    PageRenderItem? currentItem,
    List<String> paragraphs = const [],
    int charAnchorOffset = 0,
    bool isScrollMode = false,
  }) async {
    final list = existingBookmarks ?? await db.getBookmarksByBook(bookId);
    final match = findMatchingBookmark(
      bookmarks: list, chapterIndex: chapterIndex, currentItem: currentItem,
      charAnchorOffset: charAnchorOffset, isScrollMode: isScrollMode,
    );
    if (match != null) {
      await db.deleteBookmark(match.id);
      if (context != null && context.mounted) AppFeedback.showToast(context, '已移除本页书签');
      return false;
    }
    final offset = resolveCharOffset(currentItem: currentItem, charAnchorOffset: charAnchorOffset, isScrollMode: isScrollMode);
    final excerpt = extractExcerpt(
      currentItem: currentItem, paragraphs: paragraphs,
      charAnchorOffset: charAnchorOffset, fallbackTitle: chapterTitle, isScrollMode: isScrollMode,
    );
    await db.addBookmark(
      bookId: bookId, chapterIndex: chapterIndex, chapterTitle: chapterTitle,
      charOffset: offset, excerpt: excerpt,
    );
    if (context != null && context.mounted) AppFeedback.showToast(context, '已添加书签');
    return true;
  }
}
