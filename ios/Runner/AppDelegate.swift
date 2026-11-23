import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let channelName = "com.kline.yuewei/host_bridge"
  private var hostChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    hostChannel = channel

    channel.setMethodCallHandler { [weak self] call, result in
      guard self != nil else {
        result(FlutterError(code: "DEALLOCATED", message: "AppDelegate unavailable", details: nil))
        return
      }
      switch call.method {
      case "getHostCapabilities":
        let info = Bundle.main.infoDictionary
        let versionName = (info?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
        let versionCodeStr = (info?["CFBundleVersion"] as? String) ?? "1"
        let versionCode = Int(versionCodeStr) ?? 1
        result([
          "platform": "ios",
          "supportsVolumeKeyPaging": false,
          "versionName": versionName,
          "versionCode": versionCode,
        ])

      case "setVolumeKeyIntercept":
        // iOS 系统级不允许拦截硬件音量键翻页，安全归还 true 避免上层挂起
        result(true)

      case "keepScreenOn":
        let args = call.arguments as? [String: Any]
        let enabled = (args?["enabled"] as? Bool) ?? false
        DispatchQueue.main.async {
          UIApplication.shared.isIdleTimerDisabled = enabled
        }
        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
