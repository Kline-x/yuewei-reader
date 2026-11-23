import 'package:flutter/material.dart';
import '../tokens/soft_tokens.dart';

/// 静谧纸感弥散微光背景
/// 使用 RepaintBoundary 隔离纯 RadialGradient（替代高耗电 MaskFilter.blur）
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(color: tokens.canvas),
              child: CustomPaint(
                painter: _AmbientMeshPainter(
                  glow1: tokens.glowPrimary,
                  glow2: tokens.glowSecondary,
                  glow3: tokens.glowTertiary,
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _AmbientMeshPainter extends CustomPainter {
  const _AmbientMeshPainter({
    required this.glow1,
    required this.glow2,
    required this.glow3,
  });

  final Color glow1;
  final Color glow2;
  final Color glow3;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBlob(
      canvas,
      center: Offset(size.width * 0.14, size.height * 0.08),
      radius: size.width * 0.72,
      color: glow1,
    );
    _paintBlob(
      canvas,
      center: Offset(size.width * 0.92, size.height * 0.38),
      radius: size.width * 0.65,
      color: glow2,
    );
    _paintBlob(
      canvas,
      center: Offset(size.width * 0.25, size.height * 0.85),
      radius: size.width * 0.68,
      color: glow3,
    );
  }

  void _paintBlob(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0.0)],
        stops: const [0.0, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _AmbientMeshPainter oldDelegate) {
    return oldDelegate.glow1 != glow1 ||
        oldDelegate.glow2 != glow2 ||
        oldDelegate.glow3 != glow3;
  }
}
