import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../../core/database/app_database.dart';
import '../../core/storage/chapter_file_store.dart';
import '../sources/domain/book_source_rule.dart';
import 'backup_snapshot_lww.dart';

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

/// 全量备份快照编解码与无损 LWW 合并服务（严控 <= 220 行）
class BackupSnapshotCodec {
  const BackupSnapshotCodec({required this.db});

  final AppDatabase db;
  static const int currentVersion = 1;

  /// 导出当前书架元数据、阅读进度、在架书签、自定义书源与阅读主题偏好为 JSON 字符串
  /// 注意：仅导出 isInShelf == true 书籍对应的书签；本地书仅导出元数据与进度，不含正文。
  Future<String> exportSnapshotJson() async {
    final shelfBooks = await db.getShelfBooks();
    final shelfBookIds = shelfBooks.map((b) => b.id).toSet();
    final shelfBookmarks = shelfBookIds.isEmpty
        ? const <Bookmark>[]
        : await (db.select(db.bookmarks)
              ..where((t) => t.bookId.isIn(shelfBookIds)))
            .get();
    final customSources = await (db.select(db.bookSources)
          ..where((t) => t.isBuiltin.equals(false)))
        .get();
    final allPrefs = await db.select(db.appPreferences).get();
    final payload = <String, dynamic>{
      'version': currentVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'books': shelfBooks.map(BackupSnapshotLww.bookToMap).toList(),
      'bookmarks': shelfBookmarks.map(BackupSnapshotLww.bookmarkToMap).toList(),
      'customSources': customSources.map((s) => s.ruleJson).toList(),
      'preferences': <String, String>{
        for (final p in allPrefs)
          if (AppDatabase.isSyncablePreferenceKey(p.key)) p.key: p.value,
      },
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// 解析快照并与本地数据库执行 LWW 合并（防进度倒退、防复活移出书、防旧备份盲覆设置）
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

    final remoteExportedAt = BackupSnapshotLww.parseDate(root['exportedAt']);
    var booksMerged = 0;
    var bookmarksAdded = 0;
    var sourcesMerged = 0;
    final skippedBookIds = <String>{};

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
              skippedBookIds.add(bookId);
              continue;
            }
            await BackupSnapshotLww.insertMissingOnlineBook(db, map, bookId, sourceId);
            booksMerged++;
          } else {
            final merged = await BackupSnapshotLww.mergeExistingBookLww(db, local, map);
            if (merged) {
              booksMerged++;
            } else if (!local.isInShelf) {
              skippedBookIds.add(bookId);
            }
          }
        }
      }

      bookmarksAdded = await _mergeBookmarks(root['bookmarks'], skippedBookIds);
      sourcesMerged = await _mergeCustomSources(root['customSources'], remoteExportedAt);
      await _mergePreferences(root['preferences'], remoteExportedAt);
    });

    return BackupRestoreSummary(
      booksMerged: booksMerged,
      bookmarksAdded: bookmarksAdded,
      sourcesMerged: sourcesMerged,
    );
  }

  Future<int> _mergeBookmarks(Object? rawBookmarks, Set<String> skippedBookIds) async {
    if (rawBookmarks is! List) return 0;
    final existing = await db.select(db.bookmarks).get();
    final seenKeys = <String>{
      for (final bm in existing) '${bm.bookId}|${bm.chapterIndex}|${bm.charOffset}',
    };
    var added = 0;
    for (final item in rawBookmarks) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final bookId = (map['bookId'] as String?)?.trim() ?? '';
      final chapterIndex = (map['chapterIndex'] as num?)?.toInt();
      if (bookId.isEmpty || skippedBookIds.contains(bookId)) continue;
      if (chapterIndex == null || chapterIndex < 0) continue;
      final charOffset = (map['charOffset'] as num?)?.toInt() ?? 0;
      if (!seenKeys.add('$bookId|$chapterIndex|$charOffset')) continue;
      await db.into(db.bookmarks).insert(BookmarksCompanion.insert(
            bookId: bookId,
            chapterIndex: chapterIndex,
            chapterTitle: (map['chapterTitle'] as String?) ?? '',
            charOffset: Value(charOffset),
            excerpt: Value(((map['excerpt'] as String?) ?? '').trim()),
            createdAt: BackupSnapshotLww.parseDate(map['createdAt']) ?? DateTime.now(),
          ));
      added++;
    }
    return added;
  }

  Future<int> _mergeCustomSources(Object? rawSources, DateTime? remoteExportedAt) async {
    if (rawSources is! List) return 0;
    final allSources = await db.select(db.bookSources).get();
    final builtinIds = <String>{for (final s in allSources) if (s.isBuiltin) s.id};
    final existingCustom = <String, BookSource>{
      for (final s in allSources) if (!s.isBuiltin) s.id: s,
    };
    final localSourcesTs = BackupSnapshotLww.parseDate(
      await db.getPreference(AppDatabase.syncSourcesUpdatedAtKey),
    );
    final localPrefsTs = BackupSnapshotLww.parseDate(
      await db.getPreference(AppDatabase.syncPrefsUpdatedAtKey),
    );
    final baselineTs = localSourcesTs ?? localPrefsTs;
    final canOverwriteExisting = remoteExportedAt == null ||
        baselineTs == null ||
        remoteExportedAt.isAfter(baselineTs);

    var merged = 0;
    for (final item in rawSources) {
      final r = BackupSnapshotLww.parseCustomSourceRule(item);
      if (r == null || r.id.isEmpty || builtinIds.contains(r.id)) continue;
      final prev = existingCustom[r.id];
      if (prev != null) {
        final checkedNewer = prev.lastCheckedAt != null &&
            remoteExportedAt != null &&
            !remoteExportedAt.isAfter(prev.lastCheckedAt!);
        if (!canOverwriteExisting || checkedNewer) continue;
      }
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
      merged++;
    }
    if (remoteExportedAt != null &&
        (localSourcesTs == null || remoteExportedAt.isAfter(localSourcesTs))) {
      await db.setPreference(
        AppDatabase.syncSourcesUpdatedAtKey,
        remoteExportedAt.toUtc().toIso8601String(),
        touchSyncTimestamp: false,
      );
    }
    return merged;
  }

  Future<void> _mergePreferences(Object? rawPrefs, DateTime? remoteExportedAt) async {
    if (rawPrefs is! Map) return;
    final existingRows = await db.select(db.appPreferences).get();
    final existingMap = <String, String>{for (final r in existingRows) r.key: r.value};
    final localPrefsTs = BackupSnapshotLww.parseDate(
      existingMap[AppDatabase.syncPrefsUpdatedAtKey],
    );
    final canOverwrite = remoteExportedAt == null ||
        localPrefsTs == null ||
        remoteExportedAt.isAfter(localPrefsTs);

    for (final entry in rawPrefs.entries) {
      final k = entry.key.toString();
      final v = entry.value?.toString();
      if (v == null || !AppDatabase.isSyncablePreferenceKey(k)) continue;
      if (existingMap.containsKey(k) && !canOverwrite) continue;
      await db.setPreference(k, v, touchSyncTimestamp: false);
    }
    if (remoteExportedAt != null &&
        (localPrefsTs == null || remoteExportedAt.isAfter(localPrefsTs))) {
      await db.setPreference(
        AppDatabase.syncPrefsUpdatedAtKey,
        remoteExportedAt.toUtc().toIso8601String(),
        touchSyncTimestamp: false,
      );
    }
  }
}
