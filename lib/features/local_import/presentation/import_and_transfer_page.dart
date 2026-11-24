import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/platform/host_bridge.dart';
import '../../../core/storage/chapter_file_store.dart';
import '../../../design_system/components/ambient_background.dart';
import '../../../design_system/components/soft_button.dart';
import '../../../design_system/components/soft_card.dart';
import '../../../design_system/components/soft_switch.dart';
import '../../../design_system/feedback/app_feedback.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';
import '../wifi/wifi_transfer_server.dart';

typedef _ReceivedEntry = ({WifiReceivedItem item, String? bookId});

/// 本机导入与局域网 Wi-Fi 无线传书工作台（≤ 320 行）
class ImportAndTransferPage extends ConsumerStatefulWidget {
  const ImportAndTransferPage({super.key});

  @override
  ConsumerState<ImportAndTransferPage> createState() =>
      _ImportAndTransferPageState();
}

class _ImportAndTransferPageState extends ConsumerState<ImportAndTransferPage> {
  StreamSubscription<WifiReceivedItem>? _sub;
  final List<_ReceivedEntry> _received = [];
  Book? _lastImported;
  bool _importing = false;
  bool _togglingWifi = false;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(wifiTransferServerProvider).receivedStream.listen(_onWifiItem);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _onWifiItem(WifiReceivedItem item) async {
    final bookId = item.kind == 'book' ? await _findLocalBookId(item.displayTitle) : null;
    if (!mounted) return;
    setState(() => _received.insert(0, (item: item, bookId: bookId)));
    AppFeedback.showToast(
      context,
      item.kind == 'book'
          ? '收到书籍《${item.displayTitle}》（${item.itemCount} 章）'
          : '已导入 ${item.itemCount} 条书源规则',
    );
  }

  Future<String?> _findLocalBookId(String title) async {
    final books = await ref.read(appDatabaseProvider).getShelfBooks();
    final matches = books
        .where((b) => b.sourceId == kLocalBookSourceId && b.title == title)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return matches.isEmpty ? null : matches.first.id;
  }

  Future<void> _pickAndImport() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final picked = await HostBridge.instance.pickLocalBookFile();
      if (picked == null) return;
      final book = await ref.read(localImportServiceProvider).importFromFile(
            picked.path,
            originalFileName: picked.name,
          );
      if (!mounted) return;
      setState(() => _lastImported = book);
      AppFeedback.showToast(context, '已导入《${book.title}》（${book.totalChapters} 章）');
    } catch (e) {
      final msg = e is FormatException
          ? e.message
          : (e is FileSystemException ? e.message : '导入失败，请确认文件为有效 TXT 或 EPUB');
      if (mounted) AppFeedback.showToast(context, msg, isError: true);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _toggleWifi(bool enable) async {
    if (_togglingWifi) return;
    setState(() => _togglingWifi = true);
    final server = ref.read(wifiTransferServerProvider);
    try {
      enable ? await server.start() : await server.stop();
      if (mounted) {
        AppFeedback.showToast(context, enable ? 'Wi-Fi 传书服务已开启' : 'Wi-Fi 传书服务已停止');
      }
    } catch (_) {
      if (mounted) AppFeedback.showToast(context, '启停 Wi-Fi 服务失败，请检查网络权限', isError: true);
    } finally {
      if (mounted) setState(() => _togglingWifi = false);
    }
  }

  Future<void> _copyUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) AppFeedback.showToast(context, '已复制传书地址');
  }

  void _goShelf() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go('/shelf');
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _openReceived(_ReceivedEntry rec) async {
    if (rec.item.kind == 'source') {
      context.push('/sources');
      return;
    }
    final id = rec.bookId ?? await _findLocalBookId(rec.item.displayTitle);
    if (!mounted) return;
    if (id != null) {
      context.push('/book?id=$id');
    } else {
      AppFeedback.showToast(context, '未在书架找到该书籍，请回到书架查看', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final server = ref.watch(wifiTransferServerProvider);
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8.0, 8.0, 16.0, 8.0),
                child: Row(children: [
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.arrow_back_ios_new_rounded, size: 19.0, color: tokens.textPrimary),
                  ),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('IMPORT & TRANSFER', style: SoftTypography.eyebrow.copyWith(color: tokens.accent)),
                      Text('导入与传书', style: SoftTypography.sectionTitle.copyWith(color: tokens.textPrimary, fontSize: 18.0)),
                    ]),
                  ),
                ]),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(SoftSpacing.xl, SoftSpacing.sm, SoftSpacing.xl, SoftSpacing.xxl),
                  children: [
                    _buildLocalImportCard(tokens),
                    const SizedBox(height: SoftSpacing.lg),
                    _buildWifiCard(tokens, server),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _surfaceBox(SoftTokens tokens, Widget child) => Container(
        padding: const EdgeInsets.all(SoftSpacing.md),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(SoftRadius.subCard),
          border: Border.all(color: tokens.borderSubtle, width: 0.8),
        ),
        child: child,
      );

  Widget _buildLocalImportCard(SoftTokens tokens) {
    final imported = _lastImported;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.folder_open_rounded, size: 20.0, color: tokens.accent),
            const SizedBox(width: 8.0),
            Expanded(child: Text('本机文件导入', style: SoftTypography.cardTitle.copyWith(color: tokens.textPrimary))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
              decoration: BoxDecoration(color: tokens.accentSoft, borderRadius: BorderRadius.circular(SoftRadius.pill)),
              child: Text('TXT · EPUB', style: SoftTypography.micro.copyWith(color: tokens.accent)),
            ),
          ]),
          const SizedBox(height: 8.0),
          Text('自动识别 UTF-8 / GBK 编码并智能分章；EPUB 自动提取封面、作者与完整目录，立即离线阅读。',
              style: SoftTypography.body.copyWith(color: tokens.textSecondary)),
          const SizedBox(height: SoftSpacing.lg),
          SoftButton(
            label: _importing ? '正在解析导入…' : '选择本地电子书',
            icon: Icons.drive_folder_upload_outlined,
            expand: true,
            isLoading: _importing,
            onPressed: _pickAndImport,
          ),
          if (imported != null) ...[
            const SizedBox(height: SoftSpacing.md),
            _surfaceBox(tokens, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('已入库：《${imported.title}》', style: SoftTypography.cardTitle.copyWith(fontSize: 14.0, color: tokens.textPrimary)),
              const SizedBox(height: 4.0),
              Text('${imported.author} · 共 ${imported.totalChapters} 章', style: SoftTypography.caption.copyWith(color: tokens.textSecondary)),
              const SizedBox(height: SoftSpacing.md),
              Row(children: [
                Expanded(child: SoftButton(label: '立即打开', icon: Icons.menu_book_rounded, compact: true, onPressed: () => context.push('/reader/${imported.id}'))),
                const SizedBox(width: SoftSpacing.sm),
                Expanded(child: SoftButton(label: '查看书架', icon: Icons.collections_bookmark_outlined, tone: SoftButtonTone.tonal, compact: true, onPressed: _goShelf)),
              ]),
            ])),
          ],
        ]),
      ),
    );
  }

  Widget _buildWifiCard(SoftTokens tokens, WifiTransferServer server) {
    final isRunning = server.isRunning;
    final url = server.serverUrl;
    final altUrls = server.listenUrls.skip(1).take(2).toList();
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.wifi_tethering_rounded, size: 20.0, color: tokens.accent),
            const SizedBox(width: 8.0),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('局域网 Wi-Fi 无线传书', style: SoftTypography.cardTitle.copyWith(color: tokens.textPrimary)),
                Text(isRunning ? '服务运行中 · 端口 ${server.port ?? ''}' : '开启后可在电脑浏览器批量上传',
                    style: SoftTypography.caption.copyWith(color: isRunning ? tokens.accent : tokens.textTertiary)),
              ]),
            ),
            SoftSwitch(value: isRunning, semanticLabel: '开关 Wi-Fi 传书服务', onChanged: _togglingWifi ? null : _toggleWifi),
          ]),
          const SizedBox(height: 8.0),
          Text('支持同一局域网下的电脑或平板浏览器拖入上传 .txt / .epub 电子书，以及 .json 书源规则文件。',
              style: SoftTypography.body.copyWith(color: tokens.textSecondary)),
          if (isRunning && url != null) ...[
            const SizedBox(height: SoftSpacing.md),
            _surfaceBox(tokens, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('电脑浏览器访问以下地址：', style: SoftTypography.caption.copyWith(color: tokens.textSecondary)),
              const SizedBox(height: 6.0),
              Row(children: [
                Expanded(child: SelectableText(url, style: SoftTypography.cardTitle.copyWith(color: tokens.accent, fontSize: 15.0))),
                const SizedBox(width: SoftSpacing.sm),
                SoftButton(label: '复制', icon: Icons.copy_rounded, tone: SoftButtonTone.tonal, compact: true, onPressed: () => _copyUrl(url)),
              ]),
              if (altUrls.isNotEmpty) ...[
                const SizedBox(height: 4.0),
                Text('备选地址：${altUrls.join(' · ')}', style: SoftTypography.micro.copyWith(color: tokens.textTertiary)),
              ] else if (url.contains('127.0.0.1')) ...[
                const SizedBox(height: 4.0),
                Text('未检测到局域网 IP，请确认设备已接入 Wi-Fi', style: SoftTypography.micro.copyWith(color: tokens.warning)),
              ],
            ])),
          ],
          if (isRunning || _received.isNotEmpty) ...[
            const SizedBox(height: SoftSpacing.lg),
            Text('本次接收记录 (${_received.length})', style: SoftTypography.caption.copyWith(color: tokens.textSecondary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8.0),
            if (_received.isEmpty)
              Text('正在等待局域网设备上传文件…', style: SoftTypography.caption.copyWith(color: tokens.textTertiary))
            else
              ..._received.map((rec) {
                final isBook = rec.item.kind == 'book';
                final t = '${rec.item.receivedAt.hour.toString().padLeft(2, '0')}:${rec.item.receivedAt.minute.toString().padLeft(2, '0')}';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ListTile(
                    dense: true,
                    tileColor: tokens.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SoftRadius.control)),
                    leading: Icon(isBook ? Icons.menu_book_rounded : Icons.dns_outlined, size: 18.0, color: tokens.accent),
                    title: Text(rec.item.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: SoftTypography.body.copyWith(color: tokens.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text(isBook ? '本地藏书 · ${rec.item.itemCount} 章 · $t' : '书源规则 · ${rec.item.itemCount} 条 · $t',
                        style: SoftTypography.micro.copyWith(color: tokens.textSecondary)),
                    trailing: Icon(Icons.chevron_right_rounded, size: 18.0, color: tokens.textTertiary),
                    onTap: () => _openReceived(rec),
                  ),
                );
              }),
          ],
        ]),
      ),
    );
  }
}
