import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/providers.dart';
import '../../../design_system/components/soft_button.dart';
import '../../../design_system/components/soft_card.dart';
import '../../../design_system/feedback/app_feedback.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';
import '../backup_snapshot_codec.dart';
import '../webdav_sync_client.dart';
import '../webdav_sync_coordinator.dart';

/// WebDAV 云同步配置与双向同步卡片（兼容坚果云 / Nextcloud / Alist，严控 <= 260 行）
class SyncWebdavCard extends ConsumerStatefulWidget {
  const SyncWebdavCard({
    super.key,
    required this.onRestored,
    this.externalBusy = false,
    this.onBusyChanged,
    this.onPreferencesUpdated,
  });

  final Future<void> Function(BackupRestoreSummary summary) onRestored;
  final bool externalBusy;
  final ValueChanged<bool>? onBusyChanged;
  final Future<void> Function()? onPreferencesUpdated;

  @override
  ConsumerState<SyncWebdavCard> createState() => _SyncWebdavCardState();
}

class _SyncWebdavCardState extends ConsumerState<SyncWebdavCard> {
  final _urlCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();

  bool _obscurePwd = true;
  String? _busyAction;
  DateTime? _lastSyncAt;

  bool get _isBusy => _busyAction != null || widget.externalBusy;

  @override
  void initState() {
    super.initState();
    _loadSavedConfig();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedConfig() async {
    final cfg = await WebdavSyncClient.loadConfig(ref.read(appDatabaseProvider));
    if (!mounted) return;
    setState(() {
      _urlCtrl.text = cfg.url;
      _userCtrl.text = cfg.username;
      _pwdCtrl.text = cfg.password;
      _lastSyncAt = cfg.lastSyncAt;
    });
  }

  WebdavConfig _currentConfig() => WebdavConfig(
        url: _urlCtrl.text.trim(),
        username: _userCtrl.text.trim(),
        password: _pwdCtrl.text,
        lastSyncAt: _lastSyncAt,
      );

  Future<void> _runAction(String tag, Future<void> Function() task) async {
    if (_isBusy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busyAction = tag);
    widget.onBusyChanged?.call(true);
    try {
      await task();
    } on WebdavSyncException catch (e) {
      if (mounted) AppFeedback.showToast(context, e.message, isError: true);
    } on FormatException catch (e) {
      if (mounted) AppFeedback.showToast(context, e.message, isError: true);
    } catch (e) {
      if (mounted) AppFeedback.showToast(context, '云同步执行失败：$e', isError: true);
    } finally {
      widget.onBusyChanged?.call(false);
      if (mounted) setState(() => _busyAction = null);
    }
  }

  Future<void> _saveOnly() => _runAction('save', () async {
        await WebdavSyncClient.saveConfig(ref.read(appDatabaseProvider), _currentConfig());
        if (mounted) AppFeedback.showToast(context, '已保存 WebDAV 账号配置');
      });

  Future<void> _testConn() => _runAction('test', () async {
        final cfg = _currentConfig();
        await WebdavSyncClient(config: cfg).testConnection();
        await WebdavSyncClient.saveConfig(ref.read(appDatabaseProvider), cfg);
        if (mounted) AppFeedback.showToast(context, '连接测试通过，WebDAV 认证正常');
      });

  Future<void> _uploadCloud() => _runAction('upload', () async {
        final db = ref.read(appDatabaseProvider);
        final cfg = _currentConfig();
        await WebdavSyncClient.saveConfig(db, cfg);
        final res = await WebdavSyncCoordinator.uploadWithPreMerge(
          client: WebdavSyncClient(config: cfg),
          codec: ref.read(backupSnapshotCodecProvider),
        );
        final now = await WebdavSyncClient.markSyncedNow(db);
        if (res.mergedFromRemote) {
          await widget.onPreferencesUpdated?.call();
        }
        if (!mounted) return;
        setState(() => _lastSyncAt = now);
        AppFeedback.showToast(
          context,
          res.mergedFromRemote ? '已先合并云端增量并上传最新快照' : '已上传全量备份快照至云端',
        );
      });

  Future<void> _downloadAndMerge() => _runAction('download', () async {
        final db = ref.read(appDatabaseProvider);
        final cfg = _currentConfig();
        await WebdavSyncClient.saveConfig(db, cfg);
        final raw = await WebdavSyncClient(config: cfg).downloadBackup();
        if (raw == null) {
          if (mounted) AppFeedback.showToast(context, '云端尚无备份文件，请先执行一次上传', isError: true);
          return;
        }
        final summary = await ref.read(backupSnapshotCodecProvider).mergeSnapshotJson(raw);
        final now = await WebdavSyncClient.markSyncedNow(db);
        if (!mounted) return;
        setState(() => _lastSyncAt = now);
        await widget.onRestored(summary);
      });

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final syncLabel = _lastSyncAt == null
        ? '上次同步：尚未同步'
        : '上次同步：${DateFormat('yyyy-MM-dd HH:mm').format(_lastSyncAt!)}';

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.cloud_sync_rounded, size: 20.0, color: tokens.accent),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                'WebDAV 云同步（坚果云 / Nextcloud / Alist）',
                style: SoftTypography.cardTitle.copyWith(color: tokens.textPrimary),
              ),
            ),
          ]),
          const SizedBox(height: 6.0),
          Text(
            '遵循 RFC 4918 协议将书架进度、书签与自定义书源同步至私有网盘，多端按最近阅读时间无损合并。',
            style: SoftTypography.body.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: 6.0),
          Text(
            syncLabel,
            style: SoftTypography.caption.copyWith(
              color: _lastSyncAt != null ? tokens.accent : tokens.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: SoftSpacing.md),
          _buildInput(tokens, _urlCtrl, Icons.link_rounded, '服务器地址，如 https://dav.jianguoyun.com/dav/',
              keyboardType: TextInputType.url),
          const SizedBox(height: SoftSpacing.sm),
          _buildInput(tokens, _userCtrl, Icons.person_outline_rounded, 'WebDAV 账号 / 邮箱'),
          const SizedBox(height: SoftSpacing.sm),
          _buildInput(
            tokens,
            _pwdCtrl,
            Icons.key_rounded,
            '应用专用密码',
            obscure: _obscurePwd,
            trailing: IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: _obscurePwd ? '显示密码' : '隐藏密码',
              onPressed: () => setState(() => _obscurePwd = !_obscurePwd),
              icon: Icon(
                _obscurePwd ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 18.0,
                color: tokens.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: SoftSpacing.lg),
          Row(children: [
            Expanded(child: SoftButton(label: '保存配置', icon: Icons.save_outlined, tone: SoftButtonTone.tonal, compact: true, isLoading: _busyAction == 'save', onPressed: _isBusy ? null : _saveOnly)),
            const SizedBox(width: SoftSpacing.sm),
            Expanded(child: SoftButton(label: '测试连接', icon: Icons.fact_check_outlined, tone: SoftButtonTone.tonal, compact: true, isLoading: _busyAction == 'test', onPressed: _isBusy ? null : _testConn)),
          ]),
          const SizedBox(height: SoftSpacing.sm),
          Row(children: [
            Expanded(child: SoftButton(label: '上传至云端', icon: Icons.cloud_upload_outlined, expand: true, isLoading: _busyAction == 'upload', onPressed: _isBusy ? null : _uploadCloud)),
            const SizedBox(width: SoftSpacing.sm),
            Expanded(child: SoftButton(label: '从云端拉取合并', icon: Icons.cloud_download_outlined, tone: SoftButtonTone.tonal, expand: true, isLoading: _busyAction == 'download', onPressed: _isBusy ? null : _downloadAndMerge)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildInput(
    SoftTokens tokens,
    TextEditingController ctrl,
    IconData icon,
    String hint, {
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(SoftRadius.control),
        border: Border.all(color: tokens.borderSubtle, width: 0.8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
      child: Row(children: [
        Icon(icon, size: 18.0, color: tokens.textTertiary),
        const SizedBox(width: 8.0),
        Expanded(
          child: TextField(
            controller: ctrl,
            obscureText: obscure,
            keyboardType: keyboardType,
            style: SoftTypography.body.copyWith(color: tokens.textPrimary),
            cursorColor: tokens.accent,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: SoftTypography.body.copyWith(color: tokens.textTertiary),
              contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
            ),
          ),
        ),
        ?trailing,
      ]),
    );
  }
}
