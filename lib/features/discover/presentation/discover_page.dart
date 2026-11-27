import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../design_system/components/empty_error_view.dart';
import '../../../design_system/components/soft_button.dart';
import '../../../design_system/components/soft_text_field.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';
import '../../sources/domain/book_match_models.dart';
import '../../tts/tts_controller.dart';
import 'discover_sections.dart';

/// 探索书海 & 多源聚合搜书页：
/// 1. 同一书名+作者自动聚合归并，标明「N 个可用书源 · 最快 xxx ms」；
/// 2. 彻底废除造假兜底书源：无匹配/断网诚实提示可重试；
/// 3. 退页前自动 unfocus 绝不返回后复弹键盘。
class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  CancelToken? _cancelToken;
  StreamSubscription<SourceSearchHit>? _searchSub;
  int _searchEpoch = 0;

  bool _hasSearched = false;
  bool _searching = false;
  String _lastQuery = '';
  int _enabledSourceCount = 0;
  final Map<String, List<SourceSearchHit>> _groupedHits = {};

  @override
  void initState() {
    super.initState();
    _refreshEnabledCount();
  }

  @override
  void dispose() {
    _cancelActiveSearch();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _refreshEnabledCount() async {
    final rules = await ref.read(sourceRepositoryProvider).getEnabledRules();
    if (mounted) setState(() => _enabledSourceCount = rules.length);
  }

  void _cancelActiveSearch() {
    _searchSub?.cancel();
    _searchSub = null;
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('取消上一次检索');
    }
    _cancelToken = null;
  }

  Future<void> _startSearch(String rawKeyword) async {
    final query = rawKeyword.trim();
    if (query.isEmpty) return;

    _focusNode.unfocus();
    _cancelActiveSearch();

    final epoch = ++_searchEpoch;
    final token = CancelToken();
    _cancelToken = token;

    final rules = await ref.read(sourceRepositoryProvider).getEnabledRules();
    await ref.read(appDatabaseProvider).saveSearchKeyword(query);
    if (!mounted || epoch != _searchEpoch) return;

    setState(() {
      _enabledSourceCount = rules.length;
      _hasSearched = true;
      _searching = rules.isNotEmpty;
      _lastQuery = query;
      _groupedHits.clear();
    });

    if (rules.isEmpty) return;

    _searchSub = ref
        .read(crawlerServiceProvider)
        .searchStream(rules, query, cancelToken: token)
        .listen(
      (hit) {
        if (!mounted || epoch != _searchEpoch) return;
        final key = '${hit.cleanTitle}__${hit.cleanAuthor}';
        setState(() {
          final bucket = _groupedHits.putIfAbsent(key, () => []);
          if (!bucket.any((b) => b.sourceId == hit.sourceId)) {
            bucket.add(hit);
            bucket.sort((a, b) => a.latencyMs.compareTo(b.latencyMs));
          }
        });
      },
      onDone: () {
        if (mounted && epoch == _searchEpoch) {
          setState(() => _searching = false);
        }
      },
      onError: (_) {
        if (mounted && epoch == _searchEpoch) {
          setState(() => _searching = false);
        }
      },
    );
  }

  void _resetSearch() {
    _cancelActiveSearch();
    _searchEpoch++;
    _searchCtrl.clear();
    setState(() {
      _hasSearched = false;
      _searching = false;
      _lastQuery = '';
      _groupedHits.clear();
    });
  }

  List<AggregatedBookMatch> get _aggregatedList {
    final list = _groupedHits.values
        .map(
          (hits) => AggregatedBookMatch(
            cleanTitle: hits.first.cleanTitle,
            cleanAuthor: hits.first.cleanAuthor,
            hits: List.unmodifiable(hits),
          ),
        )
        .toList();
    list.sort((a, b) {
      final exactA = a.cleanTitle == SourceSearchHit.normalizeBookKey(_lastQuery) ? 0 : 1;
      final exactB = b.cleanTitle == SourceSearchHit.normalizeBookKey(_lastQuery) ? 0 : 1;
      if (exactA != exactB) return exactA.compareTo(exactB);
      final cmpCnt = b.sourceCount.compareTo(a.sourceCount);
      if (cmpCnt != 0) return cmpCnt;
      return a.fastestLatencyMs.compareTo(b.fastestLatencyMs);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final results = _aggregatedList;
    final hasTtsCapsule =
        ref.watch(ttsControllerProvider.select((s) => s.isActive));
    final bottomClearance =
        SoftSpacing.bottomClearance(hasTtsCapsule: hasTtsCapsule);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(SoftSpacing.xl, SoftSpacing.md, SoftSpacing.lg, SoftSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DISCOVER', style: SoftTypography.eyebrow.copyWith(color: tokens.textTertiary)),
                      const SizedBox(height: 2.0),
                      Text('探索书海', style: SoftTypography.displayTitle.copyWith(color: tokens.textPrimary)),
                    ],
                  ),
                ),
                SoftButton(
                  label: '书源 ($_enabledSourceCount)',
                  icon: Icons.dns_outlined,
                  tone: SoftButtonTone.tonal,
                  compact: true,
                  onPressed: () async {
                    _focusNode.unfocus();
                    await context.push('/sources');
                    _refreshEnabledCount();
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SoftSpacing.xl, vertical: SoftSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: SoftTextField(
                    controller: _searchCtrl,
                    focusNode: _focusNode,
                    hintText: '搜索书名或作者…',
                    onSubmitted: _startSearch,
                    onCleared: _resetSearch,
                  ),
                ),
                const SizedBox(width: SoftSpacing.sm),
                SoftButton(label: '搜索', compact: true, onPressed: () => _startSearch(_searchCtrl.text)),
              ],
            ),
          ),
          if (_searching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SoftSpacing.xl),
              child: LinearProgressIndicator(
                minHeight: 2.5,
                color: tokens.accent,
                backgroundColor: tokens.accentSoft,
              ),
            ),
          Expanded(
            child: !_hasSearched
                ? DiscoverIdleSection(
                    db: ref.watch(appDatabaseProvider),
                    bottomClearance: bottomClearance,
                    onSelectKeyword: (kw) {
                      _searchCtrl.text = kw;
                      _startSearch(kw);
                    },
                  )
                : (results.isEmpty && !_searching)
                    ? Padding(
                        padding: EdgeInsets.only(bottom: bottomClearance),
                        child: EmptyErrorView(
                          icon: Icons.search_off_rounded,
                          title: '未找到《$_lastQuery》',
                          description:
                              '当前 $_enabledSourceCount 个启用书源均未匹配到此书，可检查网络或在书源中心导入新书源。',
                          actionLabel: '重新搜索',
                          onAction: () => _startSearch(_lastQuery),
                        ),
                      )
                    : DiscoverResultsList(
                        results: results,
                        bottomClearance: bottomClearance,
                        onTapBook: (book) {
                          _focusNode.unfocus();
                          context.push('/book', extra: book);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
