import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../design_system/components/ambient_background.dart';
import '../../../design_system/components/empty_error_view.dart';
import '../../../design_system/components/soft_button.dart';
import '../../../design_system/components/soft_card.dart';
import '../../../design_system/components/soft_dialog.dart';
import '../../../design_system/components/soft_switch.dart';
import '../../../design_system/feedback/app_feedback.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';
import 'sources_sheets_and_bars.dart';

/// 书源管理与探活中心：分组筛选、并发测速、远程/粘贴/文件三合一导入与导出清理
class SourcesPage extends ConsumerStatefulWidget {
  const SourcesPage({super.key});

  @override
  ConsumerState<SourcesPage> createState() => _SourcesPageState();
}

class _SourcesPageState extends ConsumerState<SourcesPage> {
  bool _probing = false;
  String _selectedFilter = kSourceFilterAll;

  Future<void> _probeAll() async {
    if (_probing) return;
    setState(() => _probing = true);
    try {
      await ref.read(sourceRepositoryProvider).probeAllSources();
      if (mounted) AppFeedback.showToast(context, '全部书源探活完成');
    } finally {
      if (mounted) setState(() => _probing = false);
    }
  }

  Future<void> _openImportSheet() => SourcesImportSheet.show(
        context,
        onImported: (msg) {
          if (mounted) AppFeedback.showToast(context, msg);
        },
      );

  Future<void> _handleExportCustom(List<BookSource> all) async {
    final customCount = all.where((s) => !s.isBuiltin).length;
    if (customCount <= 0) {
      AppFeedback.showToast(context, '当前暂无自定义书源可导出', isError: true);
      return;
    }
    final json = await ref.read(sourceRepositoryProvider).exportCustomSourcesJson();
    if (!mounted) return;
    await showExportCustomSourcesSheet(context, jsonContent: json, count: customCount);
  }

  Future<void> _handleClearUnreachable() async {
    final ok = await SoftDialog.confirm(
      context,
      title: '清理失效自定义源',
      message: '将移除所有最近测速超时不可达的自定义书源，内置精选书源会完整保留。确定继续吗？',
      confirmLabel: '确认清理',
      isDangerous: true,
    );
    if (!ok || !mounted) return;
    final deleted = await ref.read(sourceRepositoryProvider).clearUnreachableCustomSources();
    if (!mounted) return;
    AppFeedback.showToast(
      context,
      deleted > 0 ? '已清理 $deleted 条失效自定义书源' : '当前没有不可达的自定义书源',
    );
  }

  static String _groupOf(BookSource s) =>
      s.groupName.trim().isEmpty ? '默认' : s.groupName.trim();

  List<BookSource> _filterList(List<BookSource> all, String activeFilter) {
    if (activeFilter == kSourceFilterAll) return all;
    if (activeFilter == kSourceFilterUnreachable) {
      return all.where((s) => s.lastLatencyMs == -1).toList();
    }
    return all.where((s) => _groupOf(s) == activeFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final repo = ref.watch(sourceRepositoryProvider);

    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: StreamBuilder<List<BookSource>>(
            stream: repo.watchAllSources(),
            builder: (context, snap) {
              final all = snap.data ?? const <BookSource>[];
              final isCustomGroup = _selectedFilter != kSourceFilterAll &&
                  _selectedFilter != kSourceFilterUnreachable;
              final groupExists = !isCustomGroup ||
                  all.any((s) => _groupOf(s) == _selectedFilter);
              final effectiveFilter =
                  groupExists ? _selectedFilter : kSourceFilterAll;
              if (!groupExists && snap.hasData) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _selectedFilter != kSourceFilterAll) {
                    setState(() => _selectedFilter = kSourceFilterAll);
                  }
                });
              }
              final filtered = _filterList(all, effectiveFilter);

              return Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 4.0),
                  child: Row(children: [
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 19.0, color: tokens.textPrimary),
                    ),
                    Expanded(
                      child: Text('书源生态管理',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SoftTypography.sectionTitle
                              .copyWith(color: tokens.textPrimary)),
                    ),
                    SoftButton(
                      label: _probing ? '测速中' : '探活测速',
                      icon: Icons.speed_rounded,
                      tone: SoftButtonTone.tonal,
                      compact: true,
                      isLoading: _probing,
                      onPressed: _probeAll,
                    ),
                    const SizedBox(width: 6.0),
                    SoftButton(
                      label: '导入',
                      icon: Icons.add_rounded,
                      compact: true,
                      onPressed: _openImportSheet,
                    ),
                    PopupMenuButton<String>(
                      tooltip: '更多操作',
                      color: tokens.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(SoftRadius.subCard),
                        side: BorderSide(color: tokens.borderSubtle, width: 0.8),
                      ),
                      icon: Icon(Icons.more_horiz_rounded, color: tokens.textPrimary),
                      onSelected: (val) {
                        if (val == 'export') _handleExportCustom(all);
                        if (val == 'clear') _handleClearUnreachable();
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'export',
                          child: Row(children: [
                            Icon(Icons.ios_share_rounded, size: 18.0, color: tokens.textPrimary),
                            const SizedBox(width: 10.0),
                            Text('导出自定义书源',
                                style: SoftTypography.body.copyWith(color: tokens.textPrimary)),
                          ]),
                        ),
                        PopupMenuItem(
                          value: 'clear',
                          child: Row(children: [
                            Icon(Icons.cleaning_services_outlined, size: 18.0, color: tokens.danger),
                            const SizedBox(width: 10.0),
                            Text('清理失效自定义源',
                                style: SoftTypography.body.copyWith(color: tokens.danger)),
                          ]),
                        ),
                      ],
                    ),
                  ]),
                ),
                SourcesGroupFilterBar(
                  sources: all,
                  selectedFilter: effectiveFilter,
                  onSelect: (f) => setState(() => _selectedFilter = f),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? EmptyErrorView(
                          icon: Icons.dns_outlined,
                          title: effectiveFilter == kSourceFilterUnreachable
                              ? '暂无异常书源'
                              : '该分组暂无书源',
                          description: effectiveFilter == kSourceFilterUnreachable
                              ? '所有已探活书源响应正常，或尚未执行探活测速'
                              : '可切换至「全部」查看或导入新的书源规则',
                          actionLabel: effectiveFilter == kSourceFilterAll ? null : '查看全部书源',
                          onAction: effectiveFilter == kSourceFilterAll
                              ? null
                              : () => setState(() => _selectedFilter = kSourceFilterAll),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            SoftSpacing.lg,
                            SoftSpacing.sm,
                            SoftSpacing.lg,
                            SoftSpacing.xxl,
                          ),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: SoftSpacing.md),
                          itemBuilder: (ctx, i) {
                            final src = filtered[i];
                            return _SourceRowCard(
                              source: src,
                              onToggle: (v) => repo.setEnabled(src.id, v),
                              onDelete: src.isBuiltin
                                  ? null
                                  : () async {
                                      final ok = await SoftDialog.confirm(
                                        context,
                                        title: '删除自定义书源',
                                        message: '确定删除「${src.name}」吗？',
                                        confirmLabel: '删除',
                                        isDangerous: true,
                                      );
                                      if (ok) await repo.deleteCustomSource(src.id);
                                    },
                            );
                          },
                        ),
                ),
              ]);
            },
          ),
        ),
      ),
    );
  }
}

class _SourceRowCard extends StatelessWidget {
  const _SourceRowCard({
    required this.source,
    required this.onToggle,
    this.onDelete,
  });

  final BookSource source;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final latency = source.lastLatencyMs;
    final statusColor = latency == null
        ? tokens.textTertiary
        : (latency < 0 ? tokens.danger : tokens.success);
    final statusText =
        latency == null ? '未测速' : (latency < 0 ? '超时不可达' : '${latency}ms');

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: SoftCard(
        padding: const EdgeInsets.symmetric(horizontal: SoftSpacing.lg, vertical: SoftSpacing.md),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(source.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SoftTypography.cardTitle.copyWith(color: tokens.textPrimary)),
                ),
                const SizedBox(width: 8.0),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(SoftRadius.pill),
                  ),
                  child: Text(source.groupName,
                      style: SoftTypography.micro.copyWith(color: tokens.textSecondary)),
                ),
              ]),
              const SizedBox(height: 4.0),
              Text(
                '${source.charset.toUpperCase()} · $statusText · ${source.baseUrl}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SoftTypography.micro.copyWith(color: statusColor),
              ),
            ]),
          ),
          if (onDelete != null)
            IconButton(
              tooltip: '删除此书源',
              constraints: const BoxConstraints(minWidth: 40.0, minHeight: 40.0),
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline_rounded, size: 19.0, color: tokens.danger),
            ),
          SoftSwitch(
            value: source.enabled,
            onChanged: onToggle,
            semanticLabel: '启用${source.name}',
          ),
        ]),
      ),
    );
  }
}
