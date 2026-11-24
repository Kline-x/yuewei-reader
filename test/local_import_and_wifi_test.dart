import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuewei_reader/core/database/app_database.dart';
import 'package:yuewei_reader/core/database/bookmark_dao.dart';
import 'package:yuewei_reader/core/network/app_http_client.dart';
import 'package:yuewei_reader/core/storage/chapter_file_store.dart';
import 'package:yuewei_reader/design_system/components/book_cover.dart';
import 'package:yuewei_reader/features/local_import/data/local_import_service.dart';
import 'package:yuewei_reader/features/local_import/engine/charset_and_txt_parser.dart';
import 'package:yuewei_reader/features/local_import/wifi/wifi_transfer_server.dart';
import 'package:yuewei_reader/features/reader/engine/content_pipeline.dart';
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

  test('UTF-8 与 GBK 编码 TXT 分章、无章名长文自动分节与 ContentPipeline 序列化', () async {
    const pipeline = ContentPipeline();
    const novel = '''
序章 风起青萍
这是一段超过二十字的序章内容，用于验证序章识别与段落整理效果。

第一章 初临书院
天才一秒记住本站地址：www.example.com
清晨的阳光透过窗棂洒在木桌上。
“准备好了吗？”“早就准备好了。”

第二章 深夜灯火
书架上陈列着泛黄的古籍与手抄本，微风拂过纸页沙沙作响。
''';

    final utf8Bom = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(novel)];
    final parsedUtf8 = await CharsetAndTxtParser.parseInIsolate(
      bytes: utf8Bom,
      fileName: '《青萍传》作者：沈默.txt',
    );
    expect(parsedUtf8.title, '青萍传');
    expect(parsedUtf8.author, '沈默');
    expect(parsedUtf8.chapters.length, 3);
    expect(parsedUtf8.chapters[1].title, '第一章 初临书院');
    final ch1Paras = pipeline.parseCachedText(parsedUtf8.chapters[1].serializedContent);
    expect(ch1Paras.length, 3);
    expect(ch1Paras.every((p) => p.startsWith('\u3000\u3000')), isTrue);
    expect(ch1Paras.any((p) => p.contains('www.example.com')), isFalse);

    final parsedGbk = await CharsetAndTxtParser.parseInIsolate(
      bytes: gbk.encode(novel),
      fileName: '青萍传.txt',
    );
    expect(parsedGbk.chapters.length, 3);
    expect(parsedGbk.chapters[2].serializedContent, contains('泛黄的古籍'));

    final longBuf = StringBuffer();
    for (var i = 0; i < 120; i++) {
      longBuf.writeln('第$i段记录了一段平静的日常叙事，微风吹过山野间的小径，溪水潺潺流向远方的村庄与古桥，夜色降临时灯火依次亮起。' * 2);
    }
    final parsedLong = await CharsetAndTxtParser.parseInIsolate(
      bytes: utf8.encode(longBuf.toString()),
      fileName: '无标题散文集.txt',
    );
    expect(parsedLong.chapters.length, greaterThanOrEqualTo(3));
    expect(parsedLong.chapters.first.title, '第 1 节');
    expect(parsedLong.chapters.first.serializedContent, startsWith('\u3000\u3000'));
  });

  test('动态构建带封面 EPUB 端到端导入、幂等重入与冷存储落盘校验', () async {
    final epubBytes = _buildSampleEpubBytes();
    final epubFile = File('${tempDir.path}/sample.epub')..writeAsBytesSync(epubBytes);
    final book = await importService.importFromFile(
      epubFile.path,
      originalFileName: '《星海手记》.epub',
    );

    expect(book.sourceId, kLocalBookSourceId);
    expect(book.title, '星海手记');
    expect(book.author, '林深');
    expect(book.category, 'EPUB 藏书');
    expect(book.statusText, '本地藏书');
    expect(book.isInShelf, isTrue);
    expect(book.totalChapters, 2);
    expect(book.coverUrl.startsWith('/'), isTrue);
    expect(File(book.coverUrl).existsSync(), isTrue);
    expect(await fileStore.readChapter(book.id, 0), contains('第一段星海航行记录'));
    expect(await fileStore.readChapter(book.id, 1), contains('抵达静默港湾'));

    await db.updateReadingProgress(
      bookId: book.id,
      chapterIndex: 1,
      chapterTitle: '第二章 静默港湾',
      charOffset: 12,
    );
    final reimported = await importService.importFromBytes('别名重传.epub', epubBytes);
    expect(reimported.id, book.id);
    expect(reimported.currentChapterIndex, 1);
    expect((await db.getShelfBooks()).length, 1);
  });

  testWidgets('BookCover 支持本地文件绝对路径与 file:// 封面渲染', (tester) async {
    final coverFile = File('${tempDir.path}/local_cover.png')
      ..writeAsBytesSync(_samplePngBytes);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              BookCover(title: '星海手记', coverUrl: coverFile.path),
              BookCover(title: '星海手记', coverUrl: coverFile.uri.toString()),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(Image), findsNWidgets(2));
  });

  test('Bookmarks CRUD、hasUnreadUpdate 升级与 watchTotalCachedBytes 过滤本地书', () async {
    expect(db.schemaVersion, 3);

    final id1 = await db.addBookmark(
      bookId: 'b1',
      chapterIndex: 2,
      chapterTitle: '第三章 雾海',
      charOffset: 88,
      excerpt: '夜航船穿过白雾。',
    );
    await db.addBookmark(
      bookId: 'b1',
      chapterIndex: 5,
      chapterTitle: '第六章 归途',
      charOffset: 12,
    );
    final list = await db.watchBookmarksByBook('b1').first;
    expect(list.length, 2);
    expect(list.first.chapterIndex, 5);

    await db.deleteBookmark(id1);
    expect((await db.getBookmarksByBook('b1')).length, 1);
    await db.deleteBookmarksByBook('b1');
    expect(await db.getBookmarksByBook('b1'), isEmpty);

    final localBook = await importService.importFromBytes(
      '随笔.txt',
      utf8.encode('第一章 晨光\n清晨的风吹过院子里的石阶。'),
    );
    await db.setBookUnreadUpdate(localBook.id, true);
    expect((await db.getBookById(localBook.id))?.hasUnreadUpdate, isTrue);

    await db.upsertBook(
      BooksCompanion.insert(
        id: 'online_1',
        title: '在线测试书',
        cleanTitle: '在线测试书',
        sourceId: 'builtin_test',
        bookUrl: 'https://example.com/1',
        updatedAt: DateTime.now(),
      ),
    );
    final onlineBytes = await fileStore.writeChapter('online_1', 0, '在线缓存正文');
    await db.replaceBookChapters('online_1', [
      ChaptersCompanion.insert(
        bookId: 'online_1',
        chapterIndex: 0,
        title: '第一章',
        url: 'https://example.com/c0',
      ),
    ]);
    await db.markChapterCached(
      bookId: 'online_1',
      chapterIndex: 0,
      isCached: true,
      cachedBytes: onlineBytes,
    );

    expect(await db.watchTotalCachedBytes().first, onlineBytes);
    await fileStore.clearNonLocalCaches({localBook.id});
    expect(await fileStore.readChapter('online_1', 0), isNull);
    expect(await fileStore.readChapter(localBook.id, 0), isNotNull);
  });

  test('WifiTransferServer 启动、端口回退、GET / 与 POST /api/upload 上传入库', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final blocker = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      final server = WifiTransferServer(
        localImportService: importService,
        sourceRepository: sourceRepo,
        preferredPort: blocker.port,
      );

      try {
        final url = await server.start();
        expect(server.isRunning, isTrue);
        expect(server.port, isNot(blocker.port));
        expect(url, contains(':${server.port}'));

        final client = HttpClient();
        final localBase = 'http://127.0.0.1:${server.port}';

        final getReq = await client.getUrl(Uri.parse('$localBase/'));
        final getResp = await getReq.close();
        expect(getResp.statusCode, HttpStatus.ok);
        final htmlBody = await utf8.decodeStream(getResp);
        expect(htmlBody, contains('阅微'));
        expect(htmlBody, contains('/api/upload'));
        final stResp = await (await client.getUrl(Uri.parse('$localBase/api/status'))).close();
        expect(stResp.statusCode, HttpStatus.ok);
        await stResp.drain<void>();

        final events = <WifiReceivedItem>[];
        final sub = server.receivedStream.listen(events.add);
        final uploadUri = Uri.parse(
          '$localBase/api/upload?name=${Uri.encodeQueryComponent("../../局域网传书测试.txt")}',
        );
        final postReq = await client.postUrl(uploadUri);
        postReq.add(utf8.encode('第一章 初遇\n窗外下起了绵绵细雨，桌面茶香袅袅。'));
        final postResp = await postReq.close();
        expect(postResp.statusCode, HttpStatus.ok);
        final jsonResp = jsonDecode(await utf8.decodeStream(postResp)) as Map<String, dynamic>;
        expect(jsonResp['ok'], isTrue);
        expect(jsonResp['kind'], 'book');

        final srcReq = await client.postUrl(Uri.parse('$localBase/api/upload?name=src.json'));
        srcReq.add(utf8.encode('[{"bookSourceName":"传源测试","bookSourceUrl":"https://s.example","searchUrl":"/s?q={{key}}","ruleSearch":{"bookList":".i","name":"a","bookUrl":"a@href"},"ruleToc":{"chapterList":".c a"},"ruleContent":{"content":"#txt"}}]'));
        final srcResp = await srcReq.close();
        expect(srcResp.statusCode, HttpStatus.ok);
        expect((jsonDecode(await utf8.decodeStream(srcResp)) as Map)['kind'], 'source');

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(events.length, 2);
        expect(events.first.fileName.contains('..'), isFalse);
        final shelfBooks = await db.getShelfBooks();
        expect(shelfBooks.length, 1);
        expect(shelfBooks.first.title, '局域网传书测试');

        final badReq = await client.postUrl(Uri.parse('$localBase/api/upload?name=malware.exe'));
        badReq.add([1, 2, 3]);
        final badResp = await badReq.close();
        expect(badResp.statusCode, HttpStatus.unsupportedMediaType);
        await badResp.drain<void>();
        await sub.cancel();
        client.close(force: true);
      } finally {
        await server.dispose();
        await blocker.close();
      }
    }, _DirectHttpOverrides());
  });
}

class _DirectHttpOverrides extends HttpOverrides {}

const _samplePngBytes = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

List<int> _buildSampleEpubBytes() {
  final archive = Archive()
    ..addFile(ArchiveFile('OEBPS/images/cover.png', _samplePngBytes.length, _samplePngBytes));
  void addText(String name, String text) {
    final b = utf8.encode(text);
    archive.addFile(ArchiveFile(name, b.length, b));
  }

  addText('mimetype', 'application/epub+zip');
  addText('META-INF/container.xml', '<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>');
  addText('OEBPS/content.opf', '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="uid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>星海手记</dc:title><dc:creator>林深</dc:creator>
    <dc:description>跨越星系边缘的旅途手记。</dc:description><meta name="cover" content="cover-img"/>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="cover-img" href="images/cover.png" media-type="image/png"/>
    <item id="ch1" href="text/ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch2" href="text/ch2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx"><itemref idref="ch1"/><itemref idref="ch2"/></spine>
</package>''');
  addText('OEBPS/toc.ncx', '''<?xml version="1.0" encoding="utf-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <navMap>
    <navPoint id="n1" playOrder="1"><navLabel><text>第一章 启航日</text></navLabel><content src="text/ch1.xhtml"/></navPoint>
    <navPoint id="n2" playOrder="2"><navLabel><text>第二章 静默港湾</text></navLabel><content src="text/ch2.xhtml"/></navPoint>
  </navMap>
</ncx>''');
  addText('OEBPS/text/ch1.xhtml', '<html><body><h1>第一章 启航日</h1><p>第一段星海航行记录。</p></body></html>');
  addText('OEBPS/text/ch2.xhtml', '<html><body><p>终于顺利抵达静默港湾。</p></body></html>');
  return ZipEncoder().encode(archive)!;
}
