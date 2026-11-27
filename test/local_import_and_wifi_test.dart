import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yuewei_reader/core/database/app_database.dart';
import 'package:yuewei_reader/core/database/bookmark_dao.dart';
import 'package:yuewei_reader/core/network/app_http_client.dart';
import 'package:yuewei_reader/core/storage/chapter_file_store.dart';
import 'package:yuewei_reader/design_system/components/book_cover.dart';
import 'package:yuewei_reader/features/local_import/data/local_import_service.dart';
import 'package:yuewei_reader/features/local_import/engine/charset_and_txt_parser.dart';
import 'package:yuewei_reader/features/local_import/engine/epub_archive_utils.dart';
import 'package:yuewei_reader/features/local_import/engine/epub_book_parser.dart';
import 'package:yuewei_reader/features/local_import/wifi/wifi_transfer_server.dart';
import 'package:yuewei_reader/features/local_import/wifi/wifi_web_page_html.dart';
import 'package:yuewei_reader/features/reader/engine/content_pipeline.dart';
import 'package:yuewei_reader/features/reader/fonts/custom_font_manager.dart';
import 'package:yuewei_reader/features/sources/data/source_repository.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late ChapterFileStore fileStore;
  late LocalImportService importService;
  late SourceRepository sourceRepo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('yuewei_m2_test_');
    db = AppDatabase(NativeDatabase.memory());
    fileStore = ChapterFileStore(rootDirProvider: () async => tempDir);
    importService = LocalImportService(db: db, fileStore: fileStore);
    sourceRepo = SourceRepository(db: db, httpClient: AppHttpClient());
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('UTF-8 / GBK TXT 分章、自动分节与 Emoji 预览截断防代理对劈裂', () async {
    const pipeline = ContentPipeline();
    const novel = '序章 风起青萍\n这是一段超过二十字的序章内容，用于验证序章识别与段落整理效果。\n\n'
        '第一章 初临书院\n天才一秒记住本站地址：www.example.com\n清晨的阳光透过窗棂洒在木桌上。\n“准备好了吗？”“早就准备好了。”\n\n'
        '第二章 深夜灯火\n书架上陈列着泛黄的古籍与手抄本，微风拂过纸页沙沙作响。\n';

    final parsedUtf8 = await CharsetAndTxtParser.parseInIsolate(
      bytes: <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(novel)],
      fileName: '《青萍传》作者：沈默.txt',
    );
    expect(parsedUtf8.title, '青萍传');
    expect(parsedUtf8.author, '沈默');
    expect(parsedUtf8.chapters.length, 3);
    final ch1Paras = pipeline.parseCachedText(parsedUtf8.chapters[1].serializedContent);
    expect(ch1Paras.length, 3);
    expect(ch1Paras.every((l) => l.startsWith('\u3000\u3000')), isTrue);
    expect(ch1Paras.any((l) => l.contains('www.example.com')), isFalse);

    final parsedGbk = await CharsetAndTxtParser.parseInIsolate(bytes: gbk.encode(novel), fileName: '青萍传.txt');
    expect(parsedGbk.chapters[2].serializedContent, contains('泛黄的古籍'));

    final emojiNovel = '${'文' * 119}🚀${'尾' * 40}';
    final parsedEmoji = CharsetAndTxtParser.parseSync(bytes: utf8.encode(emojiNovel), fileName: 'emoji.txt');
    expect(parsedEmoji.intro.contains('\uFFFD'), isFalse);
    expect(parsedEmoji.intro, endsWith('🚀…'));
  });

  test('EPUB 导入、封面新旧路径兼容、nav 多锚点保护、%XX 解码、实体清洗与 ZIP 防护', () async {
    final epubBytes = _buildSampleEpubBytes();
    final epubFile = File('${tempDir.path}/sample.epub')..writeAsBytesSync(epubBytes);
    final book = await importService.importFromFile(epubFile.path, originalFileName: '《星海手记》.epub');

    expect(book.sourceId, kLocalBookSourceId);
    expect(book.title, '星海手记');
    expect(book.author, '林深');
    expect(book.intro, '跨越“星系”边缘 — 旅途手记 & 秘闻。');
    expect(book.totalChapters, 2);
    expect(book.coverUrl.startsWith('/') || book.coverUrl.startsWith('local_cover://'), isTrue);
    if (book.coverUrl.startsWith('/')) {
      expect(File(book.coverUrl).existsSync(), isTrue);
    } else {
      final rel = book.coverUrl.substring('local_cover://'.length);
      expect(File(p.join(tempDir.path, 'yuewei_covers', rel)).existsSync(), isTrue);
    }
    expect(await fileStore.readChapter(book.id, 0), contains('第一段星海航行记录'));
    expect(await fileStore.readChapter(book.id, 1), contains('抵达静默港湾'));

    // 验证 nav 尾部锚点未覆盖第一章主标题
    final chs = await db.getChaptersByBook(book.id);
    expect(chs.first.title, '第一章 启航日');

    // 验证逐段安全 %XX 解码兼容 %20 与字面量 100%
    expect(EpubArchiveUtils.safeUriDecode('ch%201_100%.xhtml'), 'ch 1_100%.xhtml');
    expect(EpubArchiveUtils.resolveRelative('OEBPS', 'text/ch%201_100%.xhtml?v=1#top'), 'OEBPS/text/ch 1_100%.xhtml');

    // 幂等重入保留阅读进度
    await db.updateReadingProgress(bookId: book.id, chapterIndex: 1, chapterTitle: '第二章 静默港湾', charOffset: 12);
    final reimported = await importService.importFromBytes('别名重传.epub', epubBytes);
    expect(reimported.id, book.id);
    expect(reimported.currentChapterIndex, 1);

    // ZIP 炸弹（条目数超限 / 解压总大小超限）抛出可读 FormatException
    expect(() => EpubBookParser.parseSync(bytes: epubBytes, fileName: 'x.epub', maxEntries: 2), throwsA(isA<FormatException>()));
    expect(() => EpubBookParser.parseSync(bytes: epubBytes, fileName: 'x.epub', maxUncompressedBytes: 32), throwsA(isA<FormatException>()));
  });

  test('LocalImportService 体积超限拦截与 picked_books/ 临时副本清理', () async {
    final pickedDir = await Directory(p.join(tempDir.path, 'picked_books')).create(recursive: true);
    final pickedFile = File(p.join(pickedDir.path, 'copy.txt'))..writeAsStringSync('第一章 晨光\n清晨微风拂过书桌。');
    final normalFile = File(p.join(tempDir.path, 'keep.txt'))..writeAsStringSync('第一章 晨光\n保留原文件。');

    await importService.importFromFile(pickedFile.path, originalFileName: '临时书.txt');
    expect(await pickedFile.exists(), isFalse);

    await importService.importFromFile(normalFile.path);
    expect(await normalFile.exists(), isTrue);

    final smallLimitService = LocalImportService(db: db, fileStore: fileStore, maxFileBytes: 16);
    final oversizedPicked = File(p.join(pickedDir.path, 'big.txt'))..writeAsStringSync('超限测试内容' * 10);
    await expectLater(smallLimitService.importFromFile(oversizedPicked.path), throwsA(isA<FormatException>()));
    expect(await oversizedPicked.exists(), isFalse);
  });

  testWidgets('BookCover 支持本地文件绝对路径与 file:// 封面渲染', (tester) async {
    final coverFile = File('${tempDir.path}/local_cover.png')..writeAsBytesSync(_samplePngBytes);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(children: [
            BookCover(title: '星海手记', coverUrl: coverFile.path),
            BookCover(title: '星海手记', coverUrl: coverFile.uri.toString()),
          ]),
        ),
      ),
    );
    expect(find.byType(Image), findsNWidgets(2));
  });

  test('Bookmarks CRUD、schemaVersion 兼容与 watchTotalCachedBytes 过滤本地书', () async {
    expect(db.schemaVersion, greaterThanOrEqualTo(3));

    final id1 = await db.addBookmark(bookId: 'b1', chapterIndex: 2, chapterTitle: '第三章 雾海', charOffset: 88, excerpt: '夜航船穿过白雾。');
    await db.addBookmark(bookId: 'b1', chapterIndex: 5, chapterTitle: '第六章 归途', charOffset: 12);
    expect((await db.watchBookmarksByBook('b1').first).first.chapterIndex, 5);
    await db.deleteBookmark(id1);
    expect((await db.getBookmarksByBook('b1')).length, 1);

    final localBook = await importService.importFromBytes('随笔.txt', utf8.encode('第一章 晨光\n清晨的风吹过院子里的石阶。'));
    await db.upsertBook(BooksCompanion.insert(
      id: 'online_1', title: '在线测试书', cleanTitle: '在线测试书', sourceId: 'builtin_test',
      bookUrl: 'https://example.com/1', updatedAt: DateTime.now(),
    ));
    final onlineBytes = await fileStore.writeChapter('online_1', 0, '在线缓存正文');
    await db.replaceBookChapters('online_1', [ChaptersCompanion.insert(bookId: 'online_1', chapterIndex: 0, title: '第一章', url: 'https://example.com/c0')]);
    await db.markChapterCached(bookId: 'online_1', chapterIndex: 0, isCached: true, cachedBytes: onlineBytes);
    expect(await db.watchTotalCachedBytes().first, onlineBytes);
    await fileStore.clearNonLocalCaches({localBook.id});
    expect(await fileStore.readChapter('online_1', 0), isNull);
    expect(await fileStore.readChapter(localBook.id, 0), isNotNull);
  });

  test('WifiTransferServer 配对码鉴权、无宽泛 CORS、中文书名保护、bookId 透传与 413 优雅响应', () async {
    expect(WifiTransferServer.sanitizeUploadFileName('《诡秘之主》作者：爱潜水的乌贼.txt'), '《诡秘之主》作者：爱潜水的乌贼.txt');
    final meta = CharsetAndTxtParser.inferMetaFromFileName(WifiTransferServer.sanitizeUploadFileName('《诡秘之主》作者：爱潜水的乌贼.txt'));
    expect(meta.title, '诡秘之主');
    expect(meta.author, '爱潜水的乌贼');
    expect(WifiTransferServer.sanitizeUploadFileName('.epub'), 'upload.epub');
    expect(WifiTransferServer.sanitizeUploadFileName('../../坏文件\x00.txt').contains('..'), isFalse);

    await HttpOverrides.runWithHttpOverrides(() async {
      final blocker = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      final server = WifiTransferServer(
        localImportService: importService,
        sourceRepository: sourceRepo,
        preferredPort: blocker.port,
        maxUploadBytesLimit: 1024,
      );
      try {
        final url = await server.start();
        final token = server.accessToken;
        expect(server.isRunning, isTrue);
        expect(server.port, isNot(blocker.port));
        expect(url, contains(':${server.port}'));
        expect(token, matches(RegExp(r'^\d{4}$')));
        expect(server.authUrl, contains('?token=$token'));

        final client = HttpClient();
        final localBase = 'http://127.0.0.1:${server.port}';
        final getResp = await (await client.getUrl(Uri.parse('$localBase/'))).close();
        expect(getResp.statusCode, HttpStatus.ok);
        expect(getResp.headers.value('access-control-allow-origin'), isNull);
        final htmlBody = await utf8.decodeStream(getResp);
        expect(htmlBody, contains('tokenInput'));
        expect(htmlBody, contains('uploadQueue'));

        // 未携带配对码被拒绝 401
        final unauthReq = await client.postUrl(Uri.parse('$localBase/api/upload?name=a.txt'));
        unauthReq.add(utf8.encode('第一章\n无配对码'));
        final unauthResp = await unauthReq.close();
        expect(unauthResp.statusCode, HttpStatus.unauthorized);
        await unauthResp.drain<void>();

        // 正确配对码上传中文书名，校验真实 bookId 与解析书名作者
        final events = <WifiReceivedItem>[];
        final sub = server.receivedStream.listen(events.add);
        final bookName = Uri.encodeQueryComponent('《诡秘之主》作者：爱潜水的乌贼.txt');
        final postReq = await client.postUrl(Uri.parse('$localBase/api/upload?name=$bookName&token=$token'));
        postReq.add(utf8.encode('第一章 绯红\n痛！好痛！头好痛！'));
        final postResp = await postReq.close();
        expect(postResp.statusCode, HttpStatus.ok);
        final jsonResp = jsonDecode(await utf8.decodeStream(postResp)) as Map<String, dynamic>;
        expect(jsonResp['ok'], isTrue);
        expect(jsonResp['title'], '诡秘之主');

        // Header X-Access-Token 传书源
        final srcReq = await client.postUrl(Uri.parse('$localBase/api/upload?name=src.json'));
        srcReq.headers.set('X-Access-Token', token!);
        srcReq.add(utf8.encode('[{"bookSourceName":"传源测试","bookSourceUrl":"https://s.example","searchUrl":"/s?q={{key}}","ruleSearch":{"bookList":".i","name":"a","bookUrl":"a@href"},"ruleToc":{"chapterList":".c a"},"ruleContent":{"content":"#txt"}}]'));
        final srcResp = await srcReq.close();
        expect(srcResp.statusCode, HttpStatus.ok);
        expect((jsonDecode(await utf8.decodeStream(srcResp)) as Map)['kind'], 'source');

        // 超出体积限制返回 413 JSON 且不断流 RST
        final bigReq = await client.postUrl(Uri.parse('$localBase/api/upload?name=big.txt&token=$token'));
        bigReq.add(List<int>.filled(2048, 0x41));
        final bigResp = await bigReq.close();
        expect(bigResp.statusCode, HttpStatus.requestEntityTooLarge);
        final bigJson = jsonDecode(await utf8.decodeStream(bigResp)) as Map<String, dynamic>;
        expect(bigJson['ok'], isFalse);

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(events.length, 2);
        expect(events.first.bookId, jsonResp['bookId']);
        expect((await db.getShelfBooks()).first.author, '爱潜水的乌贼');
        await sub.cancel();
        client.close(force: true);
      } finally {
        await server.dispose();
        await blocker.close();
      }
    }, _DirectHttpOverrides());
  });

  test('WifiTransferServer 支持带 token 上传 .ttf/.otf 字体并拒绝非法文件头', () async {
    expect(kWifiTransferHtml, contains('.ttf,.otf'));
    final fontService = CustomFontService(
      db: db,
      rootDirProvider: () async => tempDir,
      fontLoader: (_, _) async {},
    );
    await HttpOverrides.runWithHttpOverrides(() async {
      final server = WifiTransferServer(
        localImportService: importService,
        sourceRepository: sourceRepo,
        preferredPort: 0,
        customFontImporter: (fileName, bytes) async {
          final res = await fontService.importFontBytes(fileName: fileName, bytes: bytes);
          return WifiImportedFont(id: res.entry.id, displayName: res.entry.displayName, fontFamily: res.entry.fontFamily, fileSizeBytes: res.entry.fileSizeBytes);
        },
      );
      try {
        await server.start();
        final token = server.accessToken!;
        final client = HttpClient();
        final base = 'http://127.0.0.1:${server.port}';
        final events = <WifiReceivedItem>[];
        final sub = server.receivedStream.listen(events.add);

        final unauth = await client.postUrl(Uri.parse('$base/api/upload?name=WenKai.ttf'));
        unauth.add([0x00, 0x01, 0x00, 0x00, 0x01]);
        final unauthResp = await unauth.close();
        expect(unauthResp.statusCode, HttpStatus.unauthorized);
        await unauthResp.drain<void>();

        final okReq = await client.postUrl(Uri.parse('$base/api/upload?name=WenKai.ttf&token=$token'));
        okReq.add([0x00, 0x01, 0x00, 0x00, 0x01, 0x02, 0x03]);
        final okResp = await okReq.close();
        expect(okResp.statusCode, HttpStatus.ok);
        final okJson = jsonDecode(await utf8.decodeStream(okResp)) as Map<String, dynamic>;
        expect(okJson['kind'], 'font');
        expect(okJson['message'], contains('收到字体'));

        final badReq = await client.postUrl(Uri.parse('$base/api/upload?name=Bad.otf&token=$token'));
        badReq.add([0x42, 0x41, 0x44, 0x21]);
        final badResp = await badReq.close();
        expect(badResp.statusCode, HttpStatus.badRequest);
        await badResp.drain<void>();

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(events.single.kind, 'font');
        expect(CustomFontEntry.decodeList(await db.getPreference(CustomFontService.prefsKey)).length, 1);
        await sub.cancel();
        client.close(force: true);
      } finally {
        await server.dispose();
      }
    }, _DirectHttpOverrides());
  });
}

class _DirectHttpOverrides extends HttpOverrides {}

const _samplePngBytes = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

List<int> _buildSampleEpubBytes() {
  final archive = Archive()..addFile(ArchiveFile('OEBPS/images/cover.png', _samplePngBytes.length, _samplePngBytes));
  void addText(String name, String text) {
    final b = utf8.encode(text);
    archive.addFile(ArchiveFile(name, b.length, b));
  }

  addText('mimetype', 'application/epub+zip');
  addText('META-INF/container.xml', '<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>');
  addText('OEBPS/content.opf', '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>星海手记</dc:title><dc:creator>林深</dc:creator>
    <dc:description>&lt;p&gt;跨越&amp;ldquo;星系&amp;rdquo;边缘 &amp;mdash; 旅途手记 &amp;amp; 秘闻。&lt;/p&gt;</dc:description><meta name="cover" content="cover-img"/>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="cover-img" href="images/cover.png?v=1" media-type="image/png"/>
    <item id="ch1" href="text/ch%201_100%.xhtml#start" media-type="application/xhtml+xml"/>
    <item id="ch2" href="text/ch2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine><itemref idref="ch1"/><itemref idref="ch2"/></spine>
</package>''');
  addText('OEBPS/nav.xhtml', '''<html><body><nav epub:type="toc"><ol>
    <li><a href="text/ch%201_100%.xhtml">第一章 启航日</a></li>
    <li><a href="text/ch%201_100%.xhtml#footnote1">尾部注释锚点</a></li>
    <li><a href="text/ch2.xhtml">第二章 静默港湾</a></li>
  </ol></nav></body></html>''');
  addText('OEBPS/text/ch 1_100%.xhtml', '<html><body><h1>第一章 启航日</h1><p>第一段星海航行记录。</p></body></html>');
  addText('OEBPS/text/ch2.xhtml', '<html><body><p>终于顺利抵达静默港湾。</p></body></html>');
  return ZipEncoder().encode(archive)!;
}
