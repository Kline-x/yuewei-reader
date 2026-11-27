import 'package:flutter/material.dart';
import '../../design_system/components/soft_button.dart';
import '../../design_system/tokens/soft_metrics.dart';
import '../../design_system/tokens/soft_tokens.dart';
import 'app_update_models.dart';

/// 更新弹窗顶部标题区
class UpdateDialogHeader extends StatelessWidget {
  const UpdateDialogHeader({super.key, required this.release});

  final AppReleaseInfo release;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    return Row(
      children: [
        Container(
          width: 40.0,
          height: 40.0,
          decoration: BoxDecoration(
            color: tokens.accentSoft,
            borderRadius: BorderRadius.circular(SoftRadius.control),
          ),
          child: Icon(
            Icons.system_update_rounded,
            color: tokens.accent,
            size: 22.0,
          ),
        ),
        const SizedBox(width: SoftSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'APP UPDATE',
                style: SoftTypography.eyebrow.copyWith(color: tokens.accent),
              ),
              Text(
                '发现新版本 ${release.tagName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SoftTypography.sectionTitle
                    .copyWith(color: tokens.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 新旧版本与安装包体积胶囊行
class UpdateVersionPillsRow extends StatelessWidget {
  const UpdateVersionPillsRow({
    super.key,
    required this.currentVersion,
    required this.release,
  });

  final String currentVersion;
  final AppReleaseInfo release;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final sizeText = release.formattedApkSize;
    return Wrap(
      spacing: SoftSpacing.sm,
      runSpacing: SoftSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _VersionPill(
          label: 'v${AppVersionComparator.normalize(currentVersion)}',
          bg: tokens.surface,
          fg: tokens.textSecondary,
        ),
        Icon(
          Icons.arrow_forward_rounded,
          size: 14.0,
          color: tokens.textTertiary,
        ),
        _VersionPill(
          label: 'v${release.version}',
          bg: tokens.accentSoft,
          fg: tokens.accent,
        ),
        if (sizeText.isNotEmpty)
          _VersionPill(
            label: sizeText,
            bg: tokens.surface,
            fg: tokens.textTertiary,
          ),
      ],
    );
  }
}

/// APK 实时下载进度区
class UpdateDownloadProgressBar extends StatelessWidget {
  const UpdateDownloadProgressBar({
    super.key,
    required this.receivedBytes,
    required this.totalBytes,
  });

  final int receivedBytes;
  final int totalBytes;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final progress =
        totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : null;
    final pctText =
        progress != null ? '${(progress * 100).round()}%' : '下载中...';
    final detailText = totalBytes > 0
        ? '${AppReleaseInfo.formatByteSize(receivedBytes)} / ${AppReleaseInfo.formatByteSize(totalBytes)}'
        : AppReleaseInfo.formatByteSize(receivedBytes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '正在下载安装包 · $pctText',
              style: SoftTypography.caption.copyWith(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              detailText,
              style: SoftTypography.micro.copyWith(color: tokens.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: SoftSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(SoftRadius.pill),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7.0,
            backgroundColor: tokens.surface,
            valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
          ),
        ),
      ],
    );
  }
}

/// 权限引导或失败状态提示条
class UpdateStatusBanner extends StatelessWidget {
  const UpdateStatusBanner({super.key, required this.outcome});

  final ApkInstallOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final isPermission =
        outcome.status == ApkInstallStatus.needInstallPermission;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: SoftSpacing.md,
        vertical: SoftSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isPermission ? tokens.accentSoft : tokens.dangerSoft,
        borderRadius: BorderRadius.circular(SoftRadius.control),
      ),
      child: Text(
        outcome.message,
        style: SoftTypography.caption.copyWith(
          color: isPermission ? tokens.accent : tokens.danger,
        ),
      ),
    );
  }
}

/// 弹窗底部动作区（按平台与下载状态动态呈现）
class UpdateDialogActions extends StatelessWidget {
  const UpdateDialogActions({
    super.key,
    required this.downloading,
    required this.canInAppInstall,
    required this.lastOutcome,
    required this.onStartInAppUpdate,
    required this.onCancelDownload,
    required this.onOpenInBrowser,
    required this.onIgnoreVersion,
    required this.onLater,
  });

  final bool downloading;
  final bool canInAppInstall;
  final ApkInstallOutcome? lastOutcome;
  final VoidCallback onStartInAppUpdate;
  final VoidCallback onCancelDownload;
  final VoidCallback onOpenInBrowser;
  final VoidCallback onIgnoreVersion;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    if (downloading) {
      return SoftButton(
        label: '取消下载',
        icon: Icons.close_rounded,
        tone: SoftButtonTone.tonal,
        expand: true,
        onPressed: onCancelDownload,
      );
    }

    final needPerm =
        lastOutcome?.status == ApkInstallStatus.needInstallPermission;
    final showFallbackBrowser = canInAppInstall &&
        lastOutcome != null &&
        lastOutcome!.status != ApkInstallStatus.cancelled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canInAppInstall)
          SoftButton(
            label: needPerm ? '继续安装' : '立即更新',
            icon: Icons.download_rounded,
            tone: SoftButtonTone.primary,
            expand: true,
            onPressed: onStartInAppUpdate,
          )
        else
          SoftButton(
            label: '浏览器下载',
            icon: Icons.open_in_new_rounded,
            tone: SoftButtonTone.primary,
            expand: true,
            onPressed: onOpenInBrowser,
          ),
        if (showFallbackBrowser) ...[
          const SizedBox(height: SoftSpacing.sm),
          SoftButton(
            label: '浏览器下载',
            icon: Icons.open_in_new_rounded,
            tone: SoftButtonTone.tonal,
            compact: true,
            expand: true,
            onPressed: onOpenInBrowser,
          ),
        ],
        const SizedBox(height: SoftSpacing.sm),
        Row(
          children: [
            Expanded(
              child: SoftButton(
                label: '忽略此版本',
                tone: SoftButtonTone.ghost,
                compact: true,
                onPressed: onIgnoreVersion,
              ),
            ),
            const SizedBox(width: SoftSpacing.sm),
            Expanded(
              child: SoftButton(
                label: '稍后再说',
                tone: SoftButtonTone.tonal,
                compact: true,
                onPressed: onLater,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VersionPill extends StatelessWidget {
  const _VersionPill({
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(SoftRadius.pill),
      ),
      child: Text(label, style: SoftTypography.micro.copyWith(color: fg)),
    );
  }
}
