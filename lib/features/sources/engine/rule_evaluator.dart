import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:json_path/json_path.dart';
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';
import '../domain/book_source_rule.dart';

/// 多引擎规则求值器：CSS（支持 :contains 与 Legado .0/.-1 索引切片）+ XPath + JSONPath
class RuleEvaluator {
  const RuleEvaluator();

  /// 将原始文本提取为节点封装列表，用于列表遍历（搜索结果 / 目录项）
  List<EvaluatedNode> selectNodes(String rawContent, String rule) {
    final trimmed = rule.trim();
    if (trimmed.isEmpty || rawContent.trim().isEmpty) return const [];

    if (trimmed.startsWith(r'$.') || trimmed.startsWith('@json:')) {
      final pathExpr = trimmed.replaceFirst(RegExp(r'^@json:'), '').trim();
      return _selectJsonNodes(rawContent, pathExpr);
    }

    if (trimmed.startsWith('@xpath:') || trimmed.startsWith('//')) {
      final xpExpr = trimmed.replaceFirst(RegExp(r'^@xpath:'), '').trim();
      return _selectXpathNodes(rawContent, xpExpr);
    }

    final doc = html_parser.parse(rawContent);
    final elements = _queryCssElements(doc.documentElement, trimmed);
    return elements.map((e) => EvaluatedNode.html(e)).toList();
  }

  /// 在根文档或节点上提取单一字符串值
  String evaluateField(
    EvaluatedNode root,
    RuleField field, {
    String baseUrl = '',
  }) {
    if (field.isEmpty) return '';

    String raw = '';
    if (root.jsonValue != null) {
      raw = _extractFromJson(root.jsonValue, field);
    } else if (root.htmlTextFallback != null) {
      raw = root.htmlTextFallback!;
    } else if (root.element != null) {
      raw = _extractFromHtmlElement(root.element!, field);
    }

    if (raw.isEmpty) return '';

    if (field.regex.isNotEmpty) {
      try {
        raw = raw.replaceAll(RegExp(field.regex, multiLine: true), '');
      } catch (_) {}
    }

    raw = raw.trim();
    if (raw.isNotEmpty &&
        (field.attr == 'href' || field.attr == 'src') &&
        baseUrl.isNotEmpty) {
      raw = resolveUrl(baseUrl, raw);
    }
    return raw;
  }

  /// 解析并补全相对 URL
  static String resolveUrl(String baseUrl, String relative) {
    final rel = relative.trim();
    if (rel.isEmpty) return '';
    if (rel.startsWith('http://') || rel.startsWith('https://')) return rel;
    if (rel.startsWith('//')) {
      final scheme = baseUrl.startsWith('https') ? 'https:' : 'http:';
      return '$scheme$rel';
    }
    try {
      return Uri.parse(baseUrl).resolve(rel).toString();
    } catch (_) {
      return rel;
    }
  }

  /// 安全 HTML 实体解码（严格校验 Unicode 合法区间防止 RangeError 崩溃）
  static String decodeHtmlEntities(String input) {
    var out = input
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#160;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&mdash;', '—')
        .replaceAll('&hellip;', '…')
        .replaceAll('&ldquo;', '“')
        .replaceAll('&rdquo;', '”');

    out = out.replaceAllMapped(RegExp(r'&#(x?)([0-9a-fA-F]{1,8});'), (m) {
      final isHex = m.group(1) == 'x';
      final code = int.tryParse(m.group(2)!, radix: isHex ? 16 : 10);
      if (code == null || code < 0x20 || code > 0x10FFFF) {
        return '';
      }
      if (code >= 0xD800 && code <= 0xDFFF) return '';
      return String.fromCharCode(code);
    });
    return out;
  }

  List<EvaluatedNode> _selectJsonNodes(String rawJson, String expr) {
    try {
      final decoded = jsonDecode(rawJson);
      final jp = JsonPath(expr);
      final matches = jp.read(decoded);
      final nodes = <EvaluatedNode>[];
      for (final m in matches) {
        final v = m.value;
        if (v is List) {
          for (final item in v) {
            nodes.add(EvaluatedNode.json(item));
          }
        } else if (v != null) {
          nodes.add(EvaluatedNode.json(v));
        }
      }
      return nodes;
    } catch (_) {
      return const [];
    }
  }

  List<EvaluatedNode> _selectXpathNodes(String rawHtml, String expr) {
    try {
      final doc = html_parser.parse(rawHtml);
      final xp = HtmlXPath.node(doc.documentElement!);
      final result = xp.query(expr);
      return result.nodes.map((n) {
        final node = n.node;
        if (node is dom.Element) return EvaluatedNode.html(node);
        return EvaluatedNode.text(n.text ?? '');
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  String _extractFromJson(dynamic jsonVal, RuleField field) {
    final sel = field.selector.trim();
    if (sel.isEmpty) return jsonVal.toString();
    try {
      final pathExpr = sel.startsWith(r'$') ? sel : '\$.$sel';
      final hits = JsonPath(pathExpr).read(jsonVal);
      if (hits.isEmpty) return '';
      return hits.first.value?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  String _extractFromHtmlElement(dom.Element el, RuleField field) {
    final sel = field.selector.trim();
    final attr = field.attr.trim().isEmpty ? 'text' : field.attr.trim();

    if (sel.startsWith('@xpath:') || sel.startsWith('//')) {
      final xpExpr = sel.replaceFirst(RegExp(r'^@xpath:'), '').trim();
      try {
        final hit = HtmlXPath.node(el).query(xpExpr).node;
        if (hit == null) return '';
        if (attr == 'text') return hit.text ?? '';
        return hit.attributes[attr] ?? hit.text ?? '';
      } catch (_) {
        return '';
      }
    }

    dom.Element? target = el;
    if (sel.isNotEmpty) {
      final hits = _queryCssElements(el, sel);
      if (hits.isEmpty) return '';
      target = hits.first;
    }

    if (attr == 'html') {
      return target.innerHtml;
    }
    if (attr == 'text' || attr == 'textNodes') {
      return decodeHtmlEntities(_extractVisibleText(target)).trim();
    }
    if (attr == 'src') {
      final src = (target.attributes['src'] ?? '').trim();
      if (src.isEmpty ||
          src.startsWith('data:') ||
          src.contains('loading') ||
          src.contains('default')) {
        final lazy = target.attributes['data-src'] ??
            target.attributes['data-original'] ??
            target.attributes['data-echo'] ??
            src;
        return lazy.trim();
      }
      return src;
    }
    return (target.attributes[attr] ?? '').trim();
  }

  static String _extractVisibleText(dom.Element target) {
    if (target.querySelector('script, style, noscript') == null) {
      return target.text;
    }
    final clone = target.clone(true);
    for (final garbage in clone.querySelectorAll('script, style, noscript')) {
      garbage.remove();
    }
    return clone.text;
  }

  /// 支持多分支逗号（保护括号内逗号）、`:contains(...)`、Legado 简写与 `.0`/`.-1` 索引切片
  List<dom.Element> _queryCssElements(dom.Element? scope, String selector) {
    if (scope == null || selector.trim().isEmpty) return const [];
    final branches = _splitBranches(selector);
    for (final branch in branches) {
      final res = _querySingleBranch(scope, branch);
      if (res.isNotEmpty) return res;
    }
    return const [];
  }

  List<dom.Element> _querySingleBranch(dom.Element scope, String rawBranch) {
    var branch = rawBranch.trim();
    if (branch.isEmpty) return const [];

    // 解析末尾索引切片，例如 `.item.0` 或 `dd a.-1`
    int? sliceIndex;
    final idxMatch = RegExp(r'\.(-?\d+)$').firstMatch(branch);
    if (idxMatch != null) {
      sliceIndex = int.tryParse(idxMatch.group(1)!);
      branch = branch.substring(0, idxMatch.start);
    }

    // 处理 Legado `class.xx` / `id.xx` / `tag.xx` 简写
    branch = branch
        .replaceAllMapped(RegExp(r'\bclass\.([a-zA-Z0-9_\-]+)'), (m) => '.${m.group(1)}')
        .replaceAllMapped(RegExp(r'\bid\.([a-zA-Z0-9_\-]+)'), (m) => '#${m.group(1)}')
        .replaceAllMapped(RegExp(r'\btag\.([a-zA-Z0-9_\-]+)'), (m) => '${m.group(1)}')
        .replaceAll('@', ' ');

    // 处理 `:contains(text)`
    final containsMatch =
        RegExp(r'^(.*?):contains\(([^)]+)\)(.*)$').firstMatch(branch);
    List<dom.Element> candidates;
    try {
      if (containsMatch != null) {
        final baseSel = containsMatch.group(1)!.trim();
        final keyword = containsMatch.group(2)!.replaceAll('"', '').replaceAll("'", '').trim();
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
      final resolved = sliceIndex < 0
          ? candidates.length + sliceIndex
          : sliceIndex;
      if (resolved < 0 || resolved >= candidates.length) return const [];
      return [candidates[resolved]];
    }
    return candidates;
  }

  List<String> _splitBranches(String input) {
    final parts = <String>[];
    final buf = StringBuffer();
    var parenDepth = 0;
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      if (ch == '(' || ch == '[') parenDepth++;
      if (ch == ')' || ch == ']') parenDepth = parenDepth > 0 ? parenDepth - 1 : 0;
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

class EvaluatedNode {
  const EvaluatedNode._({
    this.element,
    this.jsonValue,
    this.htmlTextFallback,
  });

  factory EvaluatedNode.html(dom.Element element) =>
      EvaluatedNode._(element: element);
  factory EvaluatedNode.json(dynamic value) => EvaluatedNode._(jsonValue: value);
  factory EvaluatedNode.text(String text) =>
      EvaluatedNode._(htmlTextFallback: text);

  final dom.Element? element;
  final dynamic jsonValue;
  final String? htmlTextFallback;
}
