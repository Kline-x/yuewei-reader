import 'dart:convert';
import 'package:flutter/foundation.dart';

/// 将字体字节流注册到 Flutter 渲染引擎的回调签名（支持单测注入 Mock）
typedef CustomFontLoader = Future<void> Function(
  String fontFamily,
  Uint8List bytes,
);

/// 自定义字体魔数头校验与幂等哈希工具
class CustomFontCodec {
  const CustomFontCodec._();

  static const int defaultMaxFontBytes = 30 * 1024 * 1024;
  static const Set<String> supportedExtensions = {'.ttf', '.otf'};

  /// 校验 SFNT / OpenType / TrueType 魔数头（0x00010000 / OTTO / true / ttcf）
  static bool isValidFontHeader(List<int> bytes) {
    if (bytes.length < 4) return false;
    final b0 = bytes[0];
    final b1 = bytes[1];
    final b2 = bytes[2];
    final b3 = bytes[3];
    if (b0 == 0x00 && b1 == 0x01 && b2 == 0x00 && b3 == 0x00) return true;
    if (b0 == 0x4F && b1 == 0x54 && b2 == 0x54 && b3 == 0x4F) return true;
    if (b0 == 0x74 && b1 == 0x72 && b2 == 0x75 && b3 == 0x65) return true;
    if (b0 == 0x74 && b1 == 0x74 && b2 == 0x63 && b3 == 0x66) return true;
    return false;
  }

  /// 根据字节生成幂等字体 ID，防重复导入产生磁盘副本膨胀
  static String computeFontId(List<int> bytes) {
    var h1 = 0x811c9dc5;
    var h2 = 0x9e3779b9;
    for (final b in bytes) {
      h1 ^= b;
      h1 = (h1 * 0x01000193) & 0xFFFFFFFF;
      h2 = ((h2 << 5) | (h2 >>> 27)) & 0xFFFFFFFF;
      h2 ^= (b + 0x517cc1b7) & 0xFFFFFFFF;
    }
    h1 ^= bytes.length & 0xFFFFFFFF;
    h2 ^= (bytes.length * 0x85ebca6b) & 0xFFFFFFFF;
    final hex1 = h1.toRadixString(16).padLeft(8, '0');
    final hex2 = h2.toRadixString(16).padLeft(8, '0');
    return 'font_$hex1$hex2';
  }
}

/// 用户导入的轻量自定义字体元数据（仅记录相对文件名，隔离沙盒路径变更）
@immutable
class CustomFontEntry {
  const CustomFontEntry({
    required this.id,
    required this.displayName,
    required this.fontFamily,
    required this.fileName,
    required this.fileSizeBytes,
    required this.importedAt,
  });

  final String id;
  final String displayName;
  final String fontFamily;
  final String fileName;
  final int fileSizeBytes;
  final DateTime importedAt;

  CustomFontEntry copyWith({
    String? id,
    String? displayName,
    String? fontFamily,
    String? fileName,
    int? fileSizeBytes,
    DateTime? importedAt,
  }) {
    return CustomFontEntry(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      fontFamily: fontFamily ?? this.fontFamily,
      fileName: fileName ?? this.fileName,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      importedAt: importedAt ?? this.importedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'fontFamily': fontFamily,
      'fileName': fileName,
      'fileSizeBytes': fileSizeBytes,
      'importedAt': importedAt.toUtc().toIso8601String(),
    };
  }

  factory CustomFontEntry.fromJson(Map<String, dynamic> json) {
    final rawAt = json['importedAt'] as String?;
    return CustomFontEntry(
      id: (json['id'] as String? ?? '').trim(),
      displayName: (json['displayName'] as String? ?? '').trim(),
      fontFamily: (json['fontFamily'] as String? ?? '').trim(),
      fileName: (json['fileName'] as String? ?? '').trim(),
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt() ?? 0,
      importedAt: DateTime.tryParse(rawAt ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  /// 安全编码字体元数据列表为 JSON 字符串
  static String encodeList(List<CustomFontEntry> entries) {
    return jsonEncode(entries.map((e) => e.toJson()).toList());
  }

  /// 安全解码持久化 JSON 列表（单条损坏或整体格式异常时自动降级跳过）
  static List<CustomFontEntry> decodeList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final out = <CustomFontEntry>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final entry = CustomFontEntry.fromJson(item);
          if (entry.id.isNotEmpty &&
              entry.fontFamily.isNotEmpty &&
              entry.fileName.isNotEmpty) {
            out.add(entry);
          }
        } else if (item is Map) {
          final entry = CustomFontEntry.fromJson(
            item.map((k, v) => MapEntry('$k', v)),
          );
          if (entry.id.isNotEmpty &&
              entry.fontFamily.isNotEmpty &&
              entry.fileName.isNotEmpty) {
            out.add(entry);
          }
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  @override
  bool operator ==(Object other) {
    return other is CustomFontEntry &&
        other.id == id &&
        other.displayName == displayName &&
        other.fontFamily == fontFamily &&
        other.fileName == fileName &&
        other.fileSizeBytes == fileSizeBytes &&
        other.importedAt == importedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        displayName,
        fontFamily,
        fileName,
        fileSizeBytes,
        importedAt,
      );
}
