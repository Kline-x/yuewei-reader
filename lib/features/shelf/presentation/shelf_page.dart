import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/storage/chapter_file_store.dart';
import '../../../design_system/components/empty_error_view.dart';
import '../../../design_system/components/soft_button.dart';
import '../../../design_system/feedback/app_feedback.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';
import '../data/shelf_repository.dart';
import '../data/shelf_update_checker.dart';
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
  bool _checkingUpdates = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  void _go(String route, {bool tab = false}) {
    AppFeedback.dismissSnackBar(context);
    tab ? context.go(route) : context.push(route);
  }

  Future<void> _changeSort(ShelfSortMode mode) =>
      ref.read(shelfViewPrefsProvider.notifier).setSortMode(mode);

  Future<void> _toggleGridMode() {
    ref.read(swipeCoordinatorProvider).closeAll();
    return ref.read(shelfViewPrefsProvider.notifier).toggleGridView();
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
      onCommitted: () => repo.purgeBookDataIfNotInShelf(book.id),
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

  Future<void> _checkShelfUpdates() async {
    if (_checkingUpdates) return;
    _checkingUpdates = true;
    try {
      final db = ref.read(appDatabaseProvider);
      final books = await db.getShelfBooks();
      final hasOnline = books.any(
        (b) => b.sourceId != kLocalBookSourceId && b.bookUrl.trim().isNotEmpty,
      );
      if (!hasOnline) {
        if (mounted) AppFeedback.showToast(context, '当前书架暂无在线连载书');
        return;
      }
      final checker = ShelfUpdateChecker(
        db: db,
        sourceRepo: ref.read(sourceRepositoryProvider),
        crawler: ref.read(crawlerServiceProvider),
        fileStore: ref.read(chapterFileStoreProvider),
      );
      final res = await checker.checkAll();
      if (!mounted) return;
      if (res.updated > 0) {
        AppFeedback.showToast(context, '检查完成 · 发现 ${res.updated} 部更新');
      } else if (res.checked == 0) {
        AppFeedback.showToast(context, '检查失败，请确认网络或书源状态', isError: true);
      } else {
        AppFeedback.showToast(context, '已是最新章节');
      }
    } finally {
      _checkingUpdates = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final db = ref.watch(appDatabaseProvider);
    final coordinator = ref.watch(swipeCoordinatorProvider);
    final viewPrefs = ref.watch(shelfViewPrefsProvider);

    return SafeArea(
      bottom: false,
      child: StreamBuilder<List<Book>>(
        stream: db.watchShelfBooks(),
        builder: (context, booksSnap) {
          final rawBooks = booksSnap.data ?? const <Book>[];
          final books = ShelfRepository.sortBooks(rawBooks, viewPrefs.sortMode);

          return RefreshIndicator(
            color: tokens.accent,
            backgroundColor: tokens.card,
            onRefresh: _checkShelfUpdates,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: ShelfHeaderBar(
                    isGridView: viewPrefs.isGridView,
                    onTapSearch: () => _go('/discover', tab: true),
                    onTapImport: () => _go('/import'),
                    onTapSources: () => _go('/sources'),
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
                      currentMode: viewPrefs.sortMode,
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        EmptyErrorView(
                          icon: Icons.auto_stories_outlined,
                          title: '书架空空如也',
                          description: '去探索书海搜寻心仪小说，或直接导入本地 TXT / EPUB 电子书。',
                          actionLabel: '探索书海',
                          onAction: () => _go('/discover', tab: true),
                        ),
                        SoftButton(
                          label: '导入本地藏书',
                          icon: Icons.drive_folder_upload_outlined,
                          tone: SoftButtonTone.tonal,
                          compact: true,
                          onPressed: () => _go('/import'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (viewPrefs.isGridView)
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
                          onTapRead: () => _go('/reader/${book.id}'),
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
                          onTapRead: () => _go('/reader/${book.id}'),
                          onOpenActions: () => _openBookMenu(book),
                          onSwipeRemove: () => _removeBookWithUndo(book),
                        );
                      },
                      childCount: books.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
