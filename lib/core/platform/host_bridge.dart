import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 宿主平台原生能力快照
@immutable
class HostCapabilities {
  const HostCapabilities({
    required this.platform,
    required this.supportsVolumeKeyPaging,
    required this.versionName,
    required this.versionCode,
  });

  final String platform;
  final bool supportsVolumeKeyPaging;
  final String versionName;
  final int versionCode;

  static const fallback = HostCapabilities(
    platform: 'unknown',
    supportsVolumeKeyPaging: false,
    versionName: '1.0.0',
    versionCode: 1,
  );
}

enum VolumeKeyEvent { up, down }

/// 原生文档选择器返回的本地书籍文件描述
@immutable
class PickedBookFile {
  const PickedBookFile({
    required this.path,
    required this.name,
    required this.size,
  });

  final String path;
  final String name;
  final int size;
}

/// Android / iOS 双端统一原生桥接服务
class HostBridge {
  HostBridge._() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static final HostBridge instance = HostBridge._();
  static const MethodChannel _channel =
      MethodChannel('com.kline.yuewei/host_bridge');

  final StreamController<VolumeKeyEvent> _volumeController =
      StreamController<VolumeKeyEvent>.broadcast();
  final StreamController<({String utteranceId, bool isError, String? message})>
      _ttsEventController = StreamController<
          ({String utteranceId, bool isError, String? message})>.broadcast();

  HostCapabilities _capabilities = HostCapabilities.fallback;
  bool _initialized = false;

  HostCapabilities get capabilities => _capabilities;
  Stream<VolumeKeyEvent> get volumeKeyStream => _volumeController.stream;
  Stream<({String utteranceId, bool isError, String? message})>
      get ttsEventStream => _ttsEventController.stream;

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    final args = call.arguments;
    final map = args is Map ? args : const <String, dynamic>{};
    switch (call.method) {
      case 'onVolumeDown':
        _volumeController.add(VolumeKeyEvent.down);
        return true;
      case 'onVolumeUp':
        _volumeController.add(VolumeKeyEvent.up);
        return true;
      case 'onTtsDone':
        _ttsEventController.add((
          utteranceId: (map['utteranceId'] as String?) ?? '',
          isError: false,
          message: null,
        ));
        return true;
      case 'onTtsError':
        _ttsEventController.add((
          utteranceId: (map['utteranceId'] as String?) ?? '',
          isError: true,
          message: map['message'] as String?,
        ));
        return true;
      default:
        return null;
    }
  }

  /// 初始化并获取宿主真实能力
  Future<HostCapabilities> initialize() async {
    if (_initialized) return _capabilities;
    try {
      final raw = await _channel
          .invokeMapMethod<String, dynamic>('getHostCapabilities')
          .timeout(const Duration(seconds: 2));
      if (raw != null) {
        _capabilities = HostCapabilities(
          platform: (raw['platform'] as String?) ?? 'unknown',
          supportsVolumeKeyPaging:
              (raw['supportsVolumeKeyPaging'] as bool?) ?? false,
          versionName: (raw['versionName'] as String?) ?? '1.0.0',
          versionCode: (raw['versionCode'] as int?) ?? 1,
        );
      }
    } catch (_) {
      // 单元测试或无宿主环境优雅回落默认值
    } finally {
      _initialized = true;
    }
    return _capabilities;
  }

  /// 受控开关物理音量键拦截：仅阅读中且无遮罩弹窗时开启，其余归还系统调音
  Future<void> setVolumeKeyIntercept(bool enabled) async {
    if (!_capabilities.supportsVolumeKeyPaging &&
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _channel.invokeMethod<bool>('setVolumeKeyIntercept', {
        'enabled': enabled,
      });
    } catch (_) {}
  }

  /// 控制阅读器屏幕常亮防休眠
  Future<void> keepScreenOn(bool enabled) async {
    try {
      await _channel.invokeMethod<bool>('keepScreenOn', {'enabled': enabled});
    } catch (_) {}
  }

  /// 调起双端原生文档选择器选取本地书籍（TXT / EPUB），取消或无返回值则返回 null
  Future<PickedBookFile?> pickLocalBookFile() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'pickLocalBookFile',
      );
      if (raw == null) return null;
      final path = (raw['path'] as String?)?.trim() ?? '';
      if (path.isEmpty) return null;
      final name = (raw['name'] as String?)?.trim() ?? '';
      final size = (raw['size'] as num?)?.toInt() ?? 0;
      return PickedBookFile(
        path: path,
        name: name.isNotEmpty ? name : path.split('/').last,
        size: size,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// 原生 TTS 朗读指定文本段落
  Future<bool> ttsSpeak({
    required String text,
    required String utteranceId,
    double rate = 1.0,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('ttsSpeak', {
        'text': text,
        'utteranceId': utteranceId,
        'rate': rate,
      });
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// 停止当前原生 TTS 朗读
  Future<bool> ttsStop() async {
    try {
      return (await _channel.invokeMethod<bool>('ttsStop')) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// 查询当前宿主原生 TTS 引擎是否可用
  Future<bool> ttsIsAvailable() async {
    try {
      return (await _channel.invokeMethod<bool>('ttsIsAvailable')) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// 调起系统保存选择器导出 UTF-8 文本文件（JSON/TXT），取消返回 null
  Future<String?> exportTextFile({
    required String fileName,
    required String content,
  }) async {
    try {
      final saved = await _channel.invokeMethod<String>('exportTextFile', {
        'fileName': fileName,
        'content': content,
      });
      return (saved == null || saved.trim().isEmpty) ? null : saved;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// 调起系统打开选择器读取 UTF-8 文本文件（JSON/TXT），取消返回 null
  Future<({String name, String content})?> pickAndReadTextFile() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'pickAndReadTextFile',
      );
      final content = raw?['content'] as String?;
      if (raw == null || content == null) return null;
      final name = (raw['name'] as String?)?.trim() ?? '';
      return (name: name.isNotEmpty ? name : 'imported.json', content: content);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// 调起系统安装器安装已下载 APK（Android 端支持 SHA-256 校验与权限引导；iOS 返回 UNSUPPORTED）
  Future<String> installApk({
    required String filePath,
    String? expectedSha256,
  }) async {
    final cleanPath = filePath.trim();
    if (cleanPath.isEmpty) {
      return 'FAILED:安装包路径为空';
    }
    try {
      final status = await _channel.invokeMethod<String>('installApk', {
        'filePath': cleanPath,
        if (expectedSha256 != null && expectedSha256.trim().isNotEmpty)
          'expectedSha256': expectedSha256.trim(),
      });
      if (status == null || status.trim().isEmpty) {
        return 'FAILED:宿主未返回安装结果';
      }
      return status.trim();
    } on MissingPluginException {
      return 'UNSUPPORTED';
    } on PlatformException catch (e) {
      return 'FAILED:${e.message ?? e.code}';
    }
  }

  /// 使用系统浏览器安全打开外部 HTTP/HTTPS 链接
  Future<bool> openExternalUrl(String url) async {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return false;
    }
    try {
      return (await _channel.invokeMethod<bool>('openExternalUrl', {
            'url': trimmed,
          })) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
