import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuewei_reader/core/database/app_database.dart';
import 'package:yuewei_reader/core/database/bookmark_dao.dart';
import 'package:yuewei_reader/core/network/app_http_client.dart';
import 'package:yuewei_reader/core/storage/chapter_file_store.dart';
import 'package:yuewei_reader/features/sources/data/source_repository.dart';
import 'package:yuewei_reader/features/sync/backup_snapshot_codec.dart';
import 'package:yuewei_reader/features/sync/webdav_sync_client.dart';
import 'package:yuewei_reader/features/sync/webdav_sync_coordinator.dart';

const String _sampleLegadoJson = '['
    '{"bookSourceName":"云雾书院","bookSourceUrl":"https://yunwu.example.com","bookSourceGroup":"测试分组","enabled":true,"searchUrl":"/search?q={{key}}","ruleSearch":{"bookList":".item","name":".title","author":".author","bookUrl":"a@href"},"ruleToc":{"chapterList":".toc li a","chapterName":"text","chapterUrl":"href"},"ruleContent":{"content":"#content"}},'
    '{"bookSourceName":"星河文学","bookSourceUrl":"https://xinghe.example.com","bookSourceGroup":"测试分组","enabled":true,"searchUrl":"/s?k={{key}}","ruleSearch":{"bookList":".book","name":"h3","author":".au","bookUrl":"a@href"},"ruleToc":{"chapterList":"#list a","chapterName":"text","chapterUrl":"href"},"ruleContent":{"content":".txt"}}'
    ']';

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  group('M3 备份快照编解码与 LWW 防倒退合并测试', () {
    late AppDatabase dbA;
    late AppDatabase dbB;

    setUp(() {
      dbA = AppDatabase(NativeDatabase.memory());
      dbB = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await dbA.close();
      await dbB.close();
    });

    test('快照导出->新库恢复、LWW 防进度倒退、本地书隔离、书签去重与自定义书源合并', () async {
      final t1 = DateTime.utc(2026, 11, 24, 10, 0);
      final t2 = DateTime.utc(2026, 11, 24, 12, 0);

      await dbA.upsertBook(BooksCompanion.insert(
        id: 'online_book_1', title: '雪中悍刀行', cleanTitle: '雪中悍刀行',
        author: const drift.Value('烽火戏诸侯'), sourceId: 'builtin_1',
        bookUrl: 'https://a.test/book/1', totalChapters: const drift.Value(120),
        currentChapterIndex: const drift.Value(5), currentChapterTitle: const drift.Value('第六章 风雪'),
        currentCharOffset: const drift.Value(180), hasEverRead: const drift.Value(true),
        isPinned: const drift.Value(true), isInShelf: const drift.Value(true),
        lastReadAt: drift.Value(t1), updatedAt: t1,
      ));
      await dbA.upsertBook(BooksCompanion.insert(
        id: 'local_book_1', title: '本地秘籍', cleanTitle: '本地秘籍',
        coverUrl: const drift.Value('/device_a/cover.jpg'), sourceId: kLocalBookSourceId,
        bookUrl: '/device_a/book.txt', totalChapters: const drift.Value(30),
        currentChapterIndex: const drift.Value(8), currentChapterTitle: const drift.Value('第九章'),
        currentCharOffset: const drift.Value(66), hasEverRead: const drift.Value(true),
        isInShelf: const drift.Value(true), lastReadAt: drift.Value(t2), updatedAt: t2,
      ));
      // 非书架书籍及孤儿书签：导出时必须自动过滤
      await dbA.upsertBook(BooksCompanion.insert(
        id: 'off_shelf_book', title: '移出书', cleanTitle: '移出书',
        sourceId: 'builtin_1', bookUrl: 'https://a.test/off',
        isInShelf: const drift.Value(false), updatedAt: t1,
      ));
      await dbA.addBookmark(bookId: 'online_book_1', chapterIndex: 5, chapterTitle: '第六章 风雪', charOffset: 180, excerpt: '摘录一');
      await dbA.addBookmark(bookId: 'local_book_1', chapterIndex: 8, chapterTitle: '第九章', charOffset: 66, excerpt: '本地书签');
      await dbA.addBookmark(bookId: 'off_shelf_book', chapterIndex: 0, chapterTitle: '非在架', charOffset: 1);
      await dbA.addBookmark(bookId: 'orphan_book_id', chapterIndex: 0, chapterTitle: '孤儿', charOffset: 1);

      final repoA = SourceRepository(db: dbA, httpClient: AppHttpClient());
      await repoA.importLegadoJson(_sampleLegadoJson);
      await dbA.setPreference('reader_font_size', '22.0');
      await dbA.setPreference('yuewei_tts_speech_rate', '1.75');
      await dbA.setPreference('webdav_password_obf', 'obf1:secret');

      final snapshot = await BackupSnapshotCodec(db: dbA).exportSnapshotJson();
      expect(snapshot.contains('webdav_password_obf'), isFalse);
      expect(snapshot.contains('yuewei_tts_speech_rate'), isTrue);
      expect(snapshot.contains('off_shelf_book'), isFalse);
      expect(snapshot.contains('orphan_book_id'), isFalse);

      final codecB = BackupSnapshotCodec(db: dbB);
      final s1 = await codecB.mergeSnapshotJson(snapshot);
      expect(s1.booksMerged, 1);
      expect(s1.bookmarksAdded, 1);
      expect(s1.sourcesMerged, 2);

      final restoredOnline = (await dbB.getBookById('online_book_1'))!;
      expect(restoredOnline.isInShelf, isTrue);
      expect(restoredOnline.currentChapterIndex, 5);
      expect(await dbB.getBookById('local_book_1'), isNull);
      expect(await dbB.getPreference('reader_font_size'), '22.0');
      expect(await dbB.getPreference('webdav_password_obf'), isNull);

      // 本地读至更晚进度并保留较旧本地书，验证 LWW 防倒退与本地书路径隔离
      final newerTime = DateTime.utc(2026, 11, 24, 16, 0);
      await (dbB.update(dbB.books)..where((t) => t.id.equals('online_book_1'))).write(BooksCompanion(
        currentChapterIndex: const drift.Value(20), currentChapterTitle: const drift.Value('第二十一章 登楼'),
        currentCharOffset: const drift.Value(512), lastReadAt: drift.Value(newerTime), updatedAt: drift.Value(newerTime),
      ));
      final olderTime = DateTime.utc(2026, 11, 24, 6, 0);
      await dbB.upsertBook(BooksCompanion.insert(
        id: 'local_book_1', title: '本地秘籍', cleanTitle: '本地秘籍',
        coverUrl: const drift.Value('/device_b/my_cover.jpg'), sourceId: kLocalBookSourceId,
        bookUrl: '/device_b/book.txt', totalChapters: const drift.Value(30),
        currentChapterIndex: const drift.Value(1), currentCharOffset: const drift.Value(10),
        hasEverRead: const drift.Value(true), isInShelf: const drift.Value(true),
        lastReadAt: drift.Value(olderTime), updatedAt: olderTime,
      ));

      final s2 = await codecB.mergeSnapshotJson(snapshot);
      expect(s2.booksMerged, 1);
      expect(s2.bookmarksAdded, 1);
      expect((await dbB.getBookById('online_book_1'))!.currentChapterIndex, 20);
      final afterLocal = (await dbB.getBookById('local_book_1'))!;
      expect(afterLocal.currentChapterIndex, 8);
      expect(afterLocal.coverUrl, '/device_b/my_cover.jpg');

      final s3 = await codecB.mergeSnapshotJson(snapshot);
      expect(s3.booksMerged, 0);
      expect(s3.bookmarksAdded, 0);
      expect(() => codecB.mergeSnapshotJson('{invalid json'), throwsA(isA<FormatException>()));
    });

    test('跨端换源 LWW 字段同步清旧章、不复活本地移出书架书籍、旧备份不盲覆偏好与自定义源', () async {
      final tOld = DateTime.utc(2026, 11, 20, 8, 0);
      final tNew = DateTime.utc(2026, 11, 25, 10, 0);

      // 本地旧源含 2 条旧目录 + 已移出书架的书籍
      await dbB.upsertBook(BooksCompanion.insert(
        id: 'switch_b1', title: '剑来', cleanTitle: '剑来', sourceId: 'src_old',
        bookUrl: 'https://old.test/1', tocUrl: const drift.Value('https://old.test/1'),
        totalChapters: const drift.Value(2),
        currentChapterIndex: const drift.Value(1), isInShelf: const drift.Value(true),
        lastReadAt: drift.Value(tOld), updatedAt: tOld,
      ));
      await dbB.replaceBookChapters('switch_b1', [
        ChaptersCompanion.insert(bookId: 'switch_b1', chapterIndex: 0, title: '旧1', url: 'https://old.test/c0'),
        ChaptersCompanion.insert(bookId: 'switch_b1', chapterIndex: 1, title: '旧2', url: 'https://old.test/c1'),
      ]);
      await dbB.upsertBook(BooksCompanion.insert(
        id: 'removed_b2', title: '已移出小说', cleanTitle: '已移出小说', sourceId: 'src_old',
        bookUrl: 'https://old.test/2', isInShelf: const drift.Value(false), updatedAt: tNew,
      ));
      await dbB.setPreference('reader_font_size', '26.0');
      final repoB = SourceRepository(db: dbB, httpClient: AppHttpClient());
      await repoB.importLegadoJson(_sampleLegadoJson);
      final localCustom = (await dbB.select(dbB.bookSources).get()).first;
      final mutatedRule = Map<String, dynamic>.from(jsonDecode(localCustom.ruleJson) as Map)
        ..['name'] = '旧备份篡改名';

      final codecB = BackupSnapshotCodec(db: dbB);
      // 远端包含更新的换源书籍 switch_b1 与较旧的 removed_b2 + 旧 exportedAt 偏好/书源
      final remotePayload = jsonEncode({
        'version': 1,
        'exportedAt': tOld.toUtc().toIso8601String(),
        'books': [
          {
            'id': 'switch_b1', 'title': '剑来', 'sourceId': 'src_new',
            'bookUrl': 'https://new.test/1', 'tocUrl': 'https://new.test/toc',
            'totalChapters': 900, 'latestChapterTitle': '第900章 落幕',
            'lastUpdateTime': '2026-11-25', 'statusText': '已完结', 'category': '仙侠',
            'intro': '大千世界无奇不有', 'coverUrl': 'https://new.test/cover.jpg',
            'currentChapterIndex': 120, 'currentChapterTitle': '第121章',
            'hasEverRead': true, 'isInShelf': true,
            'lastReadAt': tNew.toIso8601String(), 'updatedAt': tNew.toIso8601String(),
          },
          {
            'id': 'removed_b2', 'title': '已移出小说', 'sourceId': 'src_old',
            'bookUrl': 'https://old.test/2', 'isInShelf': true,
            'lastReadAt': tOld.toIso8601String(), 'updatedAt': tOld.toIso8601String(),
          },
        ],
        'bookmarks': [],
        'customSources': [jsonEncode(mutatedRule)],
        'preferences': {'reader_font_size': '14.0'},
      });

      final sum = await codecB.mergeSnapshotJson(remotePayload);
      expect(sum.booksMerged, 1);
      expect(sum.sourcesMerged, 0);

      final b1 = (await dbB.getBookById('switch_b1'))!;
      expect(b1.sourceId, 'src_new');
      expect(b1.bookUrl, 'https://new.test/1');
      expect(b1.tocUrl, 'https://new.test/toc');
      expect(b1.totalChapters, 900);
      expect(b1.latestChapterTitle, '第900章 落幕');
      expect(b1.statusText, '已完结');
      expect(b1.category, '仙侠');
      expect(b1.intro, '大千世界无奇不有');
      expect(b1.coverUrl, 'https://new.test/cover.jpg');
      expect(b1.currentChapterIndex, 120);
      expect(await dbB.getChaptersByBook('switch_b1'), isEmpty);

      // 本地更新的移出书架状态不被旧快照复活；当前偏好与自定义源不被旧备份盲覆
      expect((await dbB.getBookById('removed_b2'))!.isInShelf, isFalse);
      expect(await dbB.getPreference('reader_font_size'), '26.0');
      final afterCustom = (await dbB.select(dbB.bookSources).get())
          .firstWhere((s) => s.id == localCustom.id);
      expect(afterCustom.name, localCustom.name);
    });
  });

  group('M3 真实 HttpServer 模拟 WebDAV 重定向、先拉合并与远程书源测试', () {
    late HttpServer server;
    late String baseUrl;
    final createdDirs = <String>{};
    final remoteFiles = <String, String>{};
    var etagSeq = 0;
    final expectedAuth = 'Basic ${base64Encode(utf8.encode('reader@yuewei.app:app_pwd_99'))}';

    setUp(() async {
      createdDirs.clear();
      remoteFiles.clear();
      etagSeq = 0;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      baseUrl = 'http://127.0.0.1:${server.port}';

      server.listen((HttpRequest req) async {
        final path = req.uri.path;
        expect(path.contains('//'), isFalse, reason: 'WebDAV 路径绝不能含双斜杠: $path');
        Future<void> reply(int code, {String? body, List<int>? bytes, String? loc, String? etag, String? ct}) async {
          req.response.statusCode = code;
          if (loc != null) req.response.headers.set('location', loc);
          if (etag != null) req.response.headers.set('etag', etag);
          if (ct != null) req.response.headers.set('content-type', ct);
          if (bytes != null) req.response.add(bytes);
          if (body != null) req.response.write(body);
          await req.response.close();
        }
        if (path.startsWith('/dav_307/')) {
          return reply(307, loc: path.replaceFirst('/dav_307/', '/dav/'));
        }
        if (path.startsWith('/dav') || path.startsWith('/remote.php/dav/files/alice/books')) {
          if (req.headers.value('authorization') != expectedAuth) return reply(401);
          final rootPrefix = path.startsWith('/dav') ? '/dav/' : '/remote.php/dav/files/alice/books/';
          if (req.method == 'PROPFIND' && path == rootPrefix) {
            expect(req.headers.value('depth'), '0');
            return reply(207, body: '<d:multistatus/>');
          }
          if (req.method == 'MKCOL' && path == '${rootPrefix}yuewei_sync/') {
            return reply(createdDirs.add(path) ? 201 : 405);
          }
          if (req.method == 'PUT' && path == '${rootPrefix}yuewei_sync/yuewei_backup_v1.json') {
            remoteFiles[path] = await utf8.decoder.bind(req).join();
            etagSeq++;
            return reply(201, etag: '"v$etagSeq"');
          }
          if (req.method == 'GET' && path == '${rootPrefix}yuewei_sync/yuewei_backup_v1.json') {
            final content = remoteFiles[path];
            return content == null
                ? reply(404)
                : reply(200, bytes: utf8.encode(content), etag: '"v$etagSeq"', ct: 'application/json');
          }
          return reply(404);
        }
        if (path == '/sources_gbk.json') {
          return reply(200, bytes: gbk.encode(_sampleLegadoJson), ct: 'application/json; charset=gbk');
        }
        if (path == '/not_json.html') return reply(200, body: '<html><body>404 Page</body></html>');
        return reply(404);
      });
    });

    tearDown(() => server.close(force: true));

    test('WebDAV 307 非 GET 重定向、ETag 透传与先拉合并上传杜绝盲覆盖', () async {
      final db1 = AppDatabase(NativeDatabase.memory());
      final db2 = AppDatabase(NativeDatabase.memory());
      addTearDown(() async { await db1.close(); await db2.close(); });

      final badClient = WebdavSyncClient(config: WebdavConfig(url: '$baseUrl/dav', username: 'reader@yuewei.app', password: 'wrong'));
      await expectLater(badClient.testConnection(), throwsA(isA<WebdavSyncException>().having((e) => e.message, 'msg', contains('401'))));

      // 通过 /dav_307 测试 PROPFIND / MKCOL / PUT / GET 307 重定向同主机安全带凭证
      final cfg = WebdavConfig(url: '$baseUrl/dav_307', username: 'reader@yuewei.app', password: 'app_pwd_99');
      await WebdavSyncClient.saveConfig(db1, cfg);
      expect(await db1.getPreference('webdav_password_obf'), startsWith('obf1:'));
      final client = WebdavSyncClient(config: await WebdavSyncClient.loadConfig(db1));
      await client.testConnection();
      expect(await client.downloadBackup(), isNull);

      final t = DateTime.utc(2026, 11, 24, 14, 0);
      await db1.upsertBook(BooksCompanion.insert(
        id: 'cloud_b1', title: '诡秘之主', cleanTitle: '诡秘之主', sourceId: 'builtin_1', bookUrl: 'https://b.test/1',
        currentChapterIndex: const drift.Value(12), hasEverRead: const drift.Value(true), isInShelf: const drift.Value(true),
        lastReadAt: drift.Value(t), updatedAt: t,
      ));
      await db2.upsertBook(BooksCompanion.insert(
        id: 'cloud_b2', title: '宿命之环', cleanTitle: '宿命之环', sourceId: 'builtin_1', bookUrl: 'https://b.test/2',
        currentChapterIndex: const drift.Value(3), hasEverRead: const drift.Value(true), isInShelf: const drift.Value(true),
        lastReadAt: drift.Value(t), updatedAt: t,
      ));

      final r1 = await WebdavSyncCoordinator.uploadWithPreMerge(client: client, codec: BackupSnapshotCodec(db: db1));
      expect(r1.mergedFromRemote, isFalse);
      expect(r1.remoteEtag, '"v1"');

      // 设备 2 先拉取合并再上传：不得盲覆盖设备 1 的 cloud_b1
      final r2 = await WebdavSyncCoordinator.uploadWithPreMerge(client: client, codec: BackupSnapshotCodec(db: db2));
      expect(r2.mergedFromRemote, isTrue);
      expect(r2.remoteEtag, '"v2"');
      expect((await db2.getBookById('cloud_b1'))?.currentChapterIndex, 12);
      final finalCloud = await client.downloadBackupWithMeta();
      expect(finalCloud?.etag, '"v2"');
      expect(finalCloud!.content, contains('cloud_b1'));
      expect(finalCloud.content, contains('cloud_b2'));
    });

    test('WebDAV URL 归一化与多级路径闭环 + importFromUrl 远程书源导入清理', () async {
      expect(WebdavSyncClient.normalizeBaseUrl('https://dav.jianguoyun.com/dav///'), 'https://dav.jianguoyun.com/dav/');
      expect(WebdavSyncClient.normalizeBaseUrl('https://alist.example.com//'), 'https://alist.example.com/');
      expect(
        WebdavSyncClient.normalizeBaseUrl(' https://cloud.example.com/remote.php//dav/files/alice/books///?k=1#top '),
        'https://cloud.example.com/remote.php/dav/files/alice/books/',
      );
      expect(() => WebdavSyncClient.normalizeBaseUrl('ftp://dav.example.com/dav'), throwsA(isA<WebdavSyncException>()));

      final nestedClient = WebdavSyncClient(
        config: WebdavConfig(url: '$baseUrl/remote.php/dav//files/alice/books///', username: 'reader@yuewei.app', password: 'app_pwd_99'),
      );
      await nestedClient.testConnection();
      await nestedClient.uploadBackup('{"version":1,"books":[]}');
      expect(await nestedClient.downloadBackup(), '{"version":1,"books":[]}');

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = SourceRepository(db: db, httpClient: AppHttpClient());
      await repo.ensureBuiltinSourcesSeeded();
      final builtinCount = (await db.select(db.bookSources).get()).length;
      await expectLater(repo.importFromUrl('ftp://bad-url'), throwsA(isA<FormatException>()));
      await expectLater(repo.importFromUrl('$baseUrl/not_json.html'), throwsA(isA<FormatException>()));
      expect(await repo.importFromUrl('$baseUrl/sources_gbk.json'), 2);

      final all = await db.select(db.bookSources).get();
      final builtinOne = all.firstWhere((s) => s.isBuiltin);
      final customs = all.where((s) => !s.isBuiltin).toList();
      await (db.update(db.bookSources)..where((t) => t.id.equals(builtinOne.id))).write(const BookSourcesCompanion(lastLatencyMs: drift.Value(-1)));
      await (db.update(db.bookSources)..where((t) => t.id.equals(customs[0].id))).write(const BookSourcesCompanion(lastLatencyMs: drift.Value(-1)));
      await (db.update(db.bookSources)..where((t) => t.id.equals(customs[1].id))).write(const BookSourcesCompanion(lastLatencyMs: drift.Value(60)));
      expect(await repo.clearUnreachableCustomSources(), 1);
      final remaining = await db.select(db.bookSources).get();
      expect(remaining.where((s) => s.isBuiltin).length, builtinCount);
      expect(remaining.where((s) => !s.isBuiltin).length, 1);
    });
  });
}
