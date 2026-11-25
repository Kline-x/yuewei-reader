import 'package:flutter/foundation.dart';

/// 单源搜索命中结果
@immutable
class SourceSearchHit {
  const SourceSearchHit({
    required this.sourceId,
    required this.sourceName,
    required this.title,
    required this.author,
    required this.bookUrl,
    this.coverUrl = '',
    this.intro = '',
    this.latestChapter = '',
    required this.latencyMs,
  });

  final String sourceId;
  final String sourceName;
  final String title;
  final String author;
  final String bookUrl;
  final String coverUrl;
  final String intro;
  final String latestChapter;
  final int latencyMs;

  String get cleanTitle => normalizeBookKey(title);
  String get cleanAuthor => normalizeBookKey(author);

  static String normalizeBookKey(String raw) {
    return raw
        .replaceAll(RegExp(r'[《》【】\[\]\s（()）]'), '')
        .toLowerCase()
        .trim();
  }
}

/// 聚合书目卡片：把来自不同书源的同一本书归并展示（追更体验核心）
@immutable
class AggregatedBookMatch {
  AggregatedBookMatch({
    required this.cleanTitle,
    required this.cleanAuthor,
    required this.hits,
  }) : assert(hits.isNotEmpty);

  final String cleanTitle;
  final String cleanAuthor;
  final List<SourceSearchHit> hits;

  SourceSearchHit get primaryHit => hits.first;
  String get displayTitle => primaryHit.title;
  String get displayAuthor =>
      primaryHit.author.isNotEmpty ? primaryHit.author : '未知作者';
  String get bestCoverUrl => hits
      .map((h) => h.coverUrl)
      .firstWhere((c) => c.isNotEmpty, orElse: () => '');
  String get bestIntro {
    var best = '';
    var bestScore = 0;
    for (final hit in hits) {
      final candidate = hit.intro.trim();
      final score = _introQualityScore(candidate);
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    return best;
  }

  static final RegExp _introNoiseRe = RegExp(
    r'[\s\.\u2026·,，。!！?？:：;；\-—_~`"\x27“”‘’()（）【】\[\]《》<>]+',
  );
  static final RegExp _introPlaceholderRe = RegExp(
    r'^(?:暂无|无)?(?:内容|作品|书籍)?(?:简介|介绍|描述)(?:暂无)?$',
  );

  /// 过滤省略号、常见占位词或有效内容不足 4 字的无效简介，有效串返回核心字符长度用于择优
  static int _introQualityScore(String raw) {
    if (raw.isEmpty) return 0;
    final core = raw.replaceAll(_introNoiseRe, '');
    if (core.length < 4 || _introPlaceholderRe.hasMatch(core)) return 0;
    return core.length;
  }
  int get fastestLatencyMs =>
      hits.map((h) => h.latencyMs).reduce((a, b) => a < b ? a : b);
  int get sourceCount => hits.length;

  /// 生成跨书源归并统一 ID（确保同书不同源进入详情页时同一标识）
  String get canonicalBookId {
    final key = '${cleanTitle}_$cleanAuthor';
    return 'book_${_fnv1a32(key).toRadixString(16)}';
  }

  static int _fnv1a32(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }
}

@immutable
class ParsedBookDetail {
  const ParsedBookDetail({
    required this.title,
    required this.author,
    required this.intro,
    required this.coverUrl,
    required this.tocUrl,
    required this.statusText,
    required this.category,
    this.latestChapter = '',
    this.lastUpdateTime = '',
  });

  final String title;
  final String author;
  final String intro;
  final String coverUrl;
  final String tocUrl;
  final String statusText;
  final String category;
  final String latestChapter;
  final String lastUpdateTime;
}

@immutable
class ParsedChapterEntry {
  const ParsedChapterEntry({
    required this.index,
    required this.title,
    required this.url,
  });

  final int index;
  final String title;
  final String url;
}
