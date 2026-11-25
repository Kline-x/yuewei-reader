import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/platform/host_bridge.dart';
import '../../../design_system/components/soft_bottom_sheet.dart';
import '../../../design_system/components/soft_button.dart';
import '../../../design_system/components/soft_text_field.dart';
import '../../../design_system/feedback/app_feedback.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';

const String kSourceFilterAll = '__all__';
const String kSourceFilterUnreachable = '__error__';

/// 书源顶部分组与异常状态横向胶囊筛选条
class SourcesGroupFilterBar extends StatelessWidget {
  const SourcesGroupFilterBar({
    super.key,
    required this.sources,
    required this.selectedFilter,
    required this.onSelect,
  });

  final List<BookSource> sources;
  final String selectedFilter;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final groupCounts = <String, int>{};
    var errorCount = 0;
    for (final s in sources) {
      final g = s.groupName.trim().isEmpty ? '默认' : s.groupName.trim();
      groupCounts[g] = (groupCounts[g] ?? 0) + 1;
      if (s.lastLatencyMs == -1) errorCount++;
    }

    final chips = <({String key, String label, bool isDanger})>[
      (key: kSourceFilterAll, label: '全部 (${sources.length})', isDanger: false),
      ...groupCounts.entries.map((e) => (key: e.key, label: '${e.key} (${e.value})', isDanger: false)),
      (key: kSourceFilterUnreachable, label: '异常 ($errorCount)', isDanger: errorCount > 0),
    ];

    return SizedBox(
      height: 44.0,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: SoftSpacing.lg, vertical: 4.0),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8.0),
        itemBuilder: (ctx, i) {
          final item = chips[i];
          final active = selectedFilter == item.key;
          final bg = active ? (item.isDanger ? tokens.danger : tokens.accent) : tokens.card;
          final fg = active
              ? (item.isDanger ? tokens.onDanger : tokens.onAccent)
              : (item.isDanger ? tokens.danger : tokens.textSecondary);
          return Material(
            color: bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SoftRadius.pill),
              side: active ? BorderSide.none : BorderSide(color: tokens.borderSubtle, width: 0.8),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onSelect(item.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                child: Center(
                  child: Text(
                    item.label,
                    style: SoftTypography.caption.copyWith(
                      color: fg,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 三合一书源导入底部抽屉（远程 URL 订阅 / 粘贴 JSON / 选择本地 .json 文件，严控 <= 320 行）
class SourcesImportSheet extends ConsumerStatefulWidget {
  const SourcesImportSheet({super.key, required this.onImported});

  final ValueChanged<String> onImported;

  static Future<void> show(BuildContext context, {required ValueChanged<String> onImported}) {
    return SoftBottomSheet.show(
      context,
      title: '导入 Legado 书源',
      subtitle: '支持远程订阅链接、粘贴文本或本地 .json 文件',
      headerIcon: Icons.file_download_outlined,
      maxHeightFactor: 0.80,
      builder: (_) => SourcesImportSheet(onImported: onImported),
    );
  }

  @override
  ConsumerState<SourcesImportSheet> createState() => _SourcesImportSheetState();
}

class _SourcesImportSheetState extends ConsumerState<SourcesImportSheet> {
  int _tabIndex = 0;
  bool _loading = false;
  final _urlCtrl = TextEditingController();
  final _jsonCtrl = TextEditingController();

  @override
  void dispose() {
    _urlCtrl.dispose();
    _jsonCtrl.dispose();
    super.dispose();
  }

  Future<void> _runImport(Future<String?> Function() action) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final msg = await action();
      if (!mounted || msg == null) return;
      Navigator.of(context).pop();
      widget.onImported(msg);
    } on FormatException catch (e) {
      if (mounted) AppFeedback.showToast(context, e.message, isError: true);
    } catch (e) {
      if (mounted) AppFeedback.showToast(context, '书源导入失败：$e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitUrl() {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      AppFeedback.showToast(context, '请输入远程书源订阅 URL', isError: true);
      return Future.value();
    }
    return _runImport(() async {
      final n = await ref.read(sourceRepositoryProvider).importFromUrl(url);
      return '已从远程订阅导入 $n 条书源';
    });
  }

  Future<void> _submitPaste() {
    final raw = _jsonCtrl.text.trim();
    if (raw.isEmpty) {
      AppFeedback.showToast(context, '请先粘贴书源 JSON 内容', isError: true);
      return Future.value();
    }
    return _runImport(() async {
      final n = await ref.read(sourceRepositoryProvider).importLegadoJson(raw);
      if (n <= 0) throw const FormatException('未识别到有效书源规则');
      return '成功导入 $n 条书源';
    });
  }

  Future<void> _pickJsonFile() => _runImport(() async {
        final picked = await HostBridge.instance.pickAndReadTextFile();
        if (picked == null) return null;
        final n = await ref.read(sourceRepositoryProvider).importLegadoJson(picked.content);
        if (n <= 0) throw const FormatException('所选文件未包含可识别的有效书源');
        return '已从 ${picked.name} 导入 $n 条书源';
      });

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    const tabs = ['远程 URL 订阅', '粘贴 JSON', '本地 .json'];
    return Padding(
      padding: const EdgeInsets.all(SoftSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(SoftRadius.pill),
              border: Border.all(color: tokens.borderSubtle, width: 0.8),
            ),
            child: Row(
              children: List.generate(tabs.length, (i) {
                final active = _tabIndex == i;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _loading ? null : () => setState(() => _tabIndex = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      decoration: BoxDecoration(
                        color: active ? tokens.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(SoftRadius.pill),
                      ),
                      child: Center(
                        child: Text(tabs[i], style: SoftTypography.caption.copyWith(
                          color: active ? tokens.onAccent : tokens.textSecondary,
                          fontWeight: FontWeight.w700,
                        )),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: SoftSpacing.lg),
          if (_tabIndex == 0) ...[
            SoftTextField(
              controller: _urlCtrl,
              hintText: '输入 https://... 远程 Legado JSON 订阅地址',
              prefixIcon: Icons.link_rounded,
              radius: SoftRadius.control,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitUrl(),
            ),
            const SizedBox(height: SoftSpacing.sm),
            Text('自动兼容 UTF-8 / GBK 编码响应，支持单对象或数组格式书源。',
                style: SoftTypography.caption.copyWith(color: tokens.textTertiary)),
            const SizedBox(height: SoftSpacing.lg),
            SoftButton(label: _loading ? '正在拉取解析…' : '拉取并导入书源', icon: Icons.cloud_download_outlined, expand: true, isLoading: _loading, onPressed: _submitUrl),
          ] else if (_tabIndex == 1) ...[
            SoftTextField(controller: _jsonCtrl, hintText: '粘贴 JSON 文本，例如 [{"bookSourceName": "...", ...}]', prefixIcon: null, maxLines: 6, radius: SoftRadius.subCard, textInputAction: TextInputAction.newline),
            const SizedBox(height: SoftSpacing.md),
            Row(children: [
              Expanded(child: SoftButton(
                label: '读取剪贴板', icon: Icons.content_paste_rounded, tone: SoftButtonTone.tonal, compact: true,
                onPressed: _loading ? null : () async {
                  final d = await Clipboard.getData(Clipboard.kTextPlain);
                  if ((d?.text ?? '').trim().isNotEmpty) _jsonCtrl.text = d!.text!.trim();
                },
              )),
              const SizedBox(width: SoftSpacing.sm),
              Expanded(child: SoftButton(label: '解析并导入', icon: Icons.check_rounded, compact: true, isLoading: _loading, onPressed: _submitPaste)),
            ]),
          ] else ...[
            Text('从手机文件管理器或云盘选取本地保存的 .json 书源文件，自动完成规则转换入库。',
                style: SoftTypography.body.copyWith(color: tokens.textSecondary)),
            const SizedBox(height: SoftSpacing.lg),
            SoftButton(label: _loading ? '正在读取导入…' : '选择本地 .json 书源文件', icon: Icons.folder_open_rounded, expand: true, isLoading: _loading, onPressed: _pickJsonFile),
          ],
        ],
      ),
    );
  }
}

/// 导出自定义书源底部抽屉（原生文件保存 + 复制剪贴板双通道兜底）
Future<void> showExportCustomSourcesSheet(
  BuildContext context, {
  required String jsonContent,
  required int count,
}) {
  var exporting = false;
  return SoftBottomSheet.show(
    context,
    title: '导出自定义书源',
    subtitle: '共 $count 条非内置书源 · 兼容 Legado 3.0 格式',
    headerIcon: Icons.ios_share_rounded,
    maxHeightFactor: 0.45,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => Padding(
        padding: const EdgeInsets.all(SoftSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SoftButton(
              label: '导出为 .json 文件',
              icon: Icons.save_alt_rounded,
              expand: true,
              isLoading: exporting,
              onPressed: exporting
                  ? null
                  : () async {
                      setSheetState(() => exporting = true);
                      try {
                        final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
                        final saved = await HostBridge.instance.exportTextFile(
                          fileName: 'yuewei_sources_$stamp.json',
                          content: jsonContent,
                        );
                        if (!ctx.mounted || saved == null) return;
                        Navigator.of(ctx).pop();
                        if (context.mounted) {
                          AppFeedback.showToast(context, '已导出书源文件：$saved');
                        }
                      } finally {
                        if (ctx.mounted) setSheetState(() => exporting = false);
                      }
                    },
            ),
            const SizedBox(height: SoftSpacing.sm),
            SoftButton(
              label: '复制书源 JSON（剪贴板兜底）',
              icon: Icons.copy_rounded,
              tone: SoftButtonTone.tonal,
              expand: true,
              onPressed: exporting
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: jsonContent));
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      if (context.mounted) {
                        AppFeedback.showToast(context, '已复制 $count 条自定义书源 JSON');
                      }
                    },
            ),
          ],
        ),
      ),
    ),
  );
}
