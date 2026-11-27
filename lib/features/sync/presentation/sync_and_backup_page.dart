import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/providers.dart';
import '../../../core/platform/host_bridge.dart';
import '../../../design_system/components/ambient_background.dart';
import '../../../design_system/components/soft_button.dart';
import '../../../design_system/components/soft_card.dart';
import '../../../design_system/feedback/app_feedback.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';
import '../../reader/presentation/reader_settings_provider.dart';
import '../../tts/tts_controller.dart';
import '../backup_snapshot_codec.dart';
import 'sync_paste_restore_sheet.dart';
import 'sync_webdav_card.dart';

/// 本地全量备份恢复与 WebDAV 云同步中心（共享互斥忙态，严控 <= 260 行）
class SyncAndBackupPage extends ConsumerStatefulWidget {
  const SyncAndBackupPage({super.key});

  @override
  ConsumerState<SyncAndBackupPage> createState() => _SyncAndBackupPageState();
}

class _SyncAndBackupPageState extends ConsumerState<SyncAndBackupPage> {
  String? _localAction;
  bool _webdavBusy = false;

  bool get _isBusy => _localAction != null || _webdavBusy;

  Future<void> _refreshSyncedPreferences() async {
    ref.invalidate(readerSettingsProvider);
    await ref.read(ttsControllerProvider.notifier).reloadSpeechRateFromPrefs();
    await ref.read(shelfViewPrefsProvider.notifier).reloadFromDb();
    await ref.read(themeConfigProvider.notifier).reloadFromDb();
  }

  Future<void> _onRestoredSummary(BackupRestoreSummary s) async {
    await _refreshSyncedPreferences();
    if (!mounted) return;
    AppFeedback.showToast(
      context,
      '已恢复：合并 ${s.booksMerged} 本藏书 · 新增 ${s.bookmarksAdded} 条书签 · 合并 ${s.sourcesMerged} 个书源',
    );
  }

  Future<void> _exportBackupFile() async {
    if (_isBusy) return;
    setState(() => _localAction = 'export');
    try {
      final json = await ref.read(backupSnapshotCodecProvider).exportSnapshotJson();
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final saved = await HostBridge.instance.exportTextFile(
        fileName: 'yuewei_backup_$stamp.json',
        content: json,
      );
      if (mounted && saved != null) AppFeedback.showToast(context, '已导出备份文件：$saved');
    } catch (e) {
      if (mounted) AppFeedback.showToast(context, '导出备份失败：$e', isError: true);
    } finally {
      if (mounted) setState(() => _localAction = null);
    }
  }

  Future<void> _copyBackupJson() async {
    if (_isBusy) return;
    setState(() => _localAction = 'copy');
    try {
      final json = await ref.read(backupSnapshotCodecProvider).exportSnapshotJson();
      await Clipboard.setData(ClipboardData(text: json));
      if (mounted) AppFeedback.showToast(context, '已复制全量备份 JSON 到剪贴板');
    } catch (e) {
      if (mounted) AppFeedback.showToast(context, '生成备份失败：$e', isError: true);
    } finally {
      if (mounted) setState(() => _localAction = null);
    }
  }

  Future<void> _pickAndRestoreFile() async {
    if (_isBusy) return;
    setState(() => _localAction = 'restore_file');
    try {
      final picked = await HostBridge.instance.pickAndReadTextFile();
      if (picked == null) return;
      final summary = await ref.read(backupSnapshotCodecProvider).mergeSnapshotJson(picked.content);
      await _onRestoredSummary(summary);
    } on FormatException catch (e) {
      if (mounted) AppFeedback.showToast(context, e.message, isError: true);
    } catch (e) {
      if (mounted) AppFeedback.showToast(context, '恢复备份失败：$e', isError: true);
    } finally {
      if (mounted) setState(() => _localAction = null);
    }
  }

  Future<void> _openPasteRestoreSheet() async {
    if (_isBusy) return;
    setState(() => _localAction = 'restore_paste');
    BackupRestoreSummary? summary;
    try {
      summary = await showPasteBackupRestoreSheet(
        context,
        onRestore: (raw) => ref.read(backupSnapshotCodecProvider).mergeSnapshotJson(raw),
      );
    } finally {
      if (mounted) setState(() => _localAction = null);
    }
    if (summary != null) {
      await _onRestoredSummary(summary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8.0, 8.0, 16.0, 8.0),
              child: Row(children: [
                IconButton(
                  constraints: const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
                  onPressed: () {
                    AppFeedback.dismissSnackBar(context);
                    Navigator.of(context).maybePop();
                  },
                  icon: Icon(Icons.arrow_back_ios_new_rounded, size: 19.0, color: tokens.textPrimary),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('CLOUD SYNC & BACKUP',
                        style: SoftTypography.eyebrow.copyWith(color: tokens.accent)),
                    Text('云端同步与备份恢复',
                        style: SoftTypography.sectionTitle
                            .copyWith(color: tokens.textPrimary, fontSize: 18.0)),
                  ]),
                ),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  SoftSpacing.xl,
                  SoftSpacing.sm,
                  SoftSpacing.xl,
                  SoftSpacing.xxl,
                ),
                children: [
                  _buildLocalBackupCard(tokens),
                  const SizedBox(height: SoftSpacing.lg),
                  SyncWebdavCard(
                    onRestored: _onRestoredSummary,
                    externalBusy: _localAction != null,
                    onBusyChanged: (busy) {
                      if (mounted) setState(() => _webdavBusy = busy);
                    },
                    onPreferencesUpdated: _refreshSyncedPreferences,
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildLocalBackupCard(SoftTokens tokens) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.inventory_2_outlined, size: 20.0, color: tokens.accent),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text('本地全量备份与恢复',
                  style: SoftTypography.cardTitle.copyWith(color: tokens.textPrimary)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
              decoration: BoxDecoration(
                color: tokens.accentSoft,
                borderRadius: BorderRadius.circular(SoftRadius.pill),
              ),
              child: Text('LWW 防倒退', style: SoftTypography.micro.copyWith(color: tokens.accent)),
            ),
          ]),
          const SizedBox(height: 8.0),
          Text(
            '一键导出书架藏书、阅读进度、书签摘录、自定义书源与意境排版设置；本地导入电子书仅同步进度元数据，不含庞大正文。',
            style: SoftTypography.body.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: SoftSpacing.lg),
          Row(children: [
            Expanded(
              child: SoftButton(
                label: '导出备份文件',
                icon: Icons.ios_share_rounded,
                expand: true,
                isLoading: _localAction == 'export',
                onPressed: _isBusy ? null : _exportBackupFile,
              ),
            ),
            const SizedBox(width: SoftSpacing.sm),
            Expanded(
              child: SoftButton(
                label: '复制备份 JSON',
                icon: Icons.copy_rounded,
                tone: SoftButtonTone.tonal,
                expand: true,
                isLoading: _localAction == 'copy',
                onPressed: _isBusy ? null : _copyBackupJson,
              ),
            ),
          ]),
          const SizedBox(height: SoftSpacing.sm),
          Row(children: [
            Expanded(
              child: SoftButton(
                label: '从备份文件恢复',
                icon: Icons.folder_open_rounded,
                tone: SoftButtonTone.tonal,
                expand: true,
                isLoading: _localAction == 'restore_file',
                onPressed: _isBusy ? null : _pickAndRestoreFile,
              ),
            ),
            const SizedBox(width: SoftSpacing.sm),
            Expanded(
              child: SoftButton(
                label: '粘贴 JSON 恢复',
                icon: Icons.paste_rounded,
                tone: SoftButtonTone.tonal,
                expand: true,
                isLoading: _localAction == 'restore_paste',
                onPressed: _isBusy ? null : _openPasteRestoreSheet,
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
