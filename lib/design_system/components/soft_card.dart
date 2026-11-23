import 'package:flutter/material.dart';
import '../tokens/soft_metrics.dart';
import '../tokens/soft_tokens.dart';

/// 现代静谧纸感连续曲率卡片（无生硬粗边框，微透描边+温和漫射投影）
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SoftSpacing.lg),
    this.margin,
    this.radius = SoftRadius.card,
    this.backgroundColor,
    this.borderColor,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final bg = backgroundColor ?? tokens.card;
    final border = borderColor ?? tokens.borderSubtle;
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: border, width: 0.8),
    );

    Widget content = Container(
      padding: padding,
      child: child,
    );

    if (onTap != null || onLongPress != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          onLongPress: onLongPress,
          child: content,
        ),
      );
    }

    return Container(
      margin: margin,
      decoration: ShapeDecoration(
        color: bg,
        shape: shape,
        shadows: [
          BoxShadow(
            color: tokens.shadowColor,
            offset: const Offset(0, 8),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}
