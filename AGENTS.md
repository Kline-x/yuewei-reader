# AGENTS.md — 阅微工程治理与协同铁律

本文档为所有参与「阅微（Yuewei）」仓库开发与维护的工程师及 AI Agent 必须严格遵守的工程宪法。

---

## 1. 核心语言铁律

- **全链路中文沟通**：所有分析思路、设计讨论、代码注释、文档编写及协同发帖，一律使用**中文**。
- **专有名词除外**：代码标识符、包名、API 名称、命令行参数、文件路径等技术专有名词保持英文原样。
- **文档完整性保护**：严禁删除或篡改与当前改动无关的既有注释与 docstring。

---

## 2. 单文件 350 行代码红线

- **硬性上限**：仓库内 `lib/` 与 `test/` 目录下**所有非 `*.g.dart` 的 `.dart` 文件，严格要求 `<= 350` 行**（包含空行与注释）。
- **唯一豁免**：由 `build_runner` 自动生成的 `*.g.dart` 文件（当前全仓仅 `lib/core/database/app_database.g.dart`）。
- **拆分原则**：当页面、控制器或引擎文件接近 320~350 行时，必须按单一职责拆分为：
  - 页面视图骨架 (`*_page.dart`)
  - 独立区块或弹窗组件 (`*_sections.dart` / `*_sheet.dart` / `*_tiles.dart`)
  - 协调器或辅助类 (`*_loader.dart` / `*_helper.dart`)
- **CI 阻断**：`.github/workflows/ci.yml` 的 `lint_and_test` 任务会自动扫描 `lib/` 与 `test/` 下全部非 `*.g.dart` 文件，任何超限文件都会直接导致构建失败。

---

## 3. 双端宿主方法桥接对等规范

Flutter 侧通过 `lib/core/platform/host_bridge.dart` 注册唯一方法通道 `com.kline.yuewei/host_bridge`。任何平台能力增删改，必须在双端源码及配置文件同步落地：

| 端侧 | 核心实现文件 |
| :--- | :--- |
| **Flutter 契约层** | `lib/core/platform/host_bridge.dart` |
| **Android 原生层** | `android/app/src/main/kotlin/com/kline/yuewei_reader/MainActivity.kt`、`NativeTtsAndBackupHelper.kt` |
| **iOS 原生层** | `ios/Runner/AppDelegate.swift` |
| **双端静态门禁** | `test/host_bridge_parity_test.dart` |

### 强制对等检查项
1. **方法名与签名全对齐**：`getHostCapabilities`、`setVolumeKeyIntercept`、`keepScreenOn`、`pickLocalBookFile`、`ttsSpeak`、`ttsStop`、`ttsIsAvailable`、`exportTextFile`、`pickAndReadTextFile` 必须在 Android 与 iOS 均实现且返回类型、错误码语义一致。
2. **原生回调事件对齐**：`onVolumeDown`、`onVolumeUp`、`onTtsDone`、`onTtsError` 回调载荷格式须保持一致。
3. **听书态音量键安全释放**：当 `reader_page.dart` 检测到当前书籍处于 TTS 听书活跃状态（`ttsForBook == true`）或处于菜单/弹窗状态时，必须关闭音量键拦截并将物理按键归还系统媒体音量控制。
4. **网络与权限对等**：由于内置书源包含 `http://` 站点且应用提供局域网 Wi-Fi 传书：
   - Android 需维持 `AndroidManifest.xml` 中 `INTERNET` / `ACCESS_NETWORK_STATE` 与 `network_security_config.xml`；
   - iOS 需维持 `ios/Runner/Info.plist` 中 `NSAppTransportSecurity.NSAllowsArbitraryLoads = true` 与 `NSLocalNetworkUsageDescription`。
5. **平台裁切红线**：本工程仅面向 Android 与 iOS 移动端，**严禁重新引入** `ohos/`、`web/`、`macos/`、`windows/`、`linux/` 目录及冗余桌面配置（受 `test/host_bridge_parity_test.dart` 守护）。

---

## 4. 仓库洁净与静态资源白名单

### 绝对禁止提交入库的文件
- 临时调试截图与抓帧：`/*.png`、`/*.jpg`、`/*.jpeg`、`step*.png` 等（调试截图一律存放于个人临时目录或 `scratch/`，严禁污染 Git 工作树）。
- 崩溃转储与运行日志：`*.log`、`*.dmp`、`*.dump`、`*.crash`。
- 一次性调试与探活脚本：`debug_*.py`、`step*.py`、`temp_*.ps1`、临时测试 `.dart` 文件（验证完毕必须删除）。
- 构建中间体与本地签名密钥：`build/`、`build_win_artifact/`、`build_win_binaries/`、`android/key.properties`、`*.jks`、`*.keystore`。

### 合法受控静态资源白名单
仅允许以下正式业务或工程配置文件受 Git 版本控制：
- Android 启动图标与原生资源：`android/app/src/main/res/**`
- iOS 应用图标与 Storyboard：`ios/Runner/Assets.xcassets/**`、`ios/Runner/Base.lproj/**`
- 工程文档与自动化流水线：`README.md`、`AGENTS.md`、`HANDOFF.md`、`PROGRESS.md`、`.github/workflows/ci.yml`

### 提交前双重洁净审查
每次准备提交前，必须运行以下两条命令确认工作树及忽略规则绝对干净：
```bash
git status
git status --ignored
```

---

## 5. 业务数据真实性与跨仓隔离纪律

- **零虚构数据**：严禁写入未实网验证的虚假书源、占位章节或模拟成功响应；所有内置书源须通过搜书 -> 详情 -> 目录 -> 正文全链路实测。
- **跨仓严格隔离**：严禁读写或修改历史参考仓库 `/Users/yang/Documents/code/vibCoding/novel_reader_flutter`。

---

## 6. 真机 E2E 循环排查与零缺陷闭环交付纪律

所有功能迭代与缺陷修复均须走完以下闭环，严禁跳过验证直接交付：

1. **真机 E2E 回归**：每次修复或新功能落地后，必须在真实物理设备安装 Release/Profile 包进行端到端操作验证，并检查系统日志（如 `adb logcat`）无异常崩溃。
2. **扩大范围探索性排查**：回归时主动扩大测试半径，核查相邻链路（如听书态切后台/音量键、换源后缓存清理、书架未读状态消除、Wi-Fi 传书断连等）。
3. **先列出问题给用户过目**：发现隐患或缺陷后完整记录现象与根因，**先向用户汇报确认**，不擅自做范围外改动。
4. **统一批次修复与再回归**：用户确认后统一修改，修改完毕后再次执行完整真机 E2E 与全量测试门禁。
5. **零缺陷方可交付**：确认再无任何异常且门禁全绿后，更新 [PROGRESS.md](PROGRESS.md)，再执行 Git 提交与远端推送。
