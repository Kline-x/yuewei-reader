import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../design_system/components/soft_bottom_sheet.dart';
import '../../../design_system/components/soft_card.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';
import '../../sources/domain/book_match_models.dart';
import '../../sources/domain/book_source_rule.dart';

class _SourceProbeCandidate {
  const _SourceProbeCandidate({
    required this.rule,
    required this.hit,
    required this.chapters,
    required this.latencyMs,
  });

  final BookSourceRule rule;
  final SourceSearchHit hit;
  final List<ParsedChapterEntry> chapters;
  final int latencyMs;
}

/// 无感换源底部抽屉（并发探活所有启用源的真实目录章数与延迟，杜绝切向失效死源）
class ReaderSourceSheet extends ConsumerStatefulWidget {
  const ReaderSourceSheet({
    super.key,
    required this.bookTitle,
    required this.bookAuthor,
    required this.currentSourceId,
    required this.onSelectSource,
  });

  final String bookTitle;
  final String bookAuthor;
  final String currentSourceId;
  final Future<void> Function(
    BookSourceRule rule,
    SourceSearchHit hit,
    List<ParsedChapterEntry> chapters,
  ) onSelectSource;

  static Future<void> show(
    BuildContext context, {
    required String bookTitle,
    required String bookAuthor,
    required String currentSourceId,
    required Future<void> Function(
      BookSourceRule rule,
      SourceSearchHit hit,
      List<ParsedChapterEntry> chapters,
    ) onSelectSource,
  }) {
    return SoftBottomSheet.show(
      context,
      title: '切换书源',
      subtitle: '实时探活可用源 · 换源后自动清理旧章缓存',
      headerIcon: Icons.swap_horiz_rounded,
      maxHeightFactor: 0.78,
      builder: (_) => ReaderSourceSheet(
        bookTitle: bookTitle,
        bookAuthor: bookAuthor,
        currentSourceId: currentSourceId,
        onSelectSource: onSelectSource,
      ),
    );
  }

  @override
  ConsumerState<ReaderSourceSheet> createState() => _ReaderSourceSheetState();
}

class _ReaderSourceSheetState extends ConsumerState<ReaderSourceSheet> {
  final CancelToken _cancelToken = CancelToken();
  final List<_SourceProbeCandidate> _candidates = [];
  bool _probing = true;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _probeSources();
  }

  @override
  void dispose() {
    if (!_cancelToken.isCancelled) _cancelToken.cancel('关闭换源面板');
    super.dispose();
  }

  Future<void> _probeSources() async {
    final sourceRepo = ref.read(sourceRepositoryProvider);
    final crawler = ref.read(crawlerServiceProvider);
    final rules = await sourceRepo.getEnabledRules();
    final targetTitleKey = SourceSearchHit.normalizeBookKey(widget.bookTitle);
    final targetAuthorKey = SourceSearchHit.normalizeBookKey(widget.bookAuthor);

    final ruleMap = {for (final r in rules) r.id: r};
    final futures = <Future<void>>[];

    final sub = crawler
        .searchStream(rules, widget.bookTitle, cancelToken: _cancelToken)
        .listen((hit) {
      if (!mounted) return;
      final titleMatch = hit.cleanTitle == targetTitleKey ||
          hit.cleanTitle.contains(targetTitleKey);
      final authorMatch = targetAuthorKey.isEmpty ||
          hit.cleanAuthor.isEmpty ||
          hit.cleanAuthor == targetAuthorKey;
      if (!titleMatch || !authorMatch) return;
      if (_candidates.any((c) => c.rule.id == hit.sourceId)) return;

      final rule = ruleMap[hit.sourceId];
      if (rule == null) return;

      final task = crawler
          .fetchBookDetailAndToc(rule, hit.bookUrl, cancelToken: _cancelToken)
          .then((res) {
        if (!mounted || res.chapters.isEmpty) return;
        setState(() {
          _candidates.add(
            _SourceProbeCandidate(
              rule: rule,
              hit: hit,
              chapters: res.chapters,
              latencyMs: res.latencyMs,
            ),
          );
          _candidates.sort((a, b) => a.latencyMs.compareTo(b.latencyMs));
        });
      }).catchError((_) {});
      futures.add(task);
    });

    await sub.asFuture<void>().catchError((_) {});
    await Future.wait(futures);
    if (mounted) setState(() => _probing = false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    return Column(
      children: [
        if (_probing)
          LinearProgressIndicator(
            minHeight: 2.5,
            color: tokens.accent,
            backgroundColor: tokens.accentSoft,
          ),
        Expanded(
          child: _candidates.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(SoftSpacing.xl),
                    child: Text(
                      _probing
                          ? '正在并发探测各启用书源的收录情况与响应速度…'
                          : '暂无其他可用书源收录本书',
                      textAlign: TextAlign.center,
                      style: SoftTypography.body
                          .copyWith(color: tokens.textSecondary),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(SoftSpacing.lg),
                  itemCount: _candidates.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: SoftSpacing.md),
                  itemBuilder: (_, i) {
                    final item = _candidates[i];
                    final isCurrent = item.rule.id == widget.currentSourceId;
                    return SoftCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SoftSpacing.lg,
                        vertical: SoftSpacing.md,
                      ),
                      borderColor:
                          isCurrent ? tokens.accent : tokens.borderSubtle,
                      onTap: (_switching || isCurrent)
                          ? null
                          : () async {
                              setState(() => _switching = true);
                              await widget.onSelectSource(
                                item.rule,
                                item.hit,
                                item.chapters,
                              );
                              if (context.mounted) Navigator.of(context).pop();
                            },
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      item.rule.name,
                                      style: SoftTypography.cardTitle.copyWith(
                                        color: isCurrent
                                            ? tokens.accent
                                            : tokens.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 8.0),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                        vertical: 2.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: tokens.accentSoft,
                                        borderRadius: BorderRadius.circular(
                                          SoftRadius.pill,
                                        ),
                                      ),
                                      child: Text(
                                        '${item.latencyMs}ms',
                                        style: SoftTypography.micro
                                            .copyWith(color: tokens.accent),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  '共 ${item.chapters.length} 章 · ${item.chapters.last.title}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: SoftTypography.caption
                                      .copyWith(color: tokens.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          if (isCurrent)
                            Icon(
                              Icons.check_circle_rounded,
                              color: tokens.accent,
                              size: 22.0,
                            )
                          else
                            Icon(
                              Icons.chevron_right_rounded,
                              color: tokens.textTertiary,
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
