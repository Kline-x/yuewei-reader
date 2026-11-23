import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../design_system/components/ambient_background.dart';
import '../../../design_system/components/soft_bottom_sheet.dart';
import '../../../design_system/components/soft_button.dart';
import '../../../design_system/components/soft_card.dart';
import '../../../design_system/components/soft_dialog.dart';
import '../../../design_system/components/soft_switch.dart';
import '../../../design_system/components/soft_text_field.dart';
import '../../../design_system/feedback/app_feedback.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';

/// 书源管理与探活中心：一键测速、启停、支持 Legado 3.0 JSON 导入
class SourcesPage extends ConsumerStatefulWidget {
  const SourcesPage({super.key});

  @override
  ConsumerState<SourcesPage> createState() => _SourcesPageState();
}

class _SourcesPageState extends ConsumerState<SourcesPage> {
  bool _probing = false;

  Future<void> _probeAll() async {
    if (_probing) return;
    setState(() => _probing = true);
    await ref.read(sourceRepositoryProvider).probeAllSources();
    if (mounted) {
      setState(() => _probing = false);
      AppFeedback.showToast(context, '全部书源探活完成');
    }
  }

  Future<void> _openImportSheet() async {
    final jsonCtrl = TextEditingController();
    await SoftBottomSheet.show(
      context,
      title: '导入 Legado 书源',
      subtitle: '粘贴标准 Legado 书源 JSON 对象或数组',
      headerIcon: Icons.file_download_outlined,
      maxHeightFactor: 0.72,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(SoftSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SoftTextField(
              controller: jsonCtrl,
              hintText: '粘贴 JSON 文本，例如 [{"bookSourceName": "...", ...}]',
              prefixIcon: null,
              maxLines: 7,
              radius: SoftRadius.subCard,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: SoftSpacing.lg),
            SoftButton(
              label: '解析并导入书源',
              icon: Icons.check_rounded,
              expand: true,
              onPressed: () async {
                final raw = jsonCtrl.text.trim();
                if (raw.isEmpty) {
                  AppFeedback.showToast(ctx, '请先粘贴书源 JSON 内容', isError: true);
                  return;
                }
                try {
                  final count = await ref
                      .read(sourceRepositoryProvider)
                      .importLegadoJson(raw);
                  if (!ctx.mounted) return;
                  if (count <= 0) {
                    AppFeedback.showToast(ctx, '未识别到有效书源规则', isError: true);
                    return;
                  }
                  Navigator.of(ctx).pop();
                  if (!mounted) return;
                  AppFeedback.showToast(context, '成功导入 $count 条书源');
                } catch (_) {
                  if (ctx.mounted) {
                    AppFeedback.showToast(ctx, 'JSON 格式无效，请检查后重试', isError: true);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
    jsonCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final repo = ref.watch(sourceRepositoryProvider);

    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8.0, 8.0, 16.0, 8.0),
                child: Row(
                  children: [
                    IconButton(
                      constraints:
                          const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 19.0,
                        color: tokens.textPrimary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '书源生态管理',
                        style: SoftTypography.sectionTitle
                            .copyWith(color: tokens.textPrimary),
                      ),
                    ),
                    SoftButton(
                      label: _probing ? '测速中' : '探活测速',
                      icon: Icons.speed_rounded,
                      tone: SoftButtonTone.tonal,
                      compact: true,
                      isLoading: _probing,
                      onPressed: _probeAll,
                    ),
                    const SizedBox(width: 8.0),
                    SoftButton(
                      label: '导入',
                      icon: Icons.add_rounded,
                      compact: true,
                      onPressed: _openImportSheet,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<BookSource>>(
                  stream: repo.watchAllSources(),
                  builder: (context, snap) {
                    final list = snap.data ?? const [];
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        SoftSpacing.lg,
                        SoftSpacing.sm,
                        SoftSpacing.lg,
                        SoftSpacing.xxl,
                      ),
                      itemCount: list.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: SoftSpacing.md),
                      itemBuilder: (ctx, i) {
                        final src = list[i];
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
                    );
                  },
                ),
              ),
            ],
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
    final statusText = latency == null
        ? '未测速'
        : (latency < 0 ? '超时不可达' : '${latency}ms');

    return SoftCard(
      padding: const EdgeInsets.symmetric(
        horizontal: SoftSpacing.lg,
        vertical: SoftSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        source.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SoftTypography.cardTitle
                            .copyWith(color: tokens.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7.0,
                        vertical: 2.0,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius: BorderRadius.circular(SoftRadius.pill),
                      ),
                      child: Text(
                        source.groupName,
                        style: SoftTypography.micro
                            .copyWith(color: tokens.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4.0),
                Text(
                  '${source.charset.toUpperCase()} · $statusText · ${source.baseUrl}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SoftTypography.micro.copyWith(color: statusColor),
                ),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              constraints:
                  const BoxConstraints(minWidth: 40.0, minHeight: 40.0),
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 19.0,
                color: tokens.danger,
              ),
            ),
          SoftSwitch(
            value: source.enabled,
            onChanged: onToggle,
            semanticLabel: '启用${source.name}',
          ),
        ],
      ),
    );
  }
}
