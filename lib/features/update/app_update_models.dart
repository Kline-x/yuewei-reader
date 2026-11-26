import 'package:flutter/foundation.dart';
import 'app_version_comparator.dart';

export 'app_version_comparator.dart';

/// GitHub Release 应用更新元数据模型
@immutable
class AppReleaseInfo {
  const AppReleaseInfo({
    required this.tagName,
    required this.version,
    required this.name,
    required this.releaseNotes,
    required this.htmlUrl,
    this.publishedAt,
    this.apkDownloadUrl,
    this.apkFileName,
    this.apkSizeBytes,
    this.sha256AssetUrl,
  });

  final String tagName;
  final String version;
  final String name;
  final String releaseNotes;
  final String htmlUrl;
  final DateTime? publishedAt;
  final String? apkDownloadUrl;
  final String? apkFileName;
  final int? apkSizeBytes;
  final String? sha256AssetUrl;

  bool get hasApkAsset =>
      apkDownloadUrl != null && apkDownloadUrl!.trim().isNotEmpty;

  /// 将字节数格式化为人类可读的安装包大小
  String get formattedApkSize {
    final bytes = apkSizeBytes;
    if (bytes == null || bytes <= 0) return '';
    return formatByteSize(bytes);
  }

  /// 从 GitHub Releases API JSON 解析发行版信息
  factory AppReleaseInfo.fromGitHubJson(Map<String, dynamic> json) {
    final rawTag = (json['tag_name'] as String?)?.trim() ?? '';
    if (rawTag.isEmpty) {
      throw const FormatException('Release JSON 缺少有效的 tag_name');
    }
    final normalizedVersion = AppVersionComparator.normalize(rawTag);
    final rawName = (json['name'] as String?)?.trim() ?? '';
    final rawBody = ((json['body'] as String?) ?? '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    final htmlUrl = _validHttpUrl(json['html_url'] as String?) ??
        'https://github.com/Kline-x/yuewei-reader/releases';
    final publishedAt =
        DateTime.tryParse((json['published_at'] as String?)?.trim() ?? '');

    String? apkUrl;
    String? apkName;
    int? apkSize;
    String? shaUrl;

    final rawAssets = json['assets'];
    if (rawAssets is List) {
      final apkAssets = <Map<String, dynamic>>[];
      final shaAssets = <Map<String, dynamic>>[];

      for (final item in rawAssets) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final assetName = (map['name'] as String?)?.trim() ?? '';
        final dlUrl = _validHttpUrl(map['browser_download_url'] as String?);
        if (assetName.isEmpty || dlUrl == null) continue;
        final lower = assetName.toLowerCase();
        if (lower.endsWith('.apk')) {
          apkAssets.add({...map, '_dl': dlUrl, '_name': assetName});
        } else if (lower.endsWith('.sha256') || lower.endsWith('.sha256sum')) {
          shaAssets.add({...map, '_dl': dlUrl, '_name': assetName});
        }
      }

      if (apkAssets.isNotEmpty) {
        final chosen = _pickBestApkAsset(apkAssets);
        apkUrl = chosen['_dl'] as String;
        apkName = chosen['_name'] as String;
        apkSize = (chosen['size'] as num?)?.toInt();
      }

      if (shaAssets.isNotEmpty) {
        final chosenSha = _pickMatchingSha256Asset(shaAssets, apkName);
        shaUrl = chosenSha['_dl'] as String;
      }
    }

    return AppReleaseInfo(
      tagName: rawTag,
      version: normalizedVersion,
      name: rawName.isNotEmpty ? rawName : rawTag,
      releaseNotes: rawBody,
      htmlUrl: htmlUrl,
      publishedAt: publishedAt,
      apkDownloadUrl: apkUrl,
      apkFileName: apkName,
      apkSizeBytes: apkSize,
      sha256AssetUrl: shaUrl,
    );
  }

  static Map<String, dynamic> _pickBestApkAsset(
    List<Map<String, dynamic>> candidates,
  ) {
    for (final c in candidates) {
      final lower = (c['_name'] as String).toLowerCase();
      if (lower.contains('arm64') || lower.contains('release')) return c;
    }
    return candidates.first;
  }

  static Map<String, dynamic> _pickMatchingSha256Asset(
    List<Map<String, dynamic>> candidates,
    String? apkName,
  ) {
    if (apkName != null && apkName.isNotEmpty) {
      final exact = '${apkName.toLowerCase()}.sha256';
      for (final c in candidates) {
        final lower = (c['_name'] as String).toLowerCase();
        if (lower == exact || lower.contains(apkName.toLowerCase())) return c;
      }
    }
    return candidates.first;
  }

  static String? _validHttpUrl(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return null;
    }
    return trimmed;
  }

  static String formatByteSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024.0;
    if (kb < 1024.0) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024.0).toStringAsFixed(1)} MB';
  }
}

enum AppUpdateCheckStatus { hasUpdate, upToDate, ignored, throttled, failed }

/// 检查更新结果快照
@immutable
class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.status,
    required this.currentVersion,
    this.release,
    this.errorMessage,
  });

  final AppUpdateCheckStatus status;
  final String currentVersion;
  final AppReleaseInfo? release;
  final String? errorMessage;

  bool get hasUpdate =>
      status == AppUpdateCheckStatus.hasUpdate && release != null;
}

enum ApkInstallStatus {
  started,
  needInstallPermission,
  hashMismatch,
  unsupported,
  cancelled,
  failed,
}

/// APK 下载与原生安装执行结果
@immutable
class ApkInstallOutcome {
  const ApkInstallOutcome({
    required this.status,
    required this.statusCode,
    required this.message,
    this.apkFilePath,
    this.expectedSha256,
  });

  final ApkInstallStatus status;
  final String statusCode;
  final String message;
  final String? apkFilePath;
  final String? expectedSha256;

  factory ApkInstallOutcome.fromNativeStatus(
    String rawStatus, {
    String? apkFilePath,
    String? expectedSha256,
  }) {
    final code = rawStatus.trim();
    if (code == 'STARTED') {
      return ApkInstallOutcome(
        status: ApkInstallStatus.started,
        statusCode: code,
        message: '已调起系统安装程序',
        apkFilePath: apkFilePath,
        expectedSha256: expectedSha256,
      );
    }
    if (code == 'NEED_INSTALL_PERMISSION') {
      return ApkInstallOutcome(
        status: ApkInstallStatus.needInstallPermission,
        statusCode: code,
        message: '请先在系统设置中开启“允许安装未知应用”，返回后点击继续安装',
        apkFilePath: apkFilePath,
        expectedSha256: expectedSha256,
      );
    }
    if (code == 'HASH_MISMATCH') {
      return const ApkInstallOutcome(
        status: ApkInstallStatus.hashMismatch,
        statusCode: 'HASH_MISMATCH',
        message: '安装包 SHA-256 校验不一致，已清理损坏文件，请重试或改用浏览器下载',
      );
    }
    if (code == 'UNSUPPORTED') {
      return const ApkInstallOutcome(
        status: ApkInstallStatus.unsupported,
        statusCode: 'UNSUPPORTED',
        message: '当前平台不支持应用内直装，请前往发布页面下载',
      );
    }
    final detail = code.startsWith('FAILED:')
        ? code.substring('FAILED:'.length).trim()
        : code;
    return ApkInstallOutcome(
      status: ApkInstallStatus.failed,
      statusCode: code.isEmpty ? 'FAILED' : code,
      message: detail.isNotEmpty ? '安装失败：$detail' : '调起安装器失败，请改用浏览器下载',
      apkFilePath: apkFilePath,
      expectedSha256: expectedSha256,
    );
  }
}
