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
import '../../../design_system/feedback/app_feedback.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';
import '../wifi/wifi_transfer_server.dart';
import 'import_transfer_cards.dart';

/// 本机导入与局域网 Wi-Fi 无线传书工作台（离开页面自动关闭局域网服务）
class ImportAndTransferPage extends ConsumerStatefulWidget {
  const ImportAndTransferPage({super.key});

  @override
  ConsumerState<ImportAndTransferPage> createState() =>
      _ImportAndTransferPageState();
}

class _ImportAndTransferPageState extends ConsumerState<ImportAndTransferPage> {
  late final WifiTransferServer _server;
  StreamSubscription<WifiReceivedItem>? _sub;
  final List<WifiReceivedEntry> _received = [];
  Book? _lastImported;
  bool _importing = false;
  bool _togglingWifi = false;

  @override
  void initState() {
    super.initState();
    _server = ref.read(wifiTransferServerProvider);
    _sub = _server.receivedStream.listen(_onWifiItem);
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (_server.isRunning) {
      unawaited(_server.stop());
    }
    super.dispose();
  }

  Future<void> _onWifiItem(WifiReceivedItem item) async {
    final directId = item.bookId?.trim();
    final bookId = item.kind == 'book'
        ? ((directId != null && directId.isNotEmpty)
            ? directId
            : await _findLocalBookId(item.displayTitle))
        : null;
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
    try {
      enable ? await _server.start() : await _server.stop();
      if (mounted) {
        AppFeedback.showToast(
          context,
          enable ? 'Wi-Fi 传书服务已开启' : 'Wi-Fi 传书服务已停止',
        );
      }
    } catch (_) {
      if (mounted) {
        AppFeedback.showToast(context, '启停 Wi-Fi 服务失败，请检查网络权限', isError: true);
      }
    } finally {
      if (mounted) setState(() => _togglingWifi = false);
    }
  }

  Future<void> _copyText(String text, String toast) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) AppFeedback.showToast(context, toast);
  }

  void _goShelf() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go('/shelf');
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _openReceived(WifiReceivedEntry rec) async {
    if (rec.item.kind == 'source') {
      context.push('/sources');
      return;
    }
    final directId = rec.item.bookId?.trim();
    final id = (directId != null && directId.isNotEmpty)
        ? directId
        : (rec.bookId ?? await _findLocalBookId(rec.item.displayTitle));
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
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 19.0,
                      color: tokens.textPrimary,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'IMPORT & TRANSFER',
                          style: SoftTypography.eyebrow
                              .copyWith(color: tokens.accent),
                        ),
                        Text(
                          '导入与传书',
                          style: SoftTypography.sectionTitle.copyWith(
                            color: tokens.textPrimary,
                            fontSize: 18.0,
                          ),
                        ),
                      ],
                    ),
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
                    LocalImportCard(
                      importing: _importing,
                      lastImported: _lastImported,
                      onPickAndImport: _pickAndImport,
                      onOpenBook: (id) => context.push('/reader/$id'),
                      onGoShelf: _goShelf,
                    ),
                    const SizedBox(height: SoftSpacing.lg),
                    WifiTransferCard(
                      server: server,
                      togglingWifi: _togglingWifi,
                      received: _received,
                      onToggleWifi: _toggleWifi,
                      onCopyText: _copyText,
                      onOpenReceived: _openReceived,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
