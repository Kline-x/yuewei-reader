import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../design_system/components/ambient_background.dart';
import '../design_system/components/sublime_floating_dock.dart';
import '../design_system/feedback/app_feedback.dart';
import '../features/book_detail/presentation/book_detail_page.dart';
import '../features/discover/presentation/discover_page.dart';
import '../features/local_import/presentation/import_and_transfer_page.dart';
import '../features/reader/presentation/reader_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/shelf/presentation/shelf_page.dart';
import '../features/sources/domain/book_match_models.dart';
import '../features/sources/presentation/sources_page.dart';
import '../features/sync/presentation/sync_and_backup_page.dart';
import '../features/tts/global_tts_mini_capsule.dart';
import 'providers.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/shelf',
    routes: [
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, navigationShell) {
          return NoTransitionPage(
            key: state.pageKey,
            child: RootShell(navigationShell: navigationShell),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/shelf',
                builder: (_, _) => const ShelfPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                builder: (_, _) => const DiscoverPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, _) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/sources',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const SourcesPage(),
      ),
      GoRoute(
        path: '/sync',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const SyncAndBackupPage(),
      ),
      GoRoute(
        path: '/import',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const ImportAndTransferPage(),
      ),
      GoRoute(
        path: '/book',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => BookDetailPage(
          bookId: state.uri.queryParameters['id'],
          aggregatedMatch: state.extra as AggregatedBookMatch?,
        ),
      ),
      GoRoute(
        path: '/reader/:bookId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => ReaderPage(
          bookId: state.pathParameters['bookId']!,
          initialChapterIndex:
              int.tryParse(state.uri.queryParameters['chapter'] ?? ''),
        ),
      ),
    ],
  );
});

/// 阅微主导航外壳：
/// 1. AmbientBackground + 透明 Scaffold(resizeToAvoidBottomInset: false)；
/// 2. 软键盘弹出自动滑落隐藏 FloatingDock，彻底杜绝底栏被键盘顶到屏幕中间；
/// 3. 返回键先切回书架再双击退出防误触；切 Tab 自动复位左滑条并收起键盘焦点。
class RootShell extends ConsumerStatefulWidget {
  const RootShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  DateTime? _lastBackAt;

  static const _dockItems = [
    DockNavItem(
      label: '书架',
      icon: Icons.collections_bookmark_outlined,
      activeIcon: Icons.collections_bookmark_rounded,
    ),
    DockNavItem(
      label: '探索',
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore_rounded,
    ),
    DockNavItem(
      label: '设置',
      icon: Icons.tune_outlined,
      activeIcon: Icons.tune_rounded,
    ),
  ];

  void _onTabTap(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    ref.read(swipeCoordinatorProvider).closeAll();
    AppFeedback.dismissSnackBar(context);
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  void _handleBack() {
    FocusManager.instance.primaryFocus?.unfocus();
    ref.read(swipeCoordinatorProvider).closeAll();
    if (widget.navigationShell.currentIndex != 0) {
      widget.navigationShell.goBranch(0);
      return;
    }
    final now = DateTime.now();
    if (_lastBackAt == null ||
        now.difference(_lastBackAt!) > const Duration(seconds: 2)) {
      _lastBackAt = now;
      AppFeedback.showToast(context, '再按一次退出阅微');
      return;
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 40.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: AmbientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: Stack(
            fit: StackFit.expand,
            children: [
              widget.navigationShell,
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  ignoring: keyboardVisible,
                  child: AnimatedSlide(
                    offset: keyboardVisible
                        ? const Offset(0, 2.2)
                        : Offset.zero,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const GlobalTtsMiniCapsule(),
                        SublimeFloatingDock(
                          items: _dockItems,
                          currentIndex: widget.navigationShell.currentIndex,
                          onTap: _onTabTap,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
