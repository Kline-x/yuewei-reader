import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../design_system/components/empty_error_view.dart';
import '../../../design_system/feedback/app_feedback.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';
import '../data/shelf_repository.dart';
import 'shelf_book_action_sheet.dart';
import 'shelf_book_cards.dart';
import 'shelf_header_sections.dart';

/// 阅微书架工作台（全响应式、Bento 看板、单向左滑+真延迟撤销，单文件严控 ≤ 350 行）
class ShelfPage extends ConsumerStatefulWidget {
  const ShelfPage({super.key});

  @override
  ConsumerState<ShelfPage> createState() => _ShelfPageState();
}

class _ShelfPageState extends ConsumerState<ShelfPage>
    with WidgetsBindingObserver {
  ShelfSortMode _sortMode = ShelfSortMode.lastRead;
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restorePrefs();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      ref.read(swipeCoordinatorProvider).closeAll();
    }
  }

  Future<void> _restorePrefs() async {
    final repo = ref.read(shelfRepositoryProvider);
    final sort = await repo.getSortMode();
    final grid = await repo.getIsGridView();
    if (!mounted) return;
    setState(() {
      _sortMode = sort;
      _isGridView = grid;
    });
  }

  Future<void> _changeSort(ShelfSortMode mode) async {
    setState(() => _sortMode = mode);
    await ref.read(shelfRepositoryProvider).saveSortMode(mode);
  }

  Future<void> _toggleGridMode() async {
    ref.read(swipeCoordinatorProvider).closeAll();
    final next = !_isGridView;
    setState(() => _isGridView = next);
    await ref.read(shelfRepositoryProvider).saveIsGridView(next);
  }

  Future<void> _removeBookWithUndo(Book book) async {
    final repo = ref.read(shelfRepositoryProvider);
    ref.read(swipeCoordinatorProvider).closeAll();
    await repo.setInShelf(book.id, false);
    if (!mounted) return;

    AppFeedback.showUndoSnackBar(
      context,
      message: '已将《${book.title}》移出书架',
      onUndo: () => repo.setInShelf(book.id, true),
      onCommitted: () => repo.purgeBookData(book.id),
    );
  }

  void _openBookMenu(Book book) {
    final repo = ref.read(shelfRepositoryProvider);
    showShelfBookActionSheet(
      context,
      book: book,
      onTogglePin: () async {
        await repo.togglePin(book.id, !book.isPinned);
        if (mounted) {
          AppFeedback.showToast(
            context,
            book.isPinned ? '已取消置顶' : '已置顶《${book.title}》',
          );
        }
      },
      onClearBookCache: () async {
        await repo.clearBookChapterFiles(book.id);
        if (mounted) {
          AppFeedback.showToast(context, '已清理《${book.title}》离线缓存');
        }
      },
      onRemoveBook: () => _removeBookWithUndo(book),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final db = ref.watch(appDatabaseProvider);
    final coordinator = ref.watch(swipeCoordinatorProvider);

    return SafeArea(
      bottom: false,
      child: StreamBuilder<List<Book>>(
        stream: db.watchShelfBooks(),
        builder: (context, booksSnap) {
          final rawBooks = booksSnap.data ?? const <Book>[];
          final books = ShelfRepository.sortBooks(rawBooks, _sortMode);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ShelfHeaderBar(
                  isGridView: _isGridView,
                  onTapSearch: () => context.go('/discover'),
                  onTapSources: () => context.push('/sources'),
                  onToggleView: _toggleGridMode,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SoftSpacing.xl),
                  child: ShelfBentoBoard(db: db, books: books),
                ),
              ),
              if (books.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SoftSpacing.xl,
                      SoftSpacing.lg,
                      SoftSpacing.xl,
                      SoftSpacing.sm,
                    ),
                    child: ShelfSortBar(
                      currentMode: _sortMode,
                      onSelect: _changeSort,
                    ),
                  ),
                ),
              if (booksSnap.connectionState == ConnectionState.waiting &&
                  !booksSnap.hasData)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: tokens.accent),
                  ),
                )
              else if (books.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      bottom: SoftSpacing.dockClearance,
                    ),
                    child: EmptyErrorView(
                      icon: Icons.auto_stories_outlined,
                      title: '书架空空如也',
                      description: '去探索书海搜寻心仪小说，支持多源聚合与全本离线缓存。',
                      actionLabel: '探索书海',
                      onAction: () => context.go('/discover'),
                    ),
                  ),
                )
              else if (_isGridView)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    SoftSpacing.xl,
                    SoftSpacing.sm,
                    SoftSpacing.xl,
                    SoftSpacing.dockClearance,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 14.0,
                      mainAxisSpacing: 16.0,
                      childAspectRatio: 0.56,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final book = books[i];
                        return ShelfGridBookCard(
                          book: book,
                          onTapRead: () => context.push('/reader/${book.id}'),
                          onOpenActions: () => _openBookMenu(book),
                        );
                      },
                      childCount: books.length,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    SoftSpacing.xl,
                    SoftSpacing.sm,
                    SoftSpacing.xl,
                    SoftSpacing.dockClearance,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final book = books[i];
                        return ShelfListBookCard(
                          book: book,
                          coordinator: coordinator,
                          onTapRead: () => context.push('/reader/${book.id}'),
                          onOpenActions: () => _openBookMenu(book),
                          onSwipeRemove: () => _removeBookWithUndo(book),
                        );
                      },
                      childCount: books.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
