# 阅微（Yuewei）

> 现代静谧纸感追更阅读器 · Modern Soft UI v4 · Flutter + Drift

阅微是一款聚焦沉浸阅读体验与跨端原生能力的纯本地优先小说阅读器，基于 **Flutter 3.47.4 (Dart ^3.13.3)** 与 **Drift SQLite** 构建，支持 Android（Java 17 / Kotlin）与 iOS（Swift / iOS 15.0+）双端原生宿主能力。

---

## 核心特性矩阵

| 模块 | 核心能力与技术实现 |
| :--- | :--- |
| **Modern Soft UI v4** | 4 大静谧意境（苍岚烟雨 `mistyJade`、暮色暖珀 `twilightAmber`、紫陌幽兰 `violetOrchid`、极夜星芒 `auroraInk`）× 昼/夜 **8 套主题**；搭配 `AmbientBackground` 柔光画布与 `SublimeFloatingDock` 悬浮底栏 |
| **护眼纸感阅读器** | 5 款经 WCAG 对比度校验的纸感阅读色板（瓷白、暖羊皮、苍翠、暮岩夜、OLED 纯墨）；支持紧凑 / 舒适 / 宽松三档行距、字号调节与屏幕常亮 |
| **QQ 阅读级 5 模式翻页** | 原生自研分页与动画引擎，支持 **仿真 (`curl`) / 覆盖 (`cover`) / 平移 (`slide`) / 上下 (`scroll`) / 无动画 (`none`)** 五种翻页模式 |
| **12 组实测书源与换源** | 预置 12 组全链路实网 `200 OK` 书源（精品主力 / 经典备选 / 精选扩充），支持流式并发搜书聚合、详情页元数据污损自愈清洗、并发探活无感换源及自动清理旧章缓存 |
| **Legado 规则兼容管理** | 兼容 CSS 选择器、`:contains`、`.0` 索引切片、`@xpath:`、`$.` JSONPath 与 `utf-8`/`gbk` 解码；支持远程 URL、剪贴板粘贴、本地文件三合一导入导出与分组/健康分管理 |
| **本地阅读与 Wi-Fi 传书** | 原生文件选择器导入本地 `.txt` / `.epub`（自动字符集探测与章节切分）；内置 `18680` 端口局域网轻量 HTTP 服务，浏览器扫码/访问即可无线推送书籍与 `.json` 书源 |
| **双端原生 TTS 听书** | 基于 Android `TextToSpeech` 与 iOS `AVSpeechSynthesizer` 实现段级推进与跨章续播，支持 `0.75x ~ 1.75x` 五档倍速持久化、睡眠定时（15/30/60 分/播完本章）；听书期间自动释放物理音量键交还系统调音 |
| **书签与书内全文搜索** | 基于 Drift `schemaVersion = 3` 关系型存储支持书签管理与已缓存/本地章节全文检索 |
| **WebDAV 云同步与快照** | 支持 WebDAV 远端同步（`PROPFIND` / `MKCOL` / `PUT` / `GET`）与本地 JSON 快照导入导出，内置无损 **LWW (Last-Write-Wins)** 合并策略，防止较新阅读进度被旧备份覆盖 |

---

## Clean Architecture 分层结构

```text
yuewei_reader/
├── .github/workflows/ci.yml        # GitHub Actions 自动化门禁、Android/iOS 构建与 Tag Release
├── lib/
│   ├── main.dart                   # 应用入口：edgeToEdge、SharedPreferences、HostBridge 初始化与内置书源播种
│   ├── app/                        # 应用装配层：GoRouter 路由表 (router.dart) 与 Riverpod 全局依赖 (providers.dart)
│   ├── core/                       # 核心基础设施层
│   │   ├── database/               # Drift v3 数据库 (app_database.dart, tables.dart, bookmark_dao.dart)
│   │   ├── network/                # Dio 网络客户端与 GBK/UTF-8 编码自适应 (app_http_client.dart)
│   │   ├── platform/               # 双端统一 MethodChannel 桥梁 (host_bridge.dart)
│   │   └── storage/                # 本地章节正文磁盘缓存 (chapter_file_store.dart)
│   ├── design_system/              # Modern Soft UI v4 设计系统
│   │   ├── tokens/                 # 语义色板、间距、排版令牌 (soft_tokens.dart, soft_palettes.dart)
│   │   ├── components/             # AmbientBackground, FloatingDock, SoftCard, SoftButton 等基础组件
│   │   └── feedback/               # 全局轻提示与交互反馈 (app_feedback.dart)
│   └── features/                   # 垂直业务切片（Presentation / Engine / Data / Domain）
│       ├── shelf/                  # 书架展示、置顶排序与追更红点刷新
│       ├── discover/               # 聚合搜书与流式发现
│       ├── book_detail/            # 书籍详情、元数据自愈补全与目录正倒序
│       ├── reader/                 # 排版分页引擎、5 模式翻页视图、换源抽屉、书签与全文搜索
│       ├── sources/                # 12 组内置书源、规则解析器、并发抓取引擎与分组管理
│       ├── local_import/           # TXT/EPUB 解析导入与 18680 端口 Wi-Fi 传书 HTTP 服务
│       ├── download/               # 章节离线批量缓存队列
│       ├── tts/                    # 原生 TTS 状态机与听书控制台
│       ├── sync/                   # WebDAV 客户端与 LWW 快照编解码器
│       └── settings/               # 主题切换、翻页偏好与系统设置
├── test/                           # 13 个测试套件（覆盖排版、翻页、书源、TTS、同步与双端通道对等门禁）
├── android/                        # Android 宿主（Kotlin / Java 17 / applicationId: com.kline.yuewei）
└── ios/                            # iOS 宿主（Swift / AVFoundation / Deployment Target 15.0）
```

---

## 开发与构建指南

### 1. 环境要求

- **Flutter**: `3.47.4` (`stable` channel)
- **Dart**: `^3.13.3`
- **Android**: JDK `17` (Temurin)、Android SDK
- **iOS**（仅 macOS）: Xcode、CocoaPods、iOS Deployment Target `15.0+`

### 2. 日常开发与代码生成

```bash
# 获取依赖
flutter pub get

# 仅当修改 lib/core/database/tables.dart 或 app_database.dart 后执行
dart run build_runner build --delete-conflicting-outputs
```

### 3. 静态分析与质量门禁

```bash
# 1. 静态分析（要求 0 issues）
flutter analyze

# 2. 单文件行数红线检查（lib/ 与 test/ 下所有非 *.g.dart 文件必须 <= 350 行）
find lib test -name '*.dart' ! -name '*.g.dart' -print0 | xargs -0 wc -l | awk '$2 != "total" && $1 > 350 {print "超限:", $0; err=1} END {exit err}'

# 3. 运行全部单元测试（含双端 MethodChannel 对等静态门禁）
flutter test
```

### 4. 发布构建

```bash
# Android arm64 Release APK 构建与 SHA-256 校验值生成
flutter build apk --release --target-platform android-arm64
sha256sum build/app/outputs/flutter-apk/app-release.apk

# iOS 语法检查与无签名构建（macOS）
swiftc -parse ios/Runner/AppDelegate.swift
flutter build ios --no-codesign
```

---

## 工程文档索引

- [AGENTS.md](AGENTS.md) — 研发与 AI 协同治理铁律、350 行代码红线、双端对等规范与洁净仓白名单
- [HANDOFF.md](HANDOFF.md) — 新开发者与 Agent 自包含接手手册（架构坐标、入口表与运维命令）
- [PROGRESS.md](PROGRESS.md) — M1 ~ M4 里程碑全景台账与实测门禁指标记录
