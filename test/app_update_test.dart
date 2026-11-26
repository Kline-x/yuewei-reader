import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuewei_reader/core/database/app_database.dart';
import 'package:yuewei_reader/core/network/app_http_client.dart';
import 'package:yuewei_reader/core/platform/host_bridge.dart';
import 'package:yuewei_reader/design_system/tokens/soft_tokens.dart';
import 'package:yuewei_reader/features/update/app_update_dialog.dart';
import 'package:yuewei_reader/features/update/app_update_models.dart';
import 'package:yuewei_reader/features/update/app_update_service.dart';

void main() {
  group('语义版本比较、Release JSON 与 SHA-256 解析', () {
    test('语义化版本比较覆盖 v 前缀、预发布后缀、简写与构建号', () {
      expect(AppVersionComparator.compare('v1.0.1', '1.0.0'), greaterThan(0));
      expect(AppVersionComparator.compare('V1.0.0', '1.0.0'), 0);
      expect(AppVersionComparator.compare('1.0.1', '1.0.1-rc.1'), greaterThan(0));
      expect(AppVersionComparator.compare('1.0.1-beta.10', '1.0.1-beta.2'), greaterThan(0));
      expect(AppVersionComparator.compare('1.0.1-rc.1', '1.0.1-beta.9'), greaterThan(0));
      expect(AppVersionComparator.compare('1.0.0+2', '1.0.0+1'), greaterThan(0));
      expect(AppVersionComparator.compare('v1.0.0', '1.0.0+1'), 0);
      expect(AppVersionComparator.isNewer(remoteVersion: 'v1.2', currentVersion: '1.1.9'), isTrue);
    });

    test('解析 GitHub Release JSON 优先匹配 arm64 APK 与对应 SHA-256 并过滤非法协议', () {
      final info = AppReleaseInfo.fromGitHubJson({
        'tag_name': 'v1.2.0',
        'name': '阅微 1.2.0',
        'body': '新增在线更新\r\n加固双端音频中断恢复',
        'html_url': 'https://github.com/Kline-x/yuewei-reader/releases/tag/v1.2.0',
        'assets': [
          {'name': 'app-universal.apk', 'size': 20971520, 'browser_download_url': 'https://example.test/u.apk'},
          {'name': 'app-arm64-release.apk', 'size': 15728640, 'browser_download_url': 'https://example.test/arm64.apk'},
          {'name': 'app-arm64-release.apk.sha256', 'size': 96, 'browser_download_url': 'https://example.test/arm64.sha256'},
          {'name': 'bad.apk', 'size': 1024, 'browser_download_url': 'javascript:alert(1)'},
        ],
      });
      expect(info.version, '1.2.0');
      expect(info.apkFileName, 'app-arm64-release.apk');
      expect(info.apkDownloadUrl, 'https://example.test/arm64.apk');
      expect(info.sha256AssetUrl, 'https://example.test/arm64.sha256');
      expect(info.formattedApkSize, '15.0 MB');
      expect(() => AppReleaseInfo.fromGitHubJson(const {}), throwsFormatException);
    });

    test('Sha256Parser 兼容多行 sha256sum 清单与纯十六进制', () {
      const h1 = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const h2 = 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';
      expect(Sha256Parser.extract('$h1  other.apk\n$h2 *app-release.apk\n', fileName: 'app-release.apk'), h2.toLowerCase());
      expect(Sha256Parser.extract('  $h1  '), h1);
      expect(Sha256Parser.extract('invalid-short'), isNull);
    });
  });

  group('HostBridge 更新通道契约与 AppUpdateService 状态流转', () {
    late HttpServer server;
    late Directory tempDir;
    late AppDatabase db;
    late DateTime fakeNow;
    late bool return404;
    HttpOverrides? prevHttpOverrides;
    const mockSha256 = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    final mockApkBytes = List<int>.filled(64 * 1024, 0x5A);

    setUp(() async {
      // TestWidgetsFlutterBinding 会拦截全部 HttpClient 返回 400，此处放行本机 loopback HttpServer
      prevHttpOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      tempDir = await Directory.systemTemp.createTemp('yuewei_update_test_');
      db = AppDatabase(NativeDatabase.memory());
      fakeNow = DateTime(2026, 11, 26, 10, 0);
      return404 = false;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final base = 'http://${server.address.address}:${server.port}';
        if (req.uri.path == '/releases/latest') {
          if (return404) {
            req.response..statusCode = 404..write('{"message":"Not Found"}');
          } else {
            req.response
              ..statusCode = 200
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({
                'tag_name': 'v1.1.0',
                'name': '阅微 v1.1.0',
                'body': '新增在线更新与原生加固',
                'html_url': 'https://github.com/Kline-x/yuewei-reader/releases',
                'assets': [
                  {'name': 'app-release.apk', 'size': mockApkBytes.length, 'browser_download_url': '$base/files/app-release.apk'},
                  {'name': 'app-release.apk.sha256', 'size': 82, 'browser_download_url': '$base/files/app-release.apk.sha256'},
                ],
              }));
          }
        } else if (req.uri.path == '/files/app-release.apk.sha256') {
          req.response..statusCode = 200..write('$mockSha256  app-release.apk\n');
        } else if (req.uri.path == '/files/app-release.apk') {
          req.response..statusCode = 200..headers.contentLength = mockApkBytes.length..add(mockApkBytes);
        } else {
          req.response.statusCode = 404;
        }
        await req.response.close();
      });
    });

    tearDown(() async {
      HttpOverrides.global = prevHttpOverrides;
      await server.close(force: true);
      await db.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    AppUpdateService buildService({
      String platform = 'android',
      ApkInstallerCallback? installHandler,
      ExternalUrlOpener? openUrlHandler,
    }) {
      final base = 'http://${server.address.address}:${server.port}';
      return AppUpdateService(
        db: db,
        httpClient: AppHttpClient(),
        capabilitiesProvider: () => HostCapabilities(
          platform: platform,
          supportsVolumeKeyPaging: platform == 'android',
          versionName: '1.0.0',
          versionCode: 1,
        ),
        tempDirProvider: () async => tempDir,
        installApkHandler: installHandler ?? ({required filePath, expectedSha256}) async => 'STARTED',
        openExternalUrlHandler: openUrlHandler ?? (_) async => true,
        nowProvider: () => fakeNow,
        latestReleaseApiUrl: '$base/releases/latest',
      );
    }

    test('HostBridge.openExternalUrl 仅放行 http/https 并透传 installApk 参数', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const ch = MethodChannel('com.kline.yuewei/host_bridge');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ch, (call) async {
        calls.add(call);
        if (call.method == 'installApk') return 'STARTED';
        if (call.method == 'openExternalUrl') return true;
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, null));

      expect(await HostBridge.instance.openExternalUrl('file:///etc/passwd'), isFalse);
      expect(await HostBridge.instance.openExternalUrl('https://github.com/Kline-x/yuewei-reader'), isTrue);
      expect(await HostBridge.instance.installApk(filePath: '/cache/yuewei_updates/a.apk', expectedSha256: mockSha256), 'STARTED');
      expect(calls.map((c) => c.method), ['openExternalUrl', 'installApk']);
    });

    test('每日自动检查节流、忽略版本持久化与 404 平滑回落', () async {
      final service = buildService();
      expect((await service.checkForUpdate(isAuto: true)).status, AppUpdateCheckStatus.hasUpdate);
      expect((await service.checkForUpdate(isAuto: true)).status, AppUpdateCheckStatus.throttled);

      await service.ignoreVersion('v1.1.0');
      fakeNow = fakeNow.add(const Duration(days: 1));
      expect((await service.checkForUpdate(isAuto: true)).status, AppUpdateCheckStatus.ignored);
      expect((await service.checkForUpdate(isAuto: false, force: true)).status, AppUpdateCheckStatus.hasUpdate);

      return404 = true;
      expect((await service.checkForUpdate(force: true)).status, AppUpdateCheckStatus.upToDate);
    });

    test('流式下载 APK 并验证 NEED_INSTALL_PERMISSION / STARTED / HASH_MISMATCH / CANCELLED', () async {
      String? capturedPath;
      String? capturedSha;
      var nativeResponse = 'NEED_INSTALL_PERMISSION';
      final service = buildService(
        installHandler: ({required filePath, expectedSha256}) async {
          capturedPath = filePath;
          capturedSha = expectedSha256;
          return nativeResponse;
        },
      );
      final release = (await service.checkForUpdate(force: true)).release!;
      var gotProgress = false;

      final perm = await service.downloadAndInstallApk(
        release,
        onProgress: (r, t) {
          if (r > 0 && t == mockApkBytes.length) gotProgress = true;
        },
      );
      expect(gotProgress, isTrue);
      expect(perm.status, ApkInstallStatus.needInstallPermission);
      expect(capturedPath, contains('yuewei_updates'));
      expect(File(capturedPath!).existsSync(), isTrue);
      expect(capturedSha, mockSha256);

      nativeResponse = 'STARTED';
      expect((await service.retryInstallLocalApk(filePath: capturedPath!, expectedSha256: capturedSha)).status, ApkInstallStatus.started);

      nativeResponse = 'HASH_MISMATCH';
      expect((await service.retryInstallLocalApk(filePath: capturedPath!, expectedSha256: capturedSha)).status, ApkInstallStatus.hashMismatch);
      expect(File(capturedPath!).existsSync(), isFalse);

      final cancelled = await service.downloadAndInstallApk(release, cancelToken: CancelToken()..cancel());
      expect(cancelled.status, ApkInstallStatus.cancelled);
    });
  });

  group('AppUpdateDialog 弹窗渲染与双端交互', () {
    const sampleRelease = AppReleaseInfo(
      tagName: 'v1.2.0',
      version: '1.2.0',
      name: '阅微 1.2.0',
      releaseNotes: '1. 新增应用内在线更新\n2. 加固 TTS 音频焦点恢复',
      htmlUrl: 'https://github.com/Kline-x/yuewei-reader/releases/tag/v1.2.0',
      apkDownloadUrl: 'https://example.test/app-release.apk',
      apkFileName: 'app-release.apk',
      apkSizeBytes: 18 * 1024 * 1024,
    );

    Widget wrapApp(Widget child) => MaterialApp(
          theme: SoftTokens.resolve(SoftPalette.mistyJade, isDark: false).toThemeData(),
          home: Scaffold(body: child),
        );

    testWidgets('Android 弹窗展示版本、体积、日志并支持忽略此版本持久化', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      var ignored = false;
      final service = AppUpdateService(db: db, httpClient: AppHttpClient());

      await tester.pumpWidget(wrapApp(Builder(
        builder: (ctx) => ElevatedButton(
          onPressed: () => showAppUpdateDialog(
            ctx,
            release: sampleRelease,
            currentVersion: '1.0.0',
            service: service,
            supportsInAppApkInstall: true,
            onIgnored: () => ignored = true,
          ),
          child: const Text('open_android'),
        ),
      )));

      await tester.tap(find.text('open_android'));
      await tester.pumpAndSettle();
      expect(find.text('发现新版本 v1.2.0'), findsOneWidget);
      expect(find.text('18.0 MB'), findsOneWidget);
      expect(find.text('立即更新'), findsOneWidget);

      await tester.tap(find.text('忽略此版本'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      expect(ignored, isTrue);
      expect(await db.getPreference(kPrefUpdateIgnoredVersion), '1.2.0');
    });

    testWidgets('iOS 弹窗隐藏直装按钮并一键跳转 Release 页面', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      String? openedUrl;
      final service = AppUpdateService(
        db: db,
        httpClient: AppHttpClient(),
        openExternalUrlHandler: (url) async {
          openedUrl = url;
          return true;
        },
      );

      await tester.pumpWidget(wrapApp(Builder(
        builder: (ctx) => ElevatedButton(
          onPressed: () => showAppUpdateDialog(
            ctx,
            release: sampleRelease,
            currentVersion: '1.0.0',
            service: service,
            supportsInAppApkInstall: false,
          ),
          child: const Text('open_ios'),
        ),
      )));

      await tester.tap(find.text('open_ios'));
      await tester.pumpAndSettle();
      expect(find.text('浏览器下载'), findsOneWidget);
      expect(find.text('立即更新'), findsNothing);
      await tester.tap(find.text('浏览器下载'));
      await tester.pumpAndSettle();
      expect(openedUrl, sampleRelease.htmlUrl);
    });
  });
}
