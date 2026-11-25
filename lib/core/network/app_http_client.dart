import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:fast_gbk/fast_gbk.dart';

/// 全局共享网络客户端（单例复用连接池、透传 CancelToken、单次无损编码解码）
class AppHttpClient {
  AppHttpClient({Dio? dio}) : _dio = dio ?? _buildDefaultDio();

  final Dio _dio;

  static Dio _buildDefaultDio() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 9),
        sendTimeout: const Duration(seconds: 6),
        followRedirects: true,
        maxRedirects: 5,
        responseType: ResponseType.bytes,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 15; 23013RK75C) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,application/json;q=0.8,*/*;q=0.7',
          'Accept-Language': 'zh-CN,zh;q=0.9',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );
  }

  /// 按指定字符集对搜索关键词执行 URL 百分比编码（完美兼容 GBK 老牌网文站）
  static String encodeQuery(String input, String charset) {
    final lower = charset.trim().toLowerCase();
    if (lower.contains('gb')) {
      final bytes = gbk.encode(input);
      final buf = StringBuffer();
      for (final b in bytes) {
        if ((b >= 0x30 && b <= 0x39) ||
            (b >= 0x41 && b <= 0x5A) ||
            (b >= 0x61 && b <= 0x7A) ||
            b == 0x2D ||
            b == 0x5F ||
            b == 0x2E) {
          buf.writeCharCode(b);
        } else {
          buf.write('%${b.toRadixString(16).padLeft(2, '0').toUpperCase()}');
        }
      }
      return buf.toString();
    }
    return Uri.encodeQueryComponent(input);
  }

  /// 发起请求并自动解码响应体，同时测量真实往返延迟（毫秒）
  Future<HttpFetchResult> fetchText(
    String url, {
    String method = 'GET',
    String? body,
    String? referer,
    String charsetHint = 'auto',
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    final sw = Stopwatch()..start();
    final isPost = method.toUpperCase() == 'POST';
    final headers = <String, dynamic>{};
    if (referer != null && referer.isNotEmpty) {
      headers['Referer'] = referer;
    }
    if (isPost) {
      headers['Content-Type'] = 'application/x-www-form-urlencoded';
    }

    final options = Options(
      method: isPost ? 'POST' : 'GET',
      headers: headers,
      responseType: ResponseType.bytes,
      sendTimeout: timeout,
      receiveTimeout: timeout,
    );

    final resp = await _dio.request<List<int>>(
      url,
      data: isPost ? body : null,
      options: options,
      cancelToken: cancelToken,
    );
    sw.stop();

    final statusCode = resp.statusCode ?? 0;
    final bytes = resp.data ?? const <int>[];
    if (statusCode >= 400 || bytes.isEmpty) {
      throw DioException(
        requestOptions: resp.requestOptions,
        response: resp,
        message: 'HTTP $statusCode',
      );
    }

    final contentType = resp.headers.value('content-type') ?? '';
    final decoded = decodeBytes(
      bytes,
      contentType: contentType,
      charsetHint: charsetHint,
    );
    return HttpFetchResult(
      body: decoded,
      latencyMs: sw.elapsedMilliseconds,
      statusCode: statusCode,
      finalUrl: resp.realUri.toString(),
    );
  }

  /// 轻量 HEAD/GET 探活测速
  Future<int> ping(String url, {Duration timeout = const Duration(seconds: 8)}) async {
    final sw = Stopwatch()..start();
    final resp = await _dio.get<List<int>>(
      url,
      options: Options(
        receiveTimeout: timeout,
        sendTimeout: timeout,
        responseType: ResponseType.bytes,
      ),
    );
    sw.stop();
    if ((resp.statusCode ?? 0) >= 400) {
      throw StateError('HTTP ${resp.statusCode}');
    }
    return sw.elapsedMilliseconds;
  }

  /// 单次无损字符集探测与解码（BOM → Header → 前4KB meta → 严格UTF8探测 → 安全回退）
  static String decodeBytes(
    List<int> bytes, {
    String contentType = '',
    String charsetHint = 'auto',
  }) {
    if (bytes.isEmpty) return '';

    // 1. UTF-8 BOM
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }

    final detected = _resolveCharset(bytes, contentType, charsetHint);
    if (detected == 'gbk') {
      return gbk.decode(bytes, allowMalformed: true);
    }

    // 2. 先尝试严格 UTF-8，若遇非法字节序列再安全降级为 GBK（兼容无声明的老站点）
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } catch (_) {
      return gbk.decode(bytes, allowMalformed: true);
    }
  }

  static String _resolveCharset(
    List<int> bytes,
    String contentType,
    String charsetHint,
  ) {
    final ctLower = contentType.toLowerCase();
    if (ctLower.contains('gbk') ||
        ctLower.contains('gb2312') ||
        ctLower.contains('gb18030')) {
      return 'gbk';
    }
    if (ctLower.contains('utf-8') || ctLower.contains('utf8')) {
      return 'utf-8';
    }

    final headLen = bytes.length > 4096 ? 4096 : bytes.length;
    final head = latin1.decode(bytes.sublist(0, headLen), allowInvalid: true).toLowerCase();
    final metaMatch = RegExp(
      r'''charset\s*=\s*["']?\s*([a-z0-9\-_]+)''',
      caseSensitive: false,
    ).firstMatch(head);
    if (metaMatch != null) {
      final cs = metaMatch.group(1) ?? '';
      if (cs.contains('gb')) return 'gbk';
      if (cs.contains('utf')) return 'utf-8';
    }

    final hint = charsetHint.trim().toLowerCase();
    if (hint.contains('gb')) return 'gbk';
    if (hint.contains('utf')) return 'utf-8';
    return 'auto';
  }
}

class HttpFetchResult {
  const HttpFetchResult({
    required this.body,
    required this.latencyMs,
    required this.statusCode,
    required this.finalUrl,
  });

  final String body;
  final int latencyMs;
  final int statusCode;
  final String finalUrl;
}
