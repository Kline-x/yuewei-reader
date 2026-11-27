import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data' show BytesBuilder;
import 'package:path/path.dart' as p;
import '../../sources/data/source_repository.dart';
import '../data/local_import_service.dart';
import '../engine/charset_and_txt_parser.dart';
import 'wifi_transfer_models.dart';
import 'wifi_web_page_html.dart';

export 'wifi_transfer_models.dart'
    show WifiReceivedItem, WifiImportedFont, CustomFontImporter;

/// 局域网 Wi-Fi 传书轻量 HTTP 服务（同源安全无宽泛 CORS + 4 位随机配对码鉴权）
class WifiTransferServer {
  WifiTransferServer({
    required this.localImportService,
    required this.sourceRepository,
    this.customFontImporter,
    this.preferredPort = 18680,
    this.maxUploadBytesLimit = maxUploadBytes,
  });

  static const int maxUploadBytes = 120 * 1024 * 1024;

  final LocalImportService localImportService;
  final SourceRepository sourceRepository;
  final CustomFontImporter? customFontImporter;
  final int preferredPort;
  final int maxUploadBytesLimit;

  final StreamController<WifiReceivedItem> _receivedController =
      StreamController<WifiReceivedItem>.broadcast();
  final Random _secureRandom = Random.secure();

  HttpServer? _server;
  String? _serverUrl;
  String? _accessToken;
  List<String> _listenUrls = const [];
  int _receivedCount = 0;

  Stream<WifiReceivedItem> get receivedStream => _receivedController.stream;
  String? get serverUrl => _serverUrl;
  String? get accessToken => _accessToken;
  String? get authUrl =>
      (_serverUrl != null && _accessToken != null)
          ? '$_serverUrl/?token=$_accessToken'
          : _serverUrl;
  List<String> get listenUrls => _listenUrls;
  List<String> get authListenUrls => _accessToken == null
      ? _listenUrls
      : _listenUrls.map((u) => '$u/?token=$_accessToken').toList();
  int? get port => _server?.port;
  bool get isRunning => _server != null;

  /// 启动局域网 HTTP 服务，生成 4 位随机数字配对码并返回首选访问 URL
  Future<String> start() async {
    if (_server != null && _serverUrl != null) {
      return _serverUrl!;
    }
    HttpServer bound;
    try {
      bound = await HttpServer.bind(InternetAddress.anyIPv4, preferredPort);
    } on SocketException {
      bound = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
    _server = bound;
    _accessToken = (1000 + _secureRandom.nextInt(9000)).toString();

    final ips = await resolveLanIps();
    _listenUrls = ips.map((ip) => 'http://$ip:${bound.port}').toList();
    _serverUrl = _listenUrls.first;

    bound.listen(
      _handleRequest,
      onError: (_) {},
      cancelOnError: false,
    );
    return _serverUrl!;
  }

  /// 停止传书 HTTP 服务、清空配对码并释放端口
  Future<void> stop() async {
    final active = _server;
    _server = null;
    _serverUrl = null;
    _accessToken = null;
    _listenUrls = const [];
    if (active != null) {
      await active.close(force: true);
    }
  }

  /// 销毁服务器与事件流
  Future<void> dispose() async {
    await stop();
    if (!_receivedController.isClosed) {
      await _receivedController.close();
    }
  }

  /// 枚举并按局域网可达优先级排序 IPv4 地址
  static Future<List<String>> resolveLanIps() => resolveWifiLanIps();

  /// 清洗上传文件名，保护中文书名与作者标点并严防路径穿越
  static String sanitizeUploadFileName(String? rawName) =>
      sanitizeWifiUploadFileName(rawName);

  Future<void> _handleRequest(HttpRequest req) async {
    final res = req.response;
    res.headers.set('Cache-Control', 'no-store');

    try {
      final path = req.uri.path;
      if (req.method == 'GET' && (path == '/' || path == '/index.html')) {
        res.statusCode = HttpStatus.ok;
        res.headers.contentType = ContentType.html;
        res.write(kWifiTransferHtml);
        await res.close();
        return;
      }
      if (req.method == 'GET' && path == '/api/status') {
        await _sendJson(res, HttpStatus.ok, {
          'ok': true,
          'app': '阅微',
          'port': _server?.port ?? 0,
          'receivedCount': _receivedCount,
          'tokenRequired': true,
        });
        return;
      }
      if (req.method == 'POST' && path == '/api/upload') {
        await _handleUpload(req, res);
        return;
      }
      await _drainRequestSafely(req);
      await _sendJson(res, HttpStatus.notFound, {
        'ok': false,
        'error': '未找到请求接口',
      });
    } catch (e) {
      await _sendJson(res, HttpStatus.internalServerError, {
        'ok': false,
        'error': '服务端处理异常：$e',
      });
    }
  }

  bool _isAuthorizedUpload(HttpRequest req) {
    final expected = _accessToken;
    if (expected == null || expected.isEmpty) return false;
    final queryToken = (req.uri.queryParameters['token'] ?? '').trim();
    final headerToken = (req.headers.value('x-access-token') ??
            req.headers.value('x-wifi-token') ??
            '')
        .trim();
    return queryToken == expected || headerToken == expected;
  }

  Future<void> _handleUpload(HttpRequest req, HttpResponse res) async {
    if (!_isAuthorizedUpload(req)) {
      await _drainRequestSafely(req);
      res.headers.set(HttpHeaders.connectionHeader, 'close');
      await _sendJson(res, HttpStatus.unauthorized, {
        'ok': false,
        'error': '配对码错误或缺失，请核对手机端显示的 4 位配对码',
      });
      return;
    }

    if (req.contentLength > maxUploadBytesLimit) {
      await _drainRequestSafely(req);
      res.headers.set(HttpHeaders.connectionHeader, 'close');
      await _sendJson(res, HttpStatus.requestEntityTooLarge, {
        'ok': false,
        'error': '单文件大小不能超过 120MB',
      });
      return;
    }

    final builder = BytesBuilder(copy: false);
    var receivedLen = 0;
    var tooLarge = false;
    await for (final chunk in req) {
      receivedLen += chunk.length;
      if (receivedLen > maxUploadBytesLimit) {
        if (!tooLarge) {
          tooLarge = true;
          builder.clear();
        }
        continue;
      }
      builder.add(chunk);
    }

    if (tooLarge) {
      res.headers.set(HttpHeaders.connectionHeader, 'close');
      await _sendJson(res, HttpStatus.requestEntityTooLarge, {
        'ok': false,
        'error': '单文件大小不能超过 120MB',
      });
      return;
    }

    final bytes = builder.takeBytes();
    if (bytes.isEmpty) {
      await _sendJson(res, HttpStatus.badRequest, {
        'ok': false,
        'error': '上传文件内容为空',
      });
      return;
    }

    final fileName = sanitizeUploadFileName(req.uri.queryParameters['name']);
    final ext = p.extension(fileName).toLowerCase();

    if (ext == '.txt' || ext == '.epub') {
      final book = await localImportService.importFromBytes(fileName, bytes);
      _emitItem(
        WifiReceivedItem(
          fileName: fileName,
          kind: 'book',
          displayTitle: book.title,
          itemCount: book.totalChapters,
          receivedAt: DateTime.now(),
          bookId: book.id,
        ),
      );
      await _sendJson(res, HttpStatus.ok, {
        'ok': true,
        'kind': 'book',
        'bookId': book.id,
        'title': book.title,
        'chapters': book.totalChapters,
      });
      return;
    }

    if (ext == '.json') {
      final jsonText = CharsetAndTxtParser.decodeTextBytes(bytes);
      final count = await sourceRepository.importLegadoJson(jsonText);
      if (count <= 0) {
        await _sendJson(res, HttpStatus.badRequest, {
          'ok': false,
          'error': '未解析到有效的 Legado 书源规则',
        });
        return;
      }
      _emitItem(
        WifiReceivedItem(
          fileName: fileName,
          kind: 'source',
          displayTitle: fileName,
          itemCount: count,
          receivedAt: DateTime.now(),
        ),
      );
      await _sendJson(res, HttpStatus.ok, {
        'ok': true,
        'kind': 'source',
        'count': count,
      });
      return;
    }

    if (ext == '.ttf' || ext == '.otf') {
      if (customFontImporter == null) {
        await _sendJson(res, HttpStatus.notImplemented, {
          'ok': false,
          'error': '当前未启用字体导入服务',
        });
        return;
      }
      try {
        final imported = await customFontImporter!(fileName, bytes);
        _emitItem(
          WifiReceivedItem(
            fileName: fileName,
            kind: 'font',
            displayTitle: imported.displayName,
            itemCount: 1,
            receivedAt: DateTime.now(),
            fontFamily: imported.fontFamily,
          ),
        );
        await _sendJson(res, HttpStatus.ok, {
          'ok': true,
          'kind': 'font',
          'fontId': imported.id,
          'displayName': imported.displayName,
          'fontFamily': imported.fontFamily,
          'message': '收到字体「${imported.displayName}」',
        });
      } on FormatException catch (e) {
        await _sendJson(res, HttpStatus.badRequest, {
          'ok': false,
          'error': e.message,
        });
      }
      return;
    }

    await _sendJson(res, HttpStatus.unsupportedMediaType, {
      'ok': false,
      'error': '仅支持 .txt、.epub 书籍、.json 书源规则或 .ttf、.otf 字体',
    });
  }

  Future<void> _drainRequestSafely(HttpRequest req) async {
    try {
      await req.drain<void>();
    } catch (_) {}
  }

  void _emitItem(WifiReceivedItem item) {
    _receivedCount++;
    if (!_receivedController.isClosed) {
      _receivedController.add(item);
    }
  }

  Future<void> _sendJson(
    HttpResponse res,
    int statusCode,
    Map<String, dynamic> body,
  ) async {
    try {
      res.statusCode = statusCode;
      res.headers.contentType = ContentType.json;
      res.write(jsonEncode(body));
      await res.close();
    } catch (_) {}
  }
}
