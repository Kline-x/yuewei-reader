import 'package:characters/characters.dart';
import '../domain/book_source_rule.dart';
import 'rule_evaluator.dart';

/// 书籍元数据清洗与通用 OpenGraph 回退提取工具
class BookMetadataSanitizer {
  const BookMetadataSanitizer._();

  /// 从 HTML 根节点的 OpenGraph `<meta property="og:...">` 提取通用兜底值
  static String extractOgMeta(
    RuleEvaluator evaluator,
    EvaluatedNode rootNode,
    String propertyName, {
    String baseUrl = '',
  }) {
    final attrType =
        (propertyName == 'og:image' || propertyName == 'og:novel:read_url')
            ? 'src'
            : 'content';
    var val = evaluator.evaluateField(
      rootNode,
      RuleField(selector: 'meta[property="$propertyName"]', attr: 'content'),
    );
    if (val.isNotEmpty && attrType == 'src' && baseUrl.isNotEmpty) {
      val = RuleEvaluator.resolveUrl(baseUrl, val);
    }
    return val;
  }

  static String sanitizeBadge(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty || cleaned.length > 16) return '';
    if (cleaned.contains('<script') ||
        cleaned.contains('function(') ||
        cleaned.contains('window.') ||
        cleaned.contains('最新章节') ||
        cleaned.contains('无错字') ||
        cleaned.contains('免费阅读')) {
      return '';
    }
    return cleaned;
  }

  /// 过滤 SEO 垃圾模板并剥离站方推广尾巴，还原洁净作品简介
  static String cleanSeoIntro(String raw) {
    var s = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return '';
    if (RegExp(r'^\d+$').hasMatch(s)) return '';
    if (s.contains('window.') || s.contains('function(') || s.contains('<script')) {
      return '';
    }
    if (RegExp(r'最新章节.*(?:无错字|免费阅读)|^\S+\([^)]+\)-\S+-最新章节').hasMatch(s)) {
      return '';
    }

    final introMarker = RegExp(r'(?:内容)?(?:简介|介绍)[：:]\s*').firstMatch(s);
    if (introMarker != null) {
      s = s.substring(introMarker.end).trim();
    }
    s = s.replaceFirst(RegExp(r'^\d+\s+'), '').trim();

    // 剥离站点常见文末推广后缀（含求书网新版站方推广套话）
    s = s
        .replaceAll(RegExp(r'《[^》]+》是作家「[^」]+」倾力打造.*$'), '')
        .replaceAll(RegExp(r'本书由[^。]*为您呈现.*$'), '')
        .replaceAll(RegExp(r'作者[：:][^\n]*所写的《[^》]+》.*$'), '')
        .replaceAll(RegExp(r'无弹窗推荐地址[：:].*$'), '')
        .replaceAll(
          RegExp(
            r'(?:《[^》]+》|\S+)?已更新[，,]\s*本站除提供.*?(?:在线阅读|免费阅读).*$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(r'还提供\s*txt\s*电子书下载.*$', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(
            r'(?:《[^》]+》)?在手机(?:上)?也可以完美阅读(?:和下载)?[！!。]?\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    if (s.isEmpty) return '';
    if (RegExp(r'提供.*创作的.*最新章节在线阅读.*(?:无错字|免费阅读)').hasMatch(s) ||
        RegExp(r'提供《.*》的最新章节和全文阅读').hasMatch(s) ||
        RegExp(r'欢迎光临本站阅读').hasMatch(s) ||
        RegExp(r'本站提供.*无错字').hasMatch(s) ||
        RegExp(r'各位书友要是觉得《.*》还不错').hasMatch(s) ||
        RegExp(
          r'已更新[，,]\s*本站除提供.*在线阅读|还提供\s*txt\s*电子书下载|在手机(?:上)?也可以完美阅读(?:和下载)?',
          caseSensitive: false,
        ).hasMatch(s)) {
      return '';
    }
    final chars = s.characters;
    return chars.length > 600 ? '${chars.take(600)}…' : s;
  }

  /// 清洗章节更新时间（剥离前缀标签并拒绝“未知时间”或超长脏文本）
  static String sanitizeUpdateTime(String raw) {
    var s = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return '';
    s = s
        .replaceFirst(RegExp(r'^(?:最后|最近)?更新时间[：:]\s*'), '')
        .replaceFirst(RegExp(r'^最后更新[：:]\s*'), '')
        .trim();
    if (s.isEmpty ||
        s.length > 32 ||
        s.contains('未知时间') ||
        s.contains('暂无') ||
        s.contains('<script') ||
        s.contains('function(') ||
        s.contains('window.')) {
      return '';
    }
    return s;
  }

  static String sanitizeLatestChapter(String raw) {
    final s = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty ||
        s.length > 80 ||
        s.contains('<script') ||
        s.contains('function(')) {
      return '';
    }
    return s.replaceFirst(RegExp(r'^最新章节[：:]\s*'), '').trim();
  }
}
