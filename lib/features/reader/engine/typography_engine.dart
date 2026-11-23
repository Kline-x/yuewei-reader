import 'package:flutter/material.dart';
import 'page_models.dart';

/// 出版级纯度量 CJK 排版引擎（严禁篡改原文文本；按字素簇断行保护生僻字与 Emoji；真二分查找锚点）
class TypographyEngine {
  const TypographyEngine();

  /// 避头标点（严禁出现在行首）
  static const Set<String> avoidLineStart = {
    '，', '。', '、', '；', '：', '？', '！', '…', '—', '·',
    '”', '’', '）', '】', '》', '」', '』', '〕', '〉',
    ',', '.', ';', ':', '?', '!', ')', ']', '}', '%', '‰', '℃',
  };

  /// 避尾标点（严禁单独留在行尾）
  static const Set<String> avoidLineEnd = {
    '“', '‘', '（', '【', '《', '「', '『', '〔', '〈', '￥', r'$', '(', '[', '{',
  };

  static bool _isAsciiAlphaNum(String g) {
    if (g.length != 1) return false;
    final c = g.codeUnitAt(0);
    return (c >= 0x30 && c <= 0x39) ||
        (c >= 0x41 && c <= 0x5A) ||
        (c >= 0x61 && c <= 0x7A);
  }

  static bool _isAsciiWordConnector(String g) {
    return g.length == 1 && (g == '.' || g == '\'' || g == '-');
  }

  static bool _isTokenSplitAt(List<String> clusters, int split) {
    if (split <= 0 || split >= clusters.length) return false;
    final left = clusters[split - 1];
    final right = clusters[split];
    if (_isAsciiAlphaNum(left) && _isAsciiAlphaNum(right)) return true;
    if (_isAsciiWordConnector(left) &&
        split >= 2 &&
        _isAsciiAlphaNum(clusters[split - 2]) &&
        _isAsciiAlphaNum(right)) {
      return true;
    }
    if (_isAsciiWordConnector(right) &&
        _isAsciiAlphaNum(left) &&
        split + 1 < clusters.length &&
        _isAsciiAlphaNum(clusters[split + 1])) {
      return true;
    }
    return false;
  }

  /// 供引擎与画笔完全一致使用的正文样式
  static TextStyle bodyStyle(TypographyConfig config, Color color) {
    return TextStyle(
      fontSize: config.fontSize,
      height: config.lineHeightRatio,
      letterSpacing: config.letterSpacing,
      color: color,
      fontWeight: FontWeight.w400,
    );
  }

  /// 将纯段落列表排成精确整页列表（底部绝无切半行、绝对保留段间距）
  List<TypedPage> paginate({
    required List<String> paragraphs,
    required String chapterTitle,
    required TypographyConfig config,
  }) {
    final allLines = _breakAllParagraphs(paragraphs, config);
    if (allLines.isEmpty) {
      return const [
        TypedPage(
          pageIndex: 0,
          lines: [],
          charStart: 0,
          charEnd: 0,
          showChapterHeading: true,
        ),
      ];
    }

    final headingHeight = config.fontSize * 1.45 + 24.0;
    final pages = <TypedPage>[];
    var cursor = 0;

    while (cursor < allLines.length) {
      final isFirstPage = pages.isEmpty;
      var usedHeight = isFirstPage ? headingHeight : 0.0;
      final pageLines = <TypedLine>[];

      while (cursor < allLines.length) {
        final line = allLines[cursor];
        final lineHeight = config.lineHeight +
            (line.isLastLineOfPara ? config.paragraphGap : 0.0);

        // 即使只有一行的超窄视图也至少保证放下一行防止死循环
        if (pageLines.isNotEmpty && usedHeight + config.lineHeight > config.contentHeight) {
          break;
        }
        pageLines.add(line);
        usedHeight += lineHeight;
        cursor++;

        if (usedHeight >= config.contentHeight) {
          break;
        }
      }

      pages.add(
        TypedPage(
          pageIndex: pages.length,
          lines: pageLines,
          charStart: pageLines.first.charStart,
          charEnd: pageLines.last.charEnd,
          showChapterHeading: isFirstPage,
        ),
      );
    }

    return pages;
  }

  /// 真正的 O(log N) 二分查找字符偏移量所在页码
  int findPageByCharOffset(List<TypedPage> pages, int charOffset) {
    if (pages.isEmpty) return 0;
    if (charOffset <= 0) return 0;
    if (charOffset >= pages.last.charEnd) return pages.length - 1;

    var lo = 0;
    var hi = pages.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >>> 1;
      final p = pages[mid];
      if (charOffset < p.charStart) {
        hi = mid - 1;
      } else if (charOffset >= p.charEnd) {
        lo = mid + 1;
      } else {
        return mid;
      }
    }
    return lo.clamp(0, pages.length - 1);
  }

  List<TypedLine> _breakAllParagraphs(
    List<String> paragraphs,
    TypographyConfig config,
  ) {
    final widthCache = <String, double>{};
    final style = bodyStyle(config, Colors.black);
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );

    double measureGrapheme(String g) {
      return widthCache.putIfAbsent(g, () {
        painter.text = TextSpan(text: g, style: style);
        painter.layout();
        return painter.width;
      });
    }

    final result = <TypedLine>[];
    var globalOffset = 0;

    for (var pIdx = 0; pIdx < paragraphs.length; pIdx++) {
      final para = paragraphs[pIdx];
      final clusters = para.characters.toList();
      if (clusters.isEmpty) continue;

      final paraLines = <TypedLine>[];
      var startCluster = 0;
      var startCharOffset = globalOffset;

      while (startCluster < clusters.length) {
        var lineWidth = 0.0;
        var endCluster = startCluster;

        while (endCluster < clusters.length) {
          final w = measureGrapheme(clusters[endCluster]);
          if (endCluster > startCluster && lineWidth + w > config.contentWidth) {
            break;
          }
          lineWidth += w;
          endCluster++;
        }

        // 段尾单标点孤行防护：防止最后恰好仅剩 1 个避头标点单独成行
        if (endCluster == clusters.length - 1 &&
            endCluster - startCluster > 2 &&
            avoidLineStart.contains(clusters.last)) {
          endCluster--;
        }

        // CJK 避头避尾微调（含空格连带保护，最多回退 3 个字素簇）
        var retreated = 0;
        while (retreated < 3 &&
            endCluster < clusters.length &&
            endCluster - startCluster > 2) {
          final nextG = clusters[endCluster];
          final isSpaceBeforeAvoidStart = (nextG == ' ' || nextG == '\u00A0') &&
              endCluster + 1 < clusters.length &&
              avoidLineStart.contains(clusters[endCluster + 1]);
          if (avoidLineStart.contains(nextG) || isSpaceBeforeAvoidStart) {
            endCluster--;
            retreated++;
          } else if (avoidLineEnd.contains(clusters[endCluster - 1])) {
            endCluster--;
            retreated++;
          } else {
            break;
          }
        }

        // 连续 ASCII 数字/英文词完整性保护（仅整词回退；超长串允许折行以免大面积留白）
        if (endCluster < clusters.length &&
            _isTokenSplitAt(clusters, endCluster)) {
          var tokenStart = endCluster;
          while (tokenStart > 0) {
            final prev = clusters[tokenStart - 1];
            if (_isAsciiAlphaNum(prev) ||
                (_isAsciiWordConnector(prev) &&
                    tokenStart >= 2 &&
                    _isAsciiAlphaNum(clusters[tokenStart - 2]) &&
                    _isAsciiAlphaNum(clusters[tokenStart]))) {
              tokenStart--;
            } else {
              break;
            }
          }
          var tokenEnd = endCluster;
          while (tokenEnd < clusters.length) {
            final cur = clusters[tokenEnd];
            if (_isAsciiAlphaNum(cur) ||
                (_isAsciiWordConnector(cur) &&
                    tokenEnd > 0 &&
                    _isAsciiAlphaNum(clusters[tokenEnd - 1]) &&
                    tokenEnd + 1 < clusters.length &&
                    _isAsciiAlphaNum(clusters[tokenEnd + 1]))) {
              tokenEnd++;
            } else {
              break;
            }
          }
          final tokenLen = tokenEnd - tokenStart;
          if (tokenStart > startCluster && tokenLen <= 16) {
            endCluster = tokenStart;
            // 轻量避尾联动：防止如“796退完后把“孤零零留在行尾
            var endRetreated = 0;
            while (endRetreated < 2 &&
                endCluster - startCluster > 1 &&
                avoidLineEnd.contains(clusters[endCluster - 1])) {
              endCluster--;
              endRetreated++;
            }
          }
        }

        final lineStr = clusters.sublist(startCluster, endCluster).join();
        final lineCharLen = lineStr.length;

        paraLines.add(
          TypedLine(
            text: lineStr,
            paragraphIndex: pIdx,
            charStart: startCharOffset,
            charEnd: startCharOffset + lineCharLen,
            isFirstLineOfPara: paraLines.isEmpty,
            isLastLineOfPara: endCluster >= clusters.length,
          ),
        );

        startCluster = endCluster;
        startCharOffset += lineCharLen;
      }

      result.addAll(paraLines);
      globalOffset += para.length + 1; // +1 对应段落换行符坐标
    }

    painter.dispose();
    return result;
  }
}
