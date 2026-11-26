import 'package:html/dom.dart' as dom;

/// CSS 查询、Legado `||` 备选规则拆分与 HTML 实体安全解码辅助器
class RuleCssHelper {
  const RuleCssHelper._();

  static const Set<String> _knownAttrs = {
    'text',
    'textNodes',
    'html',
    'href',
    'src',
    'content',
    'title',
    'alt',
    'value',
  };

  /// 按括号与引号外的 `||` 拆分备选规则回退链
  static List<String> splitFallbackChains(String input) {
    if (!input.contains('||')) return [input];
    final parts = <String>[];
    final buf = StringBuffer();
    var depth = 0;
    String? quote;
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      if (quote != null) {
        buf.write(ch);
        if (ch == quote) quote = null;
        continue;
      }
      if (ch == '"' || ch == "'") {
        quote = ch;
        buf.write(ch);
        continue;
      }
      if (ch == '(' || ch == '[') {
        depth++;
        buf.write(ch);
        continue;
      }
      if (ch == ')' || ch == ']') {
        depth = depth > 0 ? depth - 1 : 0;
        buf.write(ch);
        continue;
      }
      if (depth == 0 && ch == '|' && i + 1 < input.length && input[i + 1] == '|') {
        final seg = buf.toString().trim();
        if (seg.isNotEmpty) parts.add(seg);
        buf.clear();
        i++;
        continue;
      }
      buf.write(ch);
    }
    final tail = buf.toString().trim();
    if (tail.isNotEmpty) parts.add(tail);
    return parts.isEmpty ? [input] : parts;
  }

  /// 解析单个备选分支可能携带的尾部 `@attr`（仅识别明确属性名，不误伤 `@tag.a` 等链式选择器）
  static ({String selector, String attr}) parseBranchAttr(
    String branch,
    String fallbackAttr,
  ) {
    final trimmed = branch.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('@xpath:') ||
        trimmed.startsWith('//') ||
        trimmed.startsWith(r'$.')) {
      return (selector: trimmed, attr: fallbackAttr);
    }
    final lastAt = trimmed.lastIndexOf('@');
    if (lastAt >= 0) {
      final tail = trimmed.substring(lastAt + 1).trim();
      final isKnown = _knownAttrs.contains(tail) ||
          RegExp(r'^data-[a-zA-Z0-9_\-]+$').hasMatch(tail);
      if (isKnown) {
        return (
          selector: trimmed.substring(0, lastAt).trim(),
          attr: tail == 'textNodes' ? 'text' : tail,
        );
      }
    }
    return (selector: trimmed, attr: fallbackAttr);
  }

  /// 安全 HTML 实体解码：先解命名与数字实体（放行 &#10;/&#13;），最后解 &amp; 防双重反转义
  static String decodeHtmlEntities(String input) {
    var out = input
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#160;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&mdash;', '—')
        .replaceAll('&hellip;', '…')
        .replaceAll('&ldquo;', '“')
        .replaceAll('&rdquo;', '”');

    out = out.replaceAllMapped(RegExp(r'&#([xX]?)([0-9a-fA-F]{1,8});'), (m) {
      final isHex = m.group(1)!.isNotEmpty;
      final code = int.tryParse(m.group(2)!, radix: isHex ? 16 : 10);
      if (code == null || code > 0x10FFFF) return '';
      if (code == 0x0A || code == 0x0D) return String.fromCharCode(code);
      if (code < 0x20 || (code >= 0xD800 && code <= 0xDFFF)) return '';
      return String.fromCharCode(code);
    });

    return out.replaceAll('&amp;', '&');
  }

  /// 支持多分支逗号（保护括号内逗号）、`:contains(...)`、Legado 简写与 `.0`/`.-1` 索引切片
  static List<dom.Element> queryCssElements(dom.Element? scope, String selector) {
    if (scope == null || selector.trim().isEmpty) return const [];
    final branches = splitBranches(selector);
    for (final branch in branches) {
      final res = _querySingleBranch(scope, branch);
      if (res.isNotEmpty) return res;
    }
    return const [];
  }

  static List<dom.Element> _querySingleBranch(dom.Element scope, String rawBranch) {
    var branch = rawBranch.trim();
    if (branch.isEmpty) return const [];

    int? sliceIndex;
    final idxMatch = RegExp(r'\.(-?\d+)$').firstMatch(branch);
    if (idxMatch != null) {
      sliceIndex = int.tryParse(idxMatch.group(1)!);
      branch = branch.substring(0, idxMatch.start);
    }

    branch = branch
        .replaceAllMapped(RegExp(r'\bclass\.([a-zA-Z0-9_\-]+)'), (m) => '.${m.group(1)}')
        .replaceAllMapped(RegExp(r'\bid\.([a-zA-Z0-9_\-]+)'), (m) => '#${m.group(1)}')
        .replaceAllMapped(RegExp(r'\btag\.([a-zA-Z0-9_\-]+)'), (m) => '${m.group(1)}')
        .replaceAll('@', ' ');

    final containsMatch =
        RegExp(r'^(.*?):contains\(([^)]+)\)(.*)$').firstMatch(branch);
    List<dom.Element> candidates;
    try {
      if (containsMatch != null) {
        final baseSel = containsMatch.group(1)!.trim();
        final keyword =
            containsMatch.group(2)!.replaceAll('"', '').replaceAll("'", '').trim();
        final tailSel = containsMatch.group(3)!.trim();
        final matched = (baseSel.isEmpty ? [scope] : scope.querySelectorAll(baseSel))
            .where((e) => e.text.contains(keyword))
            .toList();
        if (tailSel.isEmpty) {
          candidates = matched;
        } else {
          candidates = [
            for (final m in matched) ...m.querySelectorAll(tailSel),
          ];
        }
      } else {
        candidates = scope.querySelectorAll(branch);
      }
    } catch (_) {
      return const [];
    }

    if (sliceIndex != null) {
      if (candidates.isEmpty) return const [];
      final resolved =
          sliceIndex < 0 ? candidates.length + sliceIndex : sliceIndex;
      if (resolved < 0 || resolved >= candidates.length) return const [];
      return [candidates[resolved]];
    }
    return candidates;
  }

  static List<String> splitBranches(String input) {
    final parts = <String>[];
    final buf = StringBuffer();
    var parenDepth = 0;
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      if (ch == '(' || ch == '[') parenDepth++;
      if (ch == ')' || ch == ']') {
        parenDepth = parenDepth > 0 ? parenDepth - 1 : 0;
      }
      if (ch == ',' && parenDepth == 0) {
        if (buf.isNotEmpty) parts.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    if (buf.isNotEmpty) parts.add(buf.toString());
    return parts;
  }
}
