import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../design_system/components/soft_bottom_sheet.dart';
import '../../../design_system/components/soft_button.dart';
import '../../../design_system/components/soft_text_field.dart';
import '../../../design_system/feedback/app_feedback.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../backup_snapshot_codec.dart';

/// 粘贴备份 JSON 恢复抽屉（带防重入 loading 锁，杜绝连点两次多 pop 退出页面）
Future<BackupRestoreSummary?> showPasteBackupRestoreSheet(
  BuildContext context, {
  required Future<BackupRestoreSummary> Function(String rawJson) onRestore,
}) async {
  final ctrl = TextEditingController();
  BackupRestoreSummary? result;
  try {
    await SoftBottomSheet.show(
      context,
      title: '粘贴备份 JSON 恢复',
      subtitle: '按最近阅读时间 LWW 无损合并，绝不倒退本地进度',
      headerIcon: Icons.content_paste_go_rounded,
      maxHeightFactor: 0.76,
      builder: (ctx) {
        var restoring = false;
        var popped = false;
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) => SingleChildScrollView(
            padding: const EdgeInsets.all(SoftSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SoftTextField(
                  controller: ctrl,
                  hintText: '在此粘贴阅微导出的备份 JSON 内容…',
                  prefixIcon: null,
                  maxLines: 7,
                  radius: SoftRadius.subCard,
                  textInputAction: TextInputAction.newline,
                ),
                const SizedBox(height: SoftSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: SoftButton(
                        label: '读取剪贴板',
                        icon: Icons.content_paste_rounded,
                        tone: SoftButtonTone.tonal,
                        compact: true,
                        onPressed: restoring
                            ? null
                            : () async {
                                final clip =
                                    await Clipboard.getData(Clipboard.kTextPlain);
                                final text = clip?.text?.trim() ?? '';
                                if (text.isEmpty) {
                                  if (sheetCtx.mounted) {
                                    AppFeedback.showToast(
                                      sheetCtx,
                                      '剪贴板暂无文本内容',
                                      isError: true,
                                    );
                                  }
                                  return;
                                }
                                ctrl.text = text;
                              },
                      ),
                    ),
                    const SizedBox(width: SoftSpacing.sm),
                    Expanded(
                      child: SoftButton(
                        label: '解析并合并恢复',
                        icon: Icons.restore_rounded,
                        compact: true,
                        isLoading: restoring,
                        onPressed: restoring
                            ? null
                            : () async {
                                if (restoring || popped) return;
                                setSheetState(() => restoring = true);
                                try {
                                  final summary = await onRestore(ctrl.text);
                                  result = summary;
                                  if (!popped && sheetCtx.mounted) {
                                    popped = true;
                                    Navigator.of(sheetCtx).pop();
                                  }
                                } on FormatException catch (e) {
                                  if (sheetCtx.mounted) {
                                    setSheetState(() => restoring = false);
                                    AppFeedback.showToast(
                                      sheetCtx,
                                      e.message,
                                      isError: true,
                                    );
                                  }
                                } catch (e) {
                                  if (sheetCtx.mounted) {
                                    setSheetState(() => restoring = false);
                                    AppFeedback.showToast(
                                      sheetCtx,
                                      '恢复失败：$e',
                                      isError: true,
                                    );
                                  }
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  } finally {
    ctrl.dispose();
  }
  return result;
}
