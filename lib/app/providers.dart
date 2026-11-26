import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/database/app_database.dart';
import '../core/network/app_http_client.dart';
import '../core/storage/chapter_file_store.dart';
import '../design_system/components/single_swipe_tile.dart';
import '../design_system/tokens/soft_tokens.dart';
import '../features/download/download_manager.dart';
import '../features/local_import/data/local_import_service.dart';
import '../features/local_import/wifi/wifi_transfer_server.dart';
import '../features/shelf/data/shelf_repository.dart';
import '../features/sources/data/source_repository.dart';
import '../features/sources/engine/source_crawler_service.dart';
import '../features/sync/backup_snapshot_codec.dart';

final sharedPrefsProvider = Provider<SharedPreferences?>((ref) => null);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final chapterFileStoreProvider = Provider<ChapterFileStore>((ref) {
  return ChapterFileStore();
});

final appHttpClientProvider = Provider<AppHttpClient>((ref) {
  return AppHttpClient();
});

final sourceRepositoryProvider = Provider<SourceRepository>((ref) {
  return SourceRepository(
    db: ref.watch(appDatabaseProvider),
    httpClient: ref.watch(appHttpClientProvider),
  );
});

final crawlerServiceProvider = Provider<SourceCrawlerService>((ref) {
  return SourceCrawlerService(httpClient: ref.watch(appHttpClientProvider));
});

final downloadManagerProvider = Provider<DownloadManager>((ref) {
  final mgr = DownloadManager(
    db: ref.watch(appDatabaseProvider),
    fileStore: ref.watch(chapterFileStoreProvider),
    sourceRepo: ref.watch(sourceRepositoryProvider),
    crawler: ref.watch(crawlerServiceProvider),
  );
  ref.onDispose(mgr.dispose);
  return mgr;
});

final shelfRepositoryProvider = Provider<ShelfRepository>((ref) {
  return ShelfRepository(
    db: ref.watch(appDatabaseProvider),
    fileStore: ref.watch(chapterFileStoreProvider),
    downloadManager: ref.watch(downloadManagerProvider),
  );
});

final localImportServiceProvider = Provider<LocalImportService>((ref) {
  return LocalImportService(
    db: ref.watch(appDatabaseProvider),
    fileStore: ref.watch(chapterFileStoreProvider),
  );
});

final wifiTransferServerProvider = Provider<WifiTransferServer>((ref) {
  final server = WifiTransferServer(
    localImportService: ref.watch(localImportServiceProvider),
    sourceRepository: ref.watch(sourceRepositoryProvider),
  );
  ref.onDispose(() => server.dispose());
  return server;
});

final backupSnapshotCodecProvider = Provider<BackupSnapshotCodec>((ref) {
  return BackupSnapshotCodec(db: ref.watch(appDatabaseProvider));
});

@immutable
class ThemeConfigState {
  const ThemeConfigState({
    required this.mode,
    required this.palette,
  });

  final ThemeMode mode;
  final SoftPalette palette;

  ThemeConfigState copyWith({ThemeMode? mode, SoftPalette? palette}) {
    return ThemeConfigState(
      mode: mode ?? this.mode,
      palette: palette ?? this.palette,
    );
  }
}

class ThemeConfigNotifier extends Notifier<ThemeConfigState> {
  static const _keyMode = 'yuewei_theme_mode';
  static const _keyPalette = 'yuewei_theme_palette';

  @override
  ThemeConfigState build() {
    final prefs = ref.watch(sharedPrefsProvider);
    final rawMode = prefs?.getString(_keyMode);
    final rawPalette = prefs?.getString(_keyPalette);
    return ThemeConfigState(
      mode: _parseMode(rawMode),
      palette: SoftPalette.fromName(rawPalette),
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    final prefs = ref.read(sharedPrefsProvider);
    await prefs?.setString(_keyMode, mode.name);
    await ref.read(appDatabaseProvider).setPreference(_keyMode, mode.name);
  }

  Future<void> setPalette(SoftPalette palette) async {
    state = state.copyWith(palette: palette);
    final prefs = ref.read(sharedPrefsProvider);
    await prefs?.setString(_keyPalette, palette.name);
    await ref.read(appDatabaseProvider).setPreference(_keyPalette, palette.name);
  }

  /// 备份恢复后从数据库热刷新主题模式与意境色盘（不触发偏好修改时间戳）
  Future<void> reloadFromDb() async {
    final db = ref.read(appDatabaseProvider);
    final prefs = ref.read(sharedPrefsProvider);
    final rawMode = await db.getPreference(_keyMode);
    final rawPalette = await db.getPreference(_keyPalette);
    final nextMode = rawMode != null ? _parseMode(rawMode) : state.mode;
    final nextPalette =
        rawPalette != null ? SoftPalette.fromName(rawPalette) : state.palette;
    state = state.copyWith(mode: nextMode, palette: nextPalette);
    if (rawMode != null) await prefs?.setString(_keyMode, nextMode.name);
    if (rawPalette != null) await prefs?.setString(_keyPalette, nextPalette.name);
  }

  static ThemeMode _parseMode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

final themeConfigProvider =
    NotifierProvider<ThemeConfigNotifier, ThemeConfigState>(
  ThemeConfigNotifier.new,
);

@immutable
class ShelfViewPrefsState {
  const ShelfViewPrefsState({
    this.sortMode = ShelfSortMode.lastRead,
    this.isGridView = false,
  });

  final ShelfSortMode sortMode;
  final bool isGridView;

  ShelfViewPrefsState copyWith({ShelfSortMode? sortMode, bool? isGridView}) {
    return ShelfViewPrefsState(
      sortMode: sortMode ?? this.sortMode,
      isGridView: isGridView ?? this.isGridView,
    );
  }
}

/// 书架排序模式与网格视图状态管理器（供书架实时监听，备份恢复后即时刷新）
class ShelfViewPrefsNotifier extends Notifier<ShelfViewPrefsState> {
  int _mutationGen = 0;

  @override
  ShelfViewPrefsState build() {
    _loadInitial();
    return const ShelfViewPrefsState();
  }

  Future<void> _loadInitial() async {
    final gen = _mutationGen;
    final repo = ref.read(shelfRepositoryProvider);
    final sort = await repo.getSortMode();
    final grid = await repo.getIsGridView();
    if (gen != _mutationGen) return;
    state = ShelfViewPrefsState(sortMode: sort, isGridView: grid);
  }

  Future<void> reloadFromDb() async {
    final gen = ++_mutationGen;
    final repo = ref.read(shelfRepositoryProvider);
    final sort = await repo.getSortMode();
    final grid = await repo.getIsGridView();
    if (gen != _mutationGen) return;
    state = ShelfViewPrefsState(sortMode: sort, isGridView: grid);
  }

  Future<void> setSortMode(ShelfSortMode mode) async {
    _mutationGen++;
    state = state.copyWith(sortMode: mode);
    await ref.read(shelfRepositoryProvider).saveSortMode(mode);
  }

  Future<void> toggleGridView() async {
    _mutationGen++;
    final next = !state.isGridView;
    state = state.copyWith(isGridView: next);
    await ref.read(shelfRepositoryProvider).saveIsGridView(next);
  }
}

final shelfViewPrefsProvider =
    NotifierProvider<ShelfViewPrefsNotifier, ShelfViewPrefsState>(
  ShelfViewPrefsNotifier.new,
);

final swipeCoordinatorProvider = Provider<SwipeCoordinator>((ref) {
  final coordinator = SwipeCoordinator();
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
