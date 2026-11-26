import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android / iOS 双端宿主通道与图标配置对等门禁', () {
    test('lib/ 中所有 com.kline.yuewei/ 通道均在 Android 与 iOS 宿主源码对等注册', () {
      final libDir = Directory('lib');
      final channelRegex = RegExp(r'''['"](com\.kline\.yuewei/[^'"]+)['"]''');
      final discoveredChannels = <String>{};

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final content = entity.readAsStringSync();
        for (final m in channelRegex.allMatches(content)) {
          discoveredChannels.add(m.group(1)!);
        }
      }

      expect(discoveredChannels, contains('com.kline.yuewei/host_bridge'));

      final androidKt = File(
        'android/app/src/main/kotlin/com/kline/yuewei_reader/MainActivity.kt',
      );
      final iosSwift = File('ios/Runner/AppDelegate.swift');
      expect(androidKt.existsSync(), isTrue);
      expect(iosSwift.existsSync(), isTrue);

      final ktText = androidKt.readAsStringSync();
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
        'ttsSpeak',
        'ttsStop',
        'ttsIsAvailable',
        'exportTextFile',
        'pickAndReadTextFile',
        'installApk',
        'openExternalUrl',
      ]) {
        expect(ktText, contains(method), reason: 'Android 缺少宿主方法 $method');
        expect(swiftText, contains(method), reason: 'iOS 缺少宿主方法 $method');
      }
    });

    test('双端品牌名、图标集、在线更新与原生加固配置严格完整且无历史残留', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      final filePathsXml =
          File('android/app/src/main/res/xml/file_paths.xml');
      final updateHelperKt = File(
        'android/app/src/main/kotlin/com/kline/yuewei_reader/NativeAppUpdateHelper.kt',
      );
      final ttsHelperKt = File(
        'android/app/src/main/kotlin/com/kline/yuewei_reader/NativeTtsAndBackupHelper.kt',
      ).readAsStringSync();
      final swiftText =
          File('ios/Runner/AppDelegate.swift').readAsStringSync();
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      final buildGradle =
          File('android/app/build.gradle.kts').readAsStringSync();

      expect(buildGradle, contains('applicationId = "com.kline.yuewei"'));
      expect(buildGradle, contains('key.properties'));
      expect(buildGradle, contains('YUEWEI_KEYSTORE_PATH'));
      expect(buildGradle, contains('create("release")'));

      expect(manifest, contains('android:label="阅微"'));
      expect(
        manifest,
        contains('android.permission.REQUEST_INSTALL_PACKAGES'),
        reason: 'Android Manifest 缺少应用内安装 APK 权限声明',
      );
      expect(
        manifest,
        contains('androidx.core.content.FileProvider'),
        reason: 'Android Manifest 缺少 FileProvider 声明',
      );
      expect(
        manifest,
        contains(r'${applicationId}.fileprovider'),
        reason: 'Android FileProvider authorities 必须使用 applicationId.fileprovider',
      );
      expect(filePathsXml.existsSync(), isTrue);
      expect(filePathsXml.readAsStringSync(), contains('yuewei_updates/'));

      expect(updateHelperKt.existsSync(), isTrue);
      final updateKtText = updateHelperKt.readAsStringSync();
      expect(updateKtText, contains('SHA-256'));
      expect(updateKtText, contains('ACTION_MANAGE_UNKNOWN_APP_SOURCES'));
      expect(updateKtText, contains('NEED_INSTALL_PERMISSION'));
      expect(updateKtText, contains('HASH_MISMATCH'));
      expect(updateKtText, contains('STARTED'));

      expect(ttsHelperKt, contains('isHighSurrogate'));
      expect(ttsHelperKt, contains('override fun onStop'));
      expect(ttsHelperKt, contains('AUDIOFOCUS_LOSS'));

      expect(plist, contains('<string>阅微</string>'));
      expect(
        plist,
        contains('<key>UIBackgroundModes</key>'),
        reason: 'iOS Info.plist 缺少后台音频能力声明',
      );
      expect(
        plist,
        contains('<string>audio</string>'),
        reason: 'iOS Info.plist 缺少 UIBackgroundModes audio 项',
      );
      expect(
        swiftText.contains('readData(ofLength:'),
        isFalse,
        reason: 'iOS AppDelegate 严禁继续使用废弃的 readData(ofLength:)',
      );
      expect(swiftText, contains('read(upToCount:'));
      expect(swiftText, contains('interruptionNotification'));
      expect(swiftText, contains('isBeingDismissed'));
      expect(swiftText, contains('UNSUPPORTED'));
      expect(
        plist,
        contains('NSLocalNetworkUsageDescription'),
        reason: 'iOS Info.plist 缺少局域网 Wi-Fi 传书权限用途说明',
      );
      expect(
        plist.contains('UISupportsDocumentBrowser'),
        isFalse,
        reason: 'iOS Info.plist 不应残留 UISupportsDocumentBrowser',
      );

      for (final dpi in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
        expect(
          File('android/app/src/main/res/mipmap-$dpi/ic_launcher.png')
              .existsSync(),
          isTrue,
          reason: '缺少 Android mipmap-$dpi 启动图标',
        );
      }
      final iosIconsDir = Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset');
      expect(iosIconsDir.existsSync(), isTrue);
      final pngCount = iosIconsDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.png'))
          .length;
      expect(pngCount, greaterThanOrEqualTo(10));

      // 验证彻底裁切旧鸿蒙 / Desktop / Web 冗余目录
      expect(Directory('ohos').existsSync(), isFalse);
      expect(Directory('web').existsSync(), isFalse);
      expect(Directory('macos').existsSync(), isFalse);
      expect(Directory('windows').existsSync(), isFalse);
      expect(Directory('linux').existsSync(), isFalse);
    });
  });
}
