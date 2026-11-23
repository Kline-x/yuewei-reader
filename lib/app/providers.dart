import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/database/app_database.dart';
import '../core/network/app_http_client.dart';
import '../core/storage/chapter_file_store.dart';
import '../design_system/components/single_swipe_tile.dart';
import '../design_system/tokens/soft_tokens.dart';
import '../features/download/download_manager.dart';
import '../features/shelf/data/shelf_repository.dart';
import '../features/sources/data/source_repository.dart';
import '../features/sources/engine/source_crawler_service.dart';

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

final swipeCoordinatorProvider = Provider<SwipeCoordinator>((ref) {
  final coordinator = SwipeCoordinator();
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
