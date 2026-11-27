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
| **M5** | `v1.0.1` | 已完成 | 24 项全量加固、v4 索引升级与 GitHub Release 应用内在线更新 | `78/78` 测试 · `0` analyze issues · `131` 文件最大 `348` 行 · K60 两轮零缺陷 |
| **M6** | `v1.1.0` | 已完成 | 全局后台听书胶囊、双端系统媒控、轻量自定义字体与自适应双页排版 | `101/101` 测试 · `0` analyze issues · `145` 文件最大 `349` 行 · K60 两轮零缺陷 |

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

### M5 — 全量质量加固与 GitHub Release 应用内在线更新 (`1.0.1+2` / `v1.0.1`)
- **核心交付**：
  - **24 项全链路缺陷清零**：
    - **数据与同步加固**：同源刷新/前部插章经临时中转目录安全迁移磁盘章节缓存，保留既有 `isCached`/`cachedBytes`；Drift 数据库升至 `schemaVersion = 4` 新增 `idx_bookmarks_book_id` 与 `idx_reading_sessions_date_key` 索引并修复跨午夜计时；`WebdavSyncClient` 支持非 GET 最多 5 跳重定向（跨主机/HTTPS 降级自动剥离凭证）、`If-Match` ETag 乐观并发控制与上传前先拉取 LWW 无损合并；本地导入书隔离清理、封面 `local_cover://` 相对路径兼容与 `DownloadManager` 世代守卫。
    - **网络解码、书源引擎与安全传书**：`RuleEvaluator` 与 `ContentPipeline` 优先剥离 `<script>/<style>/<noscript>` 并修正 HTML 实体解码顺序，新增 `##regex##replacement` 与 `||` 备选回退；目录（`<= 30` 页）与正文（`<= 15` 页）分页防环、GBK POST 安全编码及 302 详情直解；`WifiTransferServer` 移除宽泛 CORS，新增 4 位随机数字配对码鉴权（`?token=` / `x-access-token`）与退页自动停服；补充求书网新版详情页站方 SEO 广告套话净洗规则。
    - **阅读器、TTS 与双端原生防崩**：统一 `TypographyEngine.measureHeadingHeight` 与 `PagePainter` 1:1 实测双行章标题高度彻底消除压字；修复仿真反向回拖反悔误翻页、菜单拦截防穿透与连续滚动调字号零误差重锚定；超长段 TTS 安全切分、暂停冻结睡眠计时、音频焦点/系统来电中断派发 `onTtsError`；iOS `FileHandle.read(upToCount:)` 防 NSException 闪退、新增 `UIBackgroundModes (audio)` 与非对称语速曲线校准。
  - **GitHub Release 应用内在线更新（零新增依赖）**：
    - 新增 `lib/features/update/` 模块实现语义化版本比较、启动静默每日一次节流检查、忽略版本持久化、设置页手动检查入口与 Modern Soft UI v4 风格更新弹窗。
    - 双端 `HostBridge` 对等新增 `installApk` 与 `openExternalUrl`（11 个宿主方法）；Android 端拆分 `NativeAppUpdateHelper.kt`，基于 `FileProvider`（`cache/yuewei_updates/`）与 `REQUEST_INSTALL_PACKAGES` 实现流式下载、SHA-256 校验与系统安装器唤起，iOS 端安全跳转 Release 页面；同步完善 `build.gradle.kts` 与 CI 正式签名支持。
- **实测门禁与构建指标**：
  - 代码体积门禁：`lib/` 与 `test/` 共 **131 个**非生成 `.dart` 文件，**100% 严格 `<= 350` 行**（单文件最大 **348 行**，累计 **28,165 行**）。
  - 静态分析：`flutter analyze` **0 issues**；`swiftc -parse ios/Runner/AppDelegate.swift` 与 `plutil -lint ios/Runner/Info.plist` 通过。
  - 单元测试：`flutter test` **78/78**（14 个测试文件）全绿通过。
  - Android Release 产物：云端 CI Run [`#45958131223`](https://github.com/Kline-x/yuewei-reader/actions/runs/45958131223) 已启用正式签名 Secrets 构建并发布 `v1.0.1` GitHub Release，`app-release.apk`（`arm64-v8a`，`1.0.1+2`）体积 **29,269,975 字节**，SHA-256：`891c7357302dd3372f5d58ed716ea97f98c3479bc6f060996d377e7caafe0171`，APK 签名证书 SHA-256 指纹：`4d5632e3d50e16383185ff0555723321fa643aa25e6d5da60c44e68b98c92eea`。
  - 真机 E2E 回归（Redmi K60 `22ecd9e7`）：两轮真机扩大范围回归闭环，强杀冷启耗时 **894ms**（预热 **380ms**，二轮 `v1.0.1` **664ms**），求书网刷新净洗简介并保留 `7 / 1654 章 (64.7 KB)` 缓存、设置页展示 `v1.0.1 (2)` 并实网校验最新、Wi-Fi 传书 401 鉴权与退页自动停服、双行标题与五模式/连续滚动重锚定、TTS 音量键释放全链路实测通过，`logcat` 全程零应用级崩溃与异常。

### M6 — 全局后台听书、双端系统媒控、自定义字体与双页排版 (`1.1.0+3` / `v1.1.0`)
- **核心交付**：
  - **全局悬浮听书胶囊、后台自主跨章与双端系统媒控**：
    - `TtsController` 新增 `detachReader` 实现退出阅读器不断播，新增 `TtsBackgroundChapterLoader` 在脱离阅读器态下优先从磁盘缓存/在线抓包自动跨章加载正文并原子写回 `AppDatabase` 阅读进度；新增 `GlobalTtsMiniCapsule` 悬浮于 `RootShell` 底栏正上方（支持微缩封面/回落耳机图标、呼吸状态点、播停/关闭与回跳自动重连定位，软键盘弹出时纯滑落同步隐藏）。
    - 双端 `HostBridge` 对等新增 `updateMediaSession`、`clearMediaSession` 与 `onMediaCommand`（扩展至 14 项调用方法 + 5 项回调事件）；Android 端新增纯原生 `TtsForegroundService.kt`（`MediaSession` + `Notification.MediaStyle` + `mediaPlayback` 前台服务）并支持 Android 13+ `POST_NOTIFICATIONS` 温和申请；iOS 端接入 `MediaPlayer`（`MPNowPlayingInfoCenter` 与 `MPRemoteCommandCenter`）。
  - **轻量自定义字体与精细排版调控**：
    - 新增 `lib/features/reader/fonts/`（`CustomFontCodec` / `CustomFontManager`）校验 SFNT/OTTO 魔数头与 30MB 上限，基于 Flutter 原生 `FontLoader` 启动预加载并支持 `.ttf`/`.otf` 本机选择（双端 `pickFontFile`）与局域网 Wi-Fi 传字体（`WifiTransferServer` 沿用 4 位配对码鉴权）。
    - `ReaderTypographySheet` 拆分出 `ReaderTypographySliders` 与 `ReaderFontSheet`，支持段距（`8~28px`）、页边距（`12~40px`）、字距（`0~2px`）、首行 2 字缩进开关、版式选择（自动/单页/双页）与「重置默认排版」。
  - **平板/折叠屏自适应双页书本排版**：
    - 新增 `DualPageComposer` 与 `DualPagePainter`（含折叠屏竖向铰链避让 `spineWidth` 计算、步进 2 对开配对与中缝书脊内凹渐变阴影、`PageTurnMode.curl` 平滑降级 `cover` 翻页及按字符偏移重锚定）。
  - **P1/P2 收尾加固**：
    - `SoftSpacing.bottomClearance(hasTtsCapsule:)` 为「设置」「书架」「探索」与撤销条动态追加 `80dp` 净空消除胶囊遮挡；消除 `RootShell` 与 `GlobalTtsMiniCapsule` 包裹 `BackdropFilter` 的透明度节点，彻底清零 Flutter 3.47 Impeller `SetInheritedOpacity` 验证日志。
- **实测门禁与构建指标**：
  - 代码体积门禁：`lib/` 与 `test/` 共 **145 个**非生成 `.dart` 文件，**100% 严格 `<= 350` 行**（单文件最大 **349 行**，累计 **32,739 行**）。
  - 静态分析：`flutter analyze` **0 issues**；`swiftc -parse ios/Runner/AppDelegate.swift` 与 `plutil -lint ios/Runner/Info.plist` 通过。
  - 单元测试：`flutter test` **101/101**（19 个测试文件）全绿通过。
  - 正式签名 Android 产物：`app-release.apk`（`arm64-v8a`，`1.1.0+3`）体积 **29,352,387 字节**，SHA-256：`5dcd57b7d2171b791076f7c5660ecf4571ed1a8a06182645d364dbdb3076defa`，`apksigner` 证书指纹：`4d5632e3d50e16383185ff0555723321fa643aa25e6d5da60c44e68b98c92eea`。
  - 真机 E2E 回归（Redmi K60 `22ecd9e7`）：两轮真机扩大范围回归零缺陷闭环，正式签名自覆盖升级成功、强杀冷启 **1000ms**；实测局域网 4 位配对码传字体/小说与 401/400 拦截及退页停服、精细滑杆与字体实时切换/删除回落、横屏双页对开步进 2 与奇数末页跨章对齐、全局悬浮胶囊后台自动跨章（本地 3 章/6 章）与通知栏媒控卡片联动、`v1.1.0 (3)` 净空抬升后设置「检查应用更新」完整露出实网校验最新与书架撤销条抬升零遮挡、`POST_NOTIFICATIONS` 温和申请及 `logcat` 彻底清零 `SetInheritedOpacity` 与零异常崩溃。
