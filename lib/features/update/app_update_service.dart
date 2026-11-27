import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/database/app_database.dart';
import '../../core/network/app_http_client.dart';
import '../../core/platform/host_bridge.dart';
import 'app_update_models.dart';

export 'app_update_provider.dart';

const String kGitHubLatestReleaseUrl =
    'https://api.github.com/repos/Kline-x/yuewei-reader/releases/latest';
const String kPrefUpdateIgnoredVersion = 'update_ignored_version';
const String kPrefUpdateLastAutoCheckDay = 'update_last_auto_check_day';

typedef ApkInstallerCallback = Future<String> Function({
  required String filePath,
  String? expectedSha256,
});
typedef ExternalUrlOpener = Future<bool> Function(String url);
typedef DownloadProgressCallback = void Function(int received, int total);

/// 应用内在线更新服务（GitHub Releases API 检查、流式下载、SHA-256 校验与原生安装）
class AppUpdateService {
  AppUpdateService({
    required this.db,
    required this.httpClient,
    Dio? downloadDio,
    HostCapabilities Function()? capabilitiesProvider,
    Future<Directory> Function()? tempDirProvider,
    ApkInstallerCallback? installApkHandler,
    ExternalUrlOpener? openExternalUrlHandler,
    DateTime Function()? nowProvider,
    this.latestReleaseApiUrl = kGitHubLatestReleaseUrl,
  })  : _downloadDio = downloadDio ?? _buildDownloadDio(),
        _capabilitiesProvider =
            capabilitiesProvider ?? (() => HostBridge.instance.capabilities),
        _tempDirProvider = tempDirProvider ?? getTemporaryDirectory,
        _installApkHandler = installApkHandler ?? HostBridge.instance.installApk,
        _openExternalUrlHandler =
            openExternalUrlHandler ?? HostBridge.instance.openExternalUrl,
        _nowProvider = nowProvider ?? DateTime.now;

  final AppDatabase db;
  final AppHttpClient httpClient;
  final Dio _downloadDio;
  final HostCapabilities Function() _capabilitiesProvider;
  final Future<Directory> Function() _tempDirProvider;
  final ApkInstallerCallback _installApkHandler;
  final ExternalUrlOpener _openExternalUrlHandler;
  final DateTime Function() _nowProvider;
  final String latestReleaseApiUrl;

  static Dio _buildDownloadDio() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(minutes: 3),
        sendTimeout: const Duration(seconds: 15),
        followRedirects: true,
        maxRedirects: 8,
        headers: const {
          'Accept': 'application/octet-stream, */*',
          'User-Agent': 'YueweiReader-Updater/1.0',
        },
      ),
    );
  }

  /// 当前宿主应用语义版本号
  String get currentVersion {
    final raw = _capabilitiesProvider().versionName.trim();
    return raw.isEmpty ? '1.0.0' : raw;
  }

  /// 当前运行平台是否支持应用内 APK 直装
  bool get supportsInAppApkInstall =>
      _capabilitiesProvider().platform.trim().toLowerCase() == 'android';

  /// 检查 GitHub 最新正式版本（自动检查支持每日一次节流与忽略版本跳过）
  Future<AppUpdateCheckResult> checkForUpdate({
    bool isAuto = false,
    bool force = false,
    CancelToken? cancelToken,
  }) async {
    final cur = currentVersion;
    final todayKey = _formatDayKey(_nowProvider());

    if (isAuto && !force) {
      final lastDay = await db.getPreference(kPrefUpdateLastAutoCheckDay);
      if (lastDay == todayKey) {
        return AppUpdateCheckResult(
          status: AppUpdateCheckStatus.throttled,
          currentVersion: cur,
        );
      }
    }

    try {
      final resp = await httpClient.fetchText(
        latestReleaseApiUrl,
        timeout: const Duration(seconds: 12),
        cancelToken: cancelToken,
      );
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) {
        return AppUpdateCheckResult(
          status: AppUpdateCheckStatus.failed,
          currentVersion: cur,
          errorMessage: '版本响应格式异常',
        );
      }

      final release = AppReleaseInfo.fromGitHubJson(decoded);
      if (isAuto) {
        await db.setPreference(kPrefUpdateLastAutoCheckDay, todayKey);
      }

      if (!AppVersionComparator.isNewer(
        remoteVersion: release.version,
        currentVersion: cur,
      )) {
        return AppUpdateCheckResult(
          status: AppUpdateCheckStatus.upToDate,
          currentVersion: cur,
          release: release,
        );
      }

      if (isAuto && !force) {
        final ignored = await db.getPreference(kPrefUpdateIgnoredVersion);
        if (ignored != null &&
            ignored.trim().isNotEmpty &&
            AppVersionComparator.compare(ignored, release.version) == 0) {
          return AppUpdateCheckResult(
            status: AppUpdateCheckStatus.ignored,
            currentVersion: cur,
            release: release,
          );
        }
      }

      return AppUpdateCheckResult(
        status: AppUpdateCheckStatus.hasUpdate,
        currentVersion: cur,
        release: release,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        return AppUpdateCheckResult(
          status: AppUpdateCheckStatus.failed,
          currentVersion: cur,
          errorMessage: '已取消检查更新',
        );
      }
      final statusCode = e.response?.statusCode;
      if (statusCode == 404) {
        if (isAuto) {
          await db.setPreference(kPrefUpdateLastAutoCheckDay, todayKey);
        }
        return AppUpdateCheckResult(
          status: AppUpdateCheckStatus.upToDate,
          currentVersion: cur,
        );
      }
      return AppUpdateCheckResult(
        status: AppUpdateCheckStatus.failed,
        currentVersion: cur,
        errorMessage:
            statusCode == 403 ? 'GitHub API 访问受限，请稍后重试' : '检查更新失败，请检查网络连接',
      );
    } catch (_) {
      return AppUpdateCheckResult(
        status: AppUpdateCheckStatus.failed,
        currentVersion: cur,
        errorMessage: '解析版本信息失败，请稍后重试',
      );
    }
  }

  /// 持久化记录用户忽略的版本号
  Future<void> ignoreVersion(String version) async {
    final normalized = AppVersionComparator.normalize(version);
    if (normalized.isEmpty) return;
    await db.setPreference(kPrefUpdateIgnoredVersion, normalized);
  }

  /// 拉取并解析 Release 对应的 SHA-256 校验值
  Future<String?> fetchExpectedSha256(
    AppReleaseInfo release, {
    CancelToken? cancelToken,
  }) async {
    final shaUrl = release.sha256AssetUrl;
    if (shaUrl == null || shaUrl.trim().isEmpty) return null;
    final resp = await httpClient.fetchText(
      shaUrl,
      timeout: const Duration(seconds: 12),
      cancelToken: cancelToken,
    );
    final parsed = Sha256Parser.extract(
      resp.body,
      fileName: release.apkFileName,
    );
    if (parsed == null) throw const FormatException('校验文件内容无效');
    return parsed;
  }

  /// 流式下载 APK 至 cache/yuewei_updates/，校验 SHA-256 并调起原生安装器
  Future<ApkInstallOutcome> downloadAndInstallApk(
    AppReleaseInfo release, {
    DownloadProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final downloadUrl = release.apkDownloadUrl;
    if (downloadUrl == null || downloadUrl.trim().isEmpty) {
      return const ApkInstallOutcome(
        status: ApkInstallStatus.failed,
        statusCode: 'FAILED:NO_APK_ASSET',
        message: '该版本未附带 Android APK 安装包，请前往浏览器查看',
      );
    }

    File? partFile;
    try {
      final tempRoot = await _tempDirProvider();
      final updatesDir = Directory(p.join(tempRoot.path, 'yuewei_updates'));
      await updatesDir.create(recursive: true);
      await _cleanupStaleUpdates(updatesDir);

      final safeName = _sanitizeApkName(
        release.apkFileName ?? 'yuewei-${release.version}.apk',
      );
      final apkFile = File(p.join(updatesDir.path, safeName));
      partFile = File('${apkFile.path}.part');
      await _safeDelete(partFile);
      await _safeDelete(apkFile);

      final fallbackTotal = release.apkSizeBytes ?? -1;
      await _downloadDio.download(
        downloadUrl,
        partFile.path,
        cancelToken: cancelToken,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          onProgress?.call(received, total > 0 ? total : fallbackTotal);
        },
      );

      if (!await partFile.exists() || await partFile.length() <= 0) {
        return const ApkInstallOutcome(
          status: ApkInstallStatus.failed,
          statusCode: 'FAILED:EMPTY_FILE',
          message: '安装包下载为空，请重试或改用浏览器下载',
        );
      }

      final expectedSha = await fetchExpectedSha256(
        release,
        cancelToken: cancelToken,
      );
      await partFile.rename(apkFile.path);
      return await retryInstallLocalApk(
        filePath: apkFile.path,
        expectedSha256: expectedSha,
      );
    } on DioException catch (e) {
      await _safeDelete(partFile);
      if (CancelToken.isCancel(e)) {
        return const ApkInstallOutcome(
          status: ApkInstallStatus.cancelled,
          statusCode: 'CANCELLED',
          message: '已取消下载',
        );
      }
      return ApkInstallOutcome(
        status: ApkInstallStatus.failed,
        statusCode: 'FAILED:DOWNLOAD',
        message: '下载安装包失败（${e.message ?? '网络异常'}），可改用浏览器下载',
      );
    } catch (e) {
      await _safeDelete(partFile);
      return ApkInstallOutcome(
        status: ApkInstallStatus.failed,
        statusCode: 'FAILED:EXCEPTION',
        message: '更新处理失败：$e',
      );
    }
  }

  /// 对已落盘的 APK 直接发起原生校验与安装（适用于开启未知来源权限后继续安装）
  Future<ApkInstallOutcome> retryInstallLocalApk({
    required String filePath,
    String? expectedSha256,
  }) async {
    final status = await _installApkHandler(
      filePath: filePath,
      expectedSha256: expectedSha256,
    );
    final outcome = ApkInstallOutcome.fromNativeStatus(
      status,
      apkFilePath: filePath,
      expectedSha256: expectedSha256,
    );
    if (outcome.status == ApkInstallStatus.hashMismatch) {
      await _safeDelete(File(filePath));
    }
    return outcome;
  }

  /// 使用系统浏览器打开 Release 页面
  Future<bool> openReleasePage(AppReleaseInfo release) =>
      _openExternalUrlHandler(release.htmlUrl);

  static String _formatDayKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _sanitizeApkName(String raw) {
    var safe = p
        .basename(raw.trim())
        .replaceAll(RegExp(r'[^a-zA-Z0-9._\-]'), '_')
        .replaceAll(RegExp(r'^\.+'), '');
    if (safe.isEmpty) safe = 'yuewei_update.apk';
    if (!safe.toLowerCase().endsWith('.apk')) safe = '$safe.apk';
    return safe;
  }

  static Future<void> _cleanupStaleUpdates(Directory dir) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is File) await entity.delete();
      }
    } catch (_) {}
  }

  static Future<void> _safeDelete(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
