# HANDOFF.md — 阅微项目自包含接手手册

本文档面向新接手的工程师或 AI Agent，提供无需翻阅历史会话即可直接开展开发、测试、构建与排障的完整上下文。

---

## 1. 仓库与环境坐标

| 项目信息 | 具体配置 |
| :--- | :--- |
| **当前工作仓库** | `/Users/yang/Documents/code/vibCoding/yuewei_reader` |
| **远端 Git 地址** | `https://github.com/Kline-x/yuewei-reader`（SSH: `git@github.com:Kline-x/yuewei-reader.git`） |
| **默认主干分支** | `main` |
| **历史隔离说明** | `/Users/yang/Documents/code/vibCoding/novel_reader_flutter` 为历史独立仓库，**严禁在本项目任务中修改或写入** |
| **Flutter 版本** | `3.47.4` (`stable` channel) |
| **Dart SDK 约束** | `^3.13.3` |
| **应用版本** | `1.0.1+2` (`pubspec.yaml`) |
| **Android 标识** | `applicationId = "com.kline.yuewei"`、`namespace = "com.kline.yuewei_reader"`、`JavaVersion.VERSION_17` |
| **iOS 标识** | `CFBundleDisplayName = "阅微"`、`IPHONEOS_DEPLOYMENT_TARGET = 15.0` |

### 核心依赖栈 (`pubspec.yaml`)
- **状态管理与路由**：`flutter_riverpod ^2.6.1`、`go_router ^14.6.2`
- **本地持久化**：`drift ^2.22.1`、`drift_flutter ^0.2.3`、`sqlite3_flutter_libs ^0.5.28`、`shared_preferences ^2.3.3`、`path_provider ^2.1.5`
- **网络与规则解析**：`dio ^5.7.0`、`fast_gbk ^1.0.0`、`html ^0.15.5`、`xpath_selector ^3.0.2`、`xpath_selector_html_parser ^3.0.1`、`json_path ^0.7.6`
- **文件解析与辅助**：`archive ^3.6.1`、`xml ^6.5.0`、`cached_network_image ^3.4.1`、`characters ^1.3.0`、`intl ^0.19.0`、`lpinyin ^2.0.3`

---

## 2. 关键目录地图

```text
lib/
├── main.dart                                  # 应用启动入口、全局主题绑定与内置书源初始化
├── app/
│   ├── providers.dart                         # Riverpod 全局 Provider 注入（DB、HTTP、Repos、TTS 等）
│   └── router.dart                            # GoRouter 路由配置与 RootShell（SublimeFloatingDock 悬浮底栏）
├── core/
│   ├── database/
│   │   ├── tables.dart                        # Books, BookSources, Chapters, Bookmarks 等 8 张 Drift 表
│   │   ├── app_database.dart                  # schemaVersion = 4（yuewei_v2_db），含 v1->v2->v3->v4 平滑迁移与书签/计时索引
│   │   ├── app_database.g.dart                # 唯一允许豁免 350 行红线的 Drift 生成文件
│   │   └── bookmark_dao.dart                  # 书签查询与写入 DAO
│   ├── network/                               # Dio 封装与 GBK/UTF-8 自适应解码
│   ├── platform/host_bridge.dart              # com.kline.yuewei/host_bridge 双端宿主通道封装
│   └── storage/                               # ChapterFileStore 磁盘正文缓存
├── design_system/
│   ├── tokens/                                # SoftTokens / SoftPalette（4 大意境×昼夜 8 套主题）
│   ├── components/                            # AmbientBackground, SublimeFloatingDock, SoftCard, SoftBottomSheet
│   └── feedback/                              # AppFeedback Toast/提示封装
└── features/
    ├── shelf/                                 # 书架数据仓库与网格/列表 UI
    ├── discover/                              # 搜索历史、流式并发搜书与聚合结果展示
    ├── book_detail/                           # 详情自愈 (BookDetailLoader)、目录导航与加入书架
    ├── reader/
    │   ├── engine/                            # 分页排版、5 模式翻页枚举 (PageTurnMode) 与 5 款阅读纸感色板
    │   └── presentation/                      # ReaderPage、翻页视图、连续滚动视图、换源/书签/搜书抽屉
    ├── sources/
    │   ├── domain/                            # BookSourceRule 与 AggregatedBookMatch 模型
    │   ├── engine/                            # RuleEvaluator, LegadoRuleAdapter, SourceCrawlerService
    │   ├── data/                              # builtin_sources*.dart (12 组内置源) 与 SourceRepository
    │   └── presentation/                      # 书源分组管理、并发测速与三合一导入导出
    ├── local_import/
    │   ├── data/                              # LocalImportService (TXT/EPUB 导入持久化)
    │   ├── engine/                            # 编码探测与 TXT/EPUB 章节切分
    │   ├── wifi/                              # WifiTransferServer (默认 18680 端口) 与网页端上传 HTML
    │   └── presentation/                      # 本地导入与 Wi-Fi 传书界面
    ├── download/                              # 离线章节批量缓存管理器
    ├── tts/                                   # TtsController 状态机与 TtsControlSheet 播控面板
    ├── sync/                                  # BackupSnapshotCodec (LWW 合并)、WebdavSyncClient、协调器与同步页
    ├── update/                                # GitHub Releases 在线更新检测、下载校验与弹窗
    └── settings/                              # 外观主题、阅读器设置、检查更新与关于信息

android/app/src/main/
├── AndroidManifest.xml                        # 应用名 "阅微"、INTERNET/REQUEST_INSTALL_PACKAGES 与 FileProvider 声明
├── res/xml/
│   ├── network_security_config.xml            # 明文 HTTP 书源与局域网传书网络策略
│   └── file_paths.xml                         # FileProvider cache/yuewei_updates/ 更新包安全路径声明
└── kotlin/com/kline/yuewei_reader/
    ├── MainActivity.kt                        # FlutterActivity 宿主通道、文件选择器与物理音量键拦截
    ├── NativeTtsAndBackupHelper.kt            # Android TextToSpeech（音频焦点监听）与 SAF JSON 文件导入导出
    └── NativeAppUpdateHelper.kt               # APK SHA-256 校验、未知来源权限引导与系统安装器/外链调起

ios/Runner/
├── Info.plist                                 # 品牌名 "阅微"、ATS、本地网络说明与 UIBackgroundModes (audio)
├── AppDelegate.swift                          # FlutterMethodChannel、UIDocumentPicker、AVSpeechSynthesizer 封装
└── Runner.xcodeproj/project.pbxproj           # IPHONEOS_DEPLOYMENT_TARGET = 15.0
```

---

## 3. 核心入口与路由对照表

### 启动时序 (`lib/main.dart`)
1. 调用 `WidgetsFlutterBinding.ensureInitialized()` 与 `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)`。
2. 并行完成 `SharedPreferences.getInstance()` 与 `HostBridge.instance.initialize()`（向原生端拉取平台信息、版本号及音量键翻页支持能力）。
3. 注入 `ProviderScope` 并挂载 `YueweiApp`；首帧 `initState` 中异步调用 `sourceRepositoryProvider.ensureBuiltinSourcesSeeded()` 将 12 组内置书源幂等写入数据库。

### 路由表 (`lib/app/router.dart`)
- `/shelf` — 书架主页（`RootShell` Branch 0）
- `/discover` — 聚合搜书与探索页（`RootShell` Branch 1）
- `/settings` — 主题与偏好设置页（`RootShell` Branch 2）
- `/sources` — 书源分组、测速与导入管理页
- `/sync` — WebDAV 云同步与本地快照备份页
- `/import` — 本地 TXT/EPUB 导入与 Wi-Fi 传书页
- `/book?id=<bookId>` — 书籍详情与目录页（支持 `extra: AggregatedBookMatch`）
- `/reader/:bookId?chapter=<index>` — 沉浸阅读器页

### 双端原生方法通道 (`com.kline.yuewei/host_bridge`)
- **Dart -> 原生 (`invokeMethod`，11 项)**：`getHostCapabilities`、`setVolumeKeyIntercept`、`keepScreenOn`、`pickLocalBookFile`、`ttsSpeak`、`ttsStop`、`ttsIsAvailable`、`exportTextFile`、`pickAndReadTextFile`、`installApk`、`openExternalUrl`
- **原生 -> Dart (`_handleNativeCall`)**：`onVolumeDown`、`onVolumeUp`、`onTtsDone`、`onTtsError`

---

## 4. 常用门禁、测试与真机运维命令

```bash
# 全量静态分析
flutter analyze

# 全量单元测试（14 个测试文件）
flutter test

# 单独运行关键门禁测试
flutter test test/host_bridge_parity_test.dart
flutter test test/app_update_test.dart
flutter test test/source_engine_test.dart
flutter test test/tts_engine_test.dart
flutter test test/sync_and_source_m3_test.dart

# 非生成文件 <= 350 行红线核验
find lib test -name '*.dart' ! -name '*.g.dart' -print0 | xargs -0 wc -l | sort -n | tail -n 15

# 构建 Android arm64 Release APK 并生成 SHA-256
flutter build apk --release --target-platform android-arm64
sha256sum build/app/outputs/flutter-apk/app-release.apk

# 真机安装、强杀冷启耗时测量与异常日志排查（需连接 ADB）
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell am force-stop com.kline.yuewei
adb shell am start -W com.kline.yuewei/com.kline.yuewei_reader.MainActivity
adb logcat -d -s flutter AndroidRuntime

# iOS 宿主编译语法检查与无签名构建（macOS）
swiftc -parse ios/Runner/AppDelegate.swift
flutter build ios --no-codesign
```
