import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../../sources/data/source_repository.dart';
import '../data/local_import_service.dart';
import '../engine/charset_and_txt_parser.dart';
import 'wifi_web_page_html.dart';

/// Wi-Fi 传书单次接收成功条目
@immutable
class WifiReceivedItem {
  const WifiReceivedItem({
    required this.fileName,
    required this.kind,
    required this.displayTitle,
    required this.itemCount,
    required this.receivedAt,
  });

  final String fileName;
  final String kind; // 'book' or 'source'
  final String displayTitle;
  final int itemCount;
  final DateTime receivedAt;
}

/// 局域网 Wi-Fi 传书轻量 HTTP 服务（支持多端浏览上传 .txt / .epub / .json）
class WifiTransferServer {
  WifiTransferServer({
    required this.localImportService,
    required this.sourceRepository,
    this.preferredPort = 18680,
  });

  static const int maxUploadBytes = 120 * 1024 * 1024;

  final LocalImportService localImportService;
  final SourceRepository sourceRepository;
  final int preferredPort;

  final StreamController<WifiReceivedItem> _receivedController =
      StreamController<WifiReceivedItem>.broadcast();

  HttpServer? _server;
  String? _serverUrl;
  List<String> _listenUrls = const [];
  int _receivedCount = 0;

  Stream<WifiReceivedItem> get receivedStream => _receivedController.stream;
  String? get serverUrl => _serverUrl;
  List<String> get listenUrls => _listenUrls;
  int? get port => _server?.port;
  bool get isRunning => _server != null;

  /// 启动局域网 HTTP 服务并返回首选访问 URL
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

  /// 停止传书 HTTP 服务并释放端口
  Future<void> stop() async {
    final active = _server;
    _server = null;
    _serverUrl = null;
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

  /// 枚举并按局域网可达优先级排序 IPv4 地址（192.168. > 10. > 172.16-31.）
  static Future<List<String>> resolveLanIps() async {
    final candidates = <({String ip, int score})>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (addr.isLoopback || ip.startsWith('169.254.')) continue;
          candidates.add((ip: ip, score: _ipPriority(ip)));
        }
      }
    } catch (_) {}

    if (candidates.isEmpty) return const ['127.0.0.1'];
    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.map((c) => c.ip).toSet().toList();
  }

  static int _ipPriority(String ip) {
    if (ip.startsWith('192.168.')) return 100;
    if (ip.startsWith('10.')) return 80;
    if (ip.startsWith('172.')) {
      final parts = ip.split('.');
      final second = parts.length >= 2 ? int.tryParse(parts[1]) ?? -1 : -1;
      if (second >= 16 && second <= 31) return 70;
    }
    return 10;
  }

  /// 清洗上传文件名，严防 `..` 与路径穿越
  static String sanitizeUploadFileName(String? rawName) {
    final trimmed = (rawName ?? '').trim();
    final base = p.posix.basename(trimmed.replaceAll('\\', '/'));
    final safe = base
        .replaceAll(RegExp(r'[^a-zA-Z0-9._\-\u4E00-\u9FFF ]'), '_')
        .replaceAll(RegExp(r'^\.+'), '')
        .trim();
    return safe.isEmpty ? 'upload.txt' : safe;
  }

  Future<void> _handleRequest(HttpRequest req) async {
    final res = req.response;
    res.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
      ..set('Access-Control-Allow-Headers', 'Content-Type')
      ..set('Cache-Control', 'no-store');

    try {
      if (req.method == 'OPTIONS') {
        res.statusCode = HttpStatus.noContent;
        await res.close();
        return;
      }
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
        });
        return;
      }
      if (req.method == 'POST' && path == '/api/upload') {
        await _handleUpload(req, res);
        return;
      }
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

  Future<void> _handleUpload(HttpRequest req, HttpResponse res) async {
    if (req.contentLength > maxUploadBytes) {
      await _sendJson(res, HttpStatus.requestEntityTooLarge, {
        'ok': false,
        'error': '单文件大小不能超过 120MB',
      });
      return;
    }

    final builder = BytesBuilder(copy: false);
    var receivedLen = 0;
    await for (final chunk in req) {
      receivedLen += chunk.length;
      if (receivedLen > maxUploadBytes) {
        await _sendJson(res, HttpStatus.requestEntityTooLarge, {
          'ok': false,
          'error': '单文件大小不能超过 120MB',
        });
        return;
      }
      builder.add(chunk);
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

    await _sendJson(res, HttpStatus.unsupportedMediaType, {
      'ok': false,
      'error': '仅支持 .txt、.epub 书籍或 .json 书源规则',
    });
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
