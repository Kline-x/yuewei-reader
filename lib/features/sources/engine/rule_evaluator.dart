import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:json_path/json_path.dart';
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';
import '../domain/book_source_rule.dart';
import 'rule_css_helper.dart';

/// 多引擎规则求值器：CSS（支持 :contains、Legado .0/.-1 索引与 || 回退链）+ XPath + JSONPath
class RuleEvaluator {
  const RuleEvaluator();

  /// 将原始文本提取为节点封装列表，用于列表遍历（搜索结果 / 目录项，支持 || 备选回退链）
  List<EvaluatedNode> selectNodes(String rawContent, String rule) {
    final trimmed = rule.trim();
    if (trimmed.isEmpty || rawContent.trim().isEmpty) return const [];

    dom.Document? cachedDoc;
    for (final branch in RuleCssHelper.splitFallbackChains(trimmed)) {
      final expr = branch.trim();
      if (expr.isEmpty) continue;

      List<EvaluatedNode> found;
      if (expr.startsWith(r'$.') || expr.startsWith('@json:')) {
        final pathExpr = expr.replaceFirst(RegExp(r'^@json:'), '').trim();
        found = _selectJsonNodes(rawContent, pathExpr);
      } else if (expr.startsWith('@xpath:') || expr.startsWith('//')) {
        final xpExpr = expr.replaceFirst(RegExp(r'^@xpath:'), '').trim();
        cachedDoc ??= html_parser.parse(rawContent);
        found = _selectXpathNodes(cachedDoc, xpExpr);
      } else {
        cachedDoc ??= html_parser.parse(rawContent);
        final elements = RuleCssHelper.queryCssElements(
          cachedDoc.documentElement,
          expr,
        );
        found = elements.map((e) => EvaluatedNode.html(e)).toList();
      }
      if (found.isNotEmpty) return found;
    }
    return const [];
  }

  /// 在根文档或节点上提取单一字符串值（支持 || 备选回退链与 ##regex##replacement）
  String evaluateField(
    EvaluatedNode root,
    RuleField field, {
    String baseUrl = '',
  }) {
    if (field.isEmpty) return '';

    final defaultAttr = field.attr.trim().isEmpty ? 'text' : field.attr.trim();
    final chains = field.selector.trim().isEmpty
        ? const ['']
        : RuleCssHelper.splitFallbackChains(field.selector.trim());

    var raw = '';
    var effectiveAttr = defaultAttr;

    for (final branch in chains) {
      final parsed = RuleCssHelper.parseBranchAttr(branch, defaultAttr);
      final candidate = _extractSingleBranch(root, parsed.selector, parsed.attr);
      if (candidate.isNotEmpty) {
        raw = candidate;
        effectiveAttr = parsed.attr;
        break;
      }
    }

    if (raw.isEmpty) return '';

    if (field.regex.isNotEmpty) {
      try {
        raw = raw.replaceAll(
          RegExp(field.regex, multiLine: true),
          field.replacement,
        );
      } catch (_) {}
    }

    raw = raw.trim();
    if (raw.isNotEmpty &&
        (effectiveAttr == 'href' || effectiveAttr == 'src') &&
        baseUrl.isNotEmpty) {
      raw = resolveUrl(baseUrl, raw);
    }
    return raw;
  }

  String _extractSingleBranch(EvaluatedNode root, String selector, String attr) {
    if (root.jsonValue != null) {
      return _extractFromJson(root.jsonValue, selector);
    }
    if (root.htmlTextFallback != null) {
      return root.htmlTextFallback!;
    }
    if (root.element != null) {
      return _extractFromHtmlElement(root.element!, selector, attr);
    }
    return '';
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

  /// 安全 HTML 实体解码（严格校验 Unicode 合法区间并防 &amp;lt; 双重反转义）
  static String decodeHtmlEntities(String input) =>
      RuleCssHelper.decodeHtmlEntities(input);

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

  List<EvaluatedNode> _selectXpathNodes(dom.Document doc, String expr) {
    try {
      final rootEl = doc.documentElement;
      if (rootEl == null) return const [];
      final xp = HtmlXPath.node(rootEl);
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

  String _extractFromJson(dynamic jsonVal, String sel) {
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

  String _extractFromHtmlElement(dom.Element el, String sel, String attr) {
    if (sel.startsWith('@xpath:') || sel.startsWith('//')) {
      final xpExpr = sel.replaceFirst(RegExp(r'^@xpath:'), '').trim();
      try {
        final hit = HtmlXPath.node(el).query(xpExpr).node;
        if (hit == null) return '';
        final domNode = hit.node;
        if (attr == 'html' && domNode is dom.Element) {
          return _extractCleanInnerHtml(domNode);
        }
        if (attr == 'text' || attr == 'textNodes') {
          if (domNode is dom.Element) {
            return decodeHtmlEntities(_extractVisibleText(domNode)).trim();
          }
          return decodeHtmlEntities(hit.text ?? '').trim();
        }
        return hit.attributes[attr] ?? hit.text ?? '';
      } catch (_) {
        return '';
      }
    }

    dom.Element? target = el;
    if (sel.isNotEmpty) {
      final hits = RuleCssHelper.queryCssElements(el, sel);
      if (hits.isEmpty) return '';
      target = hits.first;
    }

    if (attr == 'html') {
      return _extractCleanInnerHtml(target);
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

  /// 提取洁净 innerHtml：克隆节点并剥离全部 script/style/noscript 子树，杜绝脚本混入正文
  static String _extractCleanInnerHtml(dom.Element target) {
    if (target.querySelector('script, style, noscript') == null) {
      return target.innerHtml;
    }
    final clone = target.clone(true);
    for (final garbage in clone.querySelectorAll('script, style, noscript')) {
      garbage.remove();
    }
    return clone.innerHtml;
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
