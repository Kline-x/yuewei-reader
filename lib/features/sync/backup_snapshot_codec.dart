import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../../core/database/app_database.dart';
import '../../core/storage/chapter_file_store.dart';
import '../sources/domain/book_match_models.dart';
import '../sources/domain/book_source_rule.dart';

/// 快照恢复合并结果统计
@immutable
class BackupRestoreSummary {
  const BackupRestoreSummary({
    required this.booksMerged,
    required this.bookmarksAdded,
    required this.sourcesMerged,
  });
  final int booksMerged;
  final int bookmarksAdded;
  final int sourcesMerged;
}

/// 全量备份快照编解码与无损 LWW 合并服务（严控 <= 300 行）
class BackupSnapshotCodec {
  const BackupSnapshotCodec({required this.db});

  final AppDatabase db;
  static const int currentVersion = 1;

  static bool _isSyncablePrefKey(String key) =>
      !key.startsWith('webdav_') &&
      (key.startsWith('yuewei_theme_') ||
          key.startsWith('yuewei_tts_') ||
          key.startsWith('reader_') ||
          key.startsWith('shelf_') ||
          key.startsWith('tts_'));

  /// 导出当前书架元数据、阅读进度、书签、自定义书源与阅读主题偏好为 JSON 字符串
  /// 注意：本地书（sourceId == 'local_file'）仅导出元数据与进度，不含章节正文。
  Future<String> exportSnapshotJson() async {
    final shelfBooks = await db.getShelfBooks();
    final allBookmarks = await db.select(db.bookmarks).get();
    final customSources = await (db.select(db.bookSources)
          ..where((t) => t.isBuiltin.equals(false)))
        .get();
    final allPrefs = await db.select(db.appPreferences).get();
    final payload = <String, dynamic>{
      'version': currentVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'books': shelfBooks.map(_bookToMap).toList(),
      'bookmarks': allBookmarks.map(_bookmarkToMap).toList(),
      'customSources': customSources.map((s) => s.ruleJson).toList(),
      'preferences': <String, String>{
        for (final p in allPrefs)
          if (_isSyncablePrefKey(p.key)) p.key: p.value,
      },
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// 解析快照并与本地数据库执行 LWW 合并（绝不让较新的本地阅读进度倒退）
  Future<BackupRestoreSummary> mergeSnapshotJson(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('备份内容为空，请选择或粘贴有效的备份 JSON');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      throw const FormatException('备份 JSON 格式无效，请检查文件内容是否完整');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('备份数据结构无效：根节点必须为 JSON 对象');
    }
    final Map<String, dynamic> root = decoded;
    if (((root['version'] as num?)?.toInt() ?? 0) < 1) {
      throw const FormatException('不支持或缺失备份快照版本号，无法安全恢复');
    }

    var booksMerged = 0;
    var bookmarksAdded = 0;
    var sourcesMerged = 0;
    final skippedLocalBookIds = <String>{};

    await db.transaction(() async {
      final rawBooks = root['books'];
      if (rawBooks is List) {
        for (final item in rawBooks) {
          if (item is! Map) continue;
          final map = Map<String, dynamic>.from(item);
          final bookId = (map['id'] as String?)?.trim() ?? '';
          final sourceId = (map['sourceId'] as String?)?.trim() ?? '';
          if (bookId.isEmpty || sourceId.isEmpty) continue;

          final local = await db.getBookById(bookId);
          if (local == null) {
            if (sourceId == kLocalBookSourceId) {
              skippedLocalBookIds.add(bookId);
              continue;
            }
            await _insertMissingOnlineBook(map, bookId, sourceId);
            booksMerged++;
          } else if (await _mergeExistingBookLww(local, map)) {
            booksMerged++;
          }
        }
      }

      final rawBookmarks = root['bookmarks'];
      if (rawBookmarks is List) {
        final existing = await db.select(db.bookmarks).get();
        final seenKeys = <String>{
          for (final bm in existing) '${bm.bookId}|${bm.chapterIndex}|${bm.charOffset}',
        };
        for (final item in rawBookmarks) {
          if (item is! Map) continue;
          final map = Map<String, dynamic>.from(item);
          final bookId = (map['bookId'] as String?)?.trim() ?? '';
          final chapterIndex = (map['chapterIndex'] as num?)?.toInt();
          if (bookId.isEmpty || skippedLocalBookIds.contains(bookId)) continue;
          if (chapterIndex == null || chapterIndex < 0) continue;
          final charOffset = (map['charOffset'] as num?)?.toInt() ?? 0;
          if (!seenKeys.add('$bookId|$chapterIndex|$charOffset')) continue;
          await db.into(db.bookmarks).insert(BookmarksCompanion.insert(
                bookId: bookId,
                chapterIndex: chapterIndex,
                chapterTitle: (map['chapterTitle'] as String?) ?? '',
                charOffset: Value(charOffset),
                excerpt: Value(((map['excerpt'] as String?) ?? '').trim()),
                createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
              ));
          bookmarksAdded++;
        }
      }

      final rawSources = root['customSources'];
      if (rawSources is List) {
        final builtinIds = <String>{
          for (final r in await (db.select(db.bookSources)..where((t) => t.isBuiltin.equals(true))).get()) r.id,
        };
        for (final item in rawSources) {
          final r = _parseCustomSourceRule(item);
          if (r == null || r.id.isEmpty || builtinIds.contains(r.id)) continue;
          final norm = BookSourceRule(
            id: r.id, name: r.name, baseUrl: r.baseUrl, groupName: r.groupName,
            charset: r.charset, enabled: r.enabled, isBuiltin: false,
            search: r.search, detail: r.detail, toc: r.toc, chapter: r.chapter,
          );
          await db.into(db.bookSources).insertOnConflictUpdate(BookSourcesCompanion.insert(
                id: norm.id, name: norm.name, baseUrl: norm.baseUrl,
                groupName: Value(norm.groupName), charset: Value(norm.charset),
                enabled: Value(norm.enabled), isBuiltin: const Value(false),
                ruleJson: norm.toJsonString(), healthScore: const Value(90),
              ));
          sourcesMerged++;
        }
      }

      final rawPrefs = root['preferences'];
      if (rawPrefs is Map) {
        for (final entry in rawPrefs.entries) {
          final k = entry.key.toString();
          final v = entry.value?.toString();
          if (v != null && _isSyncablePrefKey(k)) await db.setPreference(k, v);
        }
      }
    });

    return BackupRestoreSummary(
      booksMerged: booksMerged,
      bookmarksAdded: bookmarksAdded,
      sourcesMerged: sourcesMerged,
    );
  }

  Future<void> _insertMissingOnlineBook(
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
      lastReadAt: Value(_parseDate(m['lastReadAt'])),
      addedAt: Value(_parseDate(m['addedAt']) ?? now),
      updatedAt: _parseDate(m['updatedAt']) ?? now,
    ));
  }

  Future<bool> _mergeExistingBookLww(Book local, Map<String, dynamic> remote) async {
    final remoteTs = _parseDate(remote['lastReadAt']) ??
        _parseDate(remote['updatedAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final localTs = local.lastReadAt ?? local.updatedAt;
    if (!remoteTs.isAfter(localTs)) {
      if (!local.isInShelf) {
        await (db.update(db.books)..where((t) => t.id.equals(local.id)))
            .write(const BooksCompanion(isInShelf: Value(true)));
        return true;
      }
      return false;
    }
    await (db.update(db.books)..where((t) => t.id.equals(local.id))).write(BooksCompanion(
      currentChapterIndex:
          Value((remote['currentChapterIndex'] as num?)?.toInt() ?? local.currentChapterIndex),
      currentChapterTitle:
          Value((remote['currentChapterTitle'] as String?) ?? local.currentChapterTitle),
      currentCharOffset:
          Value((remote['currentCharOffset'] as num?)?.toInt() ?? local.currentCharOffset),
      hasEverRead: Value(((remote['hasEverRead'] as bool?) ?? false) || local.hasEverRead),
      isPinned: Value((remote['isPinned'] as bool?) ?? local.isPinned),
      isInShelf: const Value(true),
      lastReadAt: Value(_parseDate(remote['lastReadAt']) ?? local.lastReadAt),
      updatedAt: Value(_parseDate(remote['updatedAt']) ?? remoteTs),
    ));
    return true;
  }

  static BookSourceRule? _parseCustomSourceRule(Object? item) {
    try {
      if (item is String && item.trim().isNotEmpty) return BookSourceRule.fromJsonString(item);
      if (item is Map) {
        final m = Map<String, dynamic>.from(item);
        return m['ruleJson'] is String
            ? BookSourceRule.fromJsonString(m['ruleJson'] as String)
            : BookSourceRule.fromJson(m);
      }
    } catch (_) {}
    return null;
  }

  static DateTime? _parseDate(Object? raw) =>
      raw is String && raw.isNotEmpty ? DateTime.tryParse(raw)?.toLocal() : null;

  static Map<String, dynamic> _bookToMap(Book b) {
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

  static Map<String, dynamic> _bookmarkToMap(Bookmark bm) => {
        'bookId': bm.bookId,
        'chapterIndex': bm.chapterIndex,
        'chapterTitle': bm.chapterTitle,
        'charOffset': bm.charOffset,
        'excerpt': bm.excerpt,
        'createdAt': bm.createdAt.toUtc().toIso8601String(),
      };
}
