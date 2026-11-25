import AVFoundation
import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate,
  UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate
{
  fileprivate enum PickerOperation {
    case pickLocalBook
    case exportTextFile(tempURL: URL, fallbackName: String)
    case pickTextFile
  }

  private let channelName = "com.kline.yuewei/host_bridge"
  fileprivate static let maxTextFileBytes: Int = 30 * 1024 * 1024

  fileprivate var hostChannel: FlutterMethodChannel?
  fileprivate var pendingBookPickerResult: FlutterResult?
  fileprivate var pendingExportPickerResult: FlutterResult?
  fileprivate var pendingTextPickerResult: FlutterResult?
  fileprivate weak var activePickerController: UIDocumentPickerViewController?
  fileprivate var activePickerOperation: PickerOperation?

  fileprivate lazy var speechSynthesizer: AVSpeechSynthesizer = {
    let synthesizer = AVSpeechSynthesizer()
    synthesizer.delegate = self
    return synthesizer
  }()
  fileprivate var activeUtterance: AVSpeechUtterance?
  fileprivate var activeUtteranceId: String?

  fileprivate var isAnyPickerBusy: Bool {
    return pendingBookPickerResult != nil
      || pendingExportPickerResult != nil
      || pendingTextPickerResult != nil
  }

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
      guard let self = self else {
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
        self.presentBookPicker(result: result)

      case "ttsSpeak":
        self.handleTtsSpeak(call: call, result: result)

      case "ttsStop":
        self.handleTtsStop(result: result)

      case "ttsIsAvailable":
        result(true)

      case "exportTextFile":
        self.presentExportTextPicker(call: call, result: result)

      case "pickAndReadTextFile":
        self.presentPickTextPicker(result: result)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  fileprivate func topViewController() -> UIViewController? {
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

  private func presentBookPicker(result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        result(FlutterError(code: "DEALLOCATED", message: "AppDelegate unavailable", details: nil))
        return
      }
      if self.isAnyPickerBusy {
        result(FlutterError(code: "PICKER_BUSY", message: "已有文件选择请求正在进行", details: nil))
        return
      }
      guard let presenter = self.topViewController() else {
        result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "未找到可用界面上下文", details: nil))
        return
      }
      self.pendingBookPickerResult = result
      self.activePickerOperation = .pickLocalBook

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
      self.activePickerController = picker
      presenter.present(picker, animated: true)
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    guard let active = activePickerController, controller === active else {
      return
    }
    finishCancelledPicker()
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    guard let active = activePickerController,
      presentationController.presentedViewController === active
    else {
      return
    }
    finishCancelledPicker()
  }

  private func finishCancelledPicker() {
    let op = activePickerOperation
    activePickerOperation = nil
    activePickerController = nil

    if case .exportTextFile(let tempURL, _) = op {
      try? FileManager.default.removeItem(at: tempURL.deletingLastPathComponent())
    }

    if let pending = pendingBookPickerResult {
      pendingBookPickerResult = nil
      pending(nil)
    }
    if let pending = pendingExportPickerResult {
      pendingExportPickerResult = nil
      pending(nil)
    }
    if let pending = pendingTextPickerResult {
      pendingTextPickerResult = nil
      pending(nil)
    }
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    guard let active = activePickerController, controller === active else {
      return
    }
    let op = activePickerOperation
    activePickerOperation = nil
    activePickerController = nil

    switch op {
    case .pickLocalBook:
      let pending = pendingBookPickerResult
      pendingBookPickerResult = nil
      guard let pending = pending else { return }
      handlePickedLocalBook(urls: urls, pending: pending)

    case .exportTextFile(let tempURL, let fallbackName):
      let pending = pendingExportPickerResult
      pendingExportPickerResult = nil
      try? FileManager.default.removeItem(at: tempURL.deletingLastPathComponent())
      guard let pending = pending else { return }
      let exportedName = urls.first?.lastPathComponent
        .trimmingCharacters(in: .whitespacesAndNewlines)
      if let name = exportedName, !name.isEmpty {
        pending(name)
      } else {
        pending(fallbackName)
      }

    case .pickTextFile:
      let pending = pendingTextPickerResult
      pendingTextPickerResult = nil
      guard let pending = pending else { return }
      handlePickedTextFile(urls: urls, pending: pending)

    case .none:
      break
    }
  }

  private func handlePickedLocalBook(urls: [URL], pending: @escaping FlutterResult) {
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
        let safeName = AppDelegate.sanitizePickedFileName(displayName, fallback: "book.txt")
        let stamp = Int64(Date().timeIntervalSince1970 * 1000)
        let destURL = targetDir.appendingPathComponent("\(stamp)_\(safeName)")

        guard
          destURL.standardizedFileURL.deletingLastPathComponent() == targetDir.standardizedFileURL
        else {
          throw NSError(
            domain: "YueweiPicker",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "非法目标文件路径"]
          )
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
          pending(
            FlutterError(code: "COPY_FAILED", message: error.localizedDescription, details: nil)
          )
        }
      }
    }
  }

  fileprivate static func sanitizePickedFileName(_ rawName: String, fallback: String) -> String {
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
    return cleaned.isEmpty ? fallback : cleaned
  }
}

// MARK: - 原生 TTS 语音合成与备份文件读写扩展
extension AppDelegate: AVSpeechSynthesizerDelegate {
  fileprivate func handleTtsSpeak(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let text = (args?["text"] as? String) ?? ""
    let utteranceId = (args?["utteranceId"] as? String) ?? ""
    let rateFactor = (args?["rate"] as? NSNumber)?.floatValue ?? 1.0

    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || utteranceId.isEmpty {
      result(false)
      return
    }

    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        result(false)
        return
      }
      // 先清空当前活跃标记再停止上一句，防止 didCancel / 延迟回调误触发
      self.activeUtterance = nil
      self.activeUtteranceId = nil
      if self.speechSynthesizer.isSpeaking || self.speechSynthesizer.isPaused {
        self.speechSynthesizer.stopSpeaking(at: .immediate)
      }

      let audioSession = AVAudioSession.sharedInstance()
      try? audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
      try? audioSession.setActive(true)

      let utterance = AVSpeechUtterance(string: text)
      utterance.voice =
        AVSpeechSynthesisVoice(language: "zh-CN")
        ?? AVSpeechSynthesisVoice(language: "zh-Hans")
        ?? AVSpeechSynthesisVoice(language: "zh-TW")

      let scaledRate = AVSpeechUtteranceDefaultSpeechRate * rateFactor
      utterance.rate = min(
        max(scaledRate, AVSpeechUtteranceMinimumSpeechRate),
        AVSpeechUtteranceMaximumSpeechRate
      )

      self.activeUtterance = utterance
      self.activeUtteranceId = utteranceId
      self.speechSynthesizer.speak(utterance)
      result(true)
    }
  }

  override func applicationWillTerminate(_ application: UIApplication) {
    activeUtterance = nil
    activeUtteranceId = nil
    if speechSynthesizer.isSpeaking || speechSynthesizer.isPaused {
      speechSynthesizer.stopSpeaking(at: .immediate)
    }
    try? AVAudioSession.sharedInstance().setActive(
      false,
      options: [.notifyOthersOnDeactivation]
    )
    super.applicationWillTerminate(application)
  }

  fileprivate func handleTtsStop(result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        result(false)
        return
      }
      self.activeUtterance = nil
      self.activeUtteranceId = nil
      if self.speechSynthesizer.isSpeaking || self.speechSynthesizer.isPaused {
        self.speechSynthesizer.stopSpeaking(at: .immediate)
      }
      try? AVAudioSession.sharedInstance().setActive(
        false,
        options: [.notifyOthersOnDeactivation]
      )
      result(true)
    }
  }

  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didFinish utterance: AVSpeechUtterance
  ) {
    DispatchQueue.main.async { [weak self] in
      guard
        let self = self,
        let current = self.activeUtterance,
        utterance === current,
        let utteranceId = self.activeUtteranceId
      else {
        return
      }
      self.activeUtterance = nil
      self.activeUtteranceId = nil
      self.hostChannel?.invokeMethod("onTtsDone", arguments: ["utteranceId": utteranceId])
    }
  }

  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didCancel utterance: AVSpeechUtterance
  ) {
    // 主动取消或切句不回调 onTtsDone，防止误推进下一段
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      if let current = self.activeUtterance, utterance === current {
        self.activeUtterance = nil
        self.activeUtteranceId = nil
      }
    }
  }

  fileprivate func presentExportTextPicker(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    let args = call.arguments as? [String: Any]
    let rawFileName = (args?["fileName"] as? String) ?? "yuewei_backup.json"
    let content = (args?["content"] as? String) ?? ""
    let safeName = AppDelegate.sanitizePickedFileName(rawFileName, fallback: "yuewei_backup.json")

    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        result(FlutterError(code: "DEALLOCATED", message: "AppDelegate unavailable", details: nil))
        return
      }
      if self.isAnyPickerBusy {
        result(FlutterError(code: "PICKER_BUSY", message: "已有文件选择请求正在进行", details: nil))
        return
      }
      guard let presenter = self.topViewController() else {
        result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "未找到可用界面上下文", details: nil))
        return
      }

      do {
        let stagingDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
          .appendingPathComponent("export_staging", isDirectory: true)
          .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        let tempURL = stagingDir.appendingPathComponent(safeName)
        if FileManager.default.fileExists(atPath: tempURL.path) {
          try FileManager.default.removeItem(at: tempURL)
        }
        try content.write(to: tempURL, atomically: true, encoding: .utf8)

        let picker: UIDocumentPickerViewController
        if #available(iOS 14.0, *) {
          picker = UIDocumentPickerViewController(forExporting: [tempURL], asCopy: true)
        } else {
          picker = UIDocumentPickerViewController(url: tempURL, in: .exportToService)
        }
        picker.delegate = self
        picker.allowsMultipleSelection = false
        picker.presentationController?.delegate = self

        self.pendingExportPickerResult = result
        self.activePickerController = picker
        self.activePickerOperation = .exportTextFile(tempURL: tempURL, fallbackName: safeName)
        presenter.present(picker, animated: true)
      } catch {
        result(
          FlutterError(code: "EXPORT_PREPARE_FAILED", message: error.localizedDescription, details: nil)
        )
      }
    }
  }

  fileprivate func presentPickTextPicker(result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        result(FlutterError(code: "DEALLOCATED", message: "AppDelegate unavailable", details: nil))
        return
      }
      if self.isAnyPickerBusy {
        result(FlutterError(code: "PICKER_BUSY", message: "已有文件选择请求正在进行", details: nil))
        return
      }
      guard let presenter = self.topViewController() else {
        result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "未找到可用界面上下文", details: nil))
        return
      }

      let picker: UIDocumentPickerViewController
      if #available(iOS 14.0, *) {
        picker = UIDocumentPickerViewController(
          forOpeningContentTypes: [.json, .plainText, .data],
          asCopy: true
        )
      } else {
        picker = UIDocumentPickerViewController(
          documentTypes: ["public.json", "public.plain-text", "public.text", "public.data"],
          in: .import
        )
      }
      picker.delegate = self
      picker.allowsMultipleSelection = false
      picker.presentationController?.delegate = self

      self.pendingTextPickerResult = result
      self.activePickerController = picker
      self.activePickerOperation = .pickTextFile
      presenter.present(picker, animated: true)
    }
  }

  fileprivate func handlePickedTextFile(urls: [URL], pending: @escaping FlutterResult) {
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
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        if let fileSize = (attrs[.size] as? NSNumber)?.intValue,
          fileSize > AppDelegate.maxTextFileBytes
        {
          throw NSError(
            domain: "YueweiPicker",
            code: -2,
            userInfo: [NSLocalizedDescriptionKey: "文件体积超过 30MB 安全上限"]
          )
        }
        // 流式分块读取并实时校验大小上限，避免云盘占位文件或未上报 size 触发 OOM
        let handle = try FileHandle(forReadingFrom: url)
        defer {
          try? handle.close()
        }
        var data = Data()
        while true {
          let chunk = handle.readData(ofLength: 64 * 1024)
          if chunk.isEmpty {
            break
          }
          if data.count + chunk.count > AppDelegate.maxTextFileBytes {
            throw NSError(
              domain: "YueweiPicker",
              code: -2,
              userInfo: [NSLocalizedDescriptionKey: "文件体积超过 30MB 安全上限"]
            )
          }
          data.append(chunk)
        }
        guard var text = String(data: data, encoding: .utf8) else {
          throw NSError(
            domain: "YueweiPicker",
            code: -3,
            userInfo: [NSLocalizedDescriptionKey: "文件非有效 UTF-8 文本格式"]
          )
        }
        if text.hasPrefix("\u{FEFF}") {
          text.removeFirst()
        }
        let rawName = url.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = rawName.isEmpty ? "imported.json" : rawName
        let payload: [String: Any] = [
          "name": displayName,
          "content": text,
        ]
        DispatchQueue.main.async {
          pending(payload)
        }
      } catch {
        DispatchQueue.main.async {
          pending(
            FlutterError(code: "READ_FAILED", message: error.localizedDescription, details: nil)
          )
        }
      }
    }
  }
}
