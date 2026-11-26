import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';
import '../../core/storage/chapter_file_store.dart';
import '../sources/domain/book_match_models.dart';
import '../sources/domain/book_source_rule.dart';

/// 备份快照序列化与 LWW 无损冲突解决辅助工具（与 BackupSnapshotCodec 解耦严控 <= 220 行）
class BackupSnapshotLww {
  const BackupSnapshotLww._();

  static DateTime? parseDate(Object? raw) =>
      raw is String && raw.isNotEmpty ? DateTime.tryParse(raw)?.toLocal() : null;

  /// 取 lastReadAt 与 updatedAt 较晚者作为实体有效时间戳（兼顾换源、移出书架与阅读推进）
  static DateTime effectiveTimestamp(DateTime? lastReadAt, DateTime? updatedAt) {
    if (lastReadAt == null) {
      return updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    if (updatedAt == null) return lastReadAt;
    return updatedAt.isAfter(lastReadAt) ? updatedAt : lastReadAt;
  }

  static String _pickNonEmpty(Object? raw, String fallback) {
    final s = (raw as String?)?.trim() ?? '';
    return s.isNotEmpty ? s : fallback;
  }

  static Future<void> insertMissingOnlineBook(
    AppDatabase db,
    Map<String, dynamic> m,
    String bookId,
    String sourceId,
  ) async {
    final rawTitle = ((m['title'] as String?) ?? '').trim();
    final safeTitle = rawTitle.isEmpty ? '未命名书籍' : rawTitle;
    final clean = ((m['cleanTitle'] as String?) ?? '').trim();
    final now = DateTime.now();
    await db.upsertBook(BooksCompanion.insert(
      id: bookId,
      title: safeTitle,
      cleanTitle: clean.isNotEmpty ? clean : SourceSearchHit.normalizeBookKey(safeTitle),
      author: Value((m['author'] as String?) ?? ''),
      coverUrl: Value((m['coverUrl'] as String?) ?? ''),
      intro: Value((m['intro'] as String?) ?? ''),
      category: Value((m['category'] as String?) ?? ''),
      statusText: Value((m['statusText'] as String?) ?? '连载中'),
      latestChapterTitle: Value((m['latestChapterTitle'] as String?) ?? ''),
      lastUpdateTime: Value((m['lastUpdateTime'] as String?) ?? ''),
      sourceId: sourceId,
      bookUrl: (m['bookUrl'] as String?) ?? '',
      tocUrl: Value((m['tocUrl'] as String?) ?? ''),
      totalChapters: Value((m['totalChapters'] as num?)?.toInt() ?? 0),
      currentChapterIndex: Value((m['currentChapterIndex'] as num?)?.toInt() ?? 0),
      currentChapterTitle: Value((m['currentChapterTitle'] as String?) ?? ''),
      currentCharOffset: Value((m['currentCharOffset'] as num?)?.toInt() ?? 0),
      hasEverRead: Value((m['hasEverRead'] as bool?) ?? false),
      isPinned: Value((m['isPinned'] as bool?) ?? false),
      isInShelf: const Value(true),
      hasUnreadUpdate: Value((m['hasUnreadUpdate'] as bool?) ?? false),
      lastReadAt: Value(parseDate(m['lastReadAt'])),
      addedAt: Value(parseDate(m['addedAt']) ?? now),
      updatedAt: parseDate(m['updatedAt']) ?? now,
    ));
  }

  /// 判定远端书目记录在 LWW 下是否应胜出本地记录：
  /// - 若本地已移出书架，对比 max(lastReadAt, updatedAt)，防旧快照复活已删除书籍；
  /// - 若本地仍在书架，以最近阅读时间 lastReadAt 为首要基准，避免后台追更刷新 updatedAt 阻塞云端新进度。
  static bool shouldRemoteWin(
    Book local,
    DateTime? remoteLastRead,
    DateTime? remoteUpdated,
  ) {
    final remoteTs = effectiveTimestamp(remoteLastRead, remoteUpdated);
    if (!local.isInShelf) {
      final localTs = effectiveTimestamp(local.lastReadAt, local.updatedAt);
      return remoteTs.isAfter(localTs);
    }
    final localRead = local.lastReadAt;
    if (remoteLastRead != null && localRead != null) {
      if (remoteLastRead.isAfter(localRead)) return true;
      if (localRead.isAfter(remoteLastRead)) return false;
      return (remoteUpdated ?? remoteLastRead).isAfter(local.updatedAt);
    }
    if (remoteLastRead != null && localRead == null) return true;
    if (remoteLastRead == null && localRead != null) return false;
    final localTs = effectiveTimestamp(localRead, local.updatedAt);
    return remoteTs.isAfter(localTs);
  }

  /// 对已存在书籍执行 LWW 合并：
  /// 1. 若未胜出，尊重本地状态（含本地移出书架状态，绝不强行复活）。
  /// 2. 若远端胜出，在线书同步源信息与全量元数据，换源时清空旧 chapters 防 clamp 倒退。
  static Future<bool> mergeExistingBookLww(
    AppDatabase db,
    Book local,
    Map<String, dynamic> remote,
  ) async {
    final remoteLastRead = parseDate(remote['lastReadAt']);
    final remoteUpdated = parseDate(remote['updatedAt']);
    final remoteTs = effectiveTimestamp(remoteLastRead, remoteUpdated);

    if (!shouldRemoteWin(local, remoteLastRead, remoteUpdated)) {
      return false;
    }

    final isLocalBook = local.sourceId == kLocalBookSourceId;
    final nextSourceId = isLocalBook
        ? local.sourceId
        : _pickNonEmpty(remote['sourceId'], local.sourceId);
    final nextBookUrl = isLocalBook
        ? local.bookUrl
        : _pickNonEmpty(remote['bookUrl'], local.bookUrl);
    final sourceChanged = !isLocalBook &&
        (nextSourceId != local.sourceId || nextBookUrl != local.bookUrl);
    final rawRemoteToc = (remote['tocUrl'] as String?)?.trim() ?? '';
    final nextTocUrl = isLocalBook
        ? local.tocUrl
        : (sourceChanged
            ? (rawRemoteToc.isNotEmpty ? rawRemoteToc : nextBookUrl)
            : (rawRemoteToc.isNotEmpty ? rawRemoteToc : local.tocUrl));

    if (sourceChanged) {
      await (db.delete(db.chapters)..where((t) => t.bookId.equals(local.id))).go();
    }

    final remoteTotal = (remote['totalChapters'] as num?)?.toInt();
    final nextTotal = isLocalBook
        ? local.totalChapters
        : (remoteTotal != null && (sourceChanged || remoteTotal > 0)
            ? remoteTotal
            : local.totalChapters);

    await (db.update(db.books)..where((t) => t.id.equals(local.id))).write(
      BooksCompanion(
        sourceId: Value(nextSourceId),
        bookUrl: Value(nextBookUrl),
        tocUrl: Value(nextTocUrl),
        totalChapters: Value(nextTotal),
        latestChapterTitle: Value(
          _pickNonEmpty(remote['latestChapterTitle'], local.latestChapterTitle),
        ),
        lastUpdateTime: Value(
          _pickNonEmpty(remote['lastUpdateTime'], local.lastUpdateTime),
        ),
        statusText: Value(_pickNonEmpty(remote['statusText'], local.statusText)),
        category: Value(_pickNonEmpty(remote['category'], local.category)),
        intro: Value(_pickNonEmpty(remote['intro'], local.intro)),
        coverUrl: Value(
          isLocalBook
              ? local.coverUrl
              : _pickNonEmpty(remote['coverUrl'], local.coverUrl),
        ),
        currentChapterIndex: Value(
          (remote['currentChapterIndex'] as num?)?.toInt() ??
              local.currentChapterIndex,
        ),
        currentChapterTitle: Value(
          (remote['currentChapterTitle'] as String?) ?? local.currentChapterTitle,
        ),
        currentCharOffset: Value(
          (remote['currentCharOffset'] as num?)?.toInt() ??
              local.currentCharOffset,
        ),
        hasEverRead: Value(
          ((remote['hasEverRead'] as bool?) ?? false) || local.hasEverRead,
        ),
        isPinned: Value((remote['isPinned'] as bool?) ?? local.isPinned),
        isInShelf: Value((remote['isInShelf'] as bool?) ?? true),
        lastReadAt: Value(remoteLastRead ?? local.lastReadAt),
        updatedAt: Value(remoteUpdated ?? remoteTs),
      ),
    );
    return true;
  }

  static BookSourceRule? parseCustomSourceRule(Object? item) {
    try {
      if (item is String && item.trim().isNotEmpty) {
        return BookSourceRule.fromJsonString(item);
      }
      if (item is Map) {
        final m = Map<String, dynamic>.from(item);
        return m['ruleJson'] is String
            ? BookSourceRule.fromJsonString(m['ruleJson'] as String)
            : BookSourceRule.fromJson(m);
      }
    } catch (_) {}
    return null;
  }

  static Map<String, dynamic> bookToMap(Book b) {
    final isLocal = b.sourceId == kLocalBookSourceId;
    return {
      'id': b.id,
      'title': b.title,
      'cleanTitle': b.cleanTitle,
      'author': b.author,
      'coverUrl': isLocal ? '' : b.coverUrl,
      'intro': b.intro,
      'category': b.category,
      'statusText': b.statusText,
      'latestChapterTitle': b.latestChapterTitle,
      'lastUpdateTime': b.lastUpdateTime,
      'sourceId': b.sourceId,
      'bookUrl': isLocal ? 'local://${b.id}' : b.bookUrl,
      'tocUrl': isLocal ? '' : b.tocUrl,
      'totalChapters': b.totalChapters,
      'currentChapterIndex': b.currentChapterIndex,
      'currentChapterTitle': b.currentChapterTitle,
      'currentCharOffset': b.currentCharOffset,
      'hasEverRead': b.hasEverRead,
      'isPinned': b.isPinned,
      'isInShelf': b.isInShelf,
      'hasUnreadUpdate': b.hasUnreadUpdate,
      'lastReadAt': b.lastReadAt?.toUtc().toIso8601String(),
      'addedAt': b.addedAt?.toUtc().toIso8601String(),
      'updatedAt': b.updatedAt.toUtc().toIso8601String(),
    };
  }

  static Map<String, dynamic> bookmarkToMap(Bookmark bm) => {
        'bookId': bm.bookId,
        'chapterIndex': bm.chapterIndex,
        'chapterTitle': bm.chapterTitle,
        'charOffset': bm.charOffset,
        'excerpt': bm.excerpt,
        'createdAt': bm.createdAt.toUtc().toIso8601String(),
      };
}
