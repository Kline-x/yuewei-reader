import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../design_system/components/soft_bottom_sheet.dart';
import '../../design_system/tokens/soft_metrics.dart';
import '../../design_system/tokens/soft_tokens.dart';
import '../reader/engine/page_models.dart';
import 'tts_controller.dart';

/// Modern Soft UI 沉浸听书控制抽屉（≤ 280 行）
class TtsControlSheet extends ConsumerWidget {
  const TtsControlSheet({super.key});

  static Future<void> show(BuildContext context) => SoftBottomSheet.show(
        context, title: '沉浸听书', headerIcon: Icons.headphones_rounded,
        maxHeightFactor: 0.84, builder: (_) => const TtsControlSheet(),
      );

  static String formatRateLabel(double rate) {
    final s = rate.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
    return '${s.endsWith('.') ? '${s}0' : s}x';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = SoftTokens.of(context);
    final tts = ref.watch(ttsControllerProvider);
    final notifier = ref.read(ttsControllerProvider.notifier);
    final totalParas = tts.paragraphs.length;
    final paraPos = totalParas > 0 ? '${tts.paragraphIndex + 1}/$totalParas 段' : '';
    final preview = tts.currentParagraphText.isNotEmpty
        ? tts.currentParagraphText
        : (tts.isActive ? '正在准备段落内容…' : '朗读已停止');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(SoftSpacing.xl, SoftSpacing.md, SoftSpacing.xl, SoftSpacing.xxl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(tts.chapterTitle.isNotEmpty ? tts.chapterTitle : '当前章节',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: SoftTypography.cardTitle.copyWith(color: tokens.textPrimary)),
          ),
          if (paraPos.isNotEmpty) ...[
            const SizedBox(width: 8.0),
            Text(paraPos, style: SoftTypography.micro.copyWith(color: tokens.textSecondary)),
          ],
        ]),
        const SizedBox(height: SoftSpacing.sm),
        if (tts.lastError != null && tts.lastError!.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: tokens.danger.withValues(alpha: tokens.isDark ? 0.14 : 0.06),
              borderRadius: BorderRadius.circular(SoftRadius.subCard),
              border: Border.all(color: tokens.danger.withValues(alpha: 0.35), width: 0.8),
            ),
            child: Row(children: [
              Icon(Icons.error_outline_rounded, size: 16.0, color: tokens.danger),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  tts.lastError!,
                  style: SoftTypography.caption.copyWith(color: tokens.danger, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
          const SizedBox(height: SoftSpacing.sm),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(SoftSpacing.md),
          decoration: BoxDecoration(
            color: tokens.surface, borderRadius: BorderRadius.circular(SoftRadius.subCard),
            border: Border.all(color: tokens.borderSubtle, width: 0.8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(tts.isPlaying ? Icons.graphic_eq_rounded : Icons.pause_circle_outline_rounded,
                  size: 15.0, color: tokens.accent),
              const SizedBox(width: 6.0),
              Text(tts.isPlaying ? '正在朗读' : (tts.isPaused ? '已暂停' : '已结束'),
                  style: SoftTypography.micro.copyWith(
                      color: tokens.textPrimary, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6.0),
            Text(preview, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: SoftTypography.body.copyWith(color: tokens.textPrimary, height: 1.55)),
          ]),
        ),
        const SizedBox(height: SoftSpacing.lg),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _StepBtn(icon: Icons.skip_previous_rounded, label: '上一章',
              enabled: tts.isActive && tts.chapterIndex > 0, onTap: notifier.previousChapter),
          _StepBtn(icon: Icons.fast_rewind_rounded, label: '上一段',
              enabled: tts.isActive, onTap: notifier.previousParagraph),
          Semantics(
            button: true, label: tts.isPlaying ? '暂停朗读' : '继续朗读',
            child: Material(
              color: tokens.accent, shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: tts.isActive ? notifier.togglePlayPause : null,
                child: SizedBox(
                  width: 56.0, height: 56.0,
                  child: Icon(tts.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 30.0, color: tokens.onAccent),
                ),
              ),
            ),
          ),
          _StepBtn(icon: Icons.fast_forward_rounded, label: '下一段',
              enabled: tts.isActive, onTap: notifier.nextParagraph),
          _StepBtn(
            icon: Icons.skip_next_rounded, label: '下一章',
            enabled: tts.isActive && (tts.totalChapters <= 0 || tts.chapterIndex + 1 < tts.totalChapters),
            onTap: notifier.nextChapter,
          ),
        ]),
        const SizedBox(height: SoftSpacing.lg),
        Text('朗读语速', style: SoftTypography.caption.copyWith(color: tokens.textSecondary)),
        const SizedBox(height: SoftSpacing.sm),
        _buildPillStrip([
          for (final r in TtsController.supportedRates)
            (label: formatRateLabel(r), selected: (tts.speechRate - r).abs() < 0.01, onTap: () => notifier.setSpeechRate(r)),
        ]),
        const SizedBox(height: SoftSpacing.lg),
        Row(children: [
          Text('睡眠定时', style: SoftTypography.caption.copyWith(color: tokens.textSecondary)),
          const Spacer(),
          if (tts.formattedSleepBadge.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 3.0),
              decoration: BoxDecoration(color: tokens.accentSoft, borderRadius: BorderRadius.circular(SoftRadius.pill)),
              child: Text('剩余 ${tts.formattedSleepBadge}', style: SoftTypography.micro.copyWith(color: tokens.accent)),
            ),
        ]),
        const SizedBox(height: SoftSpacing.sm),
        _buildPillStrip([
          for (final mode in TtsSleepTimerMode.values)
            (label: mode.label, selected: tts.sleepMode == mode, onTap: () => notifier.setSleepTimer(mode)),
        ]),
        const SizedBox(height: SoftSpacing.xl),
        SizedBox(
          width: double.infinity, height: 44.0,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: tokens.danger,
              backgroundColor: tokens.danger.withValues(alpha: tokens.isDark ? 0.14 : 0.06),
              side: BorderSide(color: tokens.danger.withValues(alpha: 0.35), width: 0.8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SoftRadius.pill)),
            ),
            onPressed: () async {
              await notifier.stop();
              if (context.mounted) Navigator.of(context).pop();
            },
            icon: const Icon(Icons.stop_circle_outlined, size: 18.0),
            label: Text('退出听书', style: SoftTypography.caption.copyWith(color: tokens.danger, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  Widget _buildPillStrip(List<({String label, bool selected, VoidCallback onTap})> items) => Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == items.length - 1 ? 0.0 : 6.0),
                child: _TtsPill(label: items[i].label, selected: items[i].selected, onTap: items[i].onTap),
              ),
            ),
        ],
      );
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.label, required this.enabled, required this.onTap});
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final fg = enabled ? tokens.textPrimary : tokens.textTertiary;
    return InkWell(
      borderRadius: BorderRadius.circular(12.0), onTap: enabled ? onTap : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48.0, minHeight: 48.0),
        child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 22.0, color: fg),
          const SizedBox(height: 2.0),
          Text(label, style: SoftTypography.micro.copyWith(color: fg)),
        ]),
      ),
    );
  }
}

class _TtsPill extends StatelessWidget {
  const _TtsPill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    return Material(
      color: selected ? tokens.accent : tokens.surface,
      borderRadius: BorderRadius.circular(SoftRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(SoftRadius.pill), onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 38.0),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SoftRadius.pill),
            border: Border.all(color: selected ? tokens.accent : tokens.borderSubtle, width: 0.8),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, maxLines: 1,
                style: SoftTypography.micro.copyWith(
                    color: selected ? tokens.onAccent : tokens.textPrimary, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

/// 阅读器沉浸态底部迷你听书悬浮胶囊（定位安全区上方，不压正文末行）
class ReaderTtsFloatingPill extends StatelessWidget {
  const ReaderTtsFloatingPill({
    super.key, required this.paper, required this.botSafe, required this.isPlaying,
    required this.sleepBadge, required this.onTapExpand, required this.onTogglePlayPause,
  });

  final ReaderPaperTheme paper;
  final double botSafe;
  final bool isPlaying;
  final String sleepBadge;
  final VoidCallback onTapExpand, onTogglePlayPause;

  @override
  Widget build(BuildContext context) {
    final borderColor = paper.accent.withValues(alpha: paper.isDark ? 0.56 : 0.42);
    final shadowColor = Colors.black.withValues(alpha: paper.isDark ? 0.40 : 0.12);
    return Positioned(
      left: 0, right: 0, bottom: botSafe + 6.0,
      child: SafeArea(
        top: false, bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Center(
            child: Material(
              color: paper.menuBg, borderRadius: BorderRadius.circular(SoftRadius.pill),
              child: Container(
                constraints: const BoxConstraints(minHeight: 38.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(SoftRadius.pill),
                  border: Border.all(color: borderColor, width: 0.9),
                  boxShadow: [BoxShadow(color: shadowColor, blurRadius: 12.0, offset: const Offset(0, 3))],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(
                    child: Semantics(
                      button: true, label: '展开听书控制面板',
                      child: InkWell(
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(SoftRadius.pill)),
                        onTap: onTapExpand,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14.0, 6.0, 8.0, 6.0),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.headphones_rounded, size: 16.0, color: paper.accent),
                            const SizedBox(width: 6.0),
                            Flexible(
                              child: Text(isPlaying ? '听书中' : '听书已暂停',
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: SoftTypography.caption.copyWith(color: paper.textColor, fontWeight: FontWeight.w700)),
                            ),
                            if (sleepBadge.isNotEmpty) ...[
                              const SizedBox(width: 6.0),
                              Text('· $sleepBadge',
                                  style: SoftTypography.micro.copyWith(
                                      color: paper.textColor, fontWeight: FontWeight.w600)),
                            ],
                          ]),
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true, label: isPlaying ? '暂停听书' : '继续听书',
                    child: InkWell(
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(SoftRadius.pill)),
                      onTap: onTogglePlayPause,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                        child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 19.0, color: paper.accent),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
