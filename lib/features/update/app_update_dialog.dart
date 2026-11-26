import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../design_system/feedback/app_feedback.dart';
import '../../design_system/tokens/soft_metrics.dart';
import '../../design_system/tokens/soft_tokens.dart';
import 'app_update_dialog_sections.dart';
import 'app_update_models.dart';
import 'app_update_service.dart';

/// 展示 Modern Soft UI v4 风格应用更新弹窗
Future<void> showAppUpdateDialog(
  BuildContext context, {
  required AppReleaseInfo release,
  required String currentVersion,
  required AppUpdateService service,
  required bool supportsInAppApkInstall,
  VoidCallback? onIgnored,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppUpdateDialog(
      release: release,
      currentVersion: currentVersion,
      service: service,
      supportsInAppApkInstall: supportsInAppApkInstall,
      onIgnored: onIgnored,
    ),
  );
}

class AppUpdateDialog extends StatefulWidget {
  const AppUpdateDialog({
    super.key,
    required this.release,
    required this.currentVersion,
    required this.service,
    required this.supportsInAppApkInstall,
    this.onIgnored,
  });

  final AppReleaseInfo release;
  final String currentVersion;
  final AppUpdateService service;
  final bool supportsInAppApkInstall;
  final VoidCallback? onIgnored;

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  CancelToken? _cancelToken;
  bool _downloading = false;
  int _receivedBytes = 0;
  int _totalBytes = -1;
  ApkInstallOutcome? _lastOutcome;

  bool get _canInAppInstall =>
      widget.supportsInAppApkInstall && widget.release.hasApkAsset;

  @override
  void dispose() {
    _cancelToken?.cancel('dialog_disposed');
    super.dispose();
  }

  Future<void> _startInAppUpdate() async {
    if (_downloading) return;

    // 若上次仅因缺少未知来源安装权限暂停且本地包存在，直接续接安装无需重下
    final cachedPath = _lastOutcome?.apkFilePath;
    if (_lastOutcome?.status == ApkInstallStatus.needInstallPermission &&
        cachedPath != null &&
        cachedPath.isNotEmpty) {
      setState(() => _downloading = true);
      final retryOutcome = await widget.service.retryInstallLocalApk(
        filePath: cachedPath,
        expectedSha256: _lastOutcome?.expectedSha256,
      );
      if (!mounted) return;
      _handleOutcome(retryOutcome);
      return;
    }

    final token = CancelToken();
    setState(() {
      _cancelToken = token;
      _downloading = true;
      _receivedBytes = 0;
      _totalBytes = widget.release.apkSizeBytes ?? -1;
      _lastOutcome = null;
    });

    final outcome = await widget.service.downloadAndInstallApk(
      widget.release,
      cancelToken: token,
      onProgress: (received, total) {
        if (!mounted) return;
        setState(() {
          _receivedBytes = received;
          _totalBytes = total;
        });
      },
    );
    if (!mounted) return;
    _cancelToken = null;
    _handleOutcome(outcome);
  }

  void _handleOutcome(ApkInstallOutcome outcome) {
    setState(() {
      _downloading = false;
      _lastOutcome = outcome;
    });
    if (outcome.status == ApkInstallStatus.started) {
      AppFeedback.showToast(context, outcome.message);
      Navigator.of(context).pop();
    } else if (outcome.status == ApkInstallStatus.cancelled) {
      AppFeedback.showToast(context, '已取消下载');
    }
  }

  Future<void> _openInBrowser() async {
    final ok = await widget.service.openReleasePage(widget.release);
    if (!mounted) return;
    if (!ok) {
      AppFeedback.showToast(
        context,
        '无法拉起系统浏览器，请手动访问 GitHub Release',
        isError: true,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _ignoreThisVersion() async {
    await widget.service.ignoreVersion(widget.release.version);
    widget.onIgnored?.call();
    if (!mounted) return;
    AppFeedback.showToast(context, '已忽略 v${widget.release.version}');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final release = widget.release;
    final notes = release.releaseNotes.isEmpty
        ? '包含核心稳定性加固、双端体验优化与细节修复。'
        : release.releaseNotes;
    final showBanner = !_downloading &&
        _lastOutcome != null &&
        _lastOutcome!.status != ApkInstallStatus.cancelled &&
        _lastOutcome!.status != ApkInstallStatus.started;

    return PopScope(
      canPop: !_downloading,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380.0),
          child: Container(
            padding: const EdgeInsets.all(SoftSpacing.xl),
            decoration: BoxDecoration(
              color: tokens.card,
              borderRadius: BorderRadius.circular(SoftRadius.card),
              border: Border.all(color: tokens.borderSubtle, width: 0.9),
              boxShadow: [
                BoxShadow(
                  color: tokens.shadowColor,
                  blurRadius: 28.0,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UpdateDialogHeader(release: release),
                const SizedBox(height: SoftSpacing.md),
                UpdateVersionPillsRow(
                  currentVersion: widget.currentVersion,
                  release: release,
                ),
                const SizedBox(height: SoftSpacing.md),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 170.0),
                  padding: const EdgeInsets.all(SoftSpacing.md),
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(SoftRadius.subCard),
                    border: Border.all(color: tokens.borderSubtle, width: 0.7),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      notes,
                      style: SoftTypography.body
                          .copyWith(color: tokens.textSecondary),
                    ),
                  ),
                ),
                if (_downloading) ...[
                  const SizedBox(height: SoftSpacing.md),
                  UpdateDownloadProgressBar(
                    receivedBytes: _receivedBytes,
                    totalBytes: _totalBytes,
                  ),
                ],
                if (showBanner) ...[
                  const SizedBox(height: SoftSpacing.md),
                  UpdateStatusBanner(outcome: _lastOutcome!),
                ],
                const SizedBox(height: SoftSpacing.lg),
                UpdateDialogActions(
                  downloading: _downloading,
                  canInAppInstall: _canInAppInstall,
                  lastOutcome: _lastOutcome,
                  onStartInAppUpdate: _startInAppUpdate,
                  onCancelDownload: () => _cancelToken?.cancel('user_cancelled'),
                  onOpenInBrowser: _openInBrowser,
                  onIgnoreVersion: _ignoreThisVersion,
                  onLater: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
