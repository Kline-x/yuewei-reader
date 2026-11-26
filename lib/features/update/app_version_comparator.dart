import 'package:flutter/foundation.dart';

/// 语义化版本号解析结果（支持 v 前缀、预发布后缀与 +构建号）
@immutable
class SemanticVersion implements Comparable<SemanticVersion> {
  const SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.preRelease = const <String>[],
    this.buildMetadata,
  });

  final int major;
  final int minor;
  final int patch;
  final List<String> preRelease;
  final String? buildMetadata;

  static final RegExp _pattern = RegExp(
    r'^[vV]?(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:-([0-9A-Za-z.\-]+))?(?:\+([0-9A-Za-z.\-]+))?$',
  );

  static SemanticVersion? tryParse(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return null;
    final match = _pattern.firstMatch(clean);
    if (match == null) return null;

    final major = int.tryParse(match.group(1) ?? '');
    final minor = int.tryParse(match.group(2) ?? '0');
    final patch = int.tryParse(match.group(3) ?? '0');
    if (major == null || minor == null || patch == null) return null;

    final preRaw = match.group(4);
    final preParts = (preRaw == null || preRaw.isEmpty)
        ? const <String>[]
        : preRaw.split('.').where((e) => e.isNotEmpty).toList(growable: false);
    final buildRaw = match.group(5);

    return SemanticVersion(
      major: major,
      minor: minor,
      patch: patch,
      preRelease: preParts,
      buildMetadata:
          (buildRaw != null && buildRaw.isNotEmpty) ? buildRaw : null,
    );
  }

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);

    // 正式版优先级高于预发布版本
    if (preRelease.isEmpty && other.preRelease.isNotEmpty) return 1;
    if (preRelease.isNotEmpty && other.preRelease.isEmpty) return -1;

    final minLen = preRelease.length < other.preRelease.length
        ? preRelease.length
        : other.preRelease.length;
    for (var i = 0; i < minLen; i++) {
      final cmp = _compareIdentifier(preRelease[i], other.preRelease[i]);
      if (cmp != 0) return cmp;
    }
    if (preRelease.length != other.preRelease.length) {
      return preRelease.length.compareTo(other.preRelease.length);
    }

    // 仅当双方均显式携带构建号时才比较构建号（避免 v1.0.0 与 1.0.0+1 误判）
    if (buildMetadata != null && other.buildMetadata != null) {
      final aParts = buildMetadata!.split('.');
      final bParts = other.buildMetadata!.split('.');
      final bMin = aParts.length < bParts.length ? aParts.length : bParts.length;
      for (var i = 0; i < bMin; i++) {
        final cmp = _compareIdentifier(aParts[i], bParts[i]);
        if (cmp != 0) return cmp;
      }
      return aParts.length.compareTo(bParts.length);
    }
    return 0;
  }

  static int _compareIdentifier(String a, String b) {
    final aNum = int.tryParse(a);
    final bNum = int.tryParse(b);
    if (aNum != null && bNum != null) return aNum.compareTo(bNum);
    if (aNum != null && bNum == null) return -1;
    if (aNum == null && bNum != null) return 1;
    return a.compareTo(b);
  }
}

/// 语义化版本比较器
abstract final class AppVersionComparator {
  /// 去除前导 v/V 与多余空白
  static String normalize(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
      return trimmed.substring(1).trim();
    }
    return trimmed;
  }

  /// 比较两个版本字符串（a > b 返回正数，相等返回 0，a < b 返回负数）
  static int compare(String a, String b) {
    final va = SemanticVersion.tryParse(a);
    final vb = SemanticVersion.tryParse(b);
    if (va != null && vb != null) {
      return va.compareTo(vb);
    }
    return normalize(a).compareTo(normalize(b));
  }

  /// 判断远端版本是否严格高于当前版本
  static bool isNewer({
    required String remoteVersion,
    required String currentVersion,
  }) {
    return compare(remoteVersion, currentVersion) > 0;
  }
}

/// SHA-256 校验文本解析器（兼容 sha256sum 输出与纯 64 位十六进制）
abstract final class Sha256Parser {
  static final RegExp _linePattern = RegExp(
    r'^\s*([0-9a-fA-F]{64})(?:\s+[*]?(.+?))?\s*$',
  );
  static final RegExp _inlineHexPattern = RegExp(r'\b([0-9a-fA-F]{64})\b');

  static String? extract(String rawText, {String? fileName}) {
    final lines = rawText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    final targetName = fileName?.trim().toLowerCase();
    String? firstValid;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final match = _linePattern.firstMatch(trimmed);
      if (match != null) {
        final hash = match.group(1)!.toLowerCase();
        final entryName = (match.group(2) ?? '').trim().toLowerCase();
        firstValid ??= hash;
        if (targetName != null &&
            targetName.isNotEmpty &&
            entryName.isNotEmpty &&
            (entryName == targetName || entryName.endsWith('/$targetName'))) {
          return hash;
        }
      }
    }
    if (firstValid != null) return firstValid;

    final fallback = _inlineHexPattern.firstMatch(rawText);
    return fallback?.group(1)?.toLowerCase();
  }
}
