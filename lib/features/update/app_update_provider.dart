import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import 'app_update_models.dart';
import 'app_update_service.dart';

/// 在线更新服务 Provider（独立维护在 lib/features/update/，不修改全局 providers.dart）
final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService(
    db: ref.watch(appDatabaseProvider),
    httpClient: ref.watch(appHttpClientProvider),
  );
});

/// 设置页与启动入口共享的更新徽标状态
@immutable
class AppUpdateBadgeState {
  const AppUpdateBadgeState({
    this.checking = false,
    this.availableRelease,
  });

  final bool checking;
  final AppReleaseInfo? availableRelease;
}

class AppUpdateController extends Notifier<AppUpdateBadgeState> {
  @override
  AppUpdateBadgeState build() => const AppUpdateBadgeState();

  /// 手动触发检查更新（无视每日节流与忽略记录）
  Future<AppUpdateCheckResult> checkManual({CancelToken? cancelToken}) async {
    final service = ref.read(appUpdateServiceProvider);
    if (state.checking) {
      return AppUpdateCheckResult(
        status: AppUpdateCheckStatus.throttled,
        currentVersion: service.currentVersion,
      );
    }
    state = AppUpdateBadgeState(
      checking: true,
      availableRelease: state.availableRelease,
    );
    try {
      final result = await service.checkForUpdate(
        isAuto: false,
        force: true,
        cancelToken: cancelToken,
      );
      state = AppUpdateBadgeState(
        checking: false,
        availableRelease: result.hasUpdate
            ? result.release
            : (result.status == AppUpdateCheckStatus.upToDate
                ? null
                : state.availableRelease),
      );
      return result;
    } catch (_) {
      state = AppUpdateBadgeState(
        checking: false,
        availableRelease: state.availableRelease,
      );
      rethrow;
    }
  }

  /// 启动后静默自动检查更新（受每日一次节流与忽略版本约束）
  Future<AppUpdateCheckResult> checkAuto({CancelToken? cancelToken}) async {
    final service = ref.read(appUpdateServiceProvider);
    final result = await service.checkForUpdate(
      isAuto: true,
      force: false,
      cancelToken: cancelToken,
    );
    if (result.hasUpdate) {
      state = AppUpdateBadgeState(
        checking: state.checking,
        availableRelease: result.release,
      );
    }
    return result;
  }

  /// 忽略指定版本并同步消除设置页新版本徽标
  Future<void> ignoreRelease(AppReleaseInfo release) async {
    await ref.read(appUpdateServiceProvider).ignoreVersion(release.version);
    if (state.availableRelease?.version == release.version) {
      state = AppUpdateBadgeState(
        checking: state.checking,
        availableRelease: null,
      );
    }
  }
}

final appUpdateControllerProvider =
    NotifierProvider<AppUpdateController, AppUpdateBadgeState>(
  AppUpdateController.new,
);
