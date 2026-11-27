import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../design_system/components/book_cover.dart';
import '../../design_system/tokens/soft_metrics.dart';
import '../../design_system/tokens/soft_tokens.dart';
import 'tts_controller.dart';

/// Modern Soft UI v4 全局悬浮迷你听书胶囊（悬浮于 `RootShell` 底栏 `SublimeFloatingDock` 正上方）
class GlobalTtsMiniCapsule extends ConsumerWidget {
  const GlobalTtsMiniCapsule({super.key, this.onTapOverride});

  final VoidCallback? onTapOverride;
  static const double height = 56.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tts = ref.watch(ttsControllerProvider);
    final active = tts.isActive && (tts.bookId?.isNotEmpty ?? false);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        alignment: Alignment.bottomCenter,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.35),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: active
          ? _MiniCapsuleBody(
              key: const ValueKey('global_tts_mini_capsule_active'),
              tts: tts,
              onTapCapsule: onTapOverride ??
                  () => context.push(
                        '/reader/${tts.bookId}?chapter=${tts.chapterIndex}',
                      ),
              onTogglePlayPause: () =>
                  ref.read(ttsControllerProvider.notifier).togglePlayPause(),
              onStop: () => ref.read(ttsControllerProvider.notifier).stop(),
            )
          : const SizedBox.shrink(key: ValueKey('global_tts_mini_capsule_idle')),
    );
  }
}

class _MiniCapsuleBody extends StatelessWidget {
  const _MiniCapsuleBody({
    super.key,
    required this.tts,
    required this.onTapCapsule,
    required this.onTogglePlayPause,
    required this.onStop,
  });

  final TtsState tts;
  final VoidCallback onTapCapsule;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final title = tts.bookTitle.isNotEmpty ? tts.bookTitle : '正在听书';
    final snippet = tts.currentParagraphText;
    final chapter = tts.chapterTitle.trim();
    final subtitle = chapter.isNotEmpty
        ? (snippet.isNotEmpty ? '$chapter · $snippet' : chapter)
        : (snippet.isNotEmpty ? snippet : (tts.isPlaying ? '正在朗读' : '已暂停'));

    return Padding(
      padding: const EdgeInsets.fromLTRB(SoftSpacing.xl, 0, SoftSpacing.xl, 10.0),
      child: Center(
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420.0),
          child: CustomPaint(
            painter: _HollowCapsuleShadowPainter(
              radius: GlobalTtsMiniCapsule.height / 2,
              shadowColor: tokens.shadowColor,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(SoftRadius.pill),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24.0, sigmaY: 24.0),
                child: Material(
                  color: tokens.dockBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SoftRadius.pill),
                    side: BorderSide(color: tokens.borderSubtle, width: 0.9),
                  ),
                  child: SizedBox(
                    height: GlobalTtsMiniCapsule.height,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10.0, 0, 8.0, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              button: true,
                              label: '回到阅读器：$title',
                              child: InkWell(
                                borderRadius: BorderRadius.circular(SoftRadius.pill),
                                onTap: onTapCapsule,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6.0,
                                    horizontal: 2.0,
                                  ),
                                  child: Row(
                                    children: [
                                      _MiniCoverBadge(
                                        bookTitle: title,
                                        coverUrl: tts.coverUrl,
                                        isPlaying: tts.isPlaying,
                                      ),
                                      const SizedBox(width: 10.0),
                                      Expanded(
                                        child: _CapsuleTextMeta(
                                          title: title,
                                          subtitle: subtitle,
                                          sleepBadge: tts.formattedSleepBadge,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6.0),
                          Semantics(
                            button: true,
                            label: tts.isPlaying ? '暂停听书' : '继续听书',
                            child: Material(
                              color: tokens.accentSoft,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: onTogglePlayPause,
                                child: SizedBox(
                                  width: 36.0,
                                  height: 36.0,
                                  child: Icon(
                                    tts.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 20.0,
                                    color: tokens.accent,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2.0),
                          Semantics(
                            button: true,
                            label: '关闭听书',
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: onStop,
                              child: SizedBox(
                                width: 34.0,
                                height: 36.0,
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18.0,
                                  color: tokens.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CapsuleTextMeta extends StatelessWidget {
  const _CapsuleTextMeta({
    required this.title,
    required this.subtitle,
    required this.sleepBadge,
  });

  final String title, subtitle, sleepBadge;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SoftTypography.caption.copyWith(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
            if (sleepBadge.isNotEmpty) ...[
              const SizedBox(width: 6.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.5),
                decoration: BoxDecoration(
                  color: tokens.accentSoft,
                  borderRadius: BorderRadius.circular(SoftRadius.pill),
                ),
                child: Text(
                  sleepBadge,
                  style: SoftTypography.micro.copyWith(
                    color: tokens.accent,
                    fontSize: 9.5,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2.0),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: SoftTypography.micro.copyWith(
            color: tokens.textSecondary,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _MiniCoverBadge extends StatelessWidget {
  const _MiniCoverBadge({
    required this.bookTitle,
    required this.coverUrl,
    required this.isPlaying,
  });

  final String bookTitle, coverUrl;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final hasCover = coverUrl.trim().isNotEmpty;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (hasCover)
          BookCover(title: bookTitle, coverUrl: coverUrl, width: 30.0, height: 40.0, radius: 8.0)
        else
          Container(
            width: 30.0,
            height: 40.0,
            decoration: BoxDecoration(
              color: tokens.accentSoft,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: tokens.borderSubtle, width: 0.7),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.headphones_rounded, size: 16.0, color: tokens.accent),
          ),
        Positioned(
          right: -2.0,
          bottom: -2.0,
          child: Container(
            width: 11.0,
            height: 11.0,
            decoration: BoxDecoration(color: tokens.card, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: isPlaying ? 7.5 : 6.5,
              height: isPlaying ? 7.5 : 6.5,
              decoration: BoxDecoration(
                color: isPlaying ? tokens.accent : tokens.textTertiary,
                shape: BoxShape.circle,
                boxShadow: isPlaying
                    ? [
                        BoxShadow(
                          color: tokens.accent.withValues(alpha: 0.48),
                          blurRadius: 5.0,
                          spreadRadius: 0.5,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HollowCapsuleShadowPainter extends CustomPainter {
  const _HollowCapsuleShadowPainter({required this.radius, required this.shadowColor});
  final double radius;
  final Color shadowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final innerPath = Path()..addRRect(rrect);
    canvas.save();
    final outerBounds = Path()..addRect(rect.inflate(40.0));
    canvas.clipPath(Path.combine(PathOperation.difference, outerBounds, innerPath));
    final paint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14.0);
    canvas.drawRRect(rrect.shift(const Offset(0, 5.0)), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HollowCapsuleShadowPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.shadowColor != shadowColor;
}
