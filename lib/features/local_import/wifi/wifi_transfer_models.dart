import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Wi-Fi 传书单次接收成功条目
@immutable
class WifiReceivedItem {
  const WifiReceivedItem({
    required this.fileName,
    required this.kind,
    required this.displayTitle,
    required this.itemCount,
    required this.receivedAt,
    this.bookId,
  });

  final String fileName;
  final String kind; // 'book' or 'source'
  final String displayTitle;
  final int itemCount;
  final DateTime receivedAt;
  final String? bookId;
}

/// 枚举并按局域网可达优先级排序 IPv4 地址（192.168. > 10. > 172.16-31.）
Future<List<String>> resolveWifiLanIps() async {
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

int _ipPriority(String ip) {
  if (ip.startsWith('192.168.')) return 100;
  if (ip.startsWith('10.')) return 80;
  if (ip.startsWith('172.')) {
    final parts = ip.split('.');
    final second = parts.length >= 2 ? int.tryParse(parts[1]) ?? -1 : -1;
    if (second >= 16 && second <= 31) return 70;
  }
  return 10;
}

/// 清洗上传文件名：保留常见中文书名/作者标点（《》（）：【】等），严禁 `/` `\` `..` 与控制字符，
/// 并修复以点开头如 `.epub` 被剥离后缀的问题。
String sanitizeWifiUploadFileName(String? rawName) {
  final trimmed = (rawName ?? '').trim();
  if (trimmed.isEmpty) return 'upload.txt';

  final base = p.posix.basename(trimmed.replaceAll('\\', '/'));
  var safe = base
      .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
      .replaceAll(RegExp(r'[^a-zA-Z0-9._\-\u4E00-\u9FFF 《》（）：:【】\[\]()、·]'), '_')
      .replaceAll(RegExp(r'\.{2,}'), '.')
      .trim();

  if (safe.isEmpty || safe == '.') return 'upload.txt';

  // 形如 `.epub` / `.txt` 的纯后缀文件名自动补全安全主干，避免剥成无后缀
  if (safe.startsWith('.')) {
    if (RegExp(r'^\.[a-zA-Z0-9]+$').hasMatch(safe)) {
      return 'upload$safe';
    }
    safe = safe.replaceFirst(RegExp(r'^\.+'), '').trim();
  }

  return safe.isEmpty ? 'upload.txt' : safe;
}
