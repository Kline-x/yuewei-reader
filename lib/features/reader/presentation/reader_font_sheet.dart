import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import '../../../core/platform/host_bridge.dart';
import '../../../design_system/components/soft_bottom_sheet.dart';
import '../../../design_system/components/soft_button.dart';
import '../../../design_system/components/soft_dialog.dart';
import '../../../design_system/feedback/app_feedback.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';
import '../fonts/custom_font_manager.dart';
import 'reader_settings_provider.dart';

/// 轻量自定义字体管理底部抽屉（系统默认 + 本地导入 .ttf/.otf + Wi-Fi 传字体 + 安全删除回落）
class ReaderFontSheet extends ConsumerStatefulWidget {
  const ReaderFontSheet({super.key, this.onWifiTransfer});

  /// 由上层排版抽屉打开时注入，确保一并关闭多层抽屉再进入传书页
  final VoidCallback? onWifiTransfer;

  static Future<T?> show<T>(
    BuildContext context, {
    VoidCallback? onWifiTransfer,
  }) {
    return SoftBottomSheet.show<T>(
      context,
      title: '阅读字体',
      subtitle: '支持 .ttf / .otf 本地字体与局域网传字体',
      headerIcon: Icons.font_download_rounded,
      maxHeightFactor: 0.78,
      builder: (_) => ReaderFontSheet(onWifiTransfer: onWifiTransfer),
    );
  }

  @override
  ConsumerState<ReaderFontSheet> createState() => _ReaderFontSheetState();
}

class _ReaderFontSheetState extends ConsumerState<ReaderFontSheet> {
  bool _importing = false;

  Future<void> _importLocalFont() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final picked = await HostBridge.instance.pickFontFile();
      if (picked == null) return;
      final entry = await ref
          .read(customFontManagerProvider.notifier)
          .importFontFile(
            sourcePath: picked.path,
            originalFileName: picked.name,
          );
      await ref
          .read(readerSettingsProvider.notifier)
          .setFontFamily(entry.fontFamily);
      if (mounted) {
        AppFeedback.showToast(context, '已导入并选用「${entry.displayName}」');
      }
    } on FormatException catch (e) {
      if (mounted) AppFeedback.showToast(context, e.message, isError: true);
    } on FileSystemException catch (e) {
      if (mounted) AppFeedback.showToast(context, e.message, isError: true);
    } catch (_) {
      if (mounted) {
        AppFeedback.showToast(
          context,
          '字体导入失败，请确认文件为有效的 .ttf 或 .otf 字体',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _deleteFont(CustomFontEntry entry) async {
    final isUsing =
        ref.read(readerSettingsProvider).fontFamily == entry.fontFamily;
    final confirmed = await SoftDialog.confirm(
      context,
      title: '删除自定义字体',
      message: isUsing
          ? '当前正在使用「${entry.displayName}」，删除后将自动切换为系统默认字体。'
          : '确定要删除「${entry.displayName}」吗？删除后本地字体文件将被清理。',
      confirmLabel: '删除',
      cancelLabel: '取消',
      isDangerous: true,
    );
    if (!confirmed || !mounted) return;
    await ref.read(customFontManagerProvider.notifier).deleteFont(entry.id);
    if (ref.read(readerSettingsProvider).fontFamily == entry.fontFamily) {
      await ref.read(readerSettingsProvider.notifier).setFontFamily(null);
    }
    if (mounted) {
      AppFeedback.showToast(
        context,
        isUsing ? '已删除字体并恢复系统默认' : '已删除字体「${entry.displayName}」',
      );
    }
  }

  void _openWifiTransfer() {
    final router = GoRouter.maybeOf(context);
    Navigator.of(context).pop();
    if (widget.onWifiTransfer != null) {
      widget.onWifiTransfer!();
    } else {
      router?.push('/import');
    }
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String _extBadge(String fileName) {
    final ext = p.extension(fileName).replaceFirst('.', '').toUpperCase();
    return ext.isEmpty ? 'FONT' : ext;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final settings = ref.watch(readerSettingsProvider);
    final fonts = ref.watch(customFontManagerProvider);
    final settingsNotifier = ref.read(readerSettingsProvider.notifier);
    final isSystemDefault =
        settings.fontFamily == null || settings.fontFamily!.trim().isEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              SoftSpacing.xl,
              SoftSpacing.md,
              SoftSpacing.xl,
              SoftSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FontOptionTile(
                  title: '系统默认字体',
                  subtitle: '跟随设备预设字体渲染，轻量清晰',
                  selected: isSystemDefault,
                  onTap: () => settingsNotifier.setFontFamily(null),
                ),
                const SizedBox(height: SoftSpacing.md),
                Text(
                  '已导入字体 (${fonts.length})',
                  style: SoftTypography.caption
                      .copyWith(color: tokens.textSecondary),
                ),
                const SizedBox(height: SoftSpacing.sm),
                if (fonts.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(SoftSpacing.lg),
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: BorderRadius.circular(SoftRadius.subCard),
                      border:
                          Border.all(color: tokens.borderSubtle, width: 0.8),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.font_download_outlined,
                          size: 28.0,
                          color: tokens.textTertiary,
                        ),
                        const SizedBox(height: 6.0),
                        Text(
                          '暂无自定义字体，支持导入本机 .ttf / .otf 文件或通过 Wi-Fi 上传',
                          textAlign: TextAlign.center,
                          style: SoftTypography.caption
                              .copyWith(color: tokens.textSecondary),
                        ),
                      ],
                    ),
                  )
                else
                  ...fonts.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: SoftSpacing.sm),
                      child: _FontOptionTile(
                        title: entry.displayName,
                        subtitle:
                            '${_extBadge(entry.fileName)} · ${_formatSize(entry.fileSizeBytes)}',
                        selected: settings.fontFamily == entry.fontFamily,
                        onTap: () =>
                            settingsNotifier.setFontFamily(entry.fontFamily),
                        onDelete: () => _deleteFont(entry),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Divider(height: 1.0, thickness: 0.8, color: tokens.borderSubtle),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SoftSpacing.xl,
            SoftSpacing.md,
            SoftSpacing.xl,
            SoftSpacing.lg,
          ),
          child: Column(
            children: [
              SoftButton(
                label: _importing ? '正在导入字体…' : '从本机导入 (.ttf / .otf)',
                icon: Icons.drive_folder_upload_outlined,
                expand: true,
                isLoading: _importing,
                onPressed: _importLocalFont,
              ),
              const SizedBox(height: SoftSpacing.sm),
              SoftButton(
                label: 'Wi-Fi 传字体',
                icon: Icons.wifi_tethering_rounded,
                tone: SoftButtonTone.tonal,
                expand: true,
                onPressed: _openWifiTransfer,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FontOptionTile extends StatelessWidget {
  const _FontOptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.onDelete,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    return Material(
      color: selected ? tokens.accentSoft : tokens.surface,
      borderRadius: BorderRadius.circular(SoftRadius.subCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(SoftRadius.subCard),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            SoftSpacing.md,
            12.0,
            SoftSpacing.xs,
            12.0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SoftRadius.subCard),
            border: Border.all(
              color: selected ? tokens.accent : tokens.borderSubtle,
              width: selected ? 1.2 : 0.8,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20.0,
                color: selected ? tokens.accent : tokens.textTertiary,
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SoftTypography.cardTitle.copyWith(
                        fontSize: 14.0,
                        color: selected ? tokens.accent : tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SoftTypography.micro
                          .copyWith(color: tokens.textSecondary),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: '删除字体',
                  constraints:
                      const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 19.0,
                    color: tokens.textTertiary,
                  ),
                )
              else
                const SizedBox(width: SoftSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
