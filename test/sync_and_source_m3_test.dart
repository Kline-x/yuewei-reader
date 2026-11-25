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

      await dbA.addBookmark(bookId: 'online_book_1', chapterIndex: 5, chapterTitle: '第六章 风雪', charOffset: 180, excerpt: '摘录一');
      await dbA.addBookmark(bookId: 'local_book_1', chapterIndex: 8, chapterTitle: '第九章', charOffset: 66, excerpt: '本地书签');

      final repoA = SourceRepository(db: dbA, httpClient: AppHttpClient());
      await repoA.importLegadoJson(_sampleLegadoJson);
      await dbA.setPreference('reader_font_size', '22.0');
      await dbA.setPreference('yuewei_tts_speech_rate', '1.75');
      await dbA.setPreference('webdav_password_obf', 'obf1:secret');

      final snapshot = await BackupSnapshotCodec(db: dbA).exportSnapshotJson();
      expect(snapshot.contains('webdav_password_obf'), isFalse);
      expect(snapshot.contains('yuewei_tts_speech_rate'), isTrue);

      // 1. 全新空库恢复：补插在线书、跳过本机不存在的本地书及对应书签
      final codecB = BackupSnapshotCodec(db: dbB);
      final s1 = await codecB.mergeSnapshotJson(snapshot);
      expect(s1.booksMerged, 1);
      expect(s1.bookmarksAdded, 1);
      expect(s1.sourcesMerged, 2);

      final restoredOnline = (await dbB.getBookById('online_book_1'))!;
      expect(restoredOnline.isInShelf, isTrue);
      expect(restoredOnline.isPinned, isTrue);
      expect(restoredOnline.currentChapterIndex, 5);
      expect(restoredOnline.currentCharOffset, 180);
      expect(await dbB.getBookById('local_book_1'), isNull);
      expect(await dbB.getPreference('reader_font_size'), '22.0');
      expect(await dbB.getPreference('yuewei_tts_speech_rate'), '1.75');
      expect(await dbB.getPreference('webdav_password_obf'), isNull);

      // 2. 在 dbB 将在线书读到更晚进度，并放入旧进度的同名 ID 本地书
      final newerTime = DateTime.utc(2026, 11, 24, 16, 0);
      await (dbB.update(dbB.books)..where((t) => t.id.equals('online_book_1'))).write(BooksCompanion(
        currentChapterIndex: const drift.Value(20),
        currentChapterTitle: const drift.Value('第二十一章 登楼'),
        currentCharOffset: const drift.Value(512),
        lastReadAt: drift.Value(newerTime),
        updatedAt: drift.Value(newerTime),
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

      // 3. 二次合并旧快照：在线书 LWW 严防倒退；已存在的本地书推进到第 8 章且保留本机路径；书签去重
      final s2 = await codecB.mergeSnapshotJson(snapshot);
      expect(s2.booksMerged, 1);
      expect(s2.bookmarksAdded, 1);

      final afterOnline = (await dbB.getBookById('online_book_1'))!;
      expect(afterOnline.currentChapterIndex, 20);
      expect(afterOnline.currentCharOffset, 512);

      final afterLocal = (await dbB.getBookById('local_book_1'))!;
      expect(afterLocal.currentChapterIndex, 8);
      expect(afterLocal.currentCharOffset, 66);
      expect(afterLocal.coverUrl, '/device_b/my_cover.jpg');

      // 4. 再次合并完全一致的快照：书签与进度均幂等不重复
      final s3 = await codecB.mergeSnapshotJson(snapshot);
      expect(s3.booksMerged, 0);
      expect(s3.bookmarksAdded, 0);

      expect(
        () => codecB.mergeSnapshotJson('{invalid json'),
        throwsA(isA<FormatException>().having((e) => e.message, 'msg', contains('无效'))),
      );
    });
  });

  group('M3 真实 HttpServer 模拟 WebDAV 与远程书源端到端测试', () {
    late HttpServer server;
    late String baseUrl;
    final createdDirs = <String>{};
    final remoteFiles = <String, String>{};
    final expectedAuth = 'Basic ${base64Encode(utf8.encode('reader@yuewei.app:app_pwd_99'))}';

    setUp(() async {
      createdDirs.clear();
      remoteFiles.clear();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      baseUrl = 'http://127.0.0.1:${server.port}';

      server.listen((HttpRequest req) async {
        final path = req.uri.path;
        expect(path.contains('//'), isFalse, reason: 'WebDAV 请求路径绝不能包含双斜杠: $path');
        if (path.startsWith('/dav') || path.startsWith('/remote.php/dav/files/alice/books')) {
          if (req.headers.value('authorization') != expectedAuth) {
            req.response.statusCode = 401;
            await req.response.close();
            return;
          }
          final rootPrefix = path.startsWith('/dav') ? '/dav/' : '/remote.php/dav/files/alice/books/';
          if (req.method == 'PROPFIND' && path == rootPrefix) {
            expect(req.headers.value('depth'), '0');
            req.response.statusCode = 207;
            req.response.write('<d:multistatus/>');
            await req.response.close();
            return;
          }
          if (req.method == 'MKCOL' && path == '${rootPrefix}yuewei_sync/') {
            req.response.statusCode = createdDirs.add(path) ? 201 : 405;
            await req.response.close();
            return;
          }
          if (req.method == 'PUT' && path == '${rootPrefix}yuewei_sync/yuewei_backup_v1.json') {
            remoteFiles[path] = await utf8.decoder.bind(req).join();
            req.response.statusCode = 201;
            await req.response.close();
            return;
          }
          if (req.method == 'GET' && path == '${rootPrefix}yuewei_sync/yuewei_backup_v1.json') {
            final content = remoteFiles[path];
            req.response.statusCode = content == null ? 404 : 200;
            if (content != null) {
              req.response.headers.contentType = ContentType.json;
              req.response.add(utf8.encode(content));
            }
            await req.response.close();
            return;
          }
          req.response.statusCode = 404;
          await req.response.close();
          return;
        }

        if (path == '/sources_gbk.json') {
          req.response.statusCode = 200;
          req.response.headers.set('content-type', 'application/json; charset=gbk');
          req.response.add(gbk.encode(_sampleLegadoJson));
          await req.response.close();
          return;
        }
        if (path == '/not_json.html') {
          req.response.statusCode = 200;
          req.response.write('<html><body>404 Page</body></html>');
          await req.response.close();
          return;
        }
        req.response.statusCode = 404;
        await req.response.close();
      });
    });

    tearDown(() => server.close(force: true));

    test('WebDAV Basic Auth 鉴权、PROPFIND->MKCOL->PUT->GET->Merge 全闭环', () async {
      final db1 = AppDatabase(NativeDatabase.memory());
      final db2 = AppDatabase(NativeDatabase.memory());
      addTearDown(() async { await db1.close(); await db2.close(); });

      final badClient = WebdavSyncClient(config: WebdavConfig(url: '$baseUrl/dav', username: 'reader@yuewei.app', password: 'wrong'));
      await expectLater(badClient.testConnection(), throwsA(isA<WebdavSyncException>().having((e) => e.message, 'msg', contains('401'))));

      final goodCfg = WebdavConfig(url: '$baseUrl/dav', username: 'reader@yuewei.app', password: 'app_pwd_99');
      await WebdavSyncClient.saveConfig(db1, goodCfg);
      final rawObf = await db1.getPreference('webdav_password_obf');
      expect(rawObf, startsWith('obf1:'));
      expect(rawObf!.contains('app_pwd_99'), isFalse);
      final loadedCfg = await WebdavSyncClient.loadConfig(db1);
      expect(loadedCfg.password, 'app_pwd_99');

      final client = WebdavSyncClient(config: loadedCfg);
      await client.testConnection();
      expect(await client.downloadBackup(), isNull);
      await db1.upsertBook(BooksCompanion.insert(
        id: 'cloud_b1', title: '诡秘之主', cleanTitle: '诡秘之主', sourceId: 'builtin_1', bookUrl: 'https://b.test/1',
        currentChapterIndex: const drift.Value(12), hasEverRead: const drift.Value(true), isInShelf: const drift.Value(true),
        lastReadAt: drift.Value(DateTime.utc(2026, 11, 24, 14, 0)), updatedAt: DateTime.utc(2026, 11, 24, 14, 0),
      ));

      final snap = await BackupSnapshotCodec(db: db1).exportSnapshotJson();
      await client.uploadBackup(snap);
      await client.uploadBackup(snap);
      final downloaded = await client.downloadBackup();
      expect(downloaded, isNotNull);
      final merged = await BackupSnapshotCodec(db: db2).mergeSnapshotJson(downloaded!);
      expect(merged.booksMerged, 1);
      expect((await db2.getBookById('cloud_b1'))?.currentChapterIndex, 12);
    });

    test('WebDAV URL 尾斜杠/多斜杠/多层级目录归一化边界及真实服务器多级路径闭环', () async {
      expect(WebdavSyncClient.normalizeBaseUrl('https://dav.jianguoyun.com/dav'), 'https://dav.jianguoyun.com/dav/');
      expect(WebdavSyncClient.normalizeBaseUrl('https://dav.jianguoyun.com/dav/'), 'https://dav.jianguoyun.com/dav/');
      expect(WebdavSyncClient.normalizeBaseUrl('https://dav.jianguoyun.com/dav///'), 'https://dav.jianguoyun.com/dav/');
      expect(WebdavSyncClient.normalizeBaseUrl('https://alist.example.com'), 'https://alist.example.com/');
      expect(WebdavSyncClient.normalizeBaseUrl('https://alist.example.com//'), 'https://alist.example.com/');
      expect(
        WebdavSyncClient.normalizeBaseUrl(' https://cloud.example.com/remote.php//dav/files/alice/books///?k=1#top '),
        'https://cloud.example.com/remote.php/dav/files/alice/books/',
      );
      expect(() => WebdavSyncClient.normalizeBaseUrl('ftp://dav.example.com/dav'), throwsA(isA<WebdavSyncException>()));
      expect(() => WebdavSyncClient.normalizeBaseUrl('https://'), throwsA(isA<WebdavSyncException>()));

      final nestedClient = WebdavSyncClient(
        config: WebdavConfig(url: '$baseUrl/remote.php/dav//files/alice/books///', username: 'reader@yuewei.app', password: 'app_pwd_99'),
      );
      await nestedClient.testConnection();
      await nestedClient.uploadBackup('{"version":1,"books":[]}');
      expect(remoteFiles['/remote.php/dav/files/alice/books/yuewei_sync/yuewei_backup_v1.json'], isNotNull);
      expect(await nestedClient.downloadBackup(), '{"version":1,"books":[]}');
    });

    test('importFromUrl 远程 GBK/UTF-8 导入、exportCustomSourcesJson 与清理失效自定义源', () async {
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
      final exported = await repo.exportCustomSourcesJson();
      expect(exported, contains('bookSourceName'));
      expect(await repo.importLegadoJson(exported), 1);
    });
  });
}
