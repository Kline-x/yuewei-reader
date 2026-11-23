import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../design_system/components/ambient_background.dart';
import '../../../design_system/components/empty_error_view.dart';
import '../../../design_system/components/soft_button.dart';
import '../../../design_system/feedback/app_feedback.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';
import '../../reader/presentation/reader_download_sheet.dart';
import '../../reader/presentation/reader_source_sheet.dart';
import '../../sources/domain/book_match_models.dart';
import 'book_detail_loader.dart';
import 'book_detail_sections.dart';
import 'book_detail_tiles.dart';

/// 书籍详情页（污损自愈擦净、旧书自动补全简介与最新更新时间，≤ 350 行）
class BookDetailPage extends ConsumerStatefulWidget {
  const BookDetailPage({super.key, this.aggregatedMatch, this.bookId});

  final AggregatedBookMatch? aggregatedMatch;
  final String? bookId;

  @override
  ConsumerState<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends ConsumerState<BookDetailPage> {
  final ScrollController _scrollCtrl = ScrollController();

  Book? _book;
  List<Chapter> _chapters = const [];
  String _sourceName = '';
  bool _loading = true;
  bool _refreshingMeta = false;
  bool _didAutoRefreshOnce = false;
  String? _errorMsg;
  bool _introExpanded = false;
  bool _descending = false;
  int _loadEpoch = 0;

  String get _resolvedBookId =>
      widget.bookId ?? widget.aggregatedMatch?.canonicalBookId ?? '';

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    final req = ++_loadEpoch;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      final local = await BookDetailLoader.loadLocal(
        ref: ref,
        bookId: _resolvedBookId,
        aggregatedMatch: widget.aggregatedMatch,
      );
      if (!mounted || req != _loadEpoch) return;

      final currentBook = local.book;
      if (currentBook != null && local.chapters.isNotEmpty) {
        final needBgRefresh =
            BookDetailLoader.needsMetaRepair(currentBook) &&
                !_didAutoRefreshOnce;
        setState(() {
          _book = currentBook;
          _chapters = local.chapters;
          _sourceName = local.sourceName;
          _loading = false;
          _refreshingMeta = needBgRefresh;
        });
        if (needBgRefresh) {
          _didAutoRefreshOnce = true;
          await _refreshFromNetwork(existing: currentBook, req: req);
        }
        return;
      }

      await _refreshFromNetwork(existing: currentBook, req: req);
    } catch (_) {
      if (mounted && req == _loadEpoch) {
        setState(() {
          _loading = false;
          _refreshingMeta = false;
          _errorMsg = '书籍目录加载失败，请检查网络或尝试换源';
        });
      }
    }
  }

  Future<void> _refreshFromNetwork({
    Book? existing,
    int? req,
    bool manual = false,
  }) async {
    final epoch = req ?? ++_loadEpoch;
    if (manual && mounted) setState(() => _refreshingMeta = true);

    try {
      final result = await BookDetailLoader.fetchAndHealFromNetwork(
        ref: ref,
        bookId: _resolvedBookId,
        aggregatedMatch: widget.aggregatedMatch,
        existing: existing,
      );
      if (!mounted || epoch != _loadEpoch) return;
      if (result == null) {
        setState(() {
          _loading = false;
          _refreshingMeta = false;
          if (_book == null) _errorMsg = '当前书源记录无效，请切换其他书源';
        });
        return;
      }
      setState(() {
        _book = result.book;
        _chapters = result.chapters;
        _sourceName = result.sourceName;
        _loading = false;
        _refreshingMeta = false;
      });
      if (manual) AppFeedback.showToast(context, '已刷新书籍简介与最新目录');
    } catch (_) {
      if (!mounted || epoch != _loadEpoch) return;
      setState(() {
        _loading = false;
        _refreshingMeta = false;
        if (_book == null) _errorMsg = '书籍目录加载失败，请检查网络或尝试换源';
      });
      if (manual) AppFeedback.showToast(context, '刷新失败，请检查网络或换源');
    }
  }

  Future<void> _toggleShelf() async {
    final b = _book;
    if (b == null) return;
    final next = !b.isInShelf;
    await ref.read(shelfRepositoryProvider).setInShelf(b.id, next);
    final updated = await ref.read(appDatabaseProvider).getBookById(b.id);
    if (mounted && updated != null) {
      setState(() => _book = updated);
      AppFeedback.showToast(context, next ? '已加入书架' : '已移出书架');
    }
  }

  Future<void> _openSourceSwitcher() async {
    final b = _book;
    if (b == null) return;
    await ReaderSourceSheet.show(
      context,
      bookTitle: b.title,
      bookAuthor: b.author,
      currentSourceId: b.sourceId,
      onSelectSource: (rule, hit, chapters) async {
        final switched = await BookDetailLoader.applySwitchedSource(
          ref: ref,
          oldBook: b,
          rule: rule,
          hit: hit,
          chapters: chapters,
        );
        if (!mounted) return;
        setState(() {
          _book = switched.book;
          _chapters = switched.chapters;
          _sourceName = switched.sourceName;
          _refreshingMeta = true;
          _introExpanded = false;
        });
        AppFeedback.showToast(context, '已换源至 ${rule.name}');
        if (switched.book != null) {
          await _refreshFromNetwork(existing: switched.book);
        }
      },
    );
  }

  String _resolveLatestChapterTitle(Book book) =>
      book.latestChapterTitle.trim().isNotEmpty
          ? book.latestChapterTitle.trim()
          : (_chapters.isNotEmpty ? _chapters.last.title : '');

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final book = _book;
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8.0, 6.0, 16.0, 6.0),
                child: Row(
                  children: [
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.arrow_back_ios_new_rounded, size: 19.0, color: tokens.textPrimary),
                    ),
                    const Spacer(),
                    if (book != null) ...[
                      IconButton(
                        tooltip: '刷新书籍信息',
                        constraints: const BoxConstraints(minWidth: 40.0, minHeight: 40.0),
                        onPressed: _refreshingMeta
                            ? null
                            : () => _refreshFromNetwork(existing: book, manual: true),
                        icon: _refreshingMeta
                            ? SizedBox(
                                width: 16.0,
                                height: 16.0,
                                child: CircularProgressIndicator(strokeWidth: 2.0, color: tokens.accent),
                              )
                            : Icon(Icons.refresh_rounded, size: 20.0, color: tokens.textSecondary),
                      ),
                      const SizedBox(width: 4.0),
                      SoftButton(
                        label: _sourceName.isNotEmpty ? _sourceName : '切换书源',
                        icon: Icons.swap_horiz_rounded,
                        tone: SoftButtonTone.tonal,
                        compact: true,
                        onPressed: _openSourceSwitcher,
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator(color: tokens.accent))
                    : _errorMsg != null || book == null
                        ? EmptyErrorView(
                            icon: Icons.cloud_off_rounded,
                            title: '详情加载失败',
                            description: _errorMsg,
                            actionLabel: '重试',
                            onAction: _loadDetail)
                        : _buildBody(context, tokens, book),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pushAndReload(String route) async {
    await context.push(route);
    _loadDetail();
  }

  Widget _buildBody(BuildContext context, SoftTokens tokens, Book book) {
    final displayChapters =
        _descending ? _chapters.reversed.toList() : _chapters;
    return CustomScrollView(
      controller: _scrollCtrl,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              SoftSpacing.xl, SoftSpacing.sm, SoftSpacing.xl, SoftSpacing.lg),
          sliver: SliverToBoxAdapter(
            child: BookDetailHeaderSection(
              book: book,
              chapterCount: _chapters.length,
              sourceName: _sourceName,
              latestChapterTitle: _resolveLatestChapterTitle(book),
              refreshingMeta: _refreshingMeta,
              introExpanded: _introExpanded,
              descending: _descending,
              onToggleShelf: _toggleShelf,
              onOpenDownload: () => ReaderDownloadSheet.show(
                context,
                bookId: book.id,
                bookTitle: book.title,
                totalChapters: _chapters.length,
                currentChapterIndex: book.currentChapterIndex,
              ),
              onStartReading: _chapters.isEmpty
                  ? null
                  : () => _pushAndReload('/reader/${book.id}'),
              onTapLatestChapter: _chapters.isEmpty
                  ? null
                  : () => _pushAndReload(
                      '/reader/${book.id}?chapter=${_chapters.length - 1}'),
              onToggleIntro: () =>
                  setState(() => _introExpanded = !_introExpanded),
              onLocateCurrent: () {
                final idx = displayChapters.indexWhere(
                  (c) => c.chapterIndex == book.currentChapterIndex,
                );
                if (idx >= 0 && _scrollCtrl.hasClients) {
                  _scrollCtrl.animateTo(
                    (520.0 + idx * 48.0).clamp(
                        0.0, _scrollCtrl.position.maxScrollExtent),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                  );
                }
              },
              onToggleOrder: () => setState(() => _descending = !_descending),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(bottom: SoftSpacing.xxl),
          sliver: SliverList.separated(
            itemCount: displayChapters.length,
            separatorBuilder: (_, _) => Divider(
                height: 1.0,
                indent: SoftSpacing.xl,
                endIndent: SoftSpacing.xl,
                color: tokens.borderSubtle),
            itemBuilder: (_, i) {
              final ch = displayChapters[i];
              return BookDetailChapterTile(
                chapter: ch,
                isCurrent: book.hasEverRead &&
                    ch.chapterIndex == book.currentChapterIndex,
                onTap: () => _pushAndReload(
                    '/reader/${book.id}?chapter=${ch.chapterIndex}'),
              );
            },
          ),
        ),
      ],
    );
  }
}
