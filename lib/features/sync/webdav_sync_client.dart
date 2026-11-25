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

/// WebDAV 云端备份客户端（遵循 RFC 4918，兼容坚果云 / Nextcloud / Alist，严控 <= 240 行）
class WebdavSyncClient {
  WebdavSyncClient({required this.config, Dio? dio})
      : _dio = dio ?? _buildDefaultDio();

  final WebdavConfig config;
  final Dio _dio;

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
        followRedirects: true,
        maxRedirects: 5,
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

  /// 确保远端 `yuewei_sync/` 目录存在（MKCOL 兼容 200 / 201 / 204 / 301 / 405）
  Future<void> ensureRemoteDir() async {
    final resp = await _send('MKCOL', '${_normalizedBaseUrl()}$remoteDirName/', headers: _authHeaders());
    final code = resp.statusCode ?? 0;
    if (code == 201 || code == 405 || code == 301 || code == 200 || code == 204) return;
    throw _mapHttpStatusError(code, scene: '创建同步目录');
  }

  /// 上传快照至 `yuewei_sync/yuewei_backup_v1.json`（兼容 200 / 201 / 204）
  Future<void> uploadBackup(String json) async {
    final baseUrl = _normalizedBaseUrl();
    await ensureRemoteDir();
    final resp = await _send(
      'PUT',
      '$baseUrl$remoteDirName/$remoteBackupFileName',
      data: utf8.encode(json),
      headers: _authHeaders({'Content-Type': 'application/json; charset=utf-8'}),
    );
    final code = resp.statusCode ?? 0;
    if (code == 200 || code == 201 || code == 204) return;
    throw _mapHttpStatusError(code, scene: '上传云备份');
  }

  /// 拉取远端快照字符串；若云端尚无备份（404）则返回 null
  Future<String?> downloadBackup() async {
    final resp = await _send(
      'GET',
      '${_normalizedBaseUrl()}$remoteDirName/$remoteBackupFileName',
      headers: _authHeaders({'Accept': 'application/json, text/plain, */*'}),
    );
    final code = resp.statusCode ?? 0;
    if (code == 404) return null;
    if (code == 200) return utf8.decode(resp.data ?? const <int>[], allowMalformed: true);
    throw _mapHttpStatusError(code, scene: '拉取云备份');
  }

  Future<Response<List<int>>> _send(
    String method,
    String url, {
    Object? data,
    required Map<String, String> headers,
  }) async {
    try {
      return await _dio.request<List<int>>(
        url,
        data: data,
        options: Options(method: method, headers: headers, responseType: ResponseType.bytes, validateStatus: (_) => true),
      );
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
    if (code >= 500) return WebdavSyncException('云端服务器异常（HTTP $code），请稍后再试', statusCode: code);
    return WebdavSyncException('$scene失败（HTTP $code），请检查服务器地址与兼容配置', statusCode: code);
  }
}
