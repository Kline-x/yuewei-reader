import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuewei_reader/core/platform/host_bridge.dart';

const _hostChannel = MethodChannel('com.kline.yuewei/host_bridge');

Future<Object?> _simulateNativeCall(
  String method,
  Map<String, dynamic> args,
) async {
  const codec = StandardMethodCodec();
  final data = codec.encodeMethodCall(MethodCall(method, args));
  Object? decoded;
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(_hostChannel.name, data, (reply) {
    if (reply != null) decoded = codec.decodeEnvelope(reply);
  });
  return decoded;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Android / iOS 双端宿主通道与图标配置对等门禁', () {
    test('lib/ 中所有 com.kline.yuewei/ 通道均在 Android 与 iOS 宿主源码对等注册', () {
      final channelRegex = RegExp(r'''['"](com\.kline\.yuewei/[^'"]+)['"]''');
      final discoveredChannels = <String>{};
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final content = entity.readAsStringSync();
        for (final m in channelRegex.allMatches(content)) {
          discoveredChannels.add(m.group(1)!);
        }
      }
      expect(discoveredChannels, contains('com.kline.yuewei/host_bridge'));

      final hostBridgeText =
          File('lib/core/platform/host_bridge.dart').readAsStringSync();
      final modelsFile = File('lib/core/platform/host_bridge_models.dart');
      expect(modelsFile.existsSync(), isTrue);
      expect(hostBridgeText, contains("export 'host_bridge_models.dart';"));
      expect(modelsFile.readAsStringSync(), contains('enum MediaCommandAction'));

      final androidKt = File(
        'android/app/src/main/kotlin/com/kline/yuewei_reader/MainActivity.kt',
      );
      final ttsServiceKt = File(
        'android/app/src/main/kotlin/com/kline/yuewei_reader/TtsForegroundService.kt',
      );
      final iosSwift = File('ios/Runner/AppDelegate.swift');
      expect(androidKt.existsSync(), isTrue);
      expect(ttsServiceKt.existsSync(), isTrue);
      expect(iosSwift.existsSync(), isTrue);

      final ktText = androidKt.readAsStringSync();
      final serviceText = ttsServiceKt.readAsStringSync();
      final swiftText = iosSwift.readAsStringSync();

      for (final ch in discoveredChannels) {
        expect(ktText, contains(ch), reason: 'Android MainActivity 未实现通道 $ch');
        expect(swiftText, contains(ch), reason: 'iOS AppDelegate 未实现通道 $ch');
      }

      for (final method in [
        'getHostCapabilities',
        'setVolumeKeyIntercept',
        'keepScreenOn',
        'pickLocalBookFile',
        'pickFontFile',
        'ttsSpeak',
        'ttsStop',
        'ttsIsAvailable',
        'updateMediaSession',
        'clearMediaSession',
        'exportTextFile',
        'pickAndReadTextFile',
        'installApk',
        'openExternalUrl',
      ]) {
        expect(ktText, contains(method), reason: 'Android 缺少宿主方法 $method');
        expect(swiftText, contains(method), reason: 'iOS 缺少宿主方法 $method');
      }

      expect(ktText, contains('onMediaCommand'));
      expect(swiftText, contains('onMediaCommand'));
      expect(ktText, contains('picked_fonts'));
      expect(serviceText, contains('MediaSession'));
    });

    test('双端品牌名、图标集、在线更新、系统媒控与原生加固配置严格完整且无历史残留', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      final filePathsXml = File('android/app/src/main/res/xml/file_paths.xml');
      final updateHelperKt = File(
        'android/app/src/main/kotlin/com/kline/yuewei_reader/NativeAppUpdateHelper.kt',
      );
      final ttsHelperKt = File(
        'android/app/src/main/kotlin/com/kline/yuewei_reader/NativeTtsAndBackupHelper.kt',
      ).readAsStringSync();
      final serviceKt = File(
        'android/app/src/main/kotlin/com/kline/yuewei_reader/TtsForegroundService.kt',
      ).readAsStringSync();
      final swiftText = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      final buildGradle = File('android/app/build.gradle.kts').readAsStringSync();

      for (final token in [
        'applicationId = "com.kline.yuewei"',
        'key.properties',
        'YUEWEI_KEYSTORE_PATH',
        'create("release")',
      ]) {
        expect(buildGradle, contains(token));
      }

      for (final token in [
        'android:label="阅微"',
        'android.permission.REQUEST_INSTALL_PACKAGES',
        'android.permission.FOREGROUND_SERVICE',
        'android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK',
        'android.permission.POST_NOTIFICATIONS',
        '.TtsForegroundService',
        'android:foregroundServiceType="mediaPlayback"',
        'androidx.core.content.FileProvider',
        r'${applicationId}.fileprovider',
      ]) {
        expect(manifest, contains(token), reason: 'AndroidManifest 缺少 $token');
      }
      expect(filePathsXml.existsSync(), isTrue);
      expect(filePathsXml.readAsStringSync(), contains('yuewei_updates/'));

      expect(updateHelperKt.existsSync(), isTrue);
      final updateKtText = updateHelperKt.readAsStringSync();
      for (final token in [
        'SHA-256',
        'ACTION_MANAGE_UNKNOWN_APP_SOURCES',
        'NEED_INSTALL_PERMISSION',
        'HASH_MISMATCH',
        'STARTED',
      ]) {
        expect(updateKtText, contains(token));
      }

      for (final token in ['isHighSurrogate', 'override fun onStop', 'AUDIOFOCUS_LOSS']) {
        expect(ttsHelperKt, contains(token));
      }

      for (final token in [
        'yuewei_tts_playback',
        'Notification.MediaStyle',
        'FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK',
        'STOP_FOREGROUND_REMOVE',
      ]) {
        expect(serviceKt, contains(token));
      }

      for (final token in [
        '<string>阅微</string>',
        '<key>UIBackgroundModes</key>',
        '<string>audio</string>',
        'NSLocalNetworkUsageDescription',
      ]) {
        expect(plist, contains(token), reason: 'iOS Info.plist 缺少 $token');
      }
      expect(plist.contains('UISupportsDocumentBrowser'), isFalse);

      expect(swiftText.contains('readData(ofLength:'), isFalse);
      for (final token in [
        'import MediaPlayer',
        '// MARK: - Media Control',
        'MPNowPlayingInfoCenter',
        'MPRemoteCommandCenter',
        'picked_fonts',
        'public.truetype-ttf-font',
        'public.opentype-font',
        'read(upToCount:',
        'interruptionNotification',
        'isBeingDismissed',
        'UNSUPPORTED',
      ]) {
        expect(swiftText, contains(token), reason: 'iOS AppDelegate 缺少 $token');
      }

      for (final dpi in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
        expect(
          File('android/app/src/main/res/mipmap-$dpi/ic_launcher.png').existsSync(),
          isTrue,
          reason: '缺少 Android mipmap-$dpi 启动图标',
        );
      }
      final iosIconsDir =
          Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset');
      expect(iosIconsDir.existsSync(), isTrue);
      final pngCount = iosIconsDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.png'))
          .length;
      expect(pngCount, greaterThanOrEqualTo(10));

      for (final legacy in ['ohos', 'web', 'macos', 'windows', 'linux']) {
        expect(Directory(legacy).existsSync(), isFalse);
      }
    });
  });

  group('HostBridge 媒控会话、事件流与字体选择器单元测试', () {
    final calls = <MethodCall>[];
    var throwPlatformError = false;
    Map<String, dynamic>? mockFontPayload;

    setUp(() {
      calls.clear();
      throwPlatformError = false;
      mockFontPayload = {
        'path': '/tmp/picked_fonts/LXGWWenKai.ttf',
        'name': 'LXGWWenKai.ttf',
        'size': 204800,
      };
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_hostChannel, (call) async {
        calls.add(call);
        if (throwPlatformError) {
          throw PlatformException(code: 'TEST_ERR', message: '模拟宿主异常');
        }
        return switch (call.method) {
          'updateMediaSession' || 'clearMediaSession' => true,
          'pickFontFile' => mockFontPayload,
          _ => null,
        };
      });
    });

    tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_hostChannel, null));

    test('mediaCommandStream 正确解析全部媒控指令并忽略未知动作', () async {
      final received = <MediaCommandAction>[];
      final sub = HostBridge.instance.mediaCommandStream.listen(received.add);
      addTearDown(sub.cancel);

      for (final wire in ['play', 'pause', 'toggle', 'next', 'prev', 'stop']) {
        expect(await _simulateNativeCall('onMediaCommand', {'action': wire}), isTrue);
      }
      expect(await _simulateNativeCall('onMediaCommand', {'action': 'unknown'}), isFalse);
      await Future<void>.delayed(Duration.zero);

      expect(received, [
        MediaCommandAction.play,
        MediaCommandAction.pause,
        MediaCommandAction.toggle,
        MediaCommandAction.next,
        MediaCommandAction.prev,
        MediaCommandAction.stop,
      ]);
    });

    test('updateMediaSession / clearMediaSession / pickFontFile 透传与异常回落', () async {
      expect(
        await HostBridge.instance.updateMediaSession(
          bookTitle: '凡人修仙传',
          author: '忘语',
          chapterTitle: '第一章 七玄门',
          isPlaying: true,
          canPrev: false,
          canNext: true,
        ),
        isTrue,
      );
      expect(calls.last.method, 'updateMediaSession');
      expect(calls.last.arguments, {
        'bookTitle': '凡人修仙传',
        'author': '忘语',
        'chapterTitle': '第一章 七玄门',
        'isPlaying': true,
        'canPrev': false,
        'canNext': true,
      });

      expect(await HostBridge.instance.clearMediaSession(), isTrue);
      expect(calls.last.method, 'clearMediaSession');

      final picked = await HostBridge.instance.pickFontFile();
      expect(picked?.path, '/tmp/picked_fonts/LXGWWenKai.ttf');
      expect(picked?.name, 'LXGWWenKai.ttf');
      expect(picked?.size, 204800);

      mockFontPayload = null;
      expect(await HostBridge.instance.pickFontFile(), isNull);

      throwPlatformError = true;
      expect(
        await HostBridge.instance.updateMediaSession(
          bookTitle: '书名',
          author: '作者',
          chapterTitle: '章节',
          isPlaying: false,
          canPrev: true,
          canNext: false,
        ),
        isFalse,
      );
      expect(await HostBridge.instance.clearMediaSession(), isFalse);
      expect(await HostBridge.instance.pickFontFile(), isNull);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_hostChannel, null);
      expect(
        await HostBridge.instance.updateMediaSession(
          bookTitle: '书名',
          author: '作者',
          chapterTitle: '章节',
          isPlaying: false,
          canPrev: false,
          canNext: false,
        ),
        isFalse,
      );
      expect(await HostBridge.instance.clearMediaSession(), isFalse);
      expect(await HostBridge.instance.pickFontFile(), isNull);
    });
  });
}
