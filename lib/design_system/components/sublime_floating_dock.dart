import 'dart:ui';
import 'package:flutter/material.dart';
import '../tokens/soft_metrics.dart';
import '../tokens/soft_tokens.dart';

class DockNavItem {
  const DockNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Modern Soft UI v4 悬浮毛玻璃药丸胶囊底栏
/// 使用镂空轮廓投影 Painter，彻底根除实心外阴影穿透半透背景导致胶囊发灰变脏的顽疾。
class SublimeFloatingDock extends StatelessWidget {
  const SublimeFloatingDock({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<DockNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const double height = 64.0;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        SoftSpacing.xl,
        0,
        SoftSpacing.xl,
        bottomInset + 14.0,
      ),
      child: Center(
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420.0),
          child: CustomPaint(
            painter: _HollowPillShadowPainter(
              radius: height / 2,
              shadowColor: tokens.shadowColor,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(SoftRadius.pill),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24.0, sigmaY: 24.0),
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: tokens.dockBg,
                    borderRadius: BorderRadius.circular(SoftRadius.pill),
                    border: Border.all(color: tokens.borderSubtle, width: 0.9),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Row(
                    children: List.generate(items.length, (i) {
                      final item = items[i];
                      final selected = i == currentIndex;
                      return Expanded(
                        child: Semantics(
                          selected: selected,
                          button: true,
                          label: item.label,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onTap(i),
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14.0,
                                  vertical: 6.0,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? tokens.accentSoft
                                      : Colors.transparent,
                                  borderRadius:
                                      BorderRadius.circular(SoftRadius.pill),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      selected ? item.activeIcon : item.icon,
                                      size: 20.0,
                                      color: selected
                                          ? tokens.accent
                                          : tokens.textSecondary,
                                    ),
                                    const SizedBox(height: 2.0),
                                    Text(
                                      item.label,
                                      maxLines: 1,
                                      style: SoftTypography.micro.copyWith(
                                        color: selected
                                            ? tokens.accent
                                            : tokens.textSecondary,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
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

class _HollowPillShadowPainter extends CustomPainter {
  const _HollowPillShadowPainter({
    required this.radius,
    required this.shadowColor,
  });

  final double radius;
  final Color shadowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final innerPath = Path()..addRRect(rrect);

    canvas.save();
    // 裁剪排除胶囊内部，使阴影绝对不会穿透染脏毛玻璃底色
    final outerBounds = Path()..addRect(rect.inflate(48.0));
    final hollowClip =
        Path.combine(PathOperation.difference, outerBounds, innerPath);
    canvas.clipPath(hollowClip);

    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18.0);
    canvas.drawRRect(rrect.shift(const Offset(0, 8.0)), shadowPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HollowPillShadowPainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.shadowColor != shadowColor;
  }
}
