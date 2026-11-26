import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/database/app_database.dart';

/// WebDAV 可读业务异常（面向中文用户直接展示可读原因）
class WebdavSyncException implements Exception {
  const WebdavSyncException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// WebDAV 连接配置与同步时间记录
@immutable
class WebdavConfig {
  const WebdavConfig({
    this.url = '',
    this.username = '',
    this.password = '',
    this.lastSyncAt,
  });

  final String url;
  final String username;
  final String password;
  final DateTime? lastSyncAt;

  bool get isConfigured =>
      url.trim().isNotEmpty && username.trim().isNotEmpty && password.isNotEmpty;

  WebdavConfig copyWith({
    String? url,
    String? username,
    String? password,
    DateTime? lastSyncAt,
  }) =>
      WebdavConfig(
        url: url ?? this.url,
        username: username ?? this.username,
        password: password ?? this.password,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      );
}

/// 远端快照下载载荷（透传正文与远端 ETag，支持乐观并发控制）
@immutable
class WebdavRemoteBackup {
  const WebdavRemoteBackup({required this.content, this.etag});

  final String content;
  final String? etag;
}

/// WebDAV 云端备份客户端（遵循 RFC 4918，兼容坚果云 / Nextcloud / Alist，严控 <= 350 行）
class WebdavSyncClient {
  WebdavSyncClient({required this.config, Dio? dio})
      : _dio = dio ?? _buildDefaultDio();

  final WebdavConfig config;
  final Dio _dio;
  String? _lastRemoteEtag;

  /// 最近一次 GET / PUT 成功交互观测到的远端 ETag（未返回时为 null）
  String? get lastRemoteEtag => _lastRemoteEtag;

  static const int _maxRedirectHops = 5;
  static const String remoteDirName = 'yuewei_sync';
  static const String remoteBackupFileName = 'yuewei_backup_v1.json';
  static const String _prefUrl = 'webdav_url';
  static const String _prefUser = 'webdav_username';
  static const String _prefPwd = 'webdav_password_obf';
  static const String _prefLastSync = 'webdav_last_sync_at';

  // 注意：仅作本地存储防直读的简单可逆混淆，并非密码学加密。
  static const List<int> _obfMask = [0x59, 0x57, 0x33, 0x7A, 0x4B, 0x9E];

  static Dio _buildDefaultDio() => Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        followRedirects: false,
        responseType: ResponseType.bytes,
        validateStatus: (_) => true,
      ));

  static Future<WebdavConfig> loadConfig(AppDatabase db) async {
    final url = (await db.getPreference(_prefUrl)) ?? '';
    final user = (await db.getPreference(_prefUser)) ?? '';
    final rawPwd = (await db.getPreference(_prefPwd)) ?? '';
    final rawSync = await db.getPreference(_prefLastSync);
    return WebdavConfig(
      url: url,
      username: user,
      password: _deobfuscate(rawPwd),
      lastSyncAt: rawSync != null && rawSync.isNotEmpty
          ? DateTime.tryParse(rawSync)?.toLocal()
          : null,
    );
  }

  /// 持久化 WebDAV 配置（密码作简单可逆混淆，注明非加密）
  static Future<void> saveConfig(AppDatabase db, WebdavConfig config) async {
    await db.setPreference(_prefUrl, config.url.trim());
    await db.setPreference(_prefUser, config.username.trim());
    await db.setPreference(_prefPwd, _obfuscate(config.password));
    if (config.lastSyncAt != null) {
      await db.setPreference(_prefLastSync, config.lastSyncAt!.toUtc().toIso8601String());
    }
  }

  static Future<DateTime> markSyncedNow(AppDatabase db) async {
    final now = DateTime.now();
    await db.setPreference(_prefLastSync, now.toUtc().toIso8601String());
    return now;
  }

  static String _obfuscate(String plain) {
    if (plain.isEmpty) return '';
    final src = utf8.encode(plain);
    final out = List<int>.generate(src.length, (i) => src[i] ^ _obfMask[i % _obfMask.length]);
    return 'obf1:${base64Encode(out)}';
  }

  static String _deobfuscate(String stored) {
    if (stored.isEmpty || !stored.startsWith('obf1:')) return stored;
    try {
      final bytes = base64Decode(stored.substring(5));
      final plain = List<int>.generate(bytes.length, (i) => bytes[i] ^ _obfMask[i % _obfMask.length]);
      return utf8.decode(plain, allowMalformed: true);
    } catch (_) {
      return '';
    }
  }

  /// 归一化 WebDAV 根地址：统一保留有且仅有一个尾斜杠，清理冗余双斜杠与查询片段，兼容多层级目录
  static String normalizeBaseUrl(String rawUrl) {
    final raw = rawUrl.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https')) || uri.host.isEmpty) {
      throw const WebdavSyncException('WebDAV 地址格式无效，需以 http:// 或 https:// 开头');
    }
    final cleanSegments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final normalized = Uri(
      scheme: uri.scheme.toLowerCase(),
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: cleanSegments.isEmpty ? '/' : null,
      pathSegments: cleanSegments.isEmpty ? null : [...cleanSegments, ''],
    ).toString();
    return normalized.endsWith('/') ? normalized : '$normalized/';
  }

  String _normalizedBaseUrl() {
    final base = normalizeBaseUrl(config.url);
    if (config.username.trim().isEmpty || config.password.isEmpty) {
      throw const WebdavSyncException('请先填写完整的 WebDAV 账号与应用密码');
    }
    return base;
  }

  Map<String, String> _authHeaders([Map<String, String>? extra]) {
    final token = base64Encode(utf8.encode('${config.username.trim()}:${config.password}'));
    return {'Authorization': 'Basic $token', ...?extra};
  }

  /// PROPFIND Depth: 0 探测认证与连通性（兼容 200 / 207）
  Future<void> testConnection() async {
    final resp = await _send('PROPFIND', _normalizedBaseUrl(), headers: _authHeaders({'Depth': '0'}));
    final code = resp.statusCode ?? 0;
    if (code == 200 || code == 207) return;
    throw _mapHttpStatusError(code, scene: '测试连接');
  }

  /// 确保远端 `yuewei_sync/` 目录存在（301 由重定向循环处理，仅 200 / 201 / 204 / 405 判成功）
  Future<void> ensureRemoteDir() async {
    final resp = await _send(
      'MKCOL',
      '${_normalizedBaseUrl()}$remoteDirName/',
      headers: _authHeaders(),
    );
    final code = resp.statusCode ?? 0;
    if (code == 201 || code == 405 || code == 200 || code == 204) return;
    throw _mapHttpStatusError(code, scene: '创建同步目录');
  }

  /// 上传快照至 `yuewei_sync/yuewei_backup_v1.json`（可选透传 If-Match ETag，兼容 200 / 201 / 204）
  Future<void> uploadBackup(String json, {String? expectedEtag}) async {
    final baseUrl = _normalizedBaseUrl();
    await ensureRemoteDir();
    final extra = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      if (expectedEtag != null && expectedEtag.trim().isNotEmpty)
        'If-Match': expectedEtag.trim(),
    };
    final resp = await _send(
      'PUT',
      '$baseUrl$remoteDirName/$remoteBackupFileName',
      data: utf8.encode(json),
      headers: _authHeaders(extra),
    );
    final code = resp.statusCode ?? 0;
    if (code == 200 || code == 201 || code == 204) {
      final etag = resp.headers.value('etag')?.trim();
      if (etag != null && etag.isNotEmpty) _lastRemoteEtag = etag;
      return;
    }
    throw _mapHttpStatusError(code, scene: '上传云备份');
  }

  /// 拉取远端快照与 ETag 元信息；若云端尚无备份（404）则返回 null
  Future<WebdavRemoteBackup?> downloadBackupWithMeta() async {
    final resp = await _send(
      'GET',
      '${_normalizedBaseUrl()}$remoteDirName/$remoteBackupFileName',
      headers: _authHeaders({'Accept': 'application/json, text/plain, */*'}),
    );
    final code = resp.statusCode ?? 0;
    if (code == 404) {
      _lastRemoteEtag = null;
      return null;
    }
    if (code == 200) {
      final rawEtag = resp.headers.value('etag')?.trim();
      final etag = (rawEtag != null && rawEtag.isNotEmpty) ? rawEtag : null;
      _lastRemoteEtag = etag;
      final content = utf8.decode(resp.data ?? const <int>[], allowMalformed: true);
      return WebdavRemoteBackup(content: content, etag: etag);
    }
    throw _mapHttpStatusError(code, scene: '拉取云备份');
  }

  /// 拉取远端快照字符串；若云端尚无备份（404）则返回 null
  Future<String?> downloadBackup() async {
    final res = await downloadBackupWithMeta();
    return res?.content;
  }

  static bool _isRedirectStatus(int code) =>
      code == 301 || code == 302 || code == 307 || code == 308;

  static bool _canForwardAuth(Uri origin, Uri target) {
    if (origin.host.toLowerCase() != target.host.toLowerCase()) return false;
    // 防止从 HTTPS 降级重定向至明文 HTTP 时泄露 Basic Auth 凭证
    if (origin.isScheme('https') && !target.isScheme('https')) return false;
    return true;
  }

  Future<Response<List<int>>> _send(
    String method,
    String url, {
    Object? data,
    required Map<String, String> headers,
  }) async {
    final originUri = Uri.parse(url);
    var currentUri = originUri;
    var currentHeaders = Map<String, String>.from(headers);

    try {
      for (var hop = 0; hop <= _maxRedirectHops; hop++) {
        final resp = await _dio.request<List<int>>(
          currentUri.toString(),
          data: data,
          options: Options(
            method: method,
            headers: currentHeaders,
            followRedirects: false,
            responseType: ResponseType.bytes,
            validateStatus: (_) => true,
          ),
        );
        final code = resp.statusCode ?? 0;
        if (!_isRedirectStatus(code)) return resp;

        final location = resp.headers.value(HttpHeaders.locationHeader)?.trim();
        if (location == null || location.isEmpty) return resp;
        if (hop == _maxRedirectHops) {
          throw WebdavSyncException(
            'WebDAV 重定向次数过多（超过 $_maxRedirectHops 跳），请检查服务器地址',
            statusCode: code,
          );
        }

        final nextUri = currentUri.resolve(location);
        if (!nextUri.isScheme('http') && !nextUri.isScheme('https')) {
          throw WebdavSyncException('WebDAV 重定向目标协议无效', statusCode: code);
        }
        currentHeaders = Map<String, String>.from(headers);
        if (!_canForwardAuth(originUri, nextUri)) {
          currentHeaders.remove('Authorization');
          currentHeaders.remove('authorization');
        }
        currentUri = nextUri;
      }
      throw const WebdavSyncException('WebDAV 重定向次数过多，请检查服务器地址');
    } on DioException catch (e) {
      throw _mapDioError(e);
    } on SocketException {
      throw const WebdavSyncException('无法连接服务器，请检查域名（DNS）或网络连接');
    } catch (e) {
      if (e is WebdavSyncException) rethrow;
      throw WebdavSyncException('网络请求失败：$e');
    }
  }

  static WebdavSyncException _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const WebdavSyncException('连接云端服务器超时，请检查网络后重试');
      case DioExceptionType.badCertificate:
        return const WebdavSyncException('HTTPS 证书校验失败，请检查服务器证书配置');
      case DioExceptionType.connectionError:
        final err = e.error;
        if (err is SocketException && err.message.toLowerCase().contains('lookup')) {
          return const WebdavSyncException('域名解析（DNS）失败，请核对服务器地址');
        }
        return const WebdavSyncException('无法连接 WebDAV 服务器，请检查地址与网络');
      default:
        final code = e.response?.statusCode;
        if (code != null) return _mapHttpStatusError(code, scene: '请求');
        return const WebdavSyncException('WebDAV 网络通信异常，请稍后重试');
    }
  }

  static WebdavSyncException _mapHttpStatusError(int code, {required String scene}) {
    if (code == 401) return const WebdavSyncException('账号或应用密码错误（HTTP 401），请核对授权凭证', statusCode: 401);
    if (code == 403) return const WebdavSyncException('云端拒绝访问（HTTP 403），请确认账号具备读写权限', statusCode: 403);
    if (code == 404) return WebdavSyncException('$scene失败：远端 WebDAV 路径不存在（HTTP 404）', statusCode: 404);
    if (code == 409) return WebdavSyncException('$scene失败：远端父目录不存在或路径冲突（HTTP 409），请确认 WebDAV 根路径已创建', statusCode: 409);
    if (code == 412) return const WebdavSyncException('云端备份已被其他设备更新（HTTP 412），请重新点击同步以合并最新进度', statusCode: 412);
    if (code >= 500) return WebdavSyncException('云端服务器异常（HTTP $code），请稍后再试', statusCode: code);
    return WebdavSyncException('$scene失败（HTTP $code），请检查服务器地址与兼容配置', statusCode: code);
  }
}
