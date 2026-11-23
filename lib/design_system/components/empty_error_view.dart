import 'package:flutter/material.dart';
import '../tokens/soft_metrics.dart';
import '../tokens/soft_tokens.dart';
import 'soft_button.dart';

/// 统一空状态 / 网络错误提示视图（诚实呈现状态，绝不造假结果）
class EmptyErrorView extends StatelessWidget {
  const EmptyErrorView({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SoftSpacing.xxl,
          vertical: SoftSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60.0,
              height: 60.0,
              decoration: BoxDecoration(
                color: tokens.accentSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28.0, color: tokens.accent),
            ),
            const SizedBox(height: SoftSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: SoftTypography.sectionTitle
                  .copyWith(color: tokens.textPrimary),
            ),
            if (description != null && description!.isNotEmpty) ...[
              const SizedBox(height: SoftSpacing.sm),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: SoftTypography.body
                    .copyWith(color: tokens.textSecondary),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: SoftSpacing.xl),
              SoftButton(
                label: actionLabel!,
                onPressed: onAction,
                compact: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
