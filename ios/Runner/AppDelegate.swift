import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate,
  UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate
{
  private let channelName = "com.kline.yuewei/host_bridge"
  private var hostChannel: FlutterMethodChannel?
  private var pendingPickerResult: FlutterResult?

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

      case "pickLocalBookFile":
        self?.presentBookPicker(result: result)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func presentBookPicker(result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        result(FlutterError(code: "DEALLOCATED", message: "AppDelegate unavailable", details: nil))
        return
      }
      if self.pendingPickerResult != nil {
        result(FlutterError(code: "PICKER_BUSY", message: "已有文件选择请求正在进行", details: nil))
        return
      }
      guard let presenter = self.topViewController() else {
        result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "未找到可用界面上下文", details: nil))
        return
      }
      self.pendingPickerResult = result

      let picker: UIDocumentPickerViewController
      if #available(iOS 14.0, *) {
        var types: [UTType] = [.plainText, .text]
        if let epubType = UTType(filenameExtension: "epub") ?? UTType("org.idpf.epub-container") {
          types.append(epubType)
        }
        types.append(.data)
        picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
      } else {
        let legacyTypes = [
          "public.plain-text",
          "public.text",
          "org.idpf.epub-container",
          "com.pkware.zip-archive",
          "public.data",
        ]
        picker = UIDocumentPickerViewController(documentTypes: legacyTypes, in: .import)
      }
      picker.delegate = self
      picker.allowsMultipleSelection = false
      picker.presentationController?.delegate = self
      presenter.present(picker, animated: true)
    }
  }

  private func topViewController() -> UIViewController? {
    let sceneWindow = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    let rootWindow = sceneWindow ?? self.window
    var top = rootWindow?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    let pending = pendingPickerResult
    pendingPickerResult = nil
    pending?(nil)
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    let pending = pendingPickerResult
    pendingPickerResult = nil
    pending?(nil)
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    let pending = pendingPickerResult
    pendingPickerResult = nil
    guard let pending = pending else { return }
    guard let url = urls.first else {
      pending(nil)
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      let scoped = url.startAccessingSecurityScopedResource()
      defer {
        if scoped {
          url.stopAccessingSecurityScopedResource()
        }
      }
      do {
        let targetDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
          .appendingPathComponent("picked_books", isDirectory: true)
        try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)

        let rawName = url.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = rawName.isEmpty ? "book.txt" : rawName
        let safeName = AppDelegate.sanitizePickedFileName(displayName)
        let stamp = Int64(Date().timeIntervalSince1970 * 1000)
        let destURL = targetDir.appendingPathComponent("\(stamp)_\(safeName)")

        guard destURL.standardizedFileURL.deletingLastPathComponent() == targetDir.standardizedFileURL else {
          throw NSError(domain: "YueweiPicker", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "非法目标文件路径",
          ])
        }
        if FileManager.default.fileExists(atPath: destURL.path) {
          try FileManager.default.removeItem(at: destURL)
        }
        try FileManager.default.copyItem(at: url, to: destURL)

        let attrs = try FileManager.default.attributesOfItem(atPath: destURL.path)
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        let payload: [String: Any] = [
          "path": destURL.path,
          "name": displayName,
          "size": size,
        ]
        DispatchQueue.main.async {
          pending(payload)
        }
      } catch {
        DispatchQueue.main.async {
          pending(FlutterError(code: "COPY_FAILED", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private static func sanitizePickedFileName(_ rawName: String) -> String {
    let base = (rawName as NSString).lastPathComponent
    let cleaned = base.replacingOccurrences(
      of: "[^a-zA-Z0-9._\\-\\u4E00-\\u9FFF]",
      with: "_",
      options: .regularExpression
    ).replacingOccurrences(
      of: "^\\.+",
      with: "",
      options: .regularExpression
    )
    return cleaned.isEmpty ? "book.txt" : cleaned
  }
}
