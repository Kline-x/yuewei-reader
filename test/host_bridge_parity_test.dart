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
      ]) {
        expect(ktText, contains(method), reason: 'Android 缺少宿主方法 $method');
        expect(swiftText, contains(method), reason: 'iOS 缺少宿主方法 $method');
      }
    });

    test('双端品牌名、图标集及裁切红线配置严格完整且无历史残留', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      final buildGradle =
          File('android/app/build.gradle.kts').readAsStringSync();

      expect(buildGradle, contains('applicationId = "com.kline.yuewei"'));
      expect(manifest, contains('android:label="阅微"'));
      expect(plist, contains('<string>阅微</string>'));
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
