import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';
import '../../../core/storage/chapter_file_store.dart';
import '../../../design_system/components/soft_bottom_sheet.dart';
import '../../../design_system/components/soft_text_field.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';
import '../engine/content_pipeline.dart';

/// 书内全文搜索单条命中记录
@immutable
class InBookSearchHit {
  const InBookSearchHit({
    required this.chapterIndex,
    required this.chapterTitle,
    required this.charOffset,
    required this.snippet,
    required this.matchStartInSnippet,
    required this.matchLength,
    required this.isTitleMatch,
  });

  final int chapterIndex, charOffset, matchStartInSnippet, matchLength;
  final String chapterTitle, snippet;
  final bool isTitleMatch;
}

/// 书内异步分批全文检索引擎（章名 + 已落盘正文，20 章让出事件循环，最多 200 条）
class InBookSearchEngine {
  const InBookSearchEngine._();
  static const int defaultMaxResults = 200;
  static const int defaultBatchSize = 20;

  static Future<List<InBookSearchHit>> search({
    required String bookId, required List<Chapter> chapters, required String query,
    required ChapterFileStore fileStore, bool Function()? isCancelled,
    void Function(int scannedChapters, List<InBookSearchHit> hits)? onProgress,
    int maxResults = defaultMaxResults, int batchSize = defaultBatchSize,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty || chapters.isEmpty) return const [];
    final lowerQuery = cleanQuery.toLowerCase();
    const pipeline = ContentPipeline();
    final hits = <InBookSearchHit>[];

    for (var i = 0; i < chapters.length; i++) {
      if (isCancelled?.call() == true || hits.length >= maxResults) break;
      final ch = chapters[i];
      final titleMatchIdx = ch.title.toLowerCase().indexOf(lowerQuery);
      if (titleMatchIdx >= 0) {
        hits.add(InBookSearchHit(
          chapterIndex: ch.chapterIndex, chapterTitle: ch.title, charOffset: 0,
          snippet: ch.title, matchStartInSnippet: titleMatchIdx, matchLength: cleanQuery.length, isTitleMatch: true,
        ));
      }
      if (hits.length < maxResults) {
        final rawText = await fileStore.readChapter(bookId, ch.chapterIndex);
        if (isCancelled?.call() == true) break;
        if (rawText != null && rawText.toLowerCase().contains(lowerQuery)) {
          _collectBodyHits(ch, rawText, cleanQuery, lowerQuery, pipeline, hits, maxResults);
        }
      }
      if ((i + 1) % batchSize == 0) {
        onProgress?.call(i + 1, List.unmodifiable(hits));
        await Future<void>.delayed(Duration.zero);
        if (isCancelled?.call() == true) break;
      }
    }
    if (isCancelled?.call() != true) onProgress?.call(chapters.length, List.unmodifiable(hits));
    return hits;
  }

  static void _collectBodyHits(
    Chapter ch, String rawText, String cleanQuery, String lowerQuery,
    ContentPipeline pipeline, List<InBookSearchHit> hits, int maxResults,
  ) {
    var paraOffset = 0;
    for (final para in pipeline.parseCachedText(rawText)) {
      final lowerPara = para.toLowerCase();
      var from = 0;
      while (hits.length < maxResults) {
        final idx = lowerPara.indexOf(lowerQuery, from);
        if (idx < 0) break;
        final built = _buildSnippet(para, idx, cleanQuery.length);
        hits.add(InBookSearchHit(
          chapterIndex: ch.chapterIndex, chapterTitle: ch.title, charOffset: paraOffset + idx,
          snippet: built.text, matchStartInSnippet: built.matchStart, matchLength: cleanQuery.length, isTitleMatch: false,
        ));
        from = idx + cleanQuery.length;
      }
      if (hits.length >= maxResults) break;
      paraOffset += para.length + 1;
    }
  }

  static ({String text, int matchStart}) _buildSnippet(String para, int idx, int qLen) {
    var start = math.max(0, idx - 16);
    var end = math.min(para.length, idx + qLen + 26);
    if (start > 0 && para.codeUnitAt(start) >= 0xDC00 && para.codeUnitAt(start) <= 0xDFFF) start--;
    if (end < para.length && para.codeUnitAt(end) >= 0xDC00 && para.codeUnitAt(end) <= 0xDFFF) end++;
    while (start < idx && (para[start] == '\u3000' || para[start] == ' ')) {
      start++;
    }
    final prefix = start > 0 ? '…' : '';
    final suffix = end < para.length ? '…' : '';
    final core = para.substring(start, end).replaceAll('\u3000', ' ');
    return (text: '$prefix$core$suffix', matchStart: prefix.length + (idx - start));
  }
}

/// 阅读器书内全文搜索抽屉（20 章分批异步扫描、关键词上下文高亮、精准跳页）
class ReaderInBookSearchSheet extends StatefulWidget {
  const ReaderInBookSearchSheet({
    super.key, required this.bookId, required this.chapters,
    required this.fileStore, required this.isLocalBook, required this.onSelectHit,
  });

  final String bookId;
  final List<Chapter> chapters;
  final ChapterFileStore fileStore;
  final bool isLocalBook;
  final Future<void> Function(int chapterIndex, int charOffset) onSelectHit;

  static Future<void> show(
    BuildContext context, {
    required String bookId, required List<Chapter> chapters,
    required ChapterFileStore fileStore, required bool isLocalBook,
    required Future<void> Function(int chapterIndex, int charOffset) onSelectHit,
  }) => SoftBottomSheet.show(
    context, title: '书内搜索', headerIcon: Icons.search_rounded, maxHeightFactor: 0.85,
    builder: (_) => ReaderInBookSearchSheet(
      bookId: bookId, chapters: chapters, fileStore: fileStore,
      isLocalBook: isLocalBook, onSelectHit: onSelectHit,
    ),
  );

  @override
  State<ReaderInBookSearchSheet> createState() => _ReaderInBookSearchSheetState();
}

class _ReaderInBookSearchSheetState extends State<ReaderInBookSearchSheet> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;
  int _epoch = 0, _scannedCount = 0;
  bool _disposed = false, _searching = false;
  String _activeQuery = '';
  List<InBookSearchHit> _hits = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (!_disposed && mounted) _focus.requestFocus(); });
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onQueryChanged(String val) {
    _debounce?.cancel();
    final q = val.trim();
    if (q.isEmpty) {
      setState(() { _epoch++; _searching = false; _scannedCount = 0; _activeQuery = ''; _hits = const []; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 220), () => _runSearch(q));
  }

  Future<void> _runSearch(String raw) async {
    _debounce?.cancel();
    final q = raw.trim();
    if (q.isEmpty || _disposed || !mounted) return;
    final epoch = ++_epoch;
    setState(() { _searching = true; _scannedCount = 0; _activeQuery = q; _hits = const []; });
    final results = await InBookSearchEngine.search(
      bookId: widget.bookId, chapters: widget.chapters, query: q, fileStore: widget.fileStore,
      isCancelled: () => _disposed || !mounted || epoch != _epoch,
      onProgress: (scanned, partial) {
        if (!_disposed && mounted && epoch == _epoch) setState(() { _scannedCount = scanned; _hits = partial; });
      },
    );
    if (!_disposed && mounted && epoch == _epoch) setState(() { _searching = false; _hits = results; });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final scopeHint = widget.isLocalBook ? '全书共 ${widget.chapters.length} 章，可检索全部章名与正文' : '支持搜索全部章名及已缓存章节正文';
    final statusText = _activeQuery.isEmpty ? scopeHint
        : _searching ? '正在扫描 $_scannedCount / ${widget.chapters.length} 章 · 已命中 ${_hits.length} 条'
        : _hits.length >= InBookSearchEngine.defaultMaxResults ? '已展示前 ${InBookSearchEngine.defaultMaxResults} 条命中结果' : '共找到 ${_hits.length} 条匹配';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(SoftSpacing.lg, SoftSpacing.md, SoftSpacing.lg, SoftSpacing.sm),
          child: SoftTextField(controller: _ctrl, focusNode: _focus, hintText: '输入关键词搜索本书内容…', onChanged: _onQueryChanged, onSubmitted: _runSearch),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SoftSpacing.xl),
          child: Row(
            children: [
              if (_searching) ...[
                SizedBox(width: 12.0, height: 12.0, child: CircularProgressIndicator(strokeWidth: 1.8, color: tokens.accent)),
                const SizedBox(width: 6.0),
              ],
              Expanded(child: Text(statusText, maxLines: 1, overflow: TextOverflow.ellipsis, style: SoftTypography.micro.copyWith(color: tokens.textTertiary))),
            ],
          ),
        ),
        const SizedBox(height: SoftSpacing.xs),
        Expanded(child: _buildBody(tokens, scopeHint)),
      ],
    );
  }

  Widget _buildBody(SoftTokens tokens, String scopeHint) {
    if (_activeQuery.isEmpty || (_hits.isEmpty && !_searching)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SoftSpacing.xxl),
          child: Text(_activeQuery.isEmpty ? scopeHint : '未找到「$_activeQuery」相关内容', textAlign: TextAlign.center,
              style: SoftTypography.body.copyWith(color: _activeQuery.isEmpty ? tokens.textTertiary : tokens.textSecondary)),
        ),
      );
    }
    return ListView.separated(
      itemCount: _hits.length,
      separatorBuilder: (_, _) => Divider(height: 1.0, indent: SoftSpacing.xl, endIndent: SoftSpacing.xl, color: tokens.borderSubtle),
      itemBuilder: (ctx, i) {
        final hit = _hits[i];
        return InkWell(
          onTap: () { Navigator.of(context).pop(); unawaited(widget.onSelectHit(hit.chapterIndex, hit.charOffset)); },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: SoftSpacing.xl, vertical: SoftSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(hit.chapterTitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: SoftTypography.caption.copyWith(color: tokens.textPrimary, fontWeight: FontWeight.w700))),
                  const SizedBox(width: 8.0),
                  Text(hit.isTitleMatch ? '章名' : '正文', style: SoftTypography.micro.copyWith(color: tokens.textTertiary)),
                ]),
                const SizedBox(height: 4.0),
                _buildSnippetRichText(hit, tokens),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSnippetRichText(InBookSearchHit hit, SoftTokens tokens) {
    final s = hit.snippet;
    final start = hit.matchStartInSnippet.clamp(0, s.length);
    final end = (start + hit.matchLength).clamp(start, s.length);
    final base = SoftTypography.caption.copyWith(color: tokens.textSecondary, height: 1.45);
    return Text.rich(
      TextSpan(style: base, children: [
        if (start > 0) TextSpan(text: s.substring(0, start)),
        TextSpan(text: s.substring(start, end), style: base.copyWith(color: tokens.accent, backgroundColor: tokens.accentSoft, fontWeight: FontWeight.w700)),
        if (end < s.length) TextSpan(text: s.substring(end)),
      ]),
      maxLines: 2, overflow: TextOverflow.ellipsis,
    );
  }
}
