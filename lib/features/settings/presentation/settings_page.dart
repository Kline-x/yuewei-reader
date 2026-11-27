import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/platform/host_bridge.dart';
import '../../../design_system/components/soft_card.dart';
import '../../../design_system/components/soft_dialog.dart';
import '../../../design_system/feedback/app_feedback.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';
import '../../reader/presentation/reader_settings_provider.dart';
import '../../update/app_update_dialog.dart';
import '../../update/app_update_models.dart';
import '../../update/app_update_service.dart';
import 'settings_sections.dart';
import 'settings_tiles.dart';

/// 阅微响应式偏好设置中心（顶部柔雾渐隐防截字，单文件严控 ≤ 350 行）
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _clearing = false;

  Future<void> _confirmClearAllCache() async {
    if (_clearing) return;
    final ok = await SoftDialog.confirm(
      context,
      title: '清理全部离线缓存',
      message: '将停止所有在途缓存任务并释放全部在线书籍的离线缓存文件，本地导入藏书与阅读进度会完整保留。',
      confirmLabel: '确认清理',
      isDangerous: true,
    );
    if (!ok || !mounted) return;
    setState(() => _clearing = true);
    try {
      await ref.read(shelfRepositoryProvider).clearAllCaches();
      if (mounted) AppFeedback.showToast(context, '已清空全部离线缓存');
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  Future<void> _handleCheckAppUpdate() async {
    final controller = ref.read(appUpdateControllerProvider.notifier);
    final result = await controller.checkManual();
    if (!mounted) return;
    if (result.hasUpdate && result.release != null) {
      final service = ref.read(appUpdateServiceProvider);
      await showAppUpdateDialog(
        context,
        release: result.release!,
        currentVersion: result.currentVersion,
        service: service,
        supportsInAppApkInstall: service.supportsInAppApkInstall,
        onIgnored: () => controller.ignoreRelease(result.release!),
      );
    } else if (result.status == AppUpdateCheckStatus.upToDate) {
      AppFeedback.showToast(
        context,
        '已是最新版本 (v${AppVersionComparator.normalize(result.currentVersion)})',
      );
    } else if (result.status == AppUpdateCheckStatus.failed) {
      AppFeedback.showToast(
        context,
        result.errorMessage ?? '检查更新失败，请稍后重试',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final db = ref.watch(appDatabaseProvider);
    final themeConfig = ref.watch(themeConfigProvider);
    final readerCfg = ref.watch(readerSettingsProvider);
    final updateState = ref.watch(appUpdateControllerProvider);
    final caps = HostBridge.instance.capabilities;

    return SafeArea(
      bottom: false,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
          ],
          stops: [0.0, 0.035, 1.0],
        ).createShader(bounds),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            SoftSpacing.xl,
            SoftSpacing.md,
            SoftSpacing.xl,
            SoftSpacing.dockClearance,
          ),
          children: [
            Text(
              'PREFERENCES',
              style: SoftTypography.eyebrow.copyWith(color: tokens.accent),
            ),
            const SizedBox(height: 2.0),
            Text(
              '偏好与意境',
              style: SoftTypography.displayTitle
                  .copyWith(color: tokens.textPrimary),
            ),
            const SizedBox(height: SoftSpacing.lg),
            SettingsRealtimeStatsRow(db: db),
            const SizedBox(height: SoftSpacing.xl),
            const SettingsSectionHeader(title: '全局主题与意境'),
            const SizedBox(height: SoftSpacing.sm),
            SettingsThemeModeCard(
              currentMode: themeConfig.mode,
              onSelect: (m) => ref.read(themeConfigProvider.notifier).setMode(m),
            ),
            const SizedBox(height: SoftSpacing.md),
            SettingsPaletteGrid(
              active: themeConfig.palette,
              onSelect: (p) =>
                  ref.read(themeConfigProvider.notifier).setPalette(p),
            ),
            const SizedBox(height: SoftSpacing.xl),
            const SettingsSectionHeader(title: '阅读沉浸控制'),
            const SizedBox(height: SoftSpacing.sm),
            SoftCard(
              padding: const EdgeInsets.symmetric(
                horizontal: SoftSpacing.lg,
                vertical: SoftSpacing.xs,
              ),
              child: Column(
                children: [
                  SettingsSwitchTile(
                    icon: Icons.brightness_auto_outlined,
                    title: '阅读纸色跟随系统',
                    subtitle: '深浅切换时自动切换夜间墨纸或素白宣纸',
                    value: readerCfg.followSystemTheme,
                    onChanged: (v) => ref
                        .read(readerSettingsProvider.notifier)
                        .setFollowSystem(v),
                  ),
                  Divider(height: 1.0, color: tokens.borderSubtle),
                  SettingsSwitchTile(
                    icon: Icons.wb_incandescent_outlined,
                    title: '阅读时保持屏幕常亮',
                    subtitle: '专注阅读期间禁止自动锁屏息屏',
                    value: readerCfg.keepScreenOn,
                    onChanged: (v) => ref
                        .read(readerSettingsProvider.notifier)
                        .setKeepScreenOn(v),
                  ),
                  Divider(height: 1.0, color: tokens.borderSubtle),
                  SettingsSwitchTile(
                    icon: Icons.volume_up_outlined,
                    title: '物理音量键翻页',
                    subtitle: caps.supportsVolumeKeyPaging
                        ? '仅在全屏沉浸读文时拦截音量上下键'
                        : '当前设备系统不支持物理音量键拦截',
                    value: caps.supportsVolumeKeyPaging &&
                        readerCfg.volumeKeyPaging,
                    onChanged: caps.supportsVolumeKeyPaging
                        ? (v) => ref
                            .read(readerSettingsProvider.notifier)
                            .setVolumeKeyPaging(v)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: SoftSpacing.xl),
            const SettingsSectionHeader(title: '书源、备份与云同步'),
            const SizedBox(height: SoftSpacing.sm),
            SoftCard(
              padding: const EdgeInsets.symmetric(
                horizontal: SoftSpacing.lg,
                vertical: SoftSpacing.xs,
              ),
              child: Column(
                children: [
                  SettingsNavTile(
                    icon: Icons.dns_outlined,
                    title: '书源生态管理与探活',
                    subtitle: '分组筛选、远程订阅、导入导出 Legado 书源',
                    onTap: () => context.push('/sources'),
                  ),
                  Divider(height: 1.0, color: tokens.borderSubtle),
                  SettingsNavTile(
                    icon: Icons.cloud_sync_outlined,
                    title: '云端同步与备份恢复',
                    subtitle: 'WebDAV 跨设备无损合并、本地全量 JSON 备份',
                    onTap: () => context.push('/sync'),
                  ),
                  Divider(height: 1.0, color: tokens.borderSubtle),
                  SettingsNavTile(
                    icon: Icons.cleaning_services_outlined,
                    title: _clearing ? '正在清理离线缓存...' : '一键清理全部离线缓存',
                    subtitle: '释放全部在线书籍缓存文件，保留本地导入藏书',
                    isDanger: true,
                    onTap: _clearing ? null : _confirmClearAllCache,
                  ),
                ],
              ),
            ),
            const SizedBox(height: SoftSpacing.xl),
            SoftCard(
              padding: const EdgeInsets.symmetric(
                horizontal: SoftSpacing.lg,
                vertical: SoftSpacing.md,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40.0,
                        height: 40.0,
                        decoration: BoxDecoration(
                          color: tokens.accentSoft,
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child:
                            Icon(Icons.menu_book_rounded, color: tokens.accent),
                      ),
                      const SizedBox(width: SoftSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '阅微 · Yuewei',
                              style: SoftTypography.cardTitle
                                  .copyWith(color: tokens.textPrimary),
                            ),
                            const SizedBox(height: 2.0),
                            Text(
                              'v${caps.versionName} (${caps.versionCode}) · ${caps.platform.toUpperCase()} · 静谧纸感阅读器',
                              style: SoftTypography.micro
                                  .copyWith(color: tokens.textTertiary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SoftSpacing.md),
                  Divider(height: 1.0, color: tokens.borderSubtle),
                  SettingsNavTile(
                    icon: Icons.system_update_alt_rounded,
                    title: updateState.checking ? '正在检查应用更新...' : '检查应用更新',
                    subtitle: updateState.availableRelease != null
                        ? '发现新版本 v${updateState.availableRelease!.version}，点击查看更新详情'
                        : '当前版本 v${caps.versionName} · 从 GitHub Releases 检查更新',
                    trailing: updateState.checking
                        ? SizedBox(
                            width: 16.0,
                            height: 16.0,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(tokens.accent),
                            ),
                          )
                        : (updateState.availableRelease != null
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 3.0,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.accentSoft,
                                  borderRadius:
                                      BorderRadius.circular(SoftRadius.pill),
                                ),
                                child: Text(
                                  'NEW v${updateState.availableRelease!.version}',
                                  style: SoftTypography.micro
                                      .copyWith(color: tokens.accent),
                                ),
                              )
                            : null),
                    onTap: updateState.checking ? null : _handleCheckAppUpdate,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
