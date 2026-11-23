import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../design_system/components/soft_bottom_sheet.dart';
import '../../../design_system/components/soft_button.dart';
import '../../../design_system/components/soft_card.dart';
import '../../../design_system/components/soft_dialog.dart';
import '../../../design_system/feedback/app_feedback.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';
import '../../download/download_manager.dart';

/// 离线缓存调度面板（显式区分完成 / 部分失败 / 失败 / 取消，杜绝局部成功误报100%）
class ReaderDownloadSheet extends ConsumerStatefulWidget {
  const ReaderDownloadSheet({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.totalChapters,
    required this.currentChapterIndex,
  });

  final String bookId;
  final String bookTitle;
  final int totalChapters;
  final int currentChapterIndex;

  static Future<void> show(
    BuildContext context, {
    required String bookId,
    required String bookTitle,
    required int totalChapters,
    required int currentChapterIndex,
  }) {
    return SoftBottomSheet.show(
      context,
      title: '离线缓存',
      subtitle: bookTitle,
      headerIcon: Icons.download_for_offline_rounded,
      maxHeightFactor: 0.72,
      builder: (_) => ReaderDownloadSheet(
        bookId: bookId,
        bookTitle: bookTitle,
        totalChapters: totalChapters,
        currentChapterIndex: currentChapterIndex,
      ),
    );
  }

  @override
  ConsumerState<ReaderDownloadSheet> createState() =>
      _ReaderDownloadSheetState();
}

class _ReaderDownloadSheetState extends ConsumerState<ReaderDownloadSheet> {
  StreamSubscription<DownloadProgressSnapshot>? _sub;
  DownloadProgressSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    final mgr = ref.read(downloadManagerProvider);
    _snapshot = mgr.currentOf(widget.bookId);
    _sub = mgr.progressStream
        .where((s) => s.bookId == widget.bookId)
        .listen((s) {
      if (mounted) setState(() => _snapshot = s);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final db = ref.watch(appDatabaseProvider);
    final mgr = ref.read(downloadManagerProvider);
    final snap = _snapshot;

    return StreamBuilder<(int, int)>(
      stream: db.watchBookCacheStats(widget.bookId),
      builder: (context, cacheSnap) {
        final cachedCount = cacheSnap.data?.$1 ?? 0;
        final cachedBytes = cacheSnap.data?.$2 ?? 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(SoftSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SoftCard(
                backgroundColor: tokens.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '已缓存 $cachedCount / ${widget.totalChapters} 章',
                          style: SoftTypography.cardTitle
                              .copyWith(color: tokens.textPrimary),
                        ),
                        Text(
                          _formatBytes(cachedBytes),
                          style: SoftTypography.caption
                              .copyWith(color: tokens.accent),
                        ),
                      ],
                    ),
                    if (snap != null &&
                        snap.status != DownloadTaskStatus.idle) ...[
                      const SizedBox(height: SoftSpacing.md),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(SoftRadius.pill),
                        child: LinearProgressIndicator(
                          value: snap.ratio,
                          minHeight: 6.0,
                          color: snap.status == DownloadTaskStatus.failed
                              ? tokens.danger
                              : (snap.status == DownloadTaskStatus.partialFailed
                                  ? tokens.warning
                                  : tokens.accent),
                          backgroundColor: tokens.borderSubtle,
                        ),
                      ),
                      const SizedBox(height: SoftSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _statusLabel(snap),
                              style: SoftTypography.caption.copyWith(
                                color: snap.status == DownloadTaskStatus.failed
                                    ? tokens.danger
                                    : tokens.textSecondary,
                              ),
                            ),
                          ),
                          if (snap.isRunning)
                            TextButton(
                              onPressed: () => mgr.cancelDownload(widget.bookId),
                              child: Text(
                                '取消',
                                style: SoftTypography.caption
                                    .copyWith(color: tokens.danger),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: SoftSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: SoftButton(
                      label: '缓存后 20 章',
                      tone: SoftButtonTone.tonal,
                      onPressed: snap?.isRunning == true
                          ? null
                          : () => mgr.startDownload(
                                bookId: widget.bookId,
                                startIndex: widget.currentChapterIndex,
                                maxCount: 20,
                              ),
                    ),
                  ),
                  const SizedBox(width: SoftSpacing.md),
                  Expanded(
                    child: SoftButton(
                      label: '缓存后 50 章',
                      tone: SoftButtonTone.primary,
                      onPressed: snap?.isRunning == true
                          ? null
                          : () => mgr.startDownload(
                                bookId: widget.bookId,
                                startIndex: widget.currentChapterIndex,
                                maxCount: 50,
                              ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SoftSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: SoftButton(
                      label: '缓存剩余全部',
                      tone: SoftButtonTone.tonal,
                      onPressed: snap?.isRunning == true
                          ? null
                          : () => mgr.startDownload(
                                bookId: widget.bookId,
                                startIndex: widget.currentChapterIndex,
                              ),
                    ),
                  ),
                  const SizedBox(width: SoftSpacing.md),
                  Expanded(
                    child: SoftButton(
                      label: '清空本书缓存',
                      tone: SoftButtonTone.danger,
                      onPressed: cachedCount == 0
                          ? null
                          : () async {
                              final ok = await SoftDialog.confirm(
                                context,
                                title: '清空缓存',
                                message: '确定删除本书已下载的 $cachedCount 章本地正文吗？阅读进度会完整保留。',
                                confirmLabel: '清空',
                                isDangerous: true,
                              );
                              if (!ok) return;
                              await ref
                                  .read(shelfRepositoryProvider)
                                  .clearBookChapterFiles(widget.bookId);
                              if (context.mounted) {
                                AppFeedback.showToast(context, '已清空本书离线缓存');
                              }
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(DownloadProgressSnapshot snap) {
    switch (snap.status) {
      case DownloadTaskStatus.downloading:
        final speed = snap.chaptersPerSec > 0
            ? ' · ${snap.chaptersPerSec.toStringAsFixed(1)} 章/秒'
            : '';
        return '缓存中 ${snap.completed}/${snap.total}$speed';
      case DownloadTaskStatus.completed:
        return '全部缓存就绪（${snap.completed} 章）';
      case DownloadTaskStatus.partialFailed:
        return snap.errorMessage ?? '部分章失败（${snap.failed} 章）';
      case DownloadTaskStatus.failed:
        return snap.errorMessage ?? '下载失败';
      case DownloadTaskStatus.cancelled:
        return '已取消（已完成 ${snap.completed}/${snap.total}）';
      case DownloadTaskStatus.idle:
        return '';
    }
  }
}
