import 'package:flutter/foundation.dart';

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

/// 物理音量键事件
enum VolumeKeyEvent { up, down }

/// 系统媒体控制中心（锁屏 / 通知栏 / 蓝牙耳机）派发的控制指令
enum MediaCommandAction {
  play,
  pause,
  toggle,
  next,
  prev,
  stop;

  /// 从原生通道载荷字符串安全解析指令（未知或空值返回 null）
  static MediaCommandAction? fromWireName(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim().toLowerCase();
    for (final action in MediaCommandAction.values) {
      if (action.name == normalized) return action;
    }
    return null;
  }
}

/// 原生文档选择器返回的本地文件（书籍 / 字体）描述
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
