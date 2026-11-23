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

/// Android / iOS 双端统一原生桥接服务
class HostBridge {
  HostBridge._() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static final HostBridge instance = HostBridge._();
  static const MethodChannel _channel = MethodChannel('com.kline.yuewei/host_bridge');

  final StreamController<VolumeKeyEvent> _volumeController =
      StreamController<VolumeKeyEvent>.broadcast();

  HostCapabilities _capabilities = HostCapabilities.fallback;
  bool _initialized = false;

  HostCapabilities get capabilities => _capabilities;
  Stream<VolumeKeyEvent> get volumeKeyStream => _volumeController.stream;

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onVolumeDown':
        _volumeController.add(VolumeKeyEvent.down);
        return true;
      case 'onVolumeUp':
        _volumeController.add(VolumeKeyEvent.up);
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
    if (!_capabilities.supportsVolumeKeyPaging && defaultTargetPlatform != TargetPlatform.android) {
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
}
