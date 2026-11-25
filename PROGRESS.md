# PROGRESS.md — 阅微（Yuewei）研发里程碑全景大盘

本文档如实记录各研发阶段的核心交付、Git 提交锚点与实测门禁指标，所有数据均来自仓库实测与真机回归结果。

---

## 里程碑总览

| 阶段 | Git Commit | 状态 | 核心主题 | 关键实测门禁 |
| :--- | :--- | :--- | :--- | :--- |
| **M1** | `b8465dd` | 已完成 | 基础工程、八套主题、书源详情自愈、五模式翻页 | 工程冷启、5 源全链路、5 模式翻页打通 |
| **M2** | `dc8469f` | 已完成 | 本地 TXT/EPUB、18680 Wi-Fi 传书、书签与全文搜书 | `48/48` 测试全绿 · 三轮真机 E2E 闭环 |
| **M3** | `f1e753e` | 已完成 | 双端 TTS 听书、WebDAV 云同步、12 组书源扩充 | `64/64` 测试 · `0` analyze issues · 最大 `348` 行 · K60 三轮零缺陷 |
| **M4** | `6f8c79e` | 已完成 | 仓库门面、治理文档体系、GitHub Actions CI/CD 与 iOS 对等核验 | CI Run `#45515717930` 全绿（门禁单测 + Android APK + `macos-latest` iOS 无签名构建）· `v1.0.0` 发版就绪 |

---

## 分阶段交付明细

### M1 — 基础工程与阅读器骨架 (`b8465dd`)
- **提交信息**：`feat(infra): 初始化「阅微（Yuewei）」M1 工程、QQ阅读级五模式翻页与书籍详情全链路`
- **核心成果**：
  - 建立基于 Flutter + Riverpod + GoRouter + Drift 的 Clean Architecture 工程骨架，彻底裁切冗余桌面/Web/鸿蒙目录。
  - 实现 **Modern Soft UI v4** 视觉令牌系统：4 大静谧意境（苍岚烟雨、暮色暖珀、紫陌幽兰、极夜星芒）× 昼/夜共 **8 套主题**，搭配 5 款 WCAG 护眼阅读纸感色板。
  - 打通 **5 组初始内置书源** 并发搜索与详情页污损元数据自动清洗自愈链路。
  - 完成自研字符级分页引擎与 QQ 阅读级 **5 模式翻页**（仿真 `curl` / 覆盖 `cover` / 平移 `slide` / 上下 `scroll` / 无动画 `none`）。

### M2 — 本地导入、Wi-Fi 传书与书内检索 (`dc8469f`)
- **提交信息**：`feat(shelf): 完成 M2 本地 TXT/EPUB 导入、Wi-Fi 传书、书签与书内全文搜索`
- **核心成果**：
  - 实现本地 `.txt` / `.epub` 文件解析导入（自动适配 UTF-8/GBK 等编码与章节识别）。
  - 内置 `18680` 端口局域网轻量 HTTP Wi-Fi 传书服务端（支持同局域网浏览器无线推送 `.txt` / `.epub` 电子书与 `.json` 书源）。
  - 升级 Drift 数据库至 `schemaVersion = 3`，新增 `Bookmarks` 书签表与 `hasUnreadUpdate` 追更标记，上线书签增删跳转与书内全文检索功能。
- **实测指标**：
  - 单元测试：`48/48` 全部通过。
  - 真机验证：完成三轮真机端到端回归闭环。

### M3 — 原生 TTS、WebDAV 云同步与 12 组书源扩充 (`f1e753e`)
- **提交信息**：`feat(m3): 完成双端 TTS 听书、WebDAV 云同步备份、12 组内置书源扩充与进阶管理`
- **核心成果**：
  - **双端原生 TTS 听书**：Android `TextToSpeech` 与 iOS `AVSpeechSynthesizer` 接入统一 `HostBridge`；支持段级推进、跨章自动续播、5 档倍速（`0.75x ~ 1.75x`）持久化与睡眠定时（15/30/60 分、播完本章）；听书活跃态自动释放物理音量键翻页拦截，还原系统调音体验。
  - **WebDAV 云同步与快照**：实现 `WebdavSyncClient` 与 `BackupSnapshotCodec`，支持 WebDAV 远端同步与本地 JSON 文件导入导出，采用 LWW（Last-Write-Wins）无损合并策略避免新进度回退。
  - **12 组内置书源扩充与管理**：新增并实网校验 7 组书源（总计 12 组全链路 200 OK），划分为「精品主力 / 经典备选 / 精选扩充」3 大分组；补全远程 URL / 粘贴 / 本地文件三合一导入与分组/健康分探活管理。
- **实测门禁与构建指标**：
  - 代码体积门禁：`lib/` 与 `test/` 共 **107 个**非生成 `.dart` 文件，**100% 严格 `<= 350` 行**（单文件最大 **348 行**，累计 **22,792 行**）。
  - 静态分析：`flutter analyze` **0 issues**。
  - 单元测试：`flutter test` **64/64** 全绿通过。
  - Android Release 产物：`app-release.apk`（`arm64-v8a`）体积 **29,006,919 字节**，SHA-256：`c574c383a438e667af3408161091156c3f0b06da261fbe6f9f400cb1edadf2ee`。
  - 真机 E2E 回归（Redmi K60）：完成三轮真机全链路零缺陷闭环，强杀冷启动耗时 **466ms**，`logcat` 全程零异常。

### M4 — 治理文档、CI/CD 与 iOS 对等核验 (`6f8c79e` / `v1.0.0`)
- **已完成交付**：
  - [x] 重写生产级项目门面 [README.md](README.md)。
  - [x] 建立自包含工程治理三件套：[AGENTS.md](AGENTS.md)、[HANDOFF.md](HANDOFF.md)、[PROGRESS.md](PROGRESS.md)。
  - [x] 构建 GitHub Actions 全自动流水线 [ci.yml](.github/workflows/ci.yml)（代码行数门禁 + 静态分析 + 单元测试 + Android Release APK & SHA-256 + iOS 无签名构建验证 + Tag 自动 Release），Run [`#45515717930`](https://github.com/Kline-x/yuewei-reader/actions/runs/45515717930) 全链路绿灯通过（`lint_and_test` 1m49s、`build_android` 5m33s、`verify_ios` 6m1s）。
  - [x] iOS 端跨平台对等核查与静态/云端构建验证（**0 个 P0/P1 阻塞缺陷**）：
    - `swiftc -parse ios/Runner/AppDelegate.swift` 与 `SceneDelegate.swift` 通过；`iPhoneOS18.5.sdk` / `iPhoneSimulator18.5.sdk`（`arm64-apple-ios15.0`）`swiftc -typecheck` 零错误零警告；云端 `macos-latest` 已跑通 `flutter build ios --no-codesign`。
    - `ios/Runner/Info.plist` 已配置 `NSAllowsArbitraryLoads = true` 与 `NSLocalNetworkUsageDescription`，12 组内置书源（含 10 组 `http://`）与 `com.kline.yuewei/host_bridge` 双端通道（9 个宿主方法与 `AVSpeechSynthesizer` / `UIDocumentPicker`）完全对等。
    - 后续 P2 温和优化备忘（不阻塞编译与主流程）：高倍速 TTS 语速曲线平缓化、`pickLocalBookFile` 临时副本清理、以及面向 Swift 6 严格并发的注解前瞻。
  - [x] 正式发版：推送 `v1.0.0` Tag 触发 GitHub Release 自动附带 `app-release.apk` 与 `.sha256` 校验产物。
